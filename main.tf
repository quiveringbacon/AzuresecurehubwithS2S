provider "azurerm" {
  features {
  }
}

#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "C-home_public_ip" {
    description = "Your home public ip address"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
}

#vwan and hub
resource "azurerm_virtual_wan" "vwan1" {
  name                = "vwan1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
    timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

resource "azurerm_virtual_hub" "vhub1" {
  name                = "vhub1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  address_prefix      = "10.0.0.0/16"
    timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_vpn_gateway" "hubvpngw" {
  resource_group_name = azurerm_resource_group.RG.name
  name                = "hubvpngw"
  location            = azurerm_resource_group.RG.location
  virtual_hub_id      = azurerm_virtual_hub.vhub1.id
}

data "azurerm_vpn_gateway" "hubpip" {
  name                = azurerm_vpn_gateway.hubvpngw.name
  resource_group_name = azurerm_resource_group.RG.name
  
}
/*
output "azurerm_vpn_gateway_id" {
  value = data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]
}
*/
resource "azurerm_vpn_site" "onprem" {
  device_vendor       = "Azure"
  location            = azurerm_resource_group.RG.location
  name                = "onprem"
  resource_group_name = azurerm_resource_group.RG.name
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  link {
    ip_address    = azurerm_public_ip.onpremvpngw-pip.ip_address
    name          = "onpremlink"
    provider_name = "Azure"
    speed_in_mbps = 10
    bgp {
      asn             = 65002
      peering_address = azurerm_virtual_network_gateway.onpremvpngw.bgp_settings[0].peering_addresses[0].default_addresses[0]
    }
  }
}
resource "azurerm_vpn_gateway_connection" "onpremconnection" {
  internet_security_enabled = true
  name                      = "Connection-onprem"
  remote_vpn_site_id        = azurerm_vpn_site.onprem.id
  vpn_gateway_id            = azurerm_vpn_gateway.hubvpngw.id
  vpn_link {
    bgp_enabled      = true
    name             = "onpremlink"
    shared_key       = "vpn123"
    vpn_site_link_id = azurerm_vpn_site.onprem.link[0].id
  }
  
}

#spoke vnets
resource "azurerm_virtual_network" "spoke1-vnet" {
  address_space       = ["10.150.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke1-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.150.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.150.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_virtual_network" "spoke2-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke2-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.250.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.250.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

resource "azurerm_virtual_network" "onprem-vnet" {
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "192.168.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "192.168.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#vnet connections to hub
resource "azurerm_virtual_hub_connection" "tospoke1" {
  name                      = "tospoke1"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
}
resource "azurerm_virtual_hub_connection" "tospoke2" {
  name                      = "tospoke2"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnet.id
}

#NSG
resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_network_security_rule" "spokevnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "spoke-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.spokevnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#Firewall and policy
resource "azurerm_firewall_policy" "azfwpolicy" {
  name                = "azfw-policy"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}
resource "azurerm_firewall_policy_rule_collection_group" "azfwpolicyrcg" {
  name               = "azfwpolicy-rcg"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id
  priority           = 500
network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}
resource "azurerm_firewall" "azfw" {
  name                = "AzureFirewall"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  sku_name            = "AZFW_Hub"
  sku_tier            = "Premium"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.vhub1.id
    public_ip_count = 1
  }
 
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#Public ip's
resource "azurerm_public_ip" "spoke1vm-pip" {
  name                = "spoke1vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_public_ip" "spoke2vm-pip" {
  name                = "spoke2vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_public_ip" "onpremvpngw-pip" {
  name                = "onpremvpngw-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_public_ip" "onpremvm-pip" {
  name                = "onpremvm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#vpngw
resource "azurerm_virtual_network_gateway" "onpremvpngw" {
  name                = "onpremVPNGW"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  type     = "Vpn"
  sku           = "VpnGw1"
  enable_bgp    = true
  bgp_settings {
    asn = "65002"
  }
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onpremvpngw-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[1]
    
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#lng
resource "azurerm_local_network_gateway" "vwanlng" {
  #address_space       = ["10.0.0.0/16", "10.250.0.0/16"]
  gateway_address     = data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]
  location            = azurerm_resource_group.RG.location
  name                = "vwanlng"
  resource_group_name = azurerm_resource_group.RG.name
  bgp_settings {
    asn = "65515"
    bgp_peering_address = data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips[0]
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#vpn connection
resource "azurerm_virtual_network_gateway_connection" "to-azure" {
  local_network_gateway_id   = azurerm_local_network_gateway.vwanlng.id
  location                   = azurerm_resource_group.RG.location
  name                       = "to-vwan"
  resource_group_name        = azurerm_resource_group.RG.name
  shared_key                 = "vpn123"
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onpremvpngw.id
  enable_bgp = true
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#route table for home access
resource "azurerm_route_table" "RT" {
  name                          = "to-home"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  disable_bgp_route_propagation = false

  route {
    name           = "tohome"
    address_prefix = "${var.C-home_public_ip}/32"
    next_hop_type  = "Internet"
    
  }
  
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke1defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke2defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}
resource "azurerm_subnet_route_table_association" "ononpremdefaultsubnet" {
  subnet_id      = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
}

#vnic's
resource "azurerm_network_interface" "spoke1vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke1vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke1vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_network_interface" "spoke2vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke2vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke2vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_network_interface" "onpremvm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "onpremvm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremvm-pip.id
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}

#VM's
resource "azurerm_windows_virtual_machine" "spoke1vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke1vm"
  network_interface_ids = [azurerm_network_interface.spoke1vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2016-datacenter-gensecond"
    version   = "latest"
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke1vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspoke1vmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke1vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_windows_virtual_machine" "spoke2vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke2vm"
  network_interface_ids = [azurerm_network_interface.spoke2vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2016-datacenter-gensecond"
    version   = "latest"
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke2vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspokevmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke2vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_windows_virtual_machine" "onpremvm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "onpremvm"
  network_interface_ids = [azurerm_network_interface.onpremvm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2016-datacenter-gensecond"
    version   = "latest"
  }
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killonpremvmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killonpremvmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.onpremvm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "1h"
    read = "1h"
    update = "1h"
    delete = "1h"
  }
  
}