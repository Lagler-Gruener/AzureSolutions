  <#
    .SYNOPSIS
        Task script to add new Azure Active Ditrectory Groups
        
    .DESCRIPTION
        This script was executed by the main logic app and
        direct from the script "TaskAddMsgtoQueue"
        This script includes the following steps:
            1.) Get Message from Cloud-Queue (Only for new AD Group workflow)
            2.) Create a new Azure Active Directory Group
            3.) Add/Update the configuration table based on the Workflow Type (New Resource Group or New On-Prem AD Group)
            

    .EXAMPLE
        -
        
    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Az.Resources (tested with Version: 1.13.0)
            -AzTable      (tested with Version: 2.0.3)  
            -MappingTool 

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
    [ValidateSet('RG','AD','RemoveAD')]
    [object] $Source,
    [parameter (Mandatory=$false)]
    [object] $WorkflowID = "null",
    [parameter (Mandatory=$false)]
    [string] $AZRGName="null",
    [parameter (Mandatory=$false)]
    [object] $AADGroupParameters,
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
#region Script start 

    try 
    {     
        $wfguid = $WorkflowID
        
        if($DebugScript -eq "true")
        {
            $GroupParameters = $AADGroupParameters | ConvertFrom-Json
        }
        else {
            $GroupParameters = $AADGroupParameters
        }        

        if($Source -eq "RG")
        {
            Write-Output "Connect to Azure"
               $loginazureresult = Login-Azure
        }
        elseif($Source -eq "AD")
        {
            Write-Output "Connect to Azure"
               $loginazureresult = Login-Azure
        }
        elseif ($Source -eq "RemoveAD") 
        {
            Write-Output "Connect to Azure"
               $loginazureresult = Login-Azure
        }

        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg        
            Write-Output "----------------------------------------------------------------"          

            if($Source -eq "RG")
            {
                ############################################################################
                # Task for Workflow "Add/Change RG Tag"
                ############################################################################

                if($GroupParameters.actiontype -eq "create")
                {
                    Write-Output "Create AAD Group named: $($GroupParameters.AADGroupName)"
                    $createaadgroupresult = Create-AADGroup -AADGroup $GroupParameters.AADGroupName                                             

                    #section RG
                    if($createaadgroupresult.ReturnMsg -eq [ReturnCode]::Success)
                    {
                        Write-Output $createaadgroupresult.LogMsg
                        ################################################################################
                        # DebugMsg in Log Analytics

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                    -WorkflowID $wfguid `
                                                    -ScriptName "TaskAADGroup.ps1" `
                                                    -ScriptSection "Create-AADGroup" `
                                                    -InfoMessage $createaadgroupresult.LogMsg `
                                                    -WarnMessage "" `
                                                    -ErrorMessage ""
            
                        ################################################################################
                        Write-Output "----------------------------------------------------------------"  

                        Write-Output "Add Information to Config Table"
                        $addinfotableresult = Add-Info-to-Config-Table -AADGroupName $GroupParameters.AADGroupName.ToLower() `
                                                                       -AADGroupID $createaadgroupresult.ReturnParameter1 `
                                                                       -RBACPermName $GroupParameters.MappingRBACPerm `
                                                                       -RBACPermID $GroupParameters.RoleID `
                                                                       -ADGroupName $GroupParameters.ADGroupName.ToLower() `
                                                                       -ADGroupSID "null" `
                                                                       -AZRG $AZRGName.ToLower() `
                                                                       -TableName $global:ConfConfigurationTable `
                                                                       -TablePartitionKey "RBACPerm" `
                                                                       -SubscriptionID $GroupParameters.SubscriptionID   
                        
                        if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                        {
                            Write-Output $addinfotableresult.LogMsg
                            ################################################################################
                            # DebugMsg in Log Analytics

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskAADGroup.ps1" `
                                                        -ScriptSection "Add-Info-to-Config-Table" `
                                                        -InfoMessage $addinfotableresult.LogMsg `
                                                        -WarnMessage "" `
                                                        -ErrorMessage ""

                            ################################################################################
                            Write-Output "----------------------------------------------------------------"  

                            Write-Output "Assign new AD Group(s) to the resource group $AZRGName"

                            Start-Sleep -Seconds 10
                            
                            Write-Output "Switch to resource subscription $($GroupParameters.SubscriptionID)"
                            Write-Output "----------------------------------------------------------------"
                            Set-AzContext -SubscriptionId $GroupParameters.SubscriptionID                            

                            $rbacassigmentresult = New-AzRoleAssignment -ResourceGroupName $AZRGName -ObjectId $createaadgroupresult.ReturnParameter1 `
                                                                        -RoleDefinitionName $GroupParameters.MappingRBACPerm `
                                                                        -ErrorVariable rbacassignerror

                            Write-Output "Switch back to default subscription $($global:DefaultSubscriptionID)"
                            Write-Output "----------------------------------------------------------------"
                            Set-AzContext -SubscriptionId $global:DefaultSubscriptionID

                            if($null -eq $rbacassignerror)
                            {
                                #region Script Error          
            
                                Write-Error "Error to add rbac permission to resource group. (go to output for more details)"
                                Write-Output "Error to add rbac permission to resource group."
                                Write-Output "Error message: $rbacassignerror"
                                Write-Output "----------------------------------------------------------------"
                                
                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                            -WorkflowID $wfguid `
                                                            -ScriptName "TaskAADGroup.ps1" `
                                                            -ScriptSection "RG/Add RBAC to RG" `
                                                            -InfoMessage "" `
                                                            -WarnMessage "" `
                                                            -ErrorMessage $rbacassignerror
                                #endregion
                            }
                            else {         
                                        
                                Write-Output "Finish"
                                
                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                                            -WorkflowID $wfguid `
                                                            -ScriptName "TaskAADGroup.ps1" `
                                                            -ScriptSection "RG/Add RBAC to RG" `
                                                            -InfoMessage "Add Group $($createaadgroupresult.ReturnParameter1) with permission $($GroupParameters.MappingRBACPerm) to resourcegroup $($AZRGName)" `
                                                            -WarnMessage "" `
                                                            -ErrorMessage "" `
                                                            -LogName "AppMpToolPermChanges"
                            }

                            Write-Output "----------------------------------------------------------------"  

                        }
                        else {
                            #region Script Error          
            
                            Write-Error "Error to add info to config table. (go to output for more details)"
                            Write-Output "Error to add info to config table."
                            Write-Output "Error message: $($addinfotableresult.LogMsg)"
                            Write-Output "----------------------------------------------------------------"
                            
                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskAADGroup.ps1" `
                                                        -ScriptSection "RG/Add-Info-to-Config-Table" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "" `
                                                        -ErrorMessage $addinfotableresult.LogMsg
                            #endregion
                        }

                    }
                    else {
                        Write-Output $createaadgroupresult.LogMsg
                        Write-Output $createaadgroupresult.ReturnMsg

                        #region script warning

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                    -WorkflowID $wfguid `
                                                    -ScriptName "TaskAADGroup.ps1" `
                                                    -ScriptSection "RG/Create-AADGroup" `
                                                    -InfoMessage "" `
                                                    -WarnMessage $createaadgroupresult.LogMsg `
                                                    -ErrorMessage ""
                        
                        #endregion

                        Write-Output "Add Information to Config Table"
                        $addinfotableresult = Add-Info-to-Config-Table -AADGroupName $GroupParameters.AADGroupName `
                                                                       -AADGroupID $createaadgroupresult.ReturnParameter1 `
                                                                       -RBACPermName $GroupParameters.MappingRBACPerm `
                                                                       -RBACPermID $GroupParameters.RoleID `
                                                                       -ADGroupName $GroupParameters.ADGroupName `
                                                                       -ADGroupSID "null" `
                                                                       -AZRG $AZRGName.ToLower() `
                                                                       -TableName $global:ConfConfigurationTable `
                                                                       -TablePartitionKey "RBACPerm" `
                                                                       -Validated "No" `
                                                                       -SubscriptionID $GroupParameters.SubscriptionID

                        if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                        {
                            Write-Output $addinfotableresult.LogMsg
                            ################################################################################
                            # DebugMsg in Log Analytics

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskAADGroup.ps1" `
                                                        -ScriptSection "Add-Info-to-Config-Table" `
                                                        -InfoMessage $addinfotableresult.LogMsg `
                                                        -WarnMessage "" `
                                                        -ErrorMessage ""

                            ################################################################################
                            Write-Output "----------------------------------------------------------------"  
                        }
                        else {
                            #region Script Error          
            
                            Write-Error "Error to add info to config table. (go to output for more details)"
                            Write-Output "Error to add info to config table."
                            Write-Output "Error message: $($addinfotableresult.LogMsg)"
                            Write-Output "----------------------------------------------------------------"
                            
                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskAADGroup.ps1" `
                                                        -ScriptSection "RG/Add-Info-to-Config-Table" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "" `
                                                        -ErrorMessage $addinfotableresult.LogMsg
                            #endregion
                        }                        
                    }
                }
            }
            elseif (($Source -eq "AD")) 
            {         
                ############################################################################
                # Task for Workflow "Application Add AD Group"
                ############################################################################

                Write-Output "Get Storage Account Queue" 
                #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
                $ctx = $global:StorageContext

                if($null -ne $ctx)
                {
                    Write-Output "Get Storage Queue"
                    $clqueue = Get-AzStorageQueue –Name $global:ConfCloudMsgQueue –Context $ctx 
                    
                    Write-Output "Check Storage queue for messages"
                    $invisibleTimeoutcheckqueue = [System.TimeSpan]::FromSeconds(1)
                    while ($null -ne $clqueue.CloudQueue.GetMessage($invisibleTimeoutcheckqueue))
                    {
                        Start-Sleep -Seconds 2

                        Write-Output "----------------------------------------------------------------"  
                        Write-Output "Set message invisible timeout to 90 seconds"
                            $invisibleTimeout = [System.TimeSpan]::FromSeconds(90)
                            $queueMessage = $clqueue.CloudQueue.GetMessage($invisibleTimeout)   

                            if($null -ne $queueMessage)
                            {
                                $result = $queueMessage.AsString | ConvertFrom-Json

                                Write-Output "Queue message:"
                                Write-Output $result

                                $wfguid = $result.WorkflowID

                                Write-Output "----------------------------------------------------------------"  
                                Write-Output "Create AAD Group named: $($result.AADGroupName)"
                                    $createaadgroupresult = Create-AADGroup -AADGroup $result.AADGroupName `
                                                                            -AADGroupType $result.Type

                                    if($createaadgroupresult.ReturnCode -eq [ReturnCode]::Success.Value__)
                                    {
                                        Write-Output $createaadgroupresult.LogMsg
                                        ################################################################################
                                        # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAADGroup.ps1" `
                                                                    -ScriptSection "Create-AADGroup" `
                                                                    -InfoMessage $createaadgroupresult.LogMsg `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""
            
                                        ################################################################################
                                        
                                        Write-Output "----------------------------------------------------------------"  
                                        Write-Output "Update Azure configuration row `n"

                                            [string]$filterPT = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"AADPerm")
                                            [string]$filterGN = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("ADGroupName",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$result.ADGroupName)
                                            [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterPT,"and",$filterGN) 
                                                                                    
                                            $updateresultAADGroupID = Update-Table-Entry -TableName $global:ConfConfigurationTable `
                                                                                         -CustomFilter $finalFilter `
                                                                                         -RowKeytoChange "AADGroupID" `
                                                                                         -RowValuetoChange $createaadgroupresult.ReturnParameter1
                                            
                                            $updateresultValidated = Update-Table-Entry -TableName $global:ConfConfigurationTable `
                                                                                        -CustomFilter $finalFilter `
                                                                                        -RowKeytoChange "Validatet" `
                                                                                        -RowValuetoChange "true"

                                            if(($updateresultAADGroupID.ReturnCode -ne [ReturnCode]::Success.Value__) -or ($updateresultAADGroupID.ReturnCode -ne [ReturnCode]::Success.Value__))
                                            {
                                                #region Script Error

                                                Write-Error "Error update the configuration row. (go to output for more details)"
                                                Write-Output "Error update the configuration row."   
                                                Write-Output "Return Message for AADGroupID update: $($updateresultAADGroupID.LogMsg)"                                                                
                                                Write-Output "Return Message for Validated  update: $($updateresultValidated.LogMsg)"                                                                
                                                Write-Output "----------------------------------------------------------------"

                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -WorkflowID $wfguid `
                                                                            -ScriptName "TaskAADGroup.ps1" `
                                                                            -ScriptSection "AD/Get-AzTableRow" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error update the configuration row." `
                                                                            -AdditionalInfo "Return Message for AADGroupID update: $($updateresultAADGroupID.LogMsg), Return Message for Validated  update: $($updateresultValidated.LogMsg)"   


                                                #endregion
                                            }     
                                            else {
                                                ################################################################################
                                                # DebugMsg in Log Analytics

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAADGroup.ps1" `
                                                                                -ScriptSection "Create-AADGroup" `
                                                                                -InfoMessage "Update AADGroupID Key: $($updateresultAADGroupID.LogMsg), Update Validation Key: $($updateresultValidated.LogMsg)" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage ""

                                                ################################################################################
                                            }                                                                                                                  
                                    } 
                                    else {
                                                                               
                                        #region Script Error

                                        Write-Error "Error to create new azure active directory group. (go to output for more details)"
                                        Write-Output "Error to create new azure active directory group."                    
                                        Write-Output $createaadgroupresult.LogMsg
                                        Write-Output "----------------------------------------------------------------"

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAADGroup.ps1" `
                                                                    -ScriptSection "AD/Create-AADGroup" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $createaadgroupresult.LogMsg `
                                                                    -AdditionalInfo "Queue message: $($queueMessage)"


                                        #endregion                                        
                                    }    

                                    Write-Output "----------------------------------------------------------------"  
                                    Write-Output "Delete message from queue"
                                    $deletequeuemsgresult = $clqueue.CloudQueue.DeleteMessage($queueMessage) 
                            }
                            else {
                                #region Script Error

                                Write-Warning "Warning read the queue message because it null."
                                Write-Output "Warning read the queue message because it null."                    
                                Write-Output "----------------------------------------------------------------"

                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                    -ScriptName "TaskAADGroup.ps1" `
                                                    -ScriptSection "AD/Read message from queue" `
                                                    -InfoMessage "" `
                                                    -WarnMessage "Warning read the queue message because it null." `
                                                    -ErrorMessage ""

                                #endregion
                            }
                    }
                }
                else {
                    #region Script Error

                    Write-Error "Error storage context is null. Script ended."
                    Write-Output "Error storage context is null. Script ended."                    
                    Write-Output "----------------------------------------------------------------"

                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                        -ScriptName "TaskAADGroup.ps1" `
                                        -ScriptSection "AD/Create storage context" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage "Error storage context is null. Script ended."

                    #endregion
                }      
            } 
            elseif ($Source -eq "RemoveAD") {
                
                ############################################################################
                # Task for Workflow "Monitor AD Remove"
                ############################################################################

                Write-Output "Get Storage Account Queue" 
                #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
                $ctx = $global:StorageContext

                if($null -ne $ctx)
                {
                    Write-Output "Get Storage Queue"
                    $clqueue = Get-AzStorageQueue –Name $global:ConfCLMonitorConfig –Context $ctx 
                    
                    Write-Output "Check Storage queue for messages"
                    $invisibleTimeoutcheckqueue = [System.TimeSpan]::FromSeconds(1)
                    while ($null -ne $clqueue.CloudQueue.GetMessage($invisibleTimeoutcheckqueue))
                    {
                        Start-Sleep -Seconds 2

                        Write-Output "----------------------------------------------------------------"  
                        Write-Output "Set message invisible timeout to 90 seconds"
                            $invisibleTimeout = [System.TimeSpan]::FromSeconds(90)
                            $queueMessage = $clqueue.CloudQueue.GetMessage($invisibleTimeout)   

                            if($null -ne $queueMessage)
                            {
                                $result = $queueMessage.AsString | ConvertFrom-Json
                                
                                $wfguid = $result.WorkflowID

                                Write-Output "Queue message:"
                                                                
                                Write-Output "Rename AAD Group $($result.AADGroupName)"
                                    $renameresult = Rename-AADGroup -AADGroup $result.AADGroupName `
                                                                    -AADGroupID $result.AADGroupID


                                    if(($renameresult.ReturnMsg -eq [ReturnCode]::Success) -or ($renameresult.ReturnMsg -eq [ReturnCode]::Warning))
                                    {
                                        Write-Output $renameresult.LogMsg
                                            ################################################################################
                                            # DebugMsg in Log Analytics

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "TaskAADGroup.ps1" `
                                                                        -ScriptSection "Rename-AADGroup" `
                                                                        -InfoMessage $renameresult.LogMsg `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage ""
            
                                            ################################################################################


                                        Write-Output "Get config from configuration table to backup."
                                        #Backup Config Data
                                            $backupdata = Get-Info-from-Config-Table -TableRowKey $result.AADGroupName `
                                                                                     -TablePartitionKey $result.PartitionKey `
                                                                                     -TableName $global:ConfConfigurationTable
                                            if($backupdata.ReturnParameter1 -eq "true")
                                            {                           
                                                if($backupdata.ReturnMsg -eq [ReturnCode]::Success)
                                                {
                                                    ################################################################################
                                                    # DebugMsg in Log Analytics

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAADGroup.ps1" `
                                                                                -ScriptSection "Get-Info-from-Config-Table" `
                                                                                -InfoMessage $backupdata.LogMsg `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage ""

                                                    ################################################################################
                                                    Write-Output $backupdata.LogMsg
                                                    Write-Output "Backup Configuration data"
                                        
                                                        $backuprowkey = "Bak-$($result.AADGroupName)-$((Get-Date).ToFileTime())"                                                                                    

                                                        if($result.AzureRG -eq "null")
                                                        {
                                                            $TablePartitionkey = "ADBackup"
                                                        }
                                                        else {
                                                            $aadgroupresult = $backupdata.ReturnJsonParameters02 | ConvertFrom-Json  

                                                            Write-Output $aadgroupresult

                                                            $TablePartitionkey = "RBACBackup"

                                                            Write-Output "Switch to resource subscription $($aadgroupresult.SubscriptionID)"
                                                            Write-Output "----------------------------------------------------------------"
                                                            Set-AzContext -SubscriptionId $aadgroupresult.subscriptionId

                                                            Write-Output "Remove group $($global:ConfAADOldPermPrefix)$($result.AADGroupName) with permission $($aadgroupresult.RBACPermName) from resourcegroup $($result.AzureRG)"

                                                            $rbacassigmentresult = Remove-AzRoleAssignment -ResourceGroupName $result.AzureRG `
                                                                                                           -ObjectId $aadgroupresult.AADGroupID `
                                                                                                           -RoleDefinitionName $aadgroupresult.RBACPermName `
                                                                                                           -ErrorVariable rbacassignerror

                                                            Write-Output "Switch back to default subscription $($global:DefaultSubscriptionID)"
                                                            Write-Output "----------------------------------------------------------------"
                                                            Set-AzContext -SubscriptionId $global:DefaultSubscriptionID
                                                                                                                        
                                                            if($null -eq $rbacassignerror)
                                                            {
                                                                #region Script Error          
                                            
                                                                Write-Error "Error to remove rbac permission from resource group. (go to output for more details)"
                                                                Write-Output "Error to remove rbac permission from resource group."
                                                                Write-Output "Error message: $rbacassignerror"
                                                                Write-Output "----------------------------------------------------------------"
                                                                
                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                            -ScriptName "TaskAADGroup.ps1" `
                                                                                            -ScriptSection "RemoveAD/Remove RBAC from RG" `
                                                                                            -InfoMessage "" `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage $rbacassignerror `
                                                                                            -LogName "AppMpToolPermChanges"
                                                                #endregion
                                                            }
                                                            else {                                                                                                                     
                                                                
                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                                                                            -ScriptName "TaskAADGroup.ps1" `
                                                                                            -ScriptSection "RemoveAD/Remove RBAC from RG" `
                                                                                            -InfoMessage "Remove group $($global:ConfAADOldPermPrefix)$($result.AADGroupName) with permission $($aadgroupresult.RBACPermName) from resourcegroup $($result.AzureRG)" `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage "" `
                                                                                            -LogName "AppMpToolPermChanges"
                                                                                                                                
                                                                $resultmapping = Get-RBAC-Mapping `
                                                                                        -MappingTableName $global:ConfPermMappingTable `
                                                                                        -ConfigTableName $global:ConfConfigurationTable `
                                                                                        -mappingvalue "null" `
                                                                                        -RBACPerm $aadgroupresult.RBACPermName `
                                                                                        -RGName "null" `
                                                                                        -RequestType "RMAD" `
                                                                                        -SubscriptionID "null"

                                                                Write-Output $resultmapping

                                                                if($resultmapping.ReturnMsg -eq [ReturnCode]::Success)
                                                                {
                                                                    Write-Output "Switch to resource subscription $($aadgroupresult.SubscriptionID)"
                                                                    Write-Output "----------------------------------------------------------------"
                                                                    Set-AzContext -SubscriptionId $aadgroupresult.subscriptionId

                                                                    $mappingresult =  $resultmapping.ReturnJsonParameters02 | ConvertFrom-Json
                                                                    
                                                                    Write-Output "Remove permission tag $($mappingresult.MappringRBACShortName) from resourcegroup $($result.AzureRG)"
                                                                    
                                                                        $rg = Get-AzResourceGroup -Name $result.AzureRG
                                                                    
                                                                        $oldtagvalue = $rg.Tags[$global:ConfRGReqTag]
                                                                        $newtagvalue = $rg.Tags[$global:ConfRGReqTag].tolower().Replace("$($mappingresult.MappringRBACShortName.tolower()),", "")

                                                                    Write-Output "Old Tag value: $oldtagvalue"
                                                                    Write-Output "New Tag value: $newtagvalue"

                                                                        $replacedTags = @{$global:ConfRGReqTag = $newtagvalue}
                                                                        Update-AzTag -ResourceId $rg.ResourceId -Tag $replacedTags -Operation Merge                                                                    
                                                                    
                                                                    Write-Output "Switch back to default subscription $($global:DefaultSubscriptionID)"
                                                                    Write-Output "----------------------------------------------------------------"
                                                                    Set-AzContext -SubscriptionId $global:DefaultSubscriptionID

                                                                    Write-Output "Finish"
                                                                }
                                                                else {
                                                                    
                                                                }
                                                            }
                                                        }

                                                        $addbackupdata = Add-Info-to-ConfigBackup-Table -TablePartitionKey $TablePartitionkey `
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
                                                                                            -ScriptName "TaskAADGroup.ps1" `
                                                                                            -ScriptSection "Add-Info-to-ConfigBackup-Table" `
                                                                                            -InfoMessage $addbackupdata.LogMsg `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage ""

                                                            ################################################################################
                                                            Write-Output "Remove configuration from configurationtable"
                                        
                                                                $removerowitem = Remove-Info-from-Config-Table -TablePartitionKey $result.PartitionKey `
                                                                                                               -TableRowKey $result.AADGroupName `
                                                                                                               -TableName $global:ConfConfigurationTable
                                        
                                                            if($removerowitem.ReturnMsg -eq [ReturnCode]::Success)
                                                            {
                                                                Write-Output $removerowitem.LogMsg

                                                                ################################################################################
                                                                # DebugMsg in Log Analytics

                                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                                -WorkflowID $wfguid `
                                                                                                -ScriptName "TaskAADGroup.ps1" `
                                                                                                -ScriptSection "Remove-Info-from-Config-Table" `
                                                                                                -InfoMessage $removerowitem.LogMsg `
                                                                                                -WarnMessage "" `
                                                                                                -ErrorMessage ""

                                                                ################################################################################
                                                                Write-Output "Finish"
                                                                Write-Output "----------------------------------------------------------------"
                                                            }
                                                            else {
                                                                #region Script Error
                                            
                                                                Write-Error "Error in function Remove-Info-from-Config-Table. (go to output for more details"
                                                                Write-Error "Error in function Remove-Info-from-Config-Table."
                                                                Write-Error "Error Message: $($removerowitem.LogMsg)"
                                                    
                                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                            -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                            -ScriptSection "RemoveAD/Remove-Info-from-Config-Table" `
                                                                                            -InfoMessage "" `
                                                                                            -WarnMessage "" `
                                                                                            -ErrorMessage $removerowitem.LogMsg
                                                    
                                                                #endregion
                                        
                                                                Write-Output "----------------------------------------------------------------"
                                                            }   
                                                            
                                                            Write-Output "----------------------------------------------------------------"  
                                                            Write-Output "Delete message from queue"
                                                            $deletequeuemsgresult = $clqueue.CloudQueue.DeleteMessage($queueMessage)
                                                        }
                                                        else {
                                                            #region Script Error
                                        
                                                            Write-Error "Error in function Add-Info-to-ConfigBackup-Table. (go to output for more details"
                                                            Write-Error "Error in function Add-Info-to-ConfigBackup-Table."
                                                            Write-Error "Error Message: $($addbackupdata.LogMsg)"
                                                
                                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                                        -WorkflowID $wfguid `
                                                                                        -ScriptName "TaskAddMSGtoQueue.ps1" `
                                                                                        -ScriptSection "RemoveAD/Add-Info-to-ConfigBackup-Table" `
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
                                                                                -ScriptName "TaskAADGroup.ps1" `
                                                                                -ScriptSection "RemoveAD/Get-Info-from-Config-Table" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage $backupdata.LogMsg
                
                                                    #endregion
                                                    Write-Output "----------------------------------------------------------------"
                                                }
                                            }
                                            else
                                            {
                                                Write-Output "No Configuration found."
                                                ################################################################################
                                                # DebugMsg in Log Analytics

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                                -WorkflowID $wfguid `
                                                                                -ScriptName "TaskAADGroup.ps1" `
                                                                                -ScriptSection "Rename-AADGroup" `
                                                                                -InfoMessage "No Configuration found." `
                                                                                -WarnMessage "" `
                                                                                -ErrorMessage ""

                                                ################################################################################
                                                Write-Output "----------------------------------------------------------------"  
                                                Write-Output "Delete message from queue"
                                                $deletequeuemsgresult = $clqueue.CloudQueue.DeleteMessage($queueMessage) 
                                            }
                                    }
                                    else {
                                        #region Script Error
   
                                        Write-Error "Error in function Rename-AADGroup. (go to output for more details"
                                        Write-Error "Error in function Rename-AADGroup."
                                        Write-Error "Error Message: $($renameresult.LogMsg)"
    
                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "TaskAADGroup.ps1" `
                                                                    -ScriptSection "RemoveAD/Rename-AADGroup" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $renameresult.LogMsg
    
                                        #endregion
                                        Write-Output "----------------------------------------------------------------"
                                   }
                            }
                            else {
                                #region Script Error

                                Write-Warning "Warning read the queue message because it null."
                                Write-Output "Warning read the queue message because it null."                    
                                Write-Output "----------------------------------------------------------------"

                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                            -WorkflowID $wfguid `
                                                            -ScriptName "TaskAADGroup.ps1" `
                                                            -ScriptSection "RemoveAD/Read message from queue" `
                                                            -InfoMessage "" `
                                                            -WarnMessage "Warning read the queue message because it null." `
                                                            -ErrorMessage ""

                                #endregion
                            }
                    }
                }
                else {
                    #region Script Error

                    Write-Error "Error storage context is null. Script ended."
                    Write-Output "Error storage context is null. Script ended."                    
                    Write-Output "----------------------------------------------------------------"

                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                -WorkflowID $wfguid `
                                                -ScriptName "TaskAADGroup.ps1" `
                                                -ScriptSection "RemoveAD/Create storage context" `
                                                -InfoMessage "" `
                                                -WarnMessage "" `
                                                -ErrorMessage "Error storage context is null. Script ended."

                    #endregion
                }  
                
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
                                        -ScriptName "TaskAADGroup.ps1" `
                                        -ScriptSection "Main/Connect to Azure" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $loginazureresult.LogMsg
            #endregion
        }

        ############################################
        # Script finish
        ############################################

        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                    -WorkflowID $wfguid `
                                    -ScriptName "TaskAADGroup.ps1" `
                                    -ScriptSection "Script End" `
                                    -InfoMessage "Script run successful at $(Get-Date)" `
                                    -WarnMessage "" `
                                    -ErrorMessage ""
    }
    catch
    {
        Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
        Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"

        #region Script Error

        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                    -WorkflowID $wfguid `
                                    -ScriptName "TaskAADGroup.ps1" `
                                    -ScriptSection "Main script" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage $_.Exception.Message

        #endregion

        throw "Script exit with errors."
    }

#endregion
#######################################################################################################################