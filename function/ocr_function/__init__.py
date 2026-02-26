import logging
import json
import os
from datetime import datetime

import azure.functions as func
from azure.storage.blob import BlobServiceClient
from azure.ai.vision.imageanalysis import ImageAnalysisClient
from azure.ai.vision.imageanalysis.models import VisualFeatures
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import HttpResponseError
from applicationinsights import TelemetryClient

# init Application Insights pour le monitoring
tc = TelemetryClient(os.environ.get("APPINSIGHTS_INSTRUMENTATIONKEY", ""))


def main(myblob: func.InputStream) -> None:
    """
    Fonction déclenchée automatiquement quand une image est uploadée
    dans le container 'images-input'.
    Elle appelle Azure AI Vision pour faire l'OCR et sauvegarde le résultat.
    """
    blob_name = myblob.name.split("/")[-1]
    logging.info(f"[OCR] Traitement de l'image : {blob_name} ({myblob.length} bytes)")

    # log de démarrage dans App Insights
    tc.track_event("ocr_started", {"blob_name": blob_name})

    try:
        # récupérer les configs depuis les env vars (injectées par Terraform)
        vision_endpoint = os.environ["VISION_ENDPOINT"]
        vision_key = os.environ["VISION_API_KEY"]
        storage_account = os.environ["STORAGE_ACCOUNT_NAME"]
        results_container = os.environ["RESULTS_CONTAINER"]

        # lire le contenu de l'image
        image_data = myblob.read()

        # appel à Azure AI Vision pour l'OCR
        vision_client = ImageAnalysisClient(
            endpoint=vision_endpoint,
            credential=AzureKeyCredential(vision_key)
        )

        logging.info(f"[OCR] Appel Azure AI Vision pour {blob_name}...")

        result = vision_client.analyze(
            image_data=image_data,
            visual_features=[VisualFeatures.READ],
        )

        # extraire tout le texte détecté
        extracted_text = ""
        if result.read is not None:
            for block in result.read.blocks:
                for line in block.lines:
                    extracted_text += line.text + "\n"

        logging.info(f"[OCR] Texte extrait ({len(extracted_text)} caractères)")

        # construire le JSON de résultat
        ocr_result = {
            "source_image": blob_name,
            "processed_at": datetime.utcnow().isoformat(),
            "text_extracted": extracted_text.strip(),
            "char_count": len(extracted_text.strip()),
            "status": "success"
        }

        # sauvegarder le résultat dans le container résultats
        result_blob_name = blob_name.rsplit(".", 1)[0] + "_ocr_result.json"

        # utiliser la managed identity via DefaultAzureCredential
        from azure.identity import DefaultAzureCredential
        credential = DefaultAzureCredential()

        blob_service = BlobServiceClient(
            account_url=f"https://{storage_account}.blob.core.windows.net",
            credential=credential
        )

        container_client = blob_service.get_container_client(results_container)
        container_client.upload_blob(
            name=result_blob_name,
            data=json.dumps(ocr_result, ensure_ascii=False, indent=2),
            overwrite=True
        )

        logging.info(f"[OCR] Résultat sauvegardé : {result_blob_name}")

        # log succès dans App Insights
        tc.track_event("ocr_completed", {
            "blob_name": blob_name,
            "char_count": str(len(extracted_text.strip())),
            "result_file": result_blob_name
        })
        tc.track_metric("ocr_chars_extracted", len(extracted_text.strip()))
        tc.flush()

    except HttpResponseError as e:
        # erreur côté Azure AI Vision
        logging.error(f"[OCR] Erreur Vision API : {e.message}")
        tc.track_exception()
        tc.track_event("ocr_failed", {"blob_name": blob_name, "error": str(e.message)})
        tc.flush()
        raise

    except Exception as e:
        logging.error(f"[OCR] Erreur inattendue sur {blob_name} : {str(e)}")
        tc.track_exception()
        tc.flush()
        raise
