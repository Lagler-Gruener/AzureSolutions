  <#
    .SYNOPSIS
        The core script for the whole solution.
        
    .DESCRIPTION
         Script was executed by Azure WebHook (webhookrg, webhookad).
         Script check the following (webhookrg):
            1.) Get rbac mapping from mapping table 
            2.) Get configuration from configuration table
            3.) Execute the script "TaskNewAADGroup"
            4.) Based on the outcome from above, add message to "on-premqueue" queue

        Script check the following (webhookad):
            1.) Get configuration from configuration table
            2.) Add information to the "on-premqueue" queue
        
    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
                       -Az.Accounts  (tested with Version: 1.7.5)
                       -Az.Storage   (tested with Version: 1.14.0)
                       -Az.Resources (tested with Version: 1.13.0)
                       -AzTable      (tested with Version: 2.0.3)             
        
        Required permissions:
            - Azure AD: User Administrator
            - Subscription: Contributor Permission
            - Storage Account/Queue: Storage Queue Data Contributor
#>

#Required Custom Module
using module MappingTool

[CmdletBinding()]
param (
    [parameter (Mandatory=$false)]
    [object] $WebhookData,

    [parameter (Mandatory=$false)]
    $ChannelURL
)

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-UnEnc

#endregion
#######################################################################################################################

#######################################################################################################################
#region Functions

