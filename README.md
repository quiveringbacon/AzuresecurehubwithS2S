# Azure securehub with S2S

This creates a vwan securehub and a couple of spoke vnets with VM's connected to the vhub but adds an onprem vnet with a S2S tunnel to the vhub. This creates a log analytics workspace and diagnostic settings for the firewall logs. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. NSG's are placed on the default subnets of each vnet allowing RDP access from your public ip. This also creates a logic app that will delete the resource group in 24hrs.

This uses a static route in the default table to send internet traffic to the hub firewall.

![wvanlabwithS2SandFW](https://user-images.githubusercontent.com/128983862/232787181-3aec5303-6e0a-4b0a-8390-0e08257d0eb8.png)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzuresecurehubwithS2S.git ./terraform".

Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.
