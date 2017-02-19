#
# Deploy_ReferenceArchitecture.ps1
#
param(
  [Parameter(Mandatory=$true)]
  $SubscriptionId,

  [Parameter(Mandatory=$true)]
  $Location,
  
  [Parameter(Mandatory=$false)]
  [ValidateSet("Prepare", "Infrastructure", "AzureADDS", "WebTier", "Workload", "DomainJoin")]
  $Mode = "Prepare"
)

$ErrorActionPreference = "Stop"

$templateRootUriString = $env:TEMPLATE_ROOT_URI
if ($templateRootUriString -eq $null) {
  $templateRootUriString = "https://raw.githubusercontent.com/mspnp/template-building-blocks/master/"
}

if (![System.Uri]::IsWellFormedUriString($templateRootUriString, [System.UriKind]::Absolute)) {
  throw "Invalid value for TEMPLATE_ROOT_URI: $env:TEMPLATE_ROOT_URI"
}

Write-Host
Write-Host "Using $templateRootUriString to locate templates"
Write-Host

$templateRootUri = New-Object System.Uri -ArgumentList @($templateRootUriString)


$loadBalancerTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/loadBalancer-backend-n-vm/azuredeploy.json")
$virtualNetworkTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vnet-n-subnet/azuredeploy.json")
$virtualMachineTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/multi-vm-n-nic-m-storage/azuredeploy.json")
$dmzTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/dmz/azuredeploy.json")
$nsgTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/networkSecurityGroups/azuredeploy.json")
$virtualNetworkGatewayTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vpn-gateway-vpn-connection/azuredeploy.json")
$virtualMachineExtensionsTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/virtualMachine-extensions/azuredeploy.json")

# Local templates
$vnetPeeringTemplate = [System.IO.Path]::Combine($PSScriptRoot, "templates\azure\vnetpeering\azuredeploy.json")
$mgmtVnetPeeringTemplate = [System.IO.Path]::Combine($PSScriptRoot, "templates\azure\vnetpeering-mgmt-vnet.json")

#Azure Quick Start template file
$applicationGatewayTemplate = New-Object System.Uri("https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-application-gateway-create/azuredeploy.json")

# Azure Parameter Files
$azureAddsVirtualMachinesParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualMachines-adds.parameters.json")
$azureCreateAddsForestExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\create-adds-forest-extension.parameters.json")
$azureAddAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\add-adds-domain-controller.parameters.json")
$azureVirtualNetworkGatewayParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetworkGateway.parameters.json")
$azureVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetwork.parameters.json")
$azureMgmtVirtualNetworkParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-vnet.parameters.json")
$azureVirtualNetworkDnsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\virtualNetwork-adds-dns.parameters.json")
$webLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-web.parameters.json")
$bizLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-biz.parameters.json")
$dataLoadBalancerParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\loadBalancer-data.parameters.json")
$azureOperationVmDomainJoinExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\ops-vm-domain-join.parameters.json")
$azureOperationalVmEnableWindowsAuthExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\ops-vm-enable-windows-auth.parameters.json")
$azureMgmtVmDomainJoinExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-vm-domain-join.parameters.json")
$azureMgmtVmEnableWindowsAuthExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-vm-enable-windows-auth.parameters.json")
$nsgParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-subnet-nsg.parameters.json")
$opsvnetnsgParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\ops-vent-nsgs.json")
$applicationGatewayParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\application-gateway.parameters.json")
$operationalVnetPeeringParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\operational-vnet-peering.parameters.json")
$mgmtVnetPeeringParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-vnet-peering.parameters.json")
$mgmtVMJumpboxParametersFile  = [System.IO.Path]::Combine($PSScriptRoot, "parameters\azure\mgmt-virtualmachine.parameters.json")


# Azure ADDS Deployments
#$azureNetworkResourceGroupName = "azure-network-rg"
$azureNetworkResourceGroupName = "netinfra-rg"
$workloadResourceGroupName = "azure-workload-rg"
$addsResourceGroupName = "azure-operational-adds-rg"



#########Remove 
$SubscriptionId = "d5a40ca2-4f53-416b-a510-659eb51b57fc"

# Login to Azure and select your subscription
Login-AzureRmAccount -SubscriptionId $SubscriptionId  #| Out-Null


##########################################################################
# Deploy Vnet and VPN Infrastructure in cloud
##########################################################################

