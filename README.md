# Azure securehub with S2S

This creates a vwan securehub and a couple of spoke vnets with VM's connected to the vhub but adds an onprem vnet with a S2S tunnel to the vhub. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. You'll need to go to the hub security configuration through firewall manager to change the settings for internet and/or private traffic to go through the firewall.
