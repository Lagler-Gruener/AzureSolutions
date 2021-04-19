  <#
    .SYNOPSIS
        Monitor On-Prem Active Directory OU for changes
        
    .DESCRIPTION
        Script was executed by Azure Logic App.
        Script check the following:
            1.) Get Information from Configuration Table
            2.) Get all Active Directory Groups based on Naming Schema
            3.) Compare the available groups and the configuration
            4.) If there is a new Group available, the information will be add to the cloud-queue

    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Mappingtool (tested with version: 1.0)  
            -ActiveDirectory (tested with version: 1.0.1.0)

        Required permissions:
            -Permission to the Azure Storage Queue (cloud-queue)          
            Permission to the Azure Storage Table (configuration)
                                   
#>

#######################################################################################################################
#region define global variables

using module MappingTool

Set-StrictMode -Version Latest

Get-Variable-Assets-static

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start 

try 
{
    [string]$wfguid = GenerateWorkflowGuid
    Write-Output "WorkflowGuid: $wfguid"

    Write-Output "Connect to Azure"
        $loginazureresult = Login-Azure
    Write-Output "----------------------------------------------------------------"

        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg
            Write-Output "----------------------------------------------------------------"
            Write-Output "Create Storage Account context"
                #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount    
                $ctx = $global:StorageContext

            Write-Output "----------------------------------------------------------------"
            
                if($null -ne $ctx)
                {
                    Write-Output "Call function Get-Info-from-Config-Table"
                    $resultconfigresult = Get-Info-from-Config-Table -TableRowKey "*" `
                                                                     -TablePartitionKey "*" `
                                                                     -TableName $global:ConfConfigurationTable
                                                                    
                    if(($resultconfigresult.ReturnMsg -eq [ReturnCode]::Success) -or ($resultconfigresult.ReturnMsg -eq [ReturnCode]::Warning))
                    {
                        $aadconfig = $resultconfigresult.ReturnJsonParameters02 | ConvertFrom-Json

                        Write-Output $resultconfigresult.LogMsg
                        ################################################################################
                        # DebugMsg in Log Analytics

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                    -WorkflowID $wfguid `
                                                    -ScriptName "MonADGroup.ps1" `
                                                    -ScriptSection "Get-Info-from-Config-Table" `
                                                    -InfoMessage $resultconfigresult.LogMsg `
                                                    -WarnMessage "" `
                                                    -ErrorMessage ""
            
                        ################################################################################
                        Write-Output "----------------------------------------------------------------"

                        Write-Output "Get Active Directory Groups from SearchBase $($global:ConfOUPathAADPerm)"
                            $adresult = Get-AdGroup -SearchBase $global:ConfOUPathAADPerm -Filter 'GroupCategory -eq "Security"'
                        Write-Output "----------------------------------------------------------------"

                        Write-Output "Compare results and check if new AD group was created without an AAD group"                        
                        foreach ($adgroup in $adresult)
                        {
                            Write-Output "Check Group $($adgroup.Name.ToLower())"
                            if(($adgroup.Name).toString().ToLower().StartsWith($global:OnPremAADRolePerm.ToLower()) -or `
                               ($adgroup.Name).toString().ToLower().StartsWith($global:OnPremAADRoleWithRolePerm.ToLower()))
                            {
                                Write-Output "Group Name match naming schema $($global:OnPremAADRolePerm.ToLower())"
                                Write-Output "Search for group in configuration"
                                if(($null -ne $aadconfig) -and ($aadconfig | where {$_.ADGroupSID -eq $adgroup.SID}))
                                {
                                    #Too much logging data.
                                    <# 
                                    ################################################################################
                                    # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "MonADGroup.ps1" `
                                                                    -ScriptSection "Get-AdGroup" `
                                                                    -InfoMessage "Group $($adgroup.Name) found, no more action required." `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""

                                    ################################################################################
                                    #>
                                    Write-Output "Group found."
                                    Write-Output "----------------------------------------------------------------"
                                }
                                else
                                {
                                    Write-Output "Group not found!"
                                    ################################################################################
                                    # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "MonADGroup.ps1" `
                                                                    -ScriptSection "Get-AdGroup" `
                                                                    -InfoMessage "Group $($adgroup.Name) not found" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""

                                    ################################################################################

                                    Write-Output "Create AAD Group name based on naming schema"
                                        $ADGroupName = $adgroup.Name
                                        $AADGroupName = "";
                                        $ADGroupSid = $adgroup.SID

                                        $RequestType = ""
                                        
                                        if (($adgroup.Name).toString().ToLower().StartsWith($global:OnPremAADRoleWithRolePerm.ToLower())) 
                                        {
                                            $RequestType = "AADWRole"
                                            $AADGroupName = ($adgroup.Name.tostring().ToLower().replace($global:OnPremAADRoleWithRolePerm.ToLower(),$global:NSAADRoleWithRolePerm)).ToLower()
                                        }                                    
                                        elseif(($adgroup.Name).toString().ToLower().StartsWith($global:OnPremAADRolePerm.ToLower()))
                                        {
                                            $RequestType = "AAD"
                                            $AADGroupName = ($adgroup.Name.tostring().ToLower().replace($global:OnPremAADRolePerm.ToLower(),$global:NSAADPerm)).ToLower()
                                        }

                                    Write-Output "On-Prem group name: $($adgroup.Name)"
                                    Write-Output "Cloud group name: $($AADGroupName)"

                                    Write-Output "Add new group to configuration table"
                                    $addinfotableresult = Add-Info-to-Config-Table -AADGroupName  $AADGroupName.ToLower() `
                                                                                   -AADGroupID "null" `
                                                                                   -ADGroupName $ADGroupName.ToLower() `
                                                                                   -ADGroupSID $ADGroupSid `
                                                                                   -ADGroupDN $adgroup.DistinguishedName `
                                                                                   -TableName $global:ConfConfigurationTable `
                                                                                   -TablePartitionKey "AADPerm"

                                    if($addinfotableresult.ReturnMsg -eq [ReturnCode]::Success)
                                    {
                                        Write-Output $addinfotableresult.LogMsg
                                        ################################################################################
                                        # DebugMsg in Log Analytics

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "MonADGroup.ps1" `
                                                                    -ScriptSection "Add-Info-to-Config-Table" `
                                                                    -InfoMessage $addinfotableresult.LogMsg `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage ""

                                        ################################################################################
                                        Write-Output $addinfotableresult.ReturnMsg

                                        Write-Output "----------------------------------------------------------------"
                                                        
                                        Write-Output "Add new AAD group request into Azure storage queue"
                                        Write-Output "----------------------------------------------------------------"                                                                                                                

                                        $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfCloudMsgQueue `
                                                                                -WorkflowID $wfguid `
                                                                                -RequestType $RequestType `
                                                                                -ADGroupName $ADGroupName.ToLower() `
                                                                                -ADGroupSID $ADGroupSid `
                                                                                -AADGroupName $AADGroupName.ToLower()                                                                                
                                        
                                        if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                        {
                                            Write-Output $resultaddmsgtoqueue.LogMsg
                                            Write-Output $resultaddmsgtoqueue.ReturnMsg

                                            ################################################################################
                                            # DebugMsg in Log Analytics

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "MonADGroup.ps1" `
                                                                        -ScriptSection "Add-Msg-to-Queue" `
                                                                        -InfoMessage $resultaddmsgtoqueue.LogMsg `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage ""
            
                                            ################################################################################

                                            Write-Output "----------------------------------------------------------------"
                                        }
                                        else {
                                            #region Script Error

                                            Write-Error "Error in function Add-Msg-to-Queue. (go to output for more details"
                                            Write-Error "Error in function Add-Msg-to-Queue."
                                            Write-Error "Error Message: $($resultaddmsgtoqueue.LogMsg)"

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                        -WorkflowID $wfguid `
                                                                        -ScriptName "MonADGroup.ps1" `
                                                                        -ScriptSection "Main/Add-Msg-to-Queue" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage $resultaddmsgtoqueue.LogMsg

                                            #endregion
                                        }
                                    }
                                    else {
                                
                                        #region Script Error
    
                                        Write-Error "Error in function Add-Info-to-Config-Table. (go to output for more details"
                                        Write-Error "Error in function Add-Msg-to-Queue."
                                        Write-Error "Error Message: $($addinfotableresult.LogMsg)"
    
                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -WorkflowID $wfguid `
                                                                    -ScriptName "MonADGroup.ps1" `
                                                                    -ScriptSection "Main/Add-Info-to-Config-Table" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "" `
                                                                    -ErrorMessage $addinfotableresult.LogMsg
    
                                        #endregion
                                    
                                    }
                                }
                            }
                            else {
                                Write-Output "Group Name isn't correct"
                            }
                        }
                    }                    
                    else {
                        #region Script Error

                        Write-Error "Error in function Get-Info-from-Config-Table. (go to output for more details"
                        Write-Error "Error in function Get-Info-from-Config-Table."
                        Write-Error "Error Message: $($resultconfigresult.LogMsg)"

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                        -WorkflowID $wfguid `
                                        -ScriptName "MonADGroup.ps1" `
                                        -ScriptSection "Main/Get-Info-from-Config-Table" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $resultconfigresult.LogMsg

                        #endregion
                    }
                }
                else {
                    #region Script Error

                    Write-Error "Error storage context is null. Script ended."
                    Write-Output "Error storage context is null. Script ended."                    
                    Write-Output "----------------------------------------------------------------"

                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                        -WorkflowID $wfguid `
                                        -ScriptName "MonADGroup.ps1" `
                                        -ScriptSection "Main/Create storage context" `
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
                                        -ScriptName "MonADGroup.ps1" `
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
                                    -ScriptName "MonADGroup.ps1" `
                                    -ScriptSection "Script End" `
                                    -InfoMessage "Script run successful at $(Get-Date)" `
                                    -WarnMessage "" `
                                    -ErrorMessage ""
    
}
catch
{
    Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
    Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"

    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                -WorkflowID $wfguid `
                                -ScriptName "MonADGroup.ps1" `
                                -ScriptSection "Main Script" `
                                -InfoMessage "" `
                                -WarnMessage "" `
                                -ErrorMessage $_.Exception.Message

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################