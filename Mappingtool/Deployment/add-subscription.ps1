[CmdletBinding()]
param (
    [parameter (Mandatory=$true)]
    [string] $webhookrgWebhook,

    [parameter (Mandatory=$true)]
    [string]$webhookrgdelWebhook
)


Write-Output "----------------------------------------------------------------------------------------------------------"
Write-Output "                                                                                                          "
Write-Output "                           Only subscription in the same AAD tenant are allowed                           "
Write-Output "                                                                                                          "
Write-Output "----------------------------------------------------------------------------------------------------------"

    Login-AzAccount

    $subscriptions = Get-AzSubscription
    $hassubscription = @{}

    $i = 1;
    foreach ($subscription in $subscriptions)
    {
        Write-Output "$i for subscription $($subscription.Name)"    
        $hassubscription[$i] = "$($subscription.Id);$($subscription.TenantId)"
        $i++
    }
    

    [int]$selsubs = Read-Host -Prompt "Please enter the subscription number for you deployment"


Write-Output "-----------------------------------------------------------------------"
Write-Output " "
Write-Output "                       Start resource deployment                       "
Write-Output " "
Write-Output "-----------------------------------------------------------------------"

if($hassubscription.ContainsKey($selsubs))
{
    $splitselsub = $hassubscription.Item($selsubs).Split(";")
    $selectedsubscription = $splitselsub[0] 
    Select-AzSubscription -Subscription $splitselsub[0]   

    #region Global Parameters for deployment
        # Variables change is not supported!
            
        Write-Output "- Define global variables"

            $TenantID = $splitselsub[1]
            $RG = "RG-MappingTool"
            $ToolName = "AppMT"
            $AppLocation = "West Europe"        
            
        Write-Output "DONE"
        Write-Output " "

    #endregion   

    #region Deploy solution resourcegroup if not exist

    Write-Output "- Deploy resourcegroup $RG"
    try {
                        
        $deploymentrg = ""

        if (Get-AzResourceGroup -Name $RG -ErrorAction SilentlyContinue) {
            Write-Output "Azure resource group exist."
            $deploymentrg = Get-AzResourceGroup -Name $RG
        }
        else {
            Write-Output "Create Azure resource group $RG"

            $tags = @{
                "Product"="Azure Mappingtool by. Hannes Lagler-Gruener"; 
                "Details"="Visit the Github Account (https://github.com/Lagler-Gruener/AzureSolutions/tree/master/Mappingtool) to get more information."
            }

            $deploymentrg = New-AzResourceGroup -Name $RG -Location $AppLocation -Tag $tags            
        }  
        
        if($deploymentrg -eq "")
        {
            throw "Error resourcegroup not deployed! Script stopped"
        }

        Write-Output "DONE"
        Write-Output " "
    }
    catch {
        throw "Error in resourcegroup deployment. Error message $($_.Exception.Message)"
    }

    #endregion

    #region create event subscriptions

        try {
                                    
            Write-Output "Register Resource provider Microsoft.EventGrid"
                Register-AzResourceProvider -ProviderNamespace "Microsoft.EventGrid"

                $registered = $false

                do {
                    if ((Get-AzResourceProvider -Location $AppLocation | where {$_.ProviderNamespace -eq "Microsoft.EventGrid"}).RegistrationState -eq "Registered") {
                        $registered = $true    
                    }

                } until ($registered)                            

            Write-Output "Create event subscription 'add event'"

                $includedEventTypes = "Microsoft.Resources.ResourceWriteSuccess"
                $AdvFilter1=@{operator="StringIn"; key="data.operationName"; Values=@('Microsoft.Resources/subscriptions/resourceGroups/write','Microsoft.Resources/tags/write')} 
                
                $rgeventsubrgadd = New-AzEventGridSubscription -EventSubscriptionName "$($ToolName)-event-rg-add" `
                                                            -EndpointType webhook `
                                                            -Endpoint $webhookrgWebhook `
                                                            -IncludedEventType $includedEventTypes `
                                                            -AdvancedFilter @($AdvFilter1) `
                                                            -ResourceGroupName $($deploymentrg.ResourceGroupName)
                
            Write-Output "DONE"
            Write-Output " "                                          
            

            Write-Output "Create event subscription 'delete event'"

                $includedEventTypes = "Microsoft.Resources.ResourceDeleteSuccess"
                $AdvFilter1=@{operator="StringIn"; key="data.operationName"; Values=@('Microsoft.Resources/subscriptions/resourcegroups/delete')} 
                                                                                    
                $rgeventsubrgdelete = New-AzEventGridSubscription -EventSubscriptionName "$($ToolName)-event-rg-delete" `
                                                                -EndpointType webhook `
                                                                -Endpoint $webhookrgdelWebhook `
                                                                -IncludedEventType $includedEventTypes `
                                                                -AdvancedFilter @($AdvFilter1) `
                                                                -ResourceGroupName $($deploymentrg.ResourceGroupName)
            Write-Output "DONE"
            Write-Output " " 
        }
        catch {
            throw "Error configure eventsubscription resources. Error: $_."                                             
        }                                                                                

    #endregion

}