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

Get-Variable-Assets-UnEnc

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start 

try 
{
    Write-Output "Connect to Azure"
        $loginazureresult = Login-Azure
    Write-Output "----------------------------------------------------------------"

        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output "Create Storage Account context"
                $ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount    

            Write-Output "----------------------------------------------------------------"
            
                if($null -ne $ctx)
                {
                    Write-Output "Call function Get-Message-from-Queue"
                    $resultconfigresult = Get-Info-from-Config-Table -TableRowKey "*" `
                                                                     -TablePartitionKey "*" `
                                                                     -TableName $global:ConfConfigurationTable `
                                                                     -TableResourceGroup $global:ConfApplRG `
                                                                     -TableStorageAccount $global:ConfApplStrAcc
                                                                    
                    if($resultconfigresult.ReturnMsg -eq [ReturnCode]::Success)
                    {
                        $aadconfig = $resultconfigresult.ReturnJsonParameters02 | ConvertFrom-Json

                        Write-Output $resultconfigresult.LogMsg
                        Write-Output "----------------------------------------------------------------"

                        Write-Output "Get Active Directory Groups from SearchBase $($global:ConfOUPathAADPerm)"
                            $adresult = Get-AdGroup -SearchBase $global:ConfOUPathAADPerm -Filter 'GroupCategory -eq "Security"'
                        Write-Output "----------------------------------------------------------------"

                        Write-Output "Compare results and check if new AD group was created without an AAD group"                        
                        foreach ($adgroup in $adresult)
                        {
                            Write-Output "Check Group $($adgroup.Name.ToLower())"
                            if(($adgroup.Name).toString().ToLower().StartsWith($global:OnPremAADRolePerm.ToLower()))
                            {
                                Write-Output "Group Name match naming schema $($global:OnPremAADRolePerm.ToLower())"
                                Write-Output "Search for group in configuration"
                                if(($null -ne $aadconfig) -and ($aadconfig | where {$_.ADGroupSID -eq $adgroup.SID}))
                                {
                                    Write-Output "Group found."
                                    Write-Output "----------------------------------------------------------------"
                                }
                                else
                                {
                                    Write-Output "Group not found!"
                                    Write-Output "Create AAD Group name based on naming schema"

                                    $ADGroupName = $adgroup.Name
                                    $AADGroupName = ($adgroup.Name.tostring().ToLower().replace($global:OnPremAADRolePerm.ToLower(),$global:NSAADPerm)).ToLower()
                                    $ADGroupSid = $adgroup.SID

                                    Write-Output "On-Prem group name: $($adgroup.Name)"
                                    Write-Output "Cloud group name: $($AADGroupName)"

                                    Write-Output "Add new group to configuration table"
                                    $addinfotableresult = Add-Info-to-Config-Table -AADGroupName  $AADGroupName.ToLower() `
                                                                                   -AADGroupID "null" `
                                                                                   -ADGroupName $ADGroupName.ToLower() `
                                                                                   -ADGroupSID $ADGroupSid `
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
                                                        
                                        $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfCloudMsgQueue `
                                                                                -StorageAccountName $global:ConfApplStrAcc `
                                                                                -RequestType "AAD" `
                                                                                -ADGroupName $ADGroupName.ToLower() `
                                                                                -ADGroupSID $ADGroupSid `
                                                                                -AADGroupName $AADGroupName.ToLower()
                                        
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
                                                                        -ScriptName "MonNewADGroup.ps1" `
                                                                        -ScriptSection "Add-Msg-to-Queue" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "" `
                                                                        -ErrorMessage $resultaddmsgtoqueue.LogMsg

                                            #endregion
                                        }
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
                                        -ScriptName "MonNewADGroup.ps1" `
                                        -ScriptSection "Get-Info-from-Config-Table" `
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
                                        -ScriptName "MonNewADGroup.ps1" `
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
                                    -ScriptName "MonNewADGroup.ps1" `
                                    -ScriptSection "End" `
                                    -InfoMessage "Script run successful at $(Get-Date)" `
                                    -WarnMessage "" `
                                    -ErrorMessage ""
    
}
catch
{
    Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
    Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"

    Write-State-to-LogAnalytics -MessageType [ReturnCode]::Error `
                                -ScriptName "MonNewADGroup.ps1" `
                                -ScriptSection "Main" `
                                -InfoMessage "" `
                                -WarnMessage "" `
                                -ErrorMessage $_.Exception.Message

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################