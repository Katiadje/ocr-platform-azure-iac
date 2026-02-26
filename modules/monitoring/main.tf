# modules/monitoring/main.tf
# Application Insights pour les logs et le monitoring de la Function

# workspace Log Analytics (requis pour Application Insights v2)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # 30 jours suffisant, augmenter en prod

  tags = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}

# alerte sur les erreurs de la function (taux d'erreur > 5%)
resource "azurerm_monitor_metric_alert" "function_errors" {
  name                = "alert-function-errors-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  # on cible l'app insights
  scopes      = [azurerm_application_insights.main.id]
  description = "Déclenche une alerte si le taux d'erreur dépasse 5%"
  severity    = 2

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  tags = var.tags
}
