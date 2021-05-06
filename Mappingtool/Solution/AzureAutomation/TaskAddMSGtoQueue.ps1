  <#
    .SYNOPSIS
        The core script for the whole solution..
        
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
    $ChannelURL,

    [parameter (Mandatory=$false)]
    [ValidateSet('true','false')]
    $DebugScript
)

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-static

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
        [string] $AZRGName,
        [parameter (Mandatory=$false)]
        [string] $SubscriptionID
    )


    $disableresult = Disable-AzContextAutosave –Scope Process

    $params = @{"Source"="RG";"AZRGName"=$AZRGName;"AADGroupParameters"=$aadgroupparameters;"WorkflowID"=$wfguid}    

    return Start-AzAutomationRunbook `
                    –AutomationAccountName $global:ConfAutoAcc `
                    –Name 'TaskAADGroup' `
                    -ResourceGroupName $global:ConfApplRG `
                    –Parameters $params
}

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start      

    try 
    {              
        $wfguid = GenerateWorkflowGuid
        Write-Output "WorkflowGuid: $wfguid"

        if($DebugScript -eq "true")
        {
            $webhook = $WebhookData | ConvertFrom-Json
        }
        else {
            $webhook = $WebhookData
        }

        Write-Output "Connect to Azure"
        Write-Output "----------------------------------------------------------------"
            if($webhook.WebhookName -eq $global:HCRGWebhook)
            {
                Write-Output "Webhook type is $global:HCRGWebhook"
                Write-Output "----------------------------------------------------------------"

                Write-Output "Convert Webhook body to JSON"
                Write-Output "----------------------------------------------------------------"
                    $RequestBody = $webhook.RequestBody | ConvertFrom-Json
                    $requestdata = $RequestBody.data
                Write-Output "----------------------------------------------------------------"
                
                    $loginazureresult = Login-Azure
            }            
            else {
                $loginazureresult = Login-Azure   
            }
        
        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg
            Write-Output "----------------------------------------------------------------"

            Write-Output "Create Storage Account context"
            Write-Output "----------------------------------------------------------------"
                #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount   
                $ctx = $global:StorageContext

                #section storage context
                if($null -ne $ctx)
                {
                    $resultmapping = ""
                    $resultaddmsgtoqueue = ""
                    Write-Output "----------------------------------------------------------------"

                    Write-Output "Check Webhook type"
                    Write-Output "----------------------------------------------------------------"
                    if($webhook.WebhookName -eq $global:HCRGWebhook)
                    {     
                        Write-Output "Check if rg compares to definition"

                            $rgnamesplit = $requestdata.resourceUri.split("/")
                            $rgname = $rgnamesplit[$rgnamesplit.count -1]

                            if($rgname.tolower().StartsWith($Global:ConfAppRGtoMon.ToString().tolower()))
                            {                                                
                                Write-Output "Check if subscription with ID $($requestdata.subscriptionId) is a valide subscription."
                                Write-Output "----------------------------------------------------------------"

                                $checksubscription = Get-RBAC-Mapping `
                                                            -MappingTableName $global:ConfPermMappingTable `
                                                            -ConfigTableName $global:ConfConfigurationTable `
                                                            -mappingvalue "null" `
                                                            -RGName "null" `
                                                            -RequestType "SUB" `
                                                            -SubscriptionID $requestdata.subscriptionId

                                if($checksubscription.ReturnMsg -eq [ReturnCode]::Success)
                                {
                                    $mappingresult =  $checksubscription.ReturnJsonParameters02 | ConvertFrom-Json
                                    
                                    if($mappingresult.State -eq "exist")
                                    {
                                        Write-Output "Switch to resource subscription $($requestdata.subscriptionId)"
                                        Write-Output "----------------------------------------------------------------"
                                        Set-AzContext -SubscriptionId $requestdata.subscriptionId

                                        Write-Output "Get resourcegroup $($requestdata.resourceUri)"
                                        Write-Output "----------------------------------------------------------------"
                                            $newrg = Get-AzResourceGroup -Id $requestdata.resourceUri
                                        Write-Output "----------------------------------------------------------------"

                                        Write-Output "Switch back to default subscription $($global:DefaultSubscriptionID)"
                                        Write-Output "----------------------------------------------------------------"
                                        Set-AzContext -SubscriptionId $global:DefaultSubscriptionID

                                        Write-Output "Check ResourceGroup tags"
                                        Write-Output "----------------------------------------------------------------"
                                        if($newrg.Tags.ContainsKey($global:ConfRGReqTag))
                                        {
                                            Write-Output "Split tag value by seperator ,"
                                            $option = [System.StringSplitOptions]::RemoveEmptyEntries
                                            $permissions = ($newrg.Tags.$global:ConfRGReqTag).toLower().split(",", $option)

                                            Write-Output "Check if permission remove."

                                            $resultcheckremove = Update-RBAC-Removed -arrtags $permissions -rgname $newrg.ResourceGroupName 
                                            Write-Output $resultcheckremove
                                            
                                            Write-Output "Check if new permission add."
                                            foreach($permission in $permissions)
                                            {
                                                #section Main RG
                                                try
                                                {
                                                    if($null -ne $permission)
                                                    {
                                                        Write-Output "Get mapping result for permission: $permission"

                                                        #Execute Function Get-RBAC-Mapping (you can find that Function in the MappingTool module)
                                                        $resultmapping = Get-RBAC-Mapping `
                                                                                -MappingTableName $global:ConfPermMappingTable `
                                                                                -ConfigTableName $global:ConfConfigurationTable `
                                                                                -mappingvalue $permission `
                                                                                -RGName $newrg.ResourceGroupName `
                                                                                -RequestType "RG" `
                                                                                -SubscriptionID $requestdata.subscriptionId
                                                    
                                                        if($resultmapping.ReturnMsg -eq [ReturnCode]::Success)
                                                        {
                                                            Write-Output $resultmapping.LogMsg
                                                            ################################################################################
                                                            # DebugMsg in Log Analytics

                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "Get-RBAC-Mapping" `
                                                                                        -InfoMessage $resultmapping.LogMsg `
                                                                                        -WarnMessage "" `
                                                                                        -ErrorMessage ""
                            
                                                            ################################################################################

                                                            Write-Output "Return Parameter:"
                                                            Write-Output $resultmapping.ReturnJsonParameters02

                                                            $mappingresult =  $resultmapping.ReturnJsonParameters02 | ConvertFrom-Json

                                                            if($mappingresult.State -eq "create")
                                                            {
                                                                #region New AAD Group will be created

                                                                Write-Output "Execute Runbook TaskNewAADGroup"                                
                                                                $job = CallRBCreateAADGroup -aadgroupparameters $mappingresult `
                                                                                            -AZRGName $newrg.ResourceGroupName

                                                                Write-Output "Wait till AADGroup is created"
                                                                do {                                    
                                                                    Write-Output "Start Sleep 30 seconds"
                                                                    Start-Sleep -Seconds 30 
                                                                    
                                                                    if((Get-AzAutomationJob -Id $job.JobId `
                                                                                            -ResourceGroupName $global:ConfApplRG `
                                                                                            -AutomationAccountName $global:ConfAutoAcc).Status -eq "Failed")
                                                                    {
                                                                        ################################################################################
                                                                        # DebugMsg in Log Analytics

                                                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                                    -WorkflowID $wfguid `
                                                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                                    -ScriptSection "CallRBCreateAADGroup" `
                                                                                                    -InfoMessage "" `
                                                                                                    -WarnMessage "" `
                                                                                                    -ErrorMessage "TaskAADGroup execution failed!"

                                                                        ################################################################################

                                                                        throw "Script execution failed!"                                                        
                                                                    }
                                                                    
                                                                } while ((Get-Info-from-Config-Table -TableRowKey $mappingresult.AADGroupName `
                                                                                                    -TablePartitionKey "RBACPerm" `
                                                                                                    -TableName $global:ConfConfigurationTable).ReturnParameter1 -eq "false")
                                                            
                                                                ################################################################################
                                                                # DebugMsg in Log Analytics

                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                            -WorkflowID $wfguid `
                                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                            -ScriptSection "CallRBCreateAADGroup" `
                                                                                            -InfoMessage "Executen of script TaskAADGroup success" `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage ""

                                                                ################################################################################
                                                                Write-Output "Created"                                
                                                                Write-Output "Add new ResourceGroup group request into Azure storage queue"

                                                                $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMsgQueue `
                                                                                                        -WorkflowID $wfguid `
                                                                                                        -RequestType "RG" `
                                                                                                        -ADGroupName $mappingresult.ADGroupName `
                                                                                                        -ADOUPath $global:ConfOUPathRBACPerm `
                                                                                                        -ADGroupDesc "AD Group created by mappingtool" `
                                                                                                        -AADGroupName $mappingresult.AADGroupName `
                                                                                                        -AADRoleID $mappingresult.RoleID

                                                                #section add msg to queue
                                                                if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                                                {                                                    
                                                                    Write-Output $resultaddmsgtoqueue.ReturnMsg                                    

                                                                    ################################################################################
                                                                    # DebugMsg in Log Analytics

                                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                                -WorkflowID $wfguid `
                                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                                -ScriptSection "Add-Msg-to-Queue" `
                                                                                                -InfoMessage $resultaddmsgtoqueue.ReturnMsg  `
                                                                                                -WarnMessage "" `
                                                                                                -ErrorMessage ""

                                                                    ################################################################################
                                                                    Write-Output $resultaddmsgtoqueue.LogMsg
                                                                }
                                                                else {
                                                                    #region Script Error
                        
                                                                    Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details"
                                                                    Write-Error "Error in function Add-Msg-to-Queue."
                                                                    Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
                        
                                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                                -WorkflowID $wfguid `
                                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                                -ScriptSection "add msg to queue/Add-Msg-to-Queue" `
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
                                                        elseif($resultmapping.ReturnMsg -eq [ReturnCode]::Error)
                                                        {
                                                            #region Script Error          
                            
                                                            Write-Error "Error durring execute get rbac mapping settings. (go to output for more details)"
                                                            Write-Output "Error durring execute get rbac mapping settings."
                                                            Write-Output "Error message: $($resultmapping.LogMsg)"
                                                            Write-Output "----------------------------------------------------------------"
                                                            
                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "Get-RBAC-Mapping/get mapping" `
                                                                                        -InfoMessage "" `
                                                                                        -WarnMessage "" `
                                                                                        -ErrorMessage $resultmapping.LogMsg
                                                            #endregion
                                                        }
                                                        elseif ($resultmapping.ReturnMsg -eq [ReturnCode]::Warning) {
                                                            #region Script Error          
                            
                                                            Write-Warning "Warning durring execute get rbac mapping settings. (go to output for more details)"
                                                            Write-Output "Warning durring execute get rbac mapping settings."
                                                            Write-Output "Warning message: $($resultmapping.LogMsg)"
                                                            Write-Output "----------------------------------------------------------------"
                                                            
                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "Get-RBAC-Mapping/get mapping" `
                                                                                        -InfoMessage "" `
                                                                                        -WarnMessage $resultmapping.LogMsg `
                                                                                        -ErrorMessage ""
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
                                                    #region Script Error          
                                                    
                                                    Write-Error "Error in section Main RG. (go to output for more details)"
                                                    Write-Error "Error in section Main RG."
                                                    Write-Output "Error in section Main RG."
                                                    Write-Output "Error message: $($_.Exception.Message)"
                                                    Write-Output "----------------------------------------------------------------"
                                                    
                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Main RG" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage $_.Exception.Message
                                                    #endregion
                                                    Write-Output "----------------------------------------------------------------"
                                                }
                                            }                            
                                        }
                                        else {
                                            Write-Output "ResourceGroup have no valid Tag based on configuration (Configuration Tag Name: $($global:ConfRGReqTag))"
                                            Write-Output "----------------------------------------------------------------"
                                        }
                                    }
                                }
                                else {
                                    if($mappingresult.State -eq "null")
                                    {
                                        #region Script Error
                                                
                                        Write-Warning "Warning Subscription not configured."
                                        Write-Output "Warning Subscription not configured. Script ended."                    
                                        Write-Output "----------------------------------------------------------------"

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                    -ScriptSection "Check if Subscription is configured" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "Warning Subscription not configured. Script ended." `
                                                                    -ErrorMessage ""

                                        #endregion                                
                                    }    
                                    else {
                                        #region Script Error
                                                
                                        Write-Warning "Error in check subscription. Full Message: $($checksubscription.ReturnJsonParameters02)"
                                        Write-Output "Error in check subscription. Script ended."                    
                                        Write-Output "----------------------------------------------------------------"

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                    -ScriptSection "Check if Subscription is configured" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $checksubscription.ReturnJsonParameters02

                                        #endregion  
                                    }                        
                                }
                            }
                            else
                            {
                                Write-Output "Wrong naming convention"
                            }

                    } 
                    elseif($webhook.WebhookName -eq $global:HCRGDelWebhook)
                    {
                        Write-Output "Webhook type is $global:HCRGDelWebhook"
                        Write-Output "----------------------------------------------------------------"
                    
                        #region Script
                        
                        Write-Output "Convert Webhook body to JSON"
                        Write-Output "----------------------------------------------------------------"
                            $RequestBody = $webhook.RequestBody | ConvertFrom-Json
                            $requestdata = $RequestBody.data
                        Write-Output "----------------------------------------------------------------"

                            #$subscriptionid =  $requestdata.subscriptionId                           
                            $i = $requestdata.resourceUri.split("/")
                            $resourcegroup = $i[$i.Length -1]

                            #$requestuser = $requestdata.claims.'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'
                            
                            if($resourcegroup.tolower().StartsWith($Global:ConfAppRGtoMon.ToString().tolower()))
                            {
                                Write-Output "Get configuration settings"
                                    $tableconfig = Get-Info-from-Config-Table -TableRowKey "*"`
                                                                            -TablePartitionKey "RBACPerm" `
                                                                            -TableName $global:ConfConfigurationTable                            
                                    
                                    $groupresult = $tableconfig.ReturnJsonParameters02 | ConvertFrom-Json                        
                                
                                    foreach($group in ($groupresult | Where-Object {$_.AzureRG -eq $resourcegroup}))
                                    {
                                        Write-Output "Rename Group $($group.AADGroupName)"

                                        $renameresult = Rename-AADGroup -AADGroup $group.AADGroupName `
                                                                        -AADGroupID $group.AADGroupID

                                        if($renameresult.ReturnMsg -eq [ReturnCode]::Success)
                                        {
                                            Write-Output $renameresult.LogMsg
                                            ################################################################################
                                            # DebugMsg in Log Analytics

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Rename-AADGroup" `
                                                                        -InfoMessage $renameresult.LogMsg `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage ""
                    
                                            ################################################################################

                                            Write-Output "Get config from configuration table to backup."
                                            #Backup Config Data
                                            $backupdata = Get-Info-from-Config-Table -TableRowKey $group.RowKey `
                                                                                    -TablePartitionKey $group.PartitionKey `
                                                                                    -TableName $global:ConfConfigurationTable
                                            
                                            if($backupdata.ReturnMsg -eq [ReturnCode]::Success)
                                            {
                                                Write-Output $backupdata.LogMsg
                                                ################################################################################
                                                # DebugMsg in Log Analytics

                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                            -WorkflowID $wfguid `
                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                            -ScriptSection "Get-Info-from-Config-Table" `
                                                                            -InfoMessage $backupdata.LogMsg `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage ""
                    
                                                ################################################################################

                                                Write-Output "Backup Configuration data"

                                                $backuprowkey = "Bak-$($group.RowKey)-$((Get-Date).ToFileTime())"

                                                $addbackupdata = Add-Info-to-ConfigBackup-Table -TablePartitionKey "RBACBackup"`
                                                                                                -TableRowKey $backuprowkey `
                                                                                                -BackupData $backupdata.ReturnJsonParameters02 `
                                                                                                -TableName $global:ConfConfigurationTableBackup 

                                                if($addbackupdata.ReturnMsg -eq [ReturnCode]::Success)
                                                {
                                                    Write-Output $addbackupdata.LogMsg
                                                    ################################################################################
                                                    # DebugMsg in Log Analytics

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Add-Info-to-ConfigBackup-Table" `
                                                                                -InfoMessage $backupdata.LogMsg `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage ""
                    
                                                    ################################################################################

                                                    Write-Output "Remove configuration from configurationtable"

                                                    $removerowitem = Remove-Info-from-Config-Table -TablePartitionKey $group.PartitionKey `
                                                                                                -TableRowKey $group.RowKey `
                                                                                                -TableName $global:ConfConfigurationTable

                                                    if($removerowitem.ReturnMsg -eq [ReturnCode]::Success)
                                                    {
                                                        Write-Output $removerowitem.LogMsg
                                                        ################################################################################
                                                        # DebugMsg in Log Analytics

                                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                    -WorkflowID $wfguid `
                                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                    -ScriptSection "Remove-Info-from-Config-Table" `
                                                                                    -InfoMessage $removerowitem.LogMsg `
                                                                                    -WarnMessage "" `
                                                                                    -ErrorMessage ""
                    
                                                        ################################################################################

                                                        Write-Output "Add new message to monitor configuration queue"

                                                        $tableconfig = $backupdata.ReturnJsonParameters02 | ConvertFrom-Json

                                                        $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMonitorConfig `
                                                                                                -WorkflowID $wfguid `
                                                                                                -RequestType "RG-Rem" `
                                                                                                -ADGroupName $tableconfig.ADGroupName `
                                                                                                -ADOUPath $tableconfig.ADGroupDN `
                                                                                                -ADGroupDesc "$((Get-Date).ToShortDateString() + " " + (Get-Date).ToShortTimeString()). Removed Azure RG $resourcegroup" `
                                                                                                -AADGroupName "none" `
                                                                                                -AADRoleID "none"

                                                        if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                                        {         
                                                            ################################################################################
                                                            # DebugMsg in Log Analytics

                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                            -WorkflowID $wfguid `
                                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                            -ScriptSection "Add-Msg-to-Queue" `
                                                                                            -InfoMessage $resultaddmsgtoqueue.LogMsg `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage ""

                                                            ################################################################################
                                                            
                                                            Write-Output "Finish"
                                                            Write-Output "----------------------------------------------------------------"
                                                        }
                                                        else {
                                                            Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details)"
                                                            Write-Error "Error in function Add-Msg-to-Queue."
                                                            Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
                        
                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "Add-Msg-to-Queue/Webhook: $($global:HCRGDelWebhook)" `
                                                                                        -InfoMessage "" `
                                                                                        -WarnMessage "" `
                                                                                        -ErrorMessage $resultaddmsgtoqueue.LogMsg
                        
                                                            #endregion

                                                            Write-Output "----------------------------------------------------------------" 
                                                        }
                                                    }
                                                    else {
                                                        #region Script Error
            
                                                        Write-Error "Error in function Remove-Info-from-Config-Table. (go to output for more details)"
                                                        Write-Error "Error in function Remove-Info-from-Config-Table."
                                                        Write-Error "Error Message: $($removerowitem.LogMsg)"
                    
                                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                    -WorkflowID $wfguid `
                                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                    -ScriptSection "Remove-Info-from-Config-Table/Webhook: $($global:HCRGDelWebhook)" `
                                                                                    -InfoMessage "" `
                                                                                    -WarnMessage "" `
                                                                                    -ErrorMessage $removerowitem.LogMsg
                    
                                                        #endregion

                                                        Write-Output "----------------------------------------------------------------"
                                                    }                                        
                                                }
                                                else {
                                                    #region Script Error

                                                    Write-Error "Error in function Add-Info-to-ConfigBackup-Table. (go to output for more details"
                                                    Write-Error "Error in function Add-Info-to-ConfigBackup-Table."
                                                    Write-Error "Error Message: $($addbackupdata.LogMsg)"
                
                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Add-Info-to-ConfigBackup-Table/Webhook: $($global:HCRGDelWebhook)" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage $addbackupdata.LogMsg
                
                                                    #endregion

                                                    Write-Output "----------------------------------------------------------------"
                                                }                                        
                                            }
                                            else {
                                                #region Script Error

                                                Write-Error "Error in function Get-Info-from-Config-Table. (go to output for more details"
                                                Write-Error "Error in function Get-Info-from-Config-Table."
                                                Write-Error "Error Message: $($backupdata.LogMsg)"
            
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -WorkflowID $wfguid `
                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                            -ScriptSection "Get-Info-from-Config-Table/Webhook: $($global:HCRGDelWebhook)" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage $backupdata.LogMsg
            
                                                #endregion
                                                Write-Output "----------------------------------------------------------------"
                                            }                                                                    
                                        }      
                                        else {
                                            #region Script Error

                                            Write-Error "Error in function Rename-AADGroup. (go to output for more details"
                                            Write-Error "Error in function Rename-AADGroup."
                                            Write-Error "Error Message: $($renameresult.LogMsg)"
        
                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Rename-AADGroup/Webhook: $($global:HCRGDelWebhook)" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage $renameresult.LogMsg
        
                                            #endregion
                                            Write-Output "----------------------------------------------------------------"
                                        }                                                                                          
                                    }      
                            }           
                            else
                            {
                                Write-Output "Wrong naming convention"
                            }       
                    } 
                    elseif ($webhook.WebhookName -eq $global:HCAADWebhook)
                    {      
                        Write-Output "Webhook type is $global:HCAADWebhook"
                        Write-Output "----------------------------------------------------------------"                
                        
                        Write-Output "Convert Webhook body to JSON"
                        Write-Output "----------------------------------------------------------------"
                            $RequestBody = $webhook.RequestBody | ConvertFrom-Json
                            $requestdata = $RequestBody.data.alertContext.SearchResults.tables[0].rows
                            $requestLinkToSearchResultsAPI = $RequestBody.data.alertContext.LinkToSearchResultsAPI
                        Write-Output "----------------------------------------------------------------"

                        $alertresult = Get-LogAnalyticsMessage -LinkToSearchResults $requestLinkToSearchResultsAPI                        
                        $affectedgroups = $alertresult.ReturnJsonParameters02 | Convertfrom-Json
                        
                        foreach ($i in $affectedgroups)
                        {
                            $AADGroupName = $i.value[1].toString().Replace('"',"").tolower()
                            $AADGroupID = $i.value[2].toString().Replace('"',"")
                            $ADGroupName = $i.value[1].tostring().tolower().replace($global:NSAADPerm.tolower(),$global:OnPremAADRolePerm).Replace('"',"")
                            $AADaction = $i.value[0].tolower()
                            $AADInitiatedBy = $i.value[3].tostring()

                            if(($AADGroupName.StartsWith($global:NSAADPerm.tolower())) -or 
                               ($AADGroupName.StartsWith($global:NSAADRBACPerm.tolower())) -or
                               ($AADGroupName.StartsWith($global:NSAADRoleWithRolePerm.tolower())))
                            {

                                Write-Output "Azure AD group webhook."
                                Write-Output "Action: $AADaction"
                                Write-Output "Get more details."
                                Write-Output "AAD GroupName: $AADGroupName"
                                Write-Output "AAD GroupID: $AADGroupID"
                                Write-Output "Initiated by: $AADInitiatedBy"  
                                Write-Output "On-Prem AD GroupName: $ADGroupName"   
                                                        
                                if($i.value[0].tolower() -eq "add group")
                                {
                                    Write-Output "Add Information to configuration Table"
                                    $addinfotableresult = Add-Info-to-Config-Table -AADGroupName  $AADGroupName.ToLower() `
                                                                                -AADGroupID $AADGroupID.ToLower() `
                                                                                -ADGroupName $ADGroupName.ToLower()`
                                                                                -TableName $global:ConfConfigurationTable `
                                                                                -TablePartitionKey "AADPerm"  

                                    if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                                    {
                                        Write-Output $addinfotableresult.LogMsg

                                        ################################################################################
                                        # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                    -ScriptSection "Add-Info-to-Config-Table" `
                                                                    -InfoMessage $addinfotableresult.LogMsg `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""
                
                                        ################################################################################

                                        Write-Output $addinfotableresult.ReturnMsg
                                        Write-Output "----------------------------------------------------------------"

                                        Write-Output "Add new AAD group request into Azure storage queue"
                                        Write-Output "----------------------------------------------------------------"

                                        $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMsgQueue `
                                                                                -WorkflowID $wfguid `
                                                                                -RequestType "AAD" `
                                                                                -ADGroupName $ADGroupName `
                                                                                -ADOUPath $global:ConfOUPathAADPerm `
                                                                                -ADGroupDesc "AD Group created by mappingtool" `
                                                                                -AADGroupName $AADGroupName `
                                                                                -AADRoleID "none"

                                        if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                        {
                                            Write-Output $resultaddmsgtoqueue.LogMsg

                                            ################################################################################
                                            # DebugMsg in Log Analytics

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Add-Msg-to-Queue" `
                                                                        -InfoMessage $resultaddmsgtoqueue.LogMsg `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage ""

                                            ################################################################################
                                            Write-Output $resultaddmsgtoqueue.ReturnMsg
                                            Write-Output "----------------------------------------------------------------"
                                        }
                                        else {
                                            #region Script Error
                                        
                                            Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details"
                                            Write-Error "Error in function Add-Msg-to-Queue."
                                            Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
                                        
                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -WorkflowID $wfguid `
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
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Add-Info-to-Config-Table" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage $addinfotableresult.LogMsg

                                            #endregion
                                        
                                    }
                                }  
                                elseif ($i.value[0].tolower() -eq "delete group") 
                                { 
                                    Write-Output "Get configuration settings"
                                    $tableconfig = Get-Info-from-Config-Table -TableRowKey $AADGroupName `
                                                                            -TablePartitionKey "AADPerm" `
                                                                            -TableName $global:ConfConfigurationTable

                                    if($tableconfig.ReturnMsg -eq [ReturnCode]::Success)
                                    {
                                        ################################################################################
                                        # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                    -ScriptSection "Get-Info-from-Config-Table" `
                                                                    -InfoMessage $tableconfig.LogMsg `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""
                
                                        ################################################################################

                                        $aadgroupresult = $tableconfig.ReturnJsonParameters02 | ConvertFrom-Json  
                                                                            
                                        Write-Output $tableconfig.ReturnMsg

                                        if($aadgroupresult.AADGroupID -eq $AADGroupID)
                                        {                                            
                                            Write-Output "Backup Configuration data"

                                            $backuprowkey = "Bak-$($AADGroupName)-$((Get-Date).ToFileTime())"

                                            $addbackupdata = Add-Info-to-ConfigBackup-Table -TablePartitionKey "AADBackup"`
                                                                                            -TableRowKey $backuprowkey `
                                                                                            -BackupData $tableconfig.ReturnJsonParameters02 `
                                                                                            -TableName $global:ConfConfigurationTableBackup

                                            if($addbackupdata.ReturnMsg -eq [ReturnCode]::Success)
                                            {                                            
                                                Write-Output $addbackupdata.LogMsg
                                                ################################################################################
                                                # DebugMsg in Log Analytics

                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                            -WorkflowID $wfguid `
                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                            -ScriptSection "Add-Info-to-ConfigBackup-Table" `
                                                                            -InfoMessage $addbackupdata.LogMsg `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage ""

                                                ################################################################################
                                                Write-Output "Remove configuration from configurationtable"

                                                $removerowitem = Remove-Info-from-Config-Table -TablePartitionKey "AADPerm" `
                                                                                            -TableRowKey $AADGroupName `
                                                                                            -TableName $global:ConfConfigurationTable

                                                if($removerowitem.ReturnMsg -eq [ReturnCode]::Success)
                                                {
                                                    Write-Output $removerowitem.LogMsg
                                                    ################################################################################
                                                    # DebugMsg in Log Analytics

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Remove-Info-from-Config-Table" `
                                                                                -InfoMessage $removerowitem.LogMsg `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage ""

                                                    ################################################################################
                                                    Write-Output "Add new message to monitor configuration queue"

                                                    $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfOnPremMonitorConfig `
                                                                                            -WorkflowID $wfguid `
                                                                                            -RequestType "AAD-Rem" `
                                                                                            -ADGroupName $aadgroupresult.ADGroupName `
                                                                                            -ADOUPath $aadgroupresult.ADGroupDN `
                                                                                            -ADGroupDesc "$((Get-Date).ToShortDateString() + " " + (Get-Date).ToShortTimeString()) Removed Azure AD group $AADGroupName." `
                                                                                            -AADGroupName "none" `
                                                                                            -AADRoleID "none"

                                                    if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                                    {           
                                                        ################################################################################
                                                        # DebugMsg in Log Analytics

                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "Add-Msg-to-Queue" `
                                                                                        -InfoMessage $resultaddmsgtoqueue.LogMsg `
                                                                                        -WarnMessage "" `
                                                                                        -ErrorMessage ""

                                                        ################################################################################                                                                                         
                                                        Write-Output "Finish"
                                                        Write-Output "----------------------------------------------------------------"
                                                    }
                                                    else {
                                                                Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details)"
                                                                Write-Error "Error in function Add-Msg-to-Queue."
                                                                Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"
                            
                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                            -WorkflowID $wfguid `
                                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                            -ScriptSection "Add-Msg-to-Queue/Webhook: $($global:HCAADDelWebhook)" `
                                                                                            -InfoMessage "" `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage $resultaddmsgtoqueue.LogMsg
                            
                                                                #endregion

                                                                Write-Output "----------------------------------------------------------------" 
                                                    }
                                                }
                                                else {
                                                    #region Script Error
                
                                                    Write-Error "Error in function Remove-Info-from-Config-Table. (go to output for more details)"
                                                    Write-Error "Error in function Remove-Info-from-Config-Table."
                                                    Write-Error "Error Message: $($removerowitem.LogMsg)"
                        
                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                -ScriptSection "Remove-Info-from-Config-Table/Webhook: $($global:HCRGDelWebhook)" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage $removerowitem.LogMsg
                        
                                                    #endregion

                                                    Write-Output "----------------------------------------------------------------"
                                                }                                        
                                            }
                                            else {
                                                #region Script Error

                                                Write-Error "Error in function Add-Info-to-ConfigBackup-Table. (go to output for more details"
                                                Write-Error "Error in function Add-Info-to-ConfigBackup-Table."
                                                Write-Error "Error Message: $($addbackupdata.LogMsg)"
                    
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -WorkflowID $wfguid `
                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                            -ScriptSection "Add-Info-to-ConfigBackup-Table/Webhook: $($global:HCRGDelWebhook)" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage $addbackupdata.LogMsg
                    
                                                #endregion

                                                Write-Output "----------------------------------------------------------------"
                                            }                                                                                    
                                        }
                                        else {
                                            #region Script Error

                                            Write-Error "Error in function Get-Info-from-Config-Table. (go to output for more details"
                                            Write-Error "Error in function Get-Info-from-Config-Table."
                                            Write-Error "Log Message: $($tableconfig.LogMsg) and Error 'The AADGroup id isn't the same as the configuration id'"

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "Get-Info-from-Config-Table/Webhook: $($global:HCAADDelWebhook)" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage "Log Message: $($tableconfig.LogMsg) and Error 'The AADGroup id isn't the same as the configuration id'"

                                            #endregion
                                            Write-Output "----------------------------------------------------------------"
                                        }
                                    }
                                    else {
                                        #region Script Error

                                        Write-Error "Error in function Get-Info-from-Config-Table. (go to output for more details"
                                        Write-Error "Error in function Get-Info-from-Config-Table."
                                        Write-Error "Error Message: $($tableconfig.LogMsg)"

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                    -ScriptSection "Webhook: $($global:HCRGDelWebhook)/Get-Info-from-Config-Table" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $tableconfig.LogMsg

                                        #endregion
                                        Write-Output "----------------------------------------------------------------"
                                    }     
                                }  
                                elseif (($i.value[0].tolower() -eq "add member to group") -or ($i.value[0].tolower() -eq "Remove member from group"))   
                                {                                                          
                                    Write-Output "----------------------------------------------------------------"  
                                    Write-Output "Get Azure configuration row `n"
                                        $configtable = Get-AzTableTable -TableName $global:ConfConfigurationTable -resourceGroup $global:ConfApplRG `
                                                                        -storageAccountName $global:ConfApplStrAcc
        
                                        [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("AADGroupID",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$AADGroupID)
                                                                                            
                                        $groupconfig = Get-AzTableRow -table $configtable -ColumnName "AADGroupID" -value $AADGroupID -operator Equal
        
                                        Write-Output $groupconfig
        
                                    
                                        if($null -ne $groupconfig)
                                        {
                                            #if($global:ConfAADPermissionWriteback) #Future request!!
                                            #{
                                                Write-Output "Update ADGroupuSNChanged to 0"
                                                $groupconfig.ADGroupuSNChanged = "0"                                                
                                                            
                                                $rupdrow = $groupconfig | Update-AzTableRow -Table $configtable
        
        
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                            -ScriptSection "$($global:HCAADCHWebhook)/Get-AzTableRow" `
                                                                            -InfoMessage "Update ADGroupuSNChanged for group $AADGroupName to 0." `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "" `
                                                                            -AdditionalInfo "Azure AD Group change action executed $AADaction" `
                                                                            -InitiatedBy $AADInitiatedBy
                                            #}
                                                                    
                                        }
                                        else {
                                            #region Script Error
        
                                            Write-Error "Error to find the configuration row based on filter. (go to output for more details)"
                                            Write-Output "Error to find the configuration row based on filter."   
                                            Write-Output "Filter: $finalFilter"                                                                
                                            Write-Output "----------------------------------------------------------------"
        
                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                        -ScriptSection "$($global:HCAADCHWebhook)/Get-AzTableRow" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage "Error to find the configuration row based on filter." `
                                                                        -AdditionalInfo "Search Filter: $($finalFilter)."
        
        
                                            #endregion
                                        }             
                                }                        
                            }
                            else
                            {
                                Write-Output "Wrong group naming convention"
                            }
                        }  
                                           
                    }
                    else {
                        #region Script Error
            
                            Write-Error "Error wrong Webhook type $($webhook.WebhookName). Script ended."
                            Write-Output "Error wrong Webhook type $($webhook.WebhookName ). Script ended."                    
                            Write-Output "----------------------------------------------------------------"
            
                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                        -ScriptSection "checkwebhooktype" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "" `
                                                        -ErrorMessage "Error wrong Webhook type $($webhook.WebhookName). Script ended."
            
                        #endregion
                        Write-Output "----------------------------------------------------------------"
                    }                     
                }   
                else {
                    #region Script Error
        
                        Write-Error "Error storage context is null. Script ended."
                        Write-Output "Error storage context is null. Script ended."                    
                        Write-Output "----------------------------------------------------------------"
        
                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                    -WorkflowID $wfguid `
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
                                        -WorkflowID $wfguid `
                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                        -ScriptSection "Main/Connect to Azure" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $loginazureresult.LogMsg
            #endregion
            Write-Output "----------------------------------------------------------------"
        }

        ############################################
        # Script finish
        ############################################

        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                    -WorkflowID $wfguid `
                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                    -ScriptSection "Script End" `
                                    -InfoMessage "Script run successful at $(Get-Date)" `
                                    -WarnMessage "" `
                                    -ErrorMessage ""
    }
    catch {
        Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
        Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"
    
        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                    -WorkflowID $wfguid `
                                    -ScriptName "TaskAddMSGtoQueue.ps1" `
                                    -ScriptSection "Main Script" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage $_.Exception.Message
    
        throw "Script exit with errors."
    }

#endregion
#######################################################################################################################
