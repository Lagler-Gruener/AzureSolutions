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


#######################################################################################################################
#region define global variables

using module MappingTool

Set-StrictMode -Version Latest

Get-Variable-Assets-UnEnc


#endregion
#######################################################################################################################

#######################################################################################################################
#region Functions

function Get-Message-from-Queue
{
    Write-Output "Get Storage Account Queue" 
        $ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
        
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

                        if ($resultcadgroup.ReturnMsg -eq [ReturnCode]::Success)
                        {                            
                            Write-Output $resultcadgroup.LogMsg
                            Write-Output $resultcadgroup.ReturnMsg
                        }        
                        else {

                            #region Script Error

                            Write-Error "Error to create new active directory group. (go to output for more details)"
                            Write-Output "Error to create new active directory group."                    
                            Write-Output $resultcadgroup.LogMsg
                            Write-Output "----------------------------------------------------------------"

                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
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
                                            -ScriptName "TaskNewADGroup.ps1" `
                                            -ScriptSection "Read message" `
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
                                    -ScriptSection "Create storage context" `
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
    Write-Output "Connect to Azure"
        $loginazureresult = Login-Azure   
            
        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg

            Write-Output "Call function Get-Message-from-Queue"
                Get-Message-from-Queue
        }
        else {            
            #region Script Error          
            
            Write-Error "Error durring Connect to Azure. (go to output for more details)"
            Write-Output "Error durring Connect to Azure."
            Write-Output "Error message: $($loginazureresult.LogMsg)"
            Write-Output "----------------------------------------------------------------"
            
            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                        -ScriptName "TaskNewADGroup.ps1" `
                                        -ScriptSection "Connect to Azure" `
                                        -InfoMessage "" `
                                        -WarnMessage "" `
                                        -ErrorMessage $loginazureresult.LogMsg
            #endregion
        }
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
