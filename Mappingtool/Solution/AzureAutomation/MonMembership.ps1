  <#
    .SYNOPSIS
       Initial script to check group memberships.
        
    .DESCRIPTION
        Script was executed by Azure Logic App.
        Script check the following:
            1.) Get Active Directory Group based on configuration setting
            2.) Get Active Directory Group members
            3.) Get Azure Active Directory Group based on configuration setting
            4.) If the uSNChanged in Active Directory was updated the next step will executed
            4.) Add configuration to membership-queue
            

    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Mappingtool (tested with version: 1.0)  
            -ActiveDirectory (tested with version: 1.0.1.0)

        Required permissions:          
            -Permission to the Azure Storage Table (configuration)
            -Permission to the Azure Storage Queue (membership-queue)
            -Read permission to Active Directory
            -Read permission to Azure Active Directory
                                   
#>

#Required custom module
using module MappingTool

[CmdletBinding()]
param (
    [parameter (Mandatory=$true)]
    [object] $ConfigTableData,
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
    if($DebugScript -eq "true")
    {
        $MonMem = $ConfigTableData | ConvertFrom-Json
    }
    else {
        $MonMem = $ConfigTableData
    } 

    Write-Output "Connect to Azure"
        $loginazureresult = Login-Azure
    Write-Output "----------------------------------------------------------------"

        if($loginazureresult.ReturnMsg -eq [ReturnCode]::Success)
        {
            Write-Output $loginazureresult.LogMsg
            Write-Output $loginazureresult.ReturnMsg
            Write-Output "----------------------------------------------------------------"

            Write-Output "Create Storage Account context"
            Write-Output "----------------------------------------------------------------"
                #$ctx = New-AzStorageContext -StorageAccountName $global:ConfApplStrAcc -UseConnectedAccount   
                $ctx = $global:StorageContext

                #Section storage context
                if($null -ne $ctx)
                {                  
                    foreach ($config in $MonMem)
                    {
                        Write-Output "Check configuration setting:"
                        Write-Output "AADGroupName: $($config.AADGroupName)"
                        Write-Output "ADGroupName: $($config.ADGroupName)"

                        #section check configuration
                        if(($config.ADGroupSID.ToLower() -ne "null") -and ($config.AADGroupID.ToLower() -ne "null"))
                        {
                            $sid = $config.ADGroupSID

                            $adgroupresult = Get-ADGroup -filter {SID -eq $sid} -Properties Members,uSNChanged
                            #section get-adgroup
                            if($null -ne $adgroupresult)
                            {
                                if($adgroupresult.Name.ToLower() -ne $config.ADGroupName)
                                {
                                    Write-Warning "Waring The Active Directory Group $($config.ADGroupName) was renamed. New name: $($adgroupresult.Name)"
                                    Write-Output "Waring The Active Directory Group $($config.ADGroupName) was renamed. New name: $($adgroupresult.Name)"                    
                                    Write-Output "----------------------------------------------------------------"

                                    #region script warning

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                        -ScriptName "MonMembership.ps1" `
                                        -ScriptSection "get-adgroup/Check AD group name" `
                                        -InfoMessage "" `
                                        -WarnMessage "Waring The Active Directory Group $($config.ADGroupName) was renamed. New name: $($adgroupresult.Name)" `
                                        -ErrorMessage ""

                                    #endregion
                                }

                                #section check location
                                if($adgroupresult.DistinguishedName.ToLower() -eq $config.ADGroupDN)
                                {
                                    $groupname = Get-AzADGroup -ObjectId $config.AADGroupID

                                    #section check aad group
                                    if($null -ne $groupname)
                                    {
                                        if($config.ADGroupuSNChanged -ne $adgroupresult.uSNChanged)
                                        {
                                            Write-Output "Get group membership"
                                            $members = [System.Collections.ArrayList]@()
                                            foreach($member in $adgroupresult.Members)
                                            {
                                                $memberdetails = Get-ADUser -Identity $member

                                                if(!($null -eq $memberdetails.UserPrincipalName))
                                                {
                                                    $member = @{"Name"=$memberdetails.Name;
                                                                "UserPrincipalName"=$memberdetails.UserPrincipalName;
                                                                "Surname"=$memberdetails.Surname;
                                                                "GivenName"=$memberdetails.GivenName;
                                                                "SID"=$memberdetails.SID.value}     
                                                
                                                    $addmember = $members.Add($member)
                                                    Write-Output "Add member $($member.UserPrincipalName) to the array."                                            
                                                }
                                                else {
                                                    Write-Warning "Waring the user $($memberdetails.Name) with SID $($memberdetails.SID.value), haven't an UPN defined!"

                                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                                -ScriptName "MonMembership.ps1" `
                                                                                -ScriptSection "add msg to queue/Get-ADUser" `
                                                                                -InfoMessage "" `
                                                                                -WarnMessage "Waring the user $($memberdetails.Name) with SID $($memberdetails.SID.value), haven't an UPN defined!" `
                                                                                -ErrorMessage ""
                                                }
                                            }         
    
                                            $jsonmsg = @{"ADGroupName" = $config.ADGroupName
                                                         "ADGroupMembers" = $members
                                                         "uSNChanged"=$adgroupresult.uSNChanged
                                                         "AADGroupName"= $config.AADGroupName
                                                         "AADGroupID" = $config.AADGroupID
                                                         "AzureRG" = $config.AzureRG
                                                         "PermType" = $config.PartitionKey
                                                        } | ConvertTo-Json 
    
                                            Write-Output "----------------------------------------------------------------"
                                            
                                            Write-Output "Add membership message to queue"
                                            Write-Output "Message: $jsonmsg"
                                            $addmsgtoqueue = Add-Msg-to-MembershipQueue -QueueName $Global:ConfMembershipMsgQueue `
                                                                                        -QueueMessage $jsonmsg
                                            
                                            #section add msg to queue
                                            if($addmsgtoqueue.ReturnMsg -eq [ReturnCode]::Success)
                                            {                                            
                                                Write-Output "----------------------------------------------------------------"
                                            }
                                            else {
                                                #region Script Error          
                            
                                                Write-Error "Error add message to queue $($Global:ConfMembershipMsgQueue). (go to output for more details)"
                                                Write-Output "Error add message to queue."
                                                Write-Output "Error message: $($addmsgtoqueue.LogMsg)"
                                                Write-Output "----------------------------------------------------------------"
                                                
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "MonMembership.ps1" `
                                                                            -ScriptSection "add msg to queue/Add-Msg-to-MembershipQueue" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage $addmsgtoqueue.LogMsg
                                                #endregion
                                            }
                                        }
                                        else {
                                            Write-Output "No group changes found"
                                            Write-Output "----------------------------------------------------------------"
                                        }                                        
                                    }
                                    else {
                                        Write-Warning "Waring The Azure Active Directory Group $($config.AADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!"
                                        Write-Output "Waring The Azure Active Directory Group $($config.AADGroupName) doesn't exist! Please review the configuration settings or delete the configuration item!"                    
                                        
                                        Write-Output "Change group configuration to not validated."
                                        Write-Output "Update Azure configuration row `n"
                                                                                                                                
                                        $updateresultValidated = Update-Table-Entry -TableName $global:ConfConfigurationTable `
                                                                                    -TableRowKey $config.RowKey `
                                                                                    -TablePartitionKey $config.PartitionKey `
                                                                                    -RowKeytoChange "Validatet" `
                                                                                    -RowValuetoChange "false"                                                                                    

                                        if(($updateresultValidated.ReturnCode -ne [ReturnCode]::Success.Value__))
                                        {
                                            #region Script Error

                                                Write-Error "Error update the configuration row. (go to output for more details)"
                                                Write-Output "Error update the configuration row."   
                                                Write-Output "Return Message for AADGroupID update: $($updateresultValidated.LogMsg)"                                                                
                                                Write-Output "Return Message for Validated  update: $($updateresultValidated.LogMsg)"                                                                
                                                Write-Output "----------------------------------------------------------------"

                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "MonMembership.ps1" `
                                                                            -ScriptSection "Update-Table-Entry/AD Group not found" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error update the configuration row." `
                                                                            -AdditionalInfo "Return Message for Validated  update: $($updateresultValidated.LogMsg)"   


                                                #endregion
                                        }  

                                        $addissuetotable = Add-Info-to-ConfigIssue-Table -TableName $global:ConfPermIssueTable `
                                                                                         -TableRowKey $config.RowKey `
                                                                                         -TablePartitionKey $config.PartitionKey `
                                                                                         -IssueType "AAD-Del" `
                                                                                         -IssueMsg "Waring The Azure Active Directory Group $($config.AADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!"
                                        
                                        if(($addissuetotable.ReturnCode -ne [ReturnCode]::Success.Value__))
                                        {
                                            #region Script Error
                                                 
                                                Write-Error "Error add issue to table. (go to output for more details)"
                                                Write-Output "Error add issue to table."   
                                                Write-Output "Return Message for ADDIssuetoTable $($addissuetotable.LogMsg)"                                                                                                                           
                                                Write-Output "----------------------------------------------------------------"
                                                 
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "MonMembership.ps1" `
                                                                            -ScriptSection "Add-Info-to-ConfigIssue-Table/AD Group not found" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error update the configuration row." `
                                                                            -AdditionalInfo "Return Message for Validated  update: $($addissuetotable.LogMsg)"   
                                                 
                                                 
                                            #endregion
                                        }

                                        Write-Output "----------------------------------------------------------------"

                                        #region script warning

                                            Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                        -ScriptName "MonMembership.ps1" `
                                                                        -ScriptSection "check aad group/Check if AAD Group exist" `
                                                                        -InfoMessage "" `
                                                                        -WarnMessage "Waring The Azure Active Directory Group $($config.AADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!" `
                                                                        -ErrorMessage ""

                                        #endregion
                                    }
                                }
                                else {
                                    Write-Warning "Waring The Active Directory Group $($config.ADGroupName) was moved from the initial location. Initial Location: $($config.ADGroupDN), new location: $($adgroupresult.DistinguishedName)"
                                    Write-Output "Waring The Active Directory Group $($config.ADGroupName) was moved from the initial location. Initial Location: $($config.ADGroupDN), new location: $($adgroupresult.DistinguishedName)"                    
                                    Write-Output "----------------------------------------------------------------"

                                    #region script warning

                                        Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                    -ScriptName "MonMembership.ps1" `
                                                                    -ScriptSection "check location/Check group location" `
                                                                    -InfoMessage "" `
                                                                    -WarnMessage "Waring The Active Directory Group $($config.ADGroupName) was moved from the initial location. Initial Location: $($config.ADGroupDN), new location: $($adgroupresult.DistinguishedName)" `
                                                                    -ErrorMessage ""

                                    #endregion

                                        $addissuetotable = Add-Info-to-ConfigIssue-Table -TableName $global:ConfPermIssueTable `
                                                                                         -TableRowKey $config.RowKey `
                                                                                         -TablePartitionKey $config.PartitionKey `
                                                                                         -IssueType "AD-Mv" `
                                                                                         -IssueMsg "Waring The Active Directory Group $($config.ADGroupName) was moved from the initial location. Initial Location: $($config.ADGroupDN), new location: $($adgroupresult.DistinguishedName)"
                                        
                                        if(($addissuetotable.ReturnCode -ne [ReturnCode]::Success.Value__))
                                        {
                                            #region Script Error
                                                 
                                                Write-Error "Error add issue to table. (go to output for more details)"
                                                Write-Output "Error add issue to table."   
                                                Write-Output "Return Message for ADDIssuetoTable $($addissuetotable.LogMsg)"                                                                                                                           
                                                Write-Output "----------------------------------------------------------------"
                                                 
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "MonMembership.ps1" `
                                                                            -ScriptSection "Add-Info-to-ConfigIssue-Table/AD Group not found" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error update the configuration row." `
                                                                            -AdditionalInfo "Return Message for Validated  update: $($addissuetotable.LogMsg)"   
                                                 
                                                 
                                            #endregion
                                        }
                                }
                            }
                            else {
                                Write-Warning "Waring The Active Directory Group $($config.ADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!"
                                Write-Output "Waring The Azure Active Directory Group $($config.ADGroupName) doesn't exist! Please review the configuration settings or delete the configuration item!"                    
                                Write-Output "----------------------------------------------------------------"

                                #region script warning

                                    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                                                -ScriptName "MonMembership.ps1" `
                                                                -ScriptSection "get-adgroup/Check if ADGroup exist" `
                                                                -InfoMessage "" `
                                                                -WarnMessage "Waring The Active Directory Group $($config.ADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!" `
                                                                -ErrorMessage ""

                                #endregion

                                        $addissuetotable = Add-Info-to-ConfigIssue-Table -TableName $global:ConfPermIssueTable `
                                                                                         -TableRowKey $config.RowKey `
                                                                                         -TablePartitionKey $config.PartitionKey `
                                                                                         -IssueType "AD-Del" `
                                                                                         -IssueMsg "Waring The Active Directory Group $($config.ADGroupName) doesn't exist! Please review the configuration settings or delete the configuration!"
                                        
                                        if(($addissuetotable.ReturnCode -ne [ReturnCode]::Success.Value__))
                                        {
                                            #region Script Error
                                                 
                                                Write-Error "Error add issue to table. (go to output for more details)"
                                                Write-Output "Error add issue to table."   
                                                Write-Output "Return Message for ADDIssuetoTable $($addissuetotable.LogMsg)"                                                                                                                           
                                                Write-Output "----------------------------------------------------------------"
                                                 
                                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                                                            -ScriptName "MonMembership.ps1" `
                                                                            -ScriptSection "Add-Info-to-ConfigIssue-Table/AD Group not found" `
                                                                            -InfoMessage "" `
                                                                            -WarnMessage "" `
                                                                            -ErrorMessage "Error update the configuration row." `
                                                                            -AdditionalInfo "Return Message for Validated  update: $($addissuetotable.LogMsg)"   
                                                 
                                                 
                                            #endregion
                                        }

                            }                                                    
                        }
                        else {
                            Write-Warning "Warning The configuration setting for Rowkey $($config.RowKey) is incomplete! Please check the AADGroupID and the ADSID setting!"
                            Write-Output "Warning The configuration setting for Rowkey $($config.RowKey) is incomplete! Please check the AADGroupID and the ADSID setting!"                    
                            Write-Output "----------------------------------------------------------------"

                            #region script warning

                                Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Warning) `
                                -ScriptName "MonMembership.ps1" `
                                -ScriptSection "check configuration/Check configuration settings" `
                                -InfoMessage "" `
                                -WarnMessage "The configuration setting for Rowkey $($config.RowKey) is incomplete! Please check the AADGroupID and the ADSID setting!" `
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
                                            -ScriptName "MonMembership.ps1" `
                                            -ScriptSection "storage context/Create storage context" `
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
                                        -ScriptName "MonMembership.ps1" `
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
                                    -ScriptName "MonMembership.ps1" `
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
                                -ScriptName "MonMembership.ps1" `
                                -ScriptSection "Main Script" `
                                -InfoMessage "" `
                                -WarnMessage "" `
                                -ErrorMessage $_.Exception.Message

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################