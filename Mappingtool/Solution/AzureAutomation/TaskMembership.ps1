  <#
    .SYNOPSIS
        Change Group Membership task in Azure AD
       
        
    .DESCRIPTION
        Script was executed by Azure Logic App.
        Script check the following:
            1.) Get messages from Storage Queue (membership-queue)
            2.) Get Azure AD Group Membership
            3.) Update Azure AD Group (Add, Remove). Important only synced Users will be affected
            4.) Update the Configuration Table with the new uSNChanged Attribute 
           
            

    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Mappingtool (tested with version: 1.0) 

        Required permissions:          
            -Permission to the Azure Storage Queue (membership-queue)
            -Read permission to Azure Active Directory
            -Permission to the Azure Subscription
                                   
#>

#Required custom module
using module MappingTool

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-static

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start 

try {
    Write-Output "Connect to Azure"
    $loginazureresult = Login-Azure       

    if(($loginazureresult.ReturnMsg -eq [ReturnCode]::Success))
    {
        Write-Output $loginazureresult.LogMsg        
        Write-Output "----------------------------------------------------------------"   
        
        Write-Output "Get Storage Account Queue" 
            #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount 
            $ctx = $global:StorageContext

            #section storage context
            if($null -ne $ctx)
            {
                Write-Output "Get Storage Queue"
                $memberqueue = Get-AzStorageQueue –Name $global:ConfMembershipMsgQueue –Context $ctx 
                    
                Write-Output "Check Storage queue for messages"
                $invisibleTimeoutcheckqueue = [System.TimeSpan]::FromSeconds(1)
                while ($null -ne $memberqueue.CloudQueue.GetMessage($invisibleTimeoutcheckqueue))
                {
                    Start-Sleep -Seconds 2

                    Write-Output "----------------------------------------------------------------"  
                    Write-Output "Set message invisible timeout to 90 seconds"
                        $invisibleTimeout = [System.TimeSpan]::FromSeconds(90)
                        $queueMessage = $memberqueue.CloudQueue.GetMessage($invisibleTimeout)   

                        #section get msg fro queue
                        if($null -ne $queueMessage)
                        {
                            $result = $queueMessage.AsString | ConvertFrom-Json

                            Write-Output "Queue message:"
                            Write-Output $result                            
                            $onpremgroupmembershasht = @{}
                            
                            Write-Output "Get AD members from message queue and check if users are synced"
                            foreach ($user in $result.ADGroupMembers) {
                                
                                $resultsynccheck = Check-is-user-synced -upn $user.UserPrincipalName
                                Write-Output $resultsynccheck.LogMsg
                                
                                #section Check-is-user-synced
                                if("true" -eq $resultsynccheck.ReturnParameter1)
                                {
                                    $value = @()
                                    $value+=$user.UserPrincipalName
                                    $value+=($resultsynccheck.ReturnJsonParameters02 | ConvertFrom-Json).id
                                    $onpremgroupmembershasht.add($user.SID, $value)
                                }
                                else {
                                    Write-Output "Synced User $($user.UserPrincipalName) not found in Azure AD!"

                                    #region add group changes         
                            
                                        Write-Output "Add error to log analytics."
                                        
                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                    -ScriptName "TaskMembership.ps1" `
                                                                    -ScriptSection "Check-is-user-synced/Check if users are synced" `
                                                                    -ErrorMessage "Synced User $($user.UserPrincipalName) not found in Azure AD!" `
                                                                    -LogName "AppMpToolPermChanges"
                                    #endregion
                                }
                            }

                            #########################################################################################################

                            Write-Output "Get AAD Group with ID:$($result.AADGroupID) and name: $($result.AADGroupName) and their members."

                            $aadgroupmembers = Get-AzADGroupMember -ObjectId $result.AADGroupID 

                            $cloudgroupmembershasht = @{}
                            foreach ($member in $aadgroupmembers) {  
                                                    
                                $resultsynccheck = Check-is-user-synced -upn $member.UserPrincipalName
                                Write-Output $resultsynccheck.LogMsg

                                if("true" -eq $resultsynccheck.ReturnParameter1)
                                {
                                    $userdata = $resultsynccheck.ReturnJsonParameters02 | ConvertFrom-Json
                                    $cloudgroupmembershasht+=@{$($userdata).onPremisesSecurityIdentifier = $member.UserPrincipalName}
                                }
                                else {
                                    Write-Output "`t User $($member.UserPrincipalName) is a CLOUD ONLY user and will be ignored!"
                                }
                            }                           

                            #########################################################################################################

                            Write-Output "Compare Hashtables"

                            #section compare hashtables
                            foreach ($onpremuser in $onpremgroupmembershasht.Keys) 
                            {                               
                                if($cloudgroupmembershasht.Keys -notcontains $onpremuser)
                                {
                                    Write-Output "`t Add User: $($onpremgroupmembershasht.$onpremuser[0]) with ID: $($onpremgroupmembershasht.$onpremuser[1]) to the Cloud group"
                                    Add-AzADGroupMember -MemberObjectId $onpremgroupmembershasht.$onpremuser[1] -TargetGroupObjectId $result.AADGroupID 

                                    #region add group changes         
                            
                                    Write-Output "Add changes to log analytics."
                                    
                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                                                -ScriptName "TaskMembership.ps1" `
                                                                -ScriptSection "compare hashtables/Add User to AAD-Group" `
                                                                -InfoMessage "Add User $($onpremgroupmembershasht.$onpremuser[0]) to AAD-Group $($result.AADGroupName)" `
                                                                -LogName "AppMpToolPermChanges"
                                    #endregion
                                }
                            }  

                            #section compare hashtables
                            foreach ($clouduser in $cloudgroupmembershasht.Keys) 
                            {                               
                                if($onpremgroupmembershasht.Keys -notcontains $clouduser)
                                {
                                    Write-Output "`t Remove User: $($cloudgroupmembershasht.$clouduser) from the Cloud group"
                                    Remove-AzADGroupMember -MemberUserPrincipalName $cloudgroupmembershasht.$clouduser -GroupObjectId $result.AADGroupID 

                                    #region add group changes         
                            
                                    Write-Output "Add changes to log analytics."
                                    
                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
                                                                -ScriptName "TaskMembership.ps1" `
                                                                -ScriptSection "compare hashtables/Remove User from AAD-Group" `
                                                                -InfoMessage "Remove User $($cloudgroupmembershasht.$clouduser) from AAD-Group $($result.AADGroupName)" `
                                                                -LogName "AppMpToolPermChanges"
                                    #endregion
                                }
                            }  

                            Write-Output "Delete message from queue"
                            $deletequeuemsgresult = $memberqueue.CloudQueue.DeleteMessage($queueMessage)                                                    

                            Write-Output "Update Configuration Table"
                            [string]$filterPT = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$result.PermType)
                            [string]$filterGN = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("ADGroupName",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$result.ADGroupName)
                            [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterPT,"and",$filterGN) 
                                  
                            Write-Output "Change validation state to true"

                            $updateresultValidatet = Update-Table-Entry -TableName $global:ConfConfigurationTable `
                                                                        -CustomFilter $finalFilter `
                                                                        -RowKeytoChange "Validatet" `
                                                                        -RowValuetoChange "true"

                            Write-Output "Update the ADGroupuSNChanged"

                            $updateresultADGroupuSNChanged = Update-Table-Entry -TableName $global:ConfConfigurationTable `
                                                                                -CustomFilter $finalFilter `
                                                                                -RowKeytoChange "ADGroupuSNChanged" `
                                                                                -RowValuetoChange $result.uSNChanged

                            if(($updateresultADGroupuSNChanged.ReturnCode -ne [ReturnCode]::Success.Value__) -or ($updateresultValidatet.ReturnCode -ne [ReturnCode]::Success.Value__))
                            {
                                #region Script Error
                                    
                                Write-Error "Error update the configuration row. (go to output for more details)"
                                Write-Output "Error update the configuration row."   
                                Write-Output "Return Message for ADGroupuSNChanged update: $($updateresultADGroupuSNChanged.LogMsg)"                                                                
                                Write-Output "Return Message for Validated  update: $($updateresultValidatet.LogMsg)"                                                                
                                Write-Output "----------------------------------------------------------------"
                                    
                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                            -ScriptName "TaskMembership.ps1" `
                                                            -ScriptSection "Get-AzTableRow/Update Table Row" `
                                                            -InfoMessage "" `
                                                            -WarnMessage "" `
                                                            -ErrorMessage "Error update the configuration row." `
                                                            -AdditionalInfo "Return Message for ADGroupuSNChanged update: $($updateresultADGroupuSNChanged.LogMsg), Return Message for Validated  update: $($updateresultValidatet.LogMsg)"   
                                    
                                    
                                #endregion
                            }                             
                        }
                        else {
                            #region Script Error
    
                            Write-Warning "Warning read the queue message because it null."
                            Write-Output "Warning read the queue message because it null."                    
                            Write-Output "----------------------------------------------------------------"
    
                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                        -ScriptName "TaskMembership.ps1" `
                                                        -ScriptSection "get msg fro queue/Read message" `
                                                        -InfoMessage "" `
                                                        -WarnMessage "Warning read the queue message because it null." `
                                                        -ErrorMessage ""
    
                            #endregion
                        }
                }
            }
            else 
            {
                #region Script Error

                Write-Error "Error storage context is null. Script ended."
                Write-Output "Error storage context is null. Script ended."                    
                Write-Output "----------------------------------------------------------------"

                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                            -ScriptName "TaskMembership.ps1" `
                                            -ScriptSection "storage context/Create storage context" `
                                            -InfoMessage "" `
                                            -WarnMessage "" `
                                            -ErrorMessage "Error storage context is null. Script ended."

                    #endregion
            }  
            
        ############################################
        # Script finish
        ############################################

        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Success) `
        -ScriptName "TaskMembership.ps1" `
        -ScriptSection "Script End" `
        -InfoMessage "Script run successful at $(Get-Date)" `
        -WarnMessage "" `
        -ErrorMessage ""
    }
    else 
    {            
        #region Script Error          
            
        Write-Error "Error durring Connect to Azure. (go to output for more details)"
        Write-Output "Error durring Connect to Azure."
        Write-Output "Error message: $($loginazureresult.LogMsg)"
        Write-Output "----------------------------------------------------------------"
            
        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                    -ScriptName "TaskMembership.ps1" `
                                    -ScriptSection "Main/Connect to Azure" `
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

    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                -ScriptName "TaskMembership.ps1" `
                                -ScriptSection "Main Script" `
                                -InfoMessage "" `
                                -WarnMessage "" `
                                -ErrorMessage $_.Exception.Message

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################