# Checks for connected Azure account, if none connected to PS session then prompt with interactive login
$azureAccount = Get-AzContext
if (!$azureAccount)
    {Connect-AzAccount}

# Prompt for resource group name and add to EastUS location
$resourceGroup = Read-Host -Prompt 'Please enter a name for the test environment'
New-AzResourceGroup -name $resourceGroup -location EastUS

# Create virtual network, subnet ID, and public IP address
$mySubnet = New-AzVirtualNetworkSubnetConfig -Name $resourceGroup'Subnet' -AddressPrefix 10.10.0.0/24
$virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location EastUS -Name $resourceGroup'Network' -AddressPrefix 10.10.0.0/16 -Subnet $mySubnet
$publicIP = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location EastUS -AllocationMethod Static -IdleTimeoutInMinutes 5 -Name $resourceGroup'PublicIP'

# Get assigned public IP and create inbound SSH firewall exception for it
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name $resourceGroup'_SSHAllow' -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix '10.10.0.0/24' -DestinationPortRange 22 -Access Allow

# Create network security group, add previous rule
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location EastUS -Name $resourceGroup'SecurityGroup' -SecurityRules $nsgRuleSSH

# Create network interface for VM, associate with public IP and network security group
$nic = New-AzNetworkInterface -Name $resourceGroup'Nic' -ResourceGroupName $resourceGroup -Location EastUS -SubnetId $virtualNetwork.Subnets[0].Id -PublicIpAddressId $publicIP.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object, note that auth is handled by SSH key pair
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a virtual machine configuration. This sets the type of VM, disables password auth to force SSH auth, and designates Ubuntu 16.04. It then attaches the previously created NIC.
$vmConfig = New-AzVMConfig -VMName $resourceGroup'VM' -VMSize "Standard_B1ls" | `
Set-AzVMOperatingSystem -Linux -ComputerName $resourceGroup'VM' -Credential $cred -DisablePasswordAuthentication | `
Set-AzVMSourceImage -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "16.04-LTS" -Version "latest" | `
Add-AzVMNetworkInterface -Id $nic.Id

# Configure the SSH key, assumes .ssh folder is in directory this script is run from
$sshPublicKey = cat ~/.ssh/id_rsa.pub
Add-AzVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

# Create the VM
New-AzVM -ResourceGroupName $resourceGroup -Location eastus -VM $vmConfig