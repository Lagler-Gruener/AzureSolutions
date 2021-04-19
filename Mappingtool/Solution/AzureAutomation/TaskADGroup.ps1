  <#
    .SYNOPSIS
        This script create a new On-Prem Active Directory Group

    .DESCRIPTION
        This script was executed by the main logic app
        This script includes the following steps:
            1.) Get messages from "on-premqueue"
            2.) Create an On-Prem Active Directory Group
            3.) Update the configuration item of the Azure Storage Table

    .EXAMPLE
        -
    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Mappingtool (tested with version: 1.0)  
            -ActiveDirectory (tested with version: 1.0.1.0)

        Required permissions:
            -         
                                   
#>

#Required Custom Module
using module MappingTool

param (
    [parameter (Mandatory=$true)]
    [ValidateSet('NewADGrp','MoveADGrp','DelADGroup')]
    [object] $Source,
    [parameter (Mandatory=$false)]
    [object] $ConfigTableData,
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

function Get-NewGrp-Message-from-Queue
{
    Write-Output "Get Storage Account Queue" 
        #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
        $ctx = $global:StorageContext
        
        if($null -ne $ctx)
        {
            Write-Output "Get Storage Queue"
            $opqueue = Get-AzStorageQueue –Name $global:ConfOnPremMsgQueue –Context $ctx  

            Write-Output "Check Storage queue for messages"
            $invisibleTimeoutcheckqueue = [System.TimeSpan]::FromSeconds(1)
            while ($null -ne $opqueue.CloudQueue.GetMessage($invisibleTimeoutcheckqueue))
            {
                Start-Sleep -Seconds 2
                Write-Output "----------------------------------------------------------------"  
                Write-Output "Set invisible timeout to 90 seconds"
                    $invisibleTimeout = [System.TimeSpan]::FromSeconds(90)
                    $queueMessagenewadgroup = $opqueue.CloudQueue.GetMessage($invisibleTimeout)   

                    if($null -ne $queueMessagenewadgroup)
                    {
                        $resultnewadgroup = $queueMessagenewadgroup.AsString | ConvertFrom-Json
                        $wfguid = $resultnewadgroup.WorkflowID

                        Write-Output "Queue message:"                            
                        Write-Output $resultnewadgroup
                        Write-Output "----------------------------------------------------------------" 

                        Write-Output "Create AD Group named: $($resultnewadgroup.ADGroupName)"
                        $resultcadgroup = Create-AD-Group -GroupName $resultnewadgroup.ADGroupName.toLower() `
                                                          -SamAccountName $resultnewadgroup.ADGroupName.toLower() `
                                                          -DisplayName $resultnewadgroup.ADGroupName.toLower() `
                                                          -GroupCategory "Security" `
                                                          -GroupScope "Global" `
                                                          -OUPath $resultnewadgroup.ADOUPath `
                                                          -Description $resultnewadgroup.ADGroupDesc `
                                                          -RequestType $resultnewadgroup.Type                    

                        if ($resultcadgroup.ReturnCode -eq [ReturnCode]::Success.Value__)
                        {                            
                            Write-Output $resultcadgroup.LogMsg
                            ################################################################################
                            # DebugMsg in Log Analytics

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskADGroup.ps1" `
                                                        -ScriptSection "Create-AD-Group " `
                                                        -InfoMessage $resultcadgroup.LogMsg `
                                                        -WarnMessage "" `
                                                        -ErrorMessage ""
            
                            ################################################################################
                            Write-Output $resultcadgroup.ReturnMsg
                        }        
                        else {

                            #region Script Error

                            Write-Error "Error to create new active directory group. (go to output for more details)"
                            Write-Output "Error to create new active directory group."                    
                            Write-Output $resultcadgroup.LogMsg
                            Write-Output "----------------------------------------------------------------"

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskNewADGroup.ps1" `
                                                        -ScriptSection "Create-AD-Group" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "" `
                                                        -ErrorMessage $resultcadgroup.LogMsg `
                                                        -AdditionalInfo "Queue message: $($queueMessagenewadgroup)"


                            #endregion                            
                        }

                        Write-Output "----------------------------------------------------------------"  
                        Write-Output "Delete message from queue"
                        $deletenewadgroupmsg = $opqueue.CloudQueue.DeleteMessage($queueMessagenewadgroup)
                    }
                    else {
                        #region Script Error

                        Write-Warning "Warning read the queue message because it null."
                        Write-Output "Warning read the queue message because it null."                    
                        Write-Output "----------------------------------------------------------------"

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                    -ScriptName "TaskADGroup.ps1" `
                                                    -ScriptSection "Get-NewGrp-Message-from-Queue/Read message" `
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
                                            -ScriptName "TaskADGroup.ps1" `
                                            -ScriptSection "Get-NewGrp-Message-from-Queue/Create storage context" `
                                            -InfoMessage "" `
                                            -WarnMessage "" `
                                            -ErrorMessage "Error storage context is null. Script ended."

            #endregion
        }                   
}

function Get-MoveGrp-Message-from-Queue
{
    Write-Output "Get Storage Account Queue" 
        #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
        $ctx = $global:StorageContext
        
        if($null -ne $ctx)
        {
            Write-Output "Get Storage Queue"
            $opqueue = Get-AzStorageQueue –Name $global:ConfOnPremMonitorConfig –Context $ctx  

            Write-Output "Check Storage queue for messages"
            $invisibleTimeoutcheckqueue = [System.TimeSpan]::FromSeconds(1)
            while ($null -ne $opqueue.CloudQueue.GetMessage($invisibleTimeoutcheckqueue))
            {
                Start-Sleep -Seconds 2
                Write-Output "----------------------------------------------------------------"  
                Write-Output "Set invisible timeout to 90 seconds"
                    $invisibleTimeout = [System.TimeSpan]::FromSeconds(90)
                    $queueMessagemoveadgroup = $opqueue.CloudQueue.GetMessage($invisibleTimeout)   

                    if($null -ne $queueMessagemoveadgroup)
                    {
                        $resultmoveadgroup = $queueMessagemoveadgroup.AsString | ConvertFrom-Json

                        $wfguid = $resultmoveadgroup.WorkflowID

                        Write-Output "Queue message:"                            
                        Write-Output $resultmoveadgroup
                        Write-Output "----------------------------------------------------------------" 

                        Write-Output "Move AD Group: $($resultmoveadgroup.ADGroupName)"
                        $resultmovegrp = Move-AD-Group -GroupName $resultmoveadgroup.ADGroupName.toLower() `
                                                       -OUPath $resultmoveadgroup.ADOUPath `
                                                       -Description $resultmoveadgroup.ADGroupDesc                                         

                        if ($resultmovegrp.ReturnCode -eq [ReturnCode]::Success.Value__)
                        {                            
                            Write-Output $resultmovegrp.LogMsg
                            ################################################################################
                            # DebugMsg in Log Analytics

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskADGroup.ps1" `
                                                        -ScriptSection "Move-AD-Group " `
                                                        -InfoMessage $resultmovegrp.LogMsg `
                                                        -WarnMessage "" `
                                                        -ErrorMessage ""
            
                            ################################################################################

                            Write-Output $resultmovegrp.ReturnMsg
                        }        
                        else {

                            #region Script Error

                            Write-Error "Error to move the active directory group. (go to output for more details)"
                            Write-Output "Error to move the active directory group."                    
                            Write-Output $resultmovegrp.LogMsg
                            Write-Output "----------------------------------------------------------------"

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                        -WorkflowID $wfguid `
                                                        -ScriptName "TaskADGroup.ps1" `
                                                        -ScriptSection "Get-MoveGrp-Message-from-Queue/Move-AD-Group" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "" `
                                                        -ErrorMessage $resultmovegrp.LogMsg `
                                                        -AdditionalInfo "Queue message: $($queueMessagemoveadgroup)"


                            #endregion                            
                        }

                        Write-Output "----------------------------------------------------------------"  
                        Write-Output "Delete message from queue"
                        $deletenewadgroupmsg = $opqueue.CloudQueue.DeleteMessage($queueMessagemoveadgroup)
                    }
                    else {
                        #region Script Error

                        Write-Warning "Warning read the queue message because it null."
                        Write-Output "Warning read the queue message because it null."                    
                        Write-Output "----------------------------------------------------------------"

                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                            -ScriptName "TaskADGroup.ps1" `
                                            -ScriptSection "Get-MoveGrp-Message-from-Queue/Read message" `
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
                                    -ScriptName "TaskNewADGroup.ps1" `
                                    -ScriptSection "Get-MoveGrp-Message-from-Queue/Create storage context" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage "Error storage context is null. Script ended."

            #endregion
        }   
}

#endregion
#######################################################################################################################

#######################################################################################################################
#region Script start 

try 
{
    $wfguid = GenerateWorkflowGuid
    Write-Output "WorkflowGuid: $wfguid"

    Write-Output "Connect to Azure"
        $loginazureresult = Login-Azure   
            
        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg

            if($Source -eq "NewADGrp")
            {
                Write-Output "Call function Get-NewGrp-Message-from-Queue"
                    Get-NewGrp-Message-from-Queue
            }
            elseif ($Source -eq "MoveADGrp") {
                Write-Output "Call function Get-MoveGrp-Message-from-Queue"
                    Get-MoveGrp-Message-from-Queue
            }
            elseif ($Source -eq "DelADGroup") {
                $ctx = $global:StorageContext
        
                if($null -ne $ctx)
                {
                    if($DebugScript -eq "true")
                    {
                        $webhook = $ConfigTableData | ConvertFrom-Json
                    }
                    else {
                        $webhook = $ConfigTableData
                    }

                    foreach ($config in $webhook)
                    {
                        Write-Output "----------------------------------------------------------------" 

                        Write-Output "Check configuration setting:"
                        Write-Output "AADGroupName: $($config.AADGroupName)"
                        Write-Output "ADGroupName: $($config.ADGroupName)"
                        Write-Output "ADGroupSID: $($config.ADGroupSID)"

                        if(($config.ADGroupSID.ToLower() -ne "null") -and ($config.AADGroupID.ToLower() -ne "null"))
                        {
                            $sid = $config.ADGroupSID
                            $adgroupresult = Get-ADGroup -Filter {SID -eq $sid}
                            if($null -eq $adgroupresult)
                            {
                                Write-Output "Group doesn't exist anymore!"
                                Write-Output "Add Group to queue"

                                $resultaddmsgtoqueue = Add-Msg-to-Queue -QueueName $global:ConfCLMonitorConfig `
                                                                        -WorkflowID $wfguid `
                                                                        -RequestType "AD-Rem" `
                                                                        -ADGroupName $config.ADGroupName `
                                                                        -ADGroupSID $config.ADGroupSID `
                                                                        -AADGroupID $config.AADGroupID `
                                                                        -AADGroupName $config.AADGroupName `
                                                                        -AzureRG $config.AzureRG `
                                                                        -SubscriptionID $config.SubscriptionID `
                                                                        -PartitionKey $config.PartitionKey                                                                        

                                if($resultaddmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                {
                                    Write-Output $resultaddmsgtoqueue.LogMsg
                                }
                                else {
                                    Write-Output $resultaddmsgtoqueue.LogMsg
                                }

                                ################################################################################
                                # DebugMsg in Log Analytics

                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Debug) `
                                                            -WorkflowID $wfguid `
                                                            -ScriptName "TaskADGroup.ps1" `
                                                            -ScriptSection "Add-Msg-to-Queue" `
                                                            -InfoMessage $resultaddmsgtoqueue.LogMsg `
                                                            -WarnMessage "" `
                                                            -ErrorMessage ""
            
                                ################################################################################
                            }
                            else {

                                    Write-Output "No changes for group."                                    
                            }
                        }

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
                                                    -ScriptName "TaskADGroup.ps1" `
                                                    -ScriptSection "DelADGroup/Create storage context" `
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
                                        -ScriptName "TaskADGroup.ps1" `
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
                                    -ScriptName "TaskADGroup.ps1" `
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
                                    -ScriptName "TaskADGroup.ps1" `
                                    -ScriptSection "Main script" `
                                    -InfoMessage "" `
                                    -WarnMessage "" `
                                    -ErrorMessage $_.Exception.Message

    #endregion

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################