if ($Mode -eq "Infrastructure" -Or $Mode -eq "Prepare") {

    
	#Write-Host "Creating Networking resource group..."
 #   $azureNetworkResourceGroup = New-AzureRmResourceGroup -Name $azureNetworkResourceGroupName -Location $Location

	$azureNetworkResourceGroup = Get-AzureRmResourceGroup -Name $azureNetworkResourceGroupName

	
	## Deploy management vnet network infrastructure
 #   Write-Host "Deploying management virtual network..."
 #   New-AzureRmResourceGroupDeployment -Name "azure-mgmt-rg-deployment" -ResourceGroupName $azureNetworkResourceGroupName.ResourceGroupName `
 #       -TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $azureMgmtVirtualNetworkParametersFile
	

	## Deploy operational vnet network infrastructure
 #   Write-Host "Deploying operational virtual network..."
 #   New-AzureRmResourceGroupDeployment -Name "operational-vnet-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
 #          -TemplateUri $virtualNetworkTemplate.AbsoluteUri -TemplateParameterFile $azureVirtualNetworkParametersFile

   
	#Create VNet Peerings
	#Write-Host "Deploying Operational VNet Peering to Mgmt VNet..."
	#New-AzureRmResourceGroupDeployment -Name "operational-vnet-deployment" -ResourceGroupName $azureNetworkResourceGroupName.ResourceGroupName `
	#-TemplateFile $vnetPeeringTemplate  -TemplateParameterFile $mgmtVnetPeeringParametersFile


	#Write-Host "Deploying Mgmt VNet Peering to Operational VNet..."
	#New-AzureRmResourceGroupDeployment -Name "azure-mgmt-rg-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
	#-TemplateFile $vnetPeeringTemplate -TemplateParameterFile $operationalVnetPeeringParametersFile

	#Create NSGs for management VNET
	# Write-Host "Deploying Management NSGs"
	# New-AzureRmResourceGroupDeployment -Name "nsg-deployment" -ResourceGroupName $azureNetworkResourceGroupName.ResourceGroupName `
 #       -TemplateUri $nsgTemplate.AbsoluteUri -TemplateParameterFile $nsgParametersFile


	##Deploy VPN Gateway
 #   Write-Host "Deploying Azure Virtual Private Network Gateway..."
	#New-AzureRmResourceGroupDeployment -Name "operational-vpn-gateway-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
 #       -TemplateUri $virtualNetworkGatewayTemplate.AbsoluteUri -TemplateParameterFile $azureVirtualNetworkGatewayParametersFile

	
	#############Fix this
	#Deploy App Gateway
	Write-Host "Deploying Inet facing App Gateway..."
    New-AzureRmResourceGroupDeployment -Name "operational-agw-deployment" -ResourceGroupName $azureNetworkResourceGroup.ResourceGroupName `
           -TemplateUri $applicationGatewayTemplate.AbsoluteUri -TemplateParameterFile $applicationGatewayParametersFile

	
}


###########################################################################
## Deploy ADDS forest in cloud
###########################################################################

#if ($Mode -eq "AzureADDS" -Or $Mode -eq "Prepare") {
#    # Deploy AD tier in azure

#    # Creating ADDS resource group
#    Write-Host "Creating ADDS resource group..."
#    $addsResourceGroup = New-AzureRmResourceGroup -Name $addsResourceGroupName -Location $Location

#    # "Deploying ADDS servers..."
#    Write-Host "Deploying ADDS servers..."
#    New-AzureRmResourceGroupDeployment -Name "operational-adds-deployment" `
#		-ResourceGroupName $addsResourceGroup.ResourceGroupName  -TemplateUri $virtualMachineTemplate.AbsoluteUri `
#		-TemplateParameterFile $azureAddsVirtualMachinesParametersFile

#    # Remove the Azure DNS entry since the forest will create a DNS forwarding entry.
#    Write-Host "Updating virtual network DNS servers..."
#    New-AzureRmResourceGroupDeployment -Name "operational-azure-dns-vnet-deployment" `
#        -ResourceGroupName $addsResourceGroup.ResourceGroupName -TemplateUri $virtualNetworkTemplate.AbsoluteUri `
#        -TemplateParameterFile $azureVirtualNetworkDnsParametersFile

#    Write-Host "Creating ADDS forest..."
#    New-AzureRmResourceGroupDeployment -Name "operational-azure-adds-forest-deployment" `
#        -ResourceGroupName $addsResourceGroup.ResourceGroupName `
#        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $azureCreateAddsForestExtensionParametersFile

#    Write-Host "Creating ADDS domain controller..."
#    New-AzureRmResourceGroupDeployment -Name "operational-azure-adds-dc-deployment" `
#        -ResourceGroupName $addsResourceGroup.ResourceGroupName `
#        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $azureAddAddsDomainControllerExtensionParametersFile

#}


############################################################################
### Deploy web tier workload loadbalancers & VMs
############################################################################

#if ($Mode -eq "Workload" -Or $Mode -eq "Prepare") {

#    Write-Host "Creating workload resource group..."
#    $workloadResourceGroup = New-AzureRmResourceGroup -Name $workloadResourceGroupName -Location $Location

#		### Deploy management vnet network infrastructure
#    Write-Host "Deploying management jumpbox..."
#    New-AzureRmResourceGroupDeployment -Name "azure-mgmt-rg-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $mgmtVMJumpboxParametersFile

#	#Deploy workload tiers
#    Write-Host "Deploying web load balancer..."
#    New-AzureRmResourceGroupDeployment -Name "operational-web-deployment"  `
#		-ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $webLoadBalancerParametersFile

#    Write-Host "Deploying biz load balancer..."
#    New-AzureRmResourceGroupDeployment -Name "operational-biz-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $bizLoadBalancerParametersFile

#    Write-Host "Deploying data load balancer..."
#    New-AzureRmResourceGroupDeployment -Name "operational-data-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $loadBalancerTemplate.AbsoluteUri -TemplateParameterFile $dataLoadBalancerParametersFile

# }

#############################################################################
#### Domain join VMs
#############################################################################

#if ($Mode -eq "DomainJoin" -Or $Mode -eq "Prepare") {

#    ##Domain Join Operational Workload VMs

#    #Get Operational Resource groups
#	Write-Host "Get Operational resource group..."
#    $workloadResourceGroup = Get-AzureRmResourceGroup -Name $workloadResourceGroupName

#	##Domain join operational machines
#	Write-Host "Joining Operational Vms to domain..."
#    New-AzureRmResourceGroupDeployment -Name "vm-join-domain-deployment" `
#        -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $azureOperationVmDomainJoinExtensionParametersFile

#	#Enable windows authentication
#    Write-Host "Enable Windows Auth for Operational Vms..."
#    New-AzureRmResourceGroupDeployment -Name "vm-enable-windows-auth" `
#        -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
#        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $azureOperationalVmEnableWindowsAuthExtensionParametersFile
    
# }







