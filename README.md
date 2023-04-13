# Azure securehub with S2S

This creates a vwan securehub and a couple of spoke vnets with VM's connected to the vhub but adds an onprem vnet with a S2S tunnel to the vhub. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. NSG's are placed on the default subnets of each vnet allowing RDP access from your public ip.

You'll need to go to the hub security configuration through firewall manager to change the settings for internet and/or private traffic to go through the firewall.

![wvanlabwithS2SandFW](https://user-images.githubusercontent.com/128983862/231878701-f59297f9-c635-4a0e-8e40-1c359fcde1fd.png)
