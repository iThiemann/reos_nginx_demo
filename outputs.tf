############################################################
# Outputs
############################################################

# Public IP so you can test nginx in the browser
output "public_ip_address" {
  description = "Public IP of the nginx VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

# Convenient full URL
output "nginx_url" {
  description = "HTTP URL to the nginx hello world page"
  value       = "http://${azurerm_public_ip.public_ip.ip_address}"
}