function CallRBCreateAADGroup()
{
    param (
        [parameter (Mandatory=$true)]
        [object] $aadgroupparameters,
        [parameter (Mandatory=$false)]
        [string] $AZRGName
    )


    $disableresult = Disable-AzContextAutosave –Scope Process

    $params = @{"Source"="RG";"AZRGName"=$AZRGName;"AADGroupParameters"=$aadgroupparameters}    

    return Start-AzAutomationRunbook `
                    –AutomationAccountName $global:ConfAutoAcc `
                    –Name 'TaskNewAADGroup' `
                    -ResourceGroupName $global:ConfApplRG `
                    –Parameters $params
}

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start      

    try 
    {  
                 
        Write-Output "Connect to Azure"
        Write-Output "----------------------------------------------------------------"
            $loginazureresult = Login-Azure   
        
        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg
            Write-Output "----------------------------------------------------------------"

            Write-Output "Create Storage Account context"
            Write-Output "----------------------------------------------------------------"
                $ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount   

                if($null -ne $ctx)
                {
                    $resultmapping = ""
                    $resultaddmsgtoqueue = ""
                    Write-Output "----------------------------------------------------------------"

                    Write-Output "Check Webhook type"
                    Write-Output "----------------------------------------------------------------"
                    if($WebhookData.WebhookName -eq $global:HCRGWebhook)
                    {
                        Write-Output "Webhook type is $global:HCRGWebhook"
                        Write-Output "----------------------------------------------------------------"
                        #region Script

                        Write-Output "Convert Webhook body to JSON"
                        Write-Output "----------------------------------------------------------------"
                            $RequestBody = $WebhookData.RequestBody | ConvertFrom-Json
                            $requestdata = $RequestBody.data
                        Write-Output "----------------------------------------------------------------"
                        
                        Write-Output "Get resourcegroup $($requestdata.resourceUri)"
                        Write-Output "----------------------------------------------------------------"
                            $newrg = Get-AzResourceGroup -Id $requestdata.resourceUri
                        Write-Output "----------------------------------------------------------------"

                        Write-Output "Check ResourceGroup tags"
                        Write-Output "----------------------------------------------------------------"
                        if($newrg.Tags.ContainsKey($global:ConfRGReqTag))
                        {
                            Write-Output "Split tag value by seperator ,"
                            $option = [System.StringSplitOptions]::RemoveEmptyEntries
                            $permissions = ($newrg.Tags.$global:ConfRGReqTag).split(",", $option)


                            foreach($permission in $permissions)
                            {
                                try
                                {
                                    if($null -ne $permission)
                                    {
                                        Write-Output "Get mapping result for permission: $permission"

                                        #Execute Function Get-RBAC-Mapping (you can find that Function in the MappingTool module)
                                        $resultmapping = Get-RBAC-Mapping `
                                                                -MappingTableName $global:ConfPermMappingTable `
                                                                -MappingTableRG $global:ConfApplRG `
                                                                -MappingTableStrAcc $global:ConfApplStrAcc `
                                                                -ConfigTableName $global:ConfConfigurationTable `
                                                                -ConfigTableRG $global:ConfApplRG `
                                                                -ConfigTableStrAcc $global:ConfApplStrAcc `
                                                                -mappingvalue $permission `
                                                                -RGName $newrg.ResourceGroupName `
                                                                -RequestType "RG"
                                    
                                        if($resultmapping.ReturnMsg -eq [ReturnCode]::Success)
                                        {
                                            Write-Output $resultmapping.LogMsg
                                            Write-Output "Return Parameter:"
                                            Write-Output $resultmapping.ReturnJsonParameters02

                                            $mappingresult =  $resultmapping.ReturnJsonParameters02 | ConvertFrom-Json

                                            if($mappingresult.State -eq "create")
                                            {
                                                #region New AAD Group will be created

                                                Write-Output "Execute Runbook TaskNewAADGroup"                                
                                                CallRBCreateAADGroup -aadgroupparameters $mappingresult `
                                                                    -AZRGName $newrg.ResourceGroupName

                                                Write-Output "Wait till AADGroup is created"
                                                do {                                    
                                                    Write-Output "Start Sleep 30 seconds"
                                                    Start-Sleep -Seconds 30 
                                                    
                                                    if((Get-AzAutomationJob -Id 3461965e-2fb8-48af-8653-fc6206a9a809 `
                                                                            -ResourceGroupName ACP-Demo-DokaApp `
                                                                            -AutomationAccountName AppMappingTool-automacc).Status -eq "Failed")
                                                    {
                                                        throw "Script execution failed!"
                                                    }
                                                    
                                                } while ((Get-Info-from-Config-Table -TableRowKey $mappingresult.AADGroupName `
                                                                                     -TablePartitionKey "RBACPerm" `
                                                                                     -TableName $global:ConfConfigurationTable `
                                                                                     -TableResourceGroup $global:ConfApplRG `
                                                                                     -TableStorageAccount $global:ConfApplStrAcc).ReturnParameter1 -eq "false")
                                            
                                                Write-Output "Created"                                
                                                Write-Output "Add new ResourceGroup group request into Azure storage queue"

                                                $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMsgQueue `
                                                                                        -StorageAccountName $global:ConfApplStrAcc `
                                                                                        -RequestType "RG" `
                                                                                        -ADGroupName $mappingresult.ADGroupName `
                                                                                        -ADOUPath $global:ConfOUPathRBACPerm `
                                                                                        -ADGroupDesc "AD Group created by mappingtool" `
                                                                                        -AADGroupName $mappingresult.AADGroupName `
                                                                                        -AADRoleID $mappingresult.RoleID

                                                if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                                {
                                                    Write-Output $resultaddmsgtoqueue.ReturnMsg                                    
                                                    Write-Output $resultaddmsgtoqueue.LogMsg
                                                }
                                                else {
                                                    #region Script Error
        
                                                    Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details"
                                                    Write-Error "Error in function Add-Msg-to-Queue."
                                                    Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
        
                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Add-Msg-to-Queue" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage $resultaddmsgtoqueue.LogMsg
        
                                                    #endregion
                                                }
                                                

                                                #endregion
                                            }
                                            elseif($mappingresult.State -eq "null")
                                            {
                                                Write-Output "The requested permission mapping isn't available. Please update the $global:ConfPermMappingTable table!"
                                            }
                                            elseif($mappingresult.State -eq "exist")
                                            {
                                                Write-Output "The permission is already set to the ResourceGroup"
                                            }
                                        }
                                        else {
                                            #region Script Error          
            
                                            Write-Error "Error durring get rbac mapping settings. (go to output for more details)"
                                            Write-Output "Error durring get rbac mapping settings."
                                            Write-Output "Error message: $($resultmapping.LogMsg)"
                                            Write-Output "----------------------------------------------------------------"
                                            
                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Get-RBAC-Mapping" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage $resultmapping.LogMsg
                                            #endregion
                                        }
                                    }
                                    else {
                                        Write-Output "No relevante permissions set."
                                    }

                                    Write-Output "##################################################################################"
                                }
                                catch
                                {
                                    Write-Error "Error in section CallRBCreateAADGroup. Error message: $($_.Exception.Message)"
                                }
                            }
                        }
                        else {
                            Write-Output "ResourceGroup have no valid Tag based on configuration (Configuration Tag Name: $($global:ConfRGReqTag))"
                            Write-Output "----------------------------------------------------------------"
                        }
                        #endregion
                    } 
                    elseif ($WebhookData.WebhookName -eq $global:HCAADWebhook)
                    {      
                        Write-Output "Webhook type is $global:HCAADWebhook"
                        Write-Output "----------------------------------------------------------------"
                    
                        #region Script
                        
                        Write-Output "Convert Webhook body to JSON"
                        Write-Output "----------------------------------------------------------------"
                            $RequestBody = $WebhookData.RequestBody | ConvertFrom-Json
                            $requestdata = $RequestBody.data.alertContext.SearchResults.tables[0].rows[0]
                        Write-Output "----------------------------------------------------------------"

                        $AADGroupName = $requestdata[1]
                        $AADGroupID = $requestdata[2]
                        $ADGroupName = $requestdata[1].tostring().tolower().replace($global:NSAADPerm.tolower(),$global:OnPremAADRolePerm)

                        Write-Output "New Azure AD group is created."
                        Write-Output "Get more details."
                        Write-Output "Type: $($requestdata[0])"
                        Write-Output "AAD GroupName: $AADGroupName"
                        Write-Output "AAD GroupID: $AADGroupID"
                        Write-Output "Initiated by: $($requestdata[3])"  
                        Write-Output "On-Prem AD GroupName: $ADGroupName"   
                    
                        

                        if($requestdata[0] -eq "Add group")
                        {
                            Write-Output "Add Information to configuration Table"
                            $addinfotableresult = Add-Info-to-Config-Table -AADGroupName  $AADGroupName.ToLower() `
                                                                           -AADGroupID $AADGroupID.ToLower() `
                                                                           -ADGroupName $ADGroupName.ToLower()`
                                                                           -TableName $global:ConfConfigurationTable `
                                                                           -TableResourceGroup $global:ConfApplRG `
                                                                           -TableStorageAccount $global:ConfApplStrAcc `
                                                                           -TablePartitionKey "AADPerm"  

                            if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                            {
                                Write-Output $addinfotableresult.LogMsg
                                Write-Output $addinfotableresult.ReturnMsg
                                Write-Output "----------------------------------------------------------------"

                                Write-Output "Add new AAD group request into Azure storage queue"
                                Write-Output "----------------------------------------------------------------"

                                $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMsgQueue `
                                                                        -StorageAccountName $global:ConfApplStrAcc `
                                                                        -RequestType "AAD" `
                                                                        -ADGroupName $ADGroupName `
                                                                        -ADOUPath $global:ConfOUPathAADPerm `
                                                                        -ADGroupDesc "AD Group created by mappingtool" `
                                                                        -AADGroupName $AADGroupName `
                                                                        -AADRoleID "none"

                                if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                {
                                    Write-Output $resultaddmsgtoqueue.LogMsg
                                    Write-Output $resultaddmsgtoqueue.ReturnMsg
                                    Write-Output "----------------------------------------------------------------"
                                }
                                else {
                                    #region Script Error
                                
                                    Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details"
                                    Write-Error "Error in function Add-Msg-to-Queue."
                                    Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
                                
                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                -ScriptSection "Add-Msg-to-Queue" `
                                                                -InfoMessage "" `
                                                                -WarnMessage "" `
                                                                -ErrorMessage $resultaddmsgtoqueue.LogMsg
                                
                                    #endregion
                                    Write-Output "----------------------------------------------------------------"
                                }                                
                            }
                            else {
                                
                                    #region Script Error

                                    Write-Error "Error in function Add-Info-to-Config-Table. (go to output for more details"
                                    Write-Error "Error in function Add-Msg-to-Queue."
                                    Write-Error "Error Message: $($addinfotableresult.LogMsg)"

                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                -ScriptSection "Add-Info-to-Config-Table" `
                                                                -InfoMessage "" `
                                                                -WarnMessage "" `
                                                                -ErrorMessage $addinfotableresult.LogMsg

                                    #endregion
                                
                            }
                        }       
                    
                        #endregion
                    }   
                } 
                else {
                    #region Script Error
        
                        Write-Error "Error storage context is null. Script ended."
                        Write-Output "Error storage context is null. Script ended."                    
                        Write-Output "----------------------------------------------------------------"
        
                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                            -ScriptSection "Create storage context" `
                                            -InfoMessage "" `
                                            -WarnMessage "" `
                                            -ErrorMessage "Error storage context is null. Script ended."
        
                    #endregion
                }                    
        }
        else {            

            #region Script Error          
            
            Write-Error "Error durring Connect to Azure. (go to output for more details)"
            Write-Output "Error durring Connect to Azure."
            Write-Output "Error message: $($loginazureresult.LogMsg)"
            Write-Output "----------------------------------------------------------------"
            
            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                        -ScriptSection "Connect to Azure" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $loginazureresult.LogMsg
            #endregion
        }
    }
    catch {
        Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
        Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"
    
        Write-State-to-LogAnalytics -MessageType [ReturnCode]::Error `
                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                    -ScriptSection "Main" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage $_.Exception.Message
    
        throw "Script exit with errors."
    }

#endregion
#######################################################################################################################
