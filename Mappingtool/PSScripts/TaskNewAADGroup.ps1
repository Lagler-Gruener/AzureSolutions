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
    [ValidateSet('RG','AD')]
    [object] $Source,
    [parameter (Mandatory=$false)]
    [string] $AZRGName="null",
    [parameter (Mandatory=$false)]
    [object] $AADGroupParameters
) 

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-UnEnc

#endregion
#######################################################################################################################

#######################################################################################################################
#region Script start 

    try 
    {
        Write-Output "Connect to Azure"
            $loginazureresult = Login-Azure           

        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg        
            Write-Output "----------------------------------------------------------------"          

            if($Source -eq "RG")
            {
                ############################################################################
                # Task for Workflow "Add/Change RG Tag"
                ############################################################################

                if($AADGroupParameters.actiontype -eq "create")
                {
                    Write-Output "Create AAD Group named: $($AADGroupParameters.AADGroupName)"
                    $createaadgroupresult = Create-AADGroup -AADGroup $AADGroupParameters.AADGroupName                                             

                    if($createaadgroupresult.ReturnMsg -eq [ReturnCode]::Success)
                    {
                        Write-Output $createaadgroupresult.LogMsg
                        Write-Output "----------------------------------------------------------------"  

                        Write-Output "Add Information to Config Table"
                        $addinfotableresult = Add-Info-to-Config-Table -AADGroupName $AADGroupParameters.AADGroupName.ToLower() `
                                                                       -AADGroupID $createaadgroupresult.ReturnParameter1 `
                                                                       -RBACPermName $AADGroupParameters.AADGroupName.ToLower() `
                                                                       -RBACPermID $AADGroupParameters.RoleID `
                                                                       -ADGroupName $AADGroupParameters.ADGroupName.ToLower() `
                                                                       -ADGroupSID "null" `
                                                                       -AZRG $AZRGName.ToLower() `
                                                                       -TableName $global:ConfConfigurationTable `
                                                                       -TableResourceGroup $global:ConfApplRG `
                                                                       -TableStorageAccount $global:ConfApplStrAcc `
                                                                       -TablePartitionKey "RBACPerm"     
                        
                        if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                        {
                            Write-Output $addinfotableresult.LogMsg
                            Write-Output "----------------------------------------------------------------"  

                            Write-Output "Assign new AD Group(s) to the resource group $AZRGName"

                            Start-Sleep -Seconds 10
                            
                            $rbacassigmentresult = New-AzRoleAssignment -ResourceGroupName $AZRGName -ObjectId $createaadgroupresult.ReturnParameter1 -RoleDefinitionName $AADGroupParameters.MappingRBACPerm -ErrorVariable rbacassignerror

                            if($null -eq $rbacassignerror)
                            {
                                #region Script Error          
            
                                Write-Error "Error to add rbac permission to resource group. (go to output for more details)"
                                Write-Output "Error to add rbac permission to resource group."
                                Write-Output "Error message: $rbacassignerror"
                                Write-Output "----------------------------------------------------------------"
                                
                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                            -ScriptName "TaskNewAADGroup.ps1" `
                                                            -ScriptSection "RG/Add RBAC to RG" `
                                                            -InfoMessage "" `
                                                            -WarnMessage "" `
                                                            -ErrorMessage $rbacassignerror
                                #endregion
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
                                                        -ScriptName "TaskNewAADGroup.ps1" `
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

                        Write-Output "Add Information to Config Table"
                        $addinfotableresult = Add-Info-to-Config-Table -AADGroupName $AADGroupParameters.AADGroupName `
                                                                       -AADGroupID $createaadgroupresult.ReturnParameter1 `
                                                                       -RBACPermName $AADGroupParameters.AADGroupName `
                                                                       -RBACPermID $AADGroupParameters.RoleID `
                                                                       -ADGroupName $AADGroupParameters.ADGroupName `
                                                                       -ADGroupSID "null" `
                                                                       -TableName $global:ConfConfigurationTable `
                                                                       -TableResourceGroup $global:ConfApplRG `
                                                                       -TableStorageAccount $global:ConfApplStrAcc `
                                                                       -TablePartitionKey "RBACPerm" `
                                                                       -Validated "No"

                        #region script warning

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                    -ScriptName "TaskNewAADGroup.ps1" `
                                                    -ScriptSection "Create-AADGroup" `
                                                    -InfoMessage "" `
                                                    -WarnMessage $createaadgroupresult.LogMsg `
                                                    -ErrorMessage ""
                        
                        #endregion
                    }
                }
            }
            elseif ($Source -eq "AD") 
            {         
                ############################################################################
                # Task for Workflow "Application Add AD Group"
                ############################################################################

                Write-Output "Get Storage Account Queue" 
                $ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
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

                                Write-Output "----------------------------------------------------------------"  
                                Write-Output "Create AAD Group named: $($result.AADGroupName)"
                                    $createaadgroupresult = Create-AADGroup -AADGroup $result.AADGroupName 

                                    if($createaadgroupresult.ReturnCode -eq [ReturnCode]::Success.Value__)
                                    {
                                        Write-Output $createaadgroupresult.LogMsg

                                        Write-Output "----------------------------------------------------------------"  
                                        Write-Output "Get Azure configuration row `n"
                                            $configtable = Get-AzTableTable -TableName $global:ConfConfigurationTable -resourceGroup $global:ConfApplRG `
                                                                            -storageAccountName $global:ConfApplStrAcc

                                            [string]$filterPT = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"AADPerm")
                                            [string]$filterGN = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("ADGroupName",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$result.ADGroupName)
                                            [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterPT,"and",$filterGN) 
                                                                                    
                                            $newadgroupconfig = Get-AzTableRow -table $configtable -CustomFilter $finalFilter

                                            if($null -ne $newadgroupconfig)
                                            {
                                                Write-Output "Update AAD group ID to $($createaadgroupresult.ReturnParameter1)"
                                                $newadgroupconfig.AADGroupID = $createaadgroupresult.ReturnParameter1
                                                if($newadgroupconfig.Validatet -eq "open")
                                                {
                                                    Write-Output "Change validation state to true `n"
                                                        $newadgroupconfig.Validatet = "true"
                                                }
                                                
                                                $rupdrow = $newadgroupconfig | Update-AzTableRow -Table $configtable
                                                        
                                            }
                                            else {
                                                #region Script Error

                                                Write-Error "Error to find the configuration row based on filter. (go to output for more details)"
                                                Write-Output "Error to find the configuration row based on filter."   
                                                Write-Output "Filter: $finalFilter"                                                                
                                                Write-Output "----------------------------------------------------------------"

                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "TaskNewAADGroup.ps1" `
                                                                            -ScriptSection "AD/Create-AADGroup" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error to find the configuration row based on filter." `
                                                                            -AdditionalInfo "Search Filter: $($finalFilter). Queue Message: $($queueMessage)"


                                                #endregion
                                            }
                                            
                                            Write-Output "----------------------------------------------------------------"  
                                            Write-Output "Delete message from queue"
                                            $deletequeuemsgresult = $clqueue.CloudQueue.DeleteMessage($queueMessage)
                                    } 
                                    else {
                                                                               
                                        #region Script Error

                                        Write-Error "Error to create new azure active directory group. (go to output for more details)"
                                        Write-Output "Error to create new azure active directory group."                    
                                        Write-Output $createaadgroupresult.LogMsg
                                        Write-Output "----------------------------------------------------------------"

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -ScriptName "TaskNewAADGroup.ps1" `
                                                                    -ScriptSection "AD/Create-AADGroup" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $createaadgroupresult.LogMsg `
                                                                    -AdditionalInfo "Queue message: $($queueMessage)"


                                        #endregion

                                        Write-Output "Delete message from queue"
                                        $deletequeuemsgresult = $clqueue.CloudQueue.DeleteMessage($queueMessage) 
                                    }    
                            }
                            else {
                                #region Script Error

                                Write-Warning "Warning read the queue message because it null."
                                Write-Output "Warning read the queue message because it null."                    
                                Write-Output "----------------------------------------------------------------"

                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                    -ScriptName "TaskNewAADGroup.ps1" `
                                                    -ScriptSection "AD/Read message" `
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
                                        -ScriptName "MonNewADGroup.ps1" `
                                        -ScriptSection "Create storage context" `
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
                                        -ScriptName "MonNewADGroup.ps1" `
                                        -ScriptSection "Connect to Azure" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $loginazureresult.LogMsg
            #endregion
        }

        ############################################
        # Script finish
        ############################################

        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                    -ScriptName "TaskNewAADGroup.ps1" `
                                    -ScriptSection "End" `
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
                                    -ScriptName "TaskNewAADGroup.ps1" `
                                    -ScriptSection "Main script" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage $_.Exception.Message

        #endregion

        throw "Script exit with errors."
    }

#endregion
#######################################################################################################################