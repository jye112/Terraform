resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Network
module "network" {
  source                = "../modules/network"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  vnet_name             = "test-vnet"
  vnet_address_space    = ["10.0.0.0/16"]
  subnet_name           = ["test-subnet-01", "test-subnet-02"]
  subnet_address_prefix = ["10.0.0.0/24", "10.0.1.0/24"]

  depends_on = [
    azurerm_resource_group.rg
  ]
}

# NSG
module "nsg" {
  source              = "../modules/nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  nsg_name            = "test-nsg"

  rules = [
    {
      name                       = "SSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "22"
    },
    {
      name                       = "RDP"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "3389"
    },
    {
      name                       = "HTTP"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "Internet"
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "80,8080"
    },

  ]

  # if you want attach nsg to subnet, set true and subnet_id
  # if you don't want attach nsg to subnet, set false alone
  attach_to_subnet = [true, module.network.subnet_id[0]]
  
  depends_on = [
    azurerm_resource_group.rg
  ]
}

module "linux_public_ip" {
  source                = "../modules/pip"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  pip_name              = "linux-vm-pip"
  pip_allocation_method = "Static"
  pip_sku               = "Standard"
  pip_av_zone           = "No-Zone"

  depends_on = [
    azurerm_resource_group.rg
  ]
}

module "linux" {
  source               = "../modules/linux-server"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = var.location
  linux_avset          = "test-linux-avset"
  linux_vm_num         = 2
  linux_vm_name        = "test-linux-vm"
  vm_size              = "Standard_D2s_v3"
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  os_disk_sku          = "Standard_LRS"
  publisher            = "Canonical"
  offer                = "UbuntuServer"
  sku                  = "18.04-LTS"
  os_tag               = "latest"
  subnet_id            = module.network.subnet_id[0]
  public_ip_address_id = module.linux_public_ip.public_ip_address_id
  
  depends_on = [
    azurerm_resource_group.rg
  ]
}

module "appgw_ip" {
  source                = "../modules/pip"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  pip_name              = "appgw-pip"
  pip_allocation_method = "Static"
  pip_sku               = "Standard"
  pip_av_zone           = "No-Zone"

  depends_on = [
    azurerm_resource_group.rg
  ]
}

module "appgw" {
  source                         = "../modules/appgw"
  resource_group_name            = azurerm_resource_group.rg.name
  location                       = var.location
  appgw_name                     = "test-appgw"
  sku_name                       = "Standard_v2"
  sku_tier                       = "Standard_v2"
  gateway_ip_configuration_name  = "appGatewayIpConfig"
  subnet_id                      = module.network.subnet_id[1]
  http_frontend_port_name        = "port_80"
  http_frontend_port             = 80
  frontend_ip_configuration_name = "appGwPublicFrontendIp"
  appgw_pip_id                   = module.appgw_ip.public_ip_address_id
  backend_address_pool_name      = "appgw-backend-pool"
  backend_http_setting_name      = "appgw-backend-setting"
  backend_http_setting_port      = 80
  backend_http_setting_protocol  = "Http"
  http_listener_name             = "appgw-listener"
  http_listener_protocol         = "Http"
  http_request_routing_rule_name = "appgw-routing-rule"
  http_request_routing_rule_type = "Basic"
  backend_vm_name                = "test-linux-vm"
  backend_vm_num                 = 2

  depends_on = [
    azurerm_resource_group.rg
  ]
}
