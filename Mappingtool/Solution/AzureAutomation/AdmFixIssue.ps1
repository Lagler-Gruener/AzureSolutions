  <#
    .SYNOPSIS
        Admin script to fix current configuration issue
        
    .DESCRIPTION
        

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
            -Permission to the Azure Storage Table (configuration)
                                   
#>

#Required custom module
using module MappingTool

[CmdletBinding()]
param (
    [parameter (Mandatory=$true)]
    [object] $PartitionKey,
    [parameter (Mandatory=$true)]
    [object] $RowKey,
    [parameter (Mandatory=$true)]
    [ValidateSet('fix','discard')]
    [object] $Action

)

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-static

#endregion
#######################################################################################################################

try 
{  
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
                    $fixissueresult = Call-Fix-Configuration-Issue -PartitionKey $PartitionKey `
                                                                   -RowKey $RowKey `
                                                                   -Action $Action
                }
        }        
}
catch
{
    Write-Error "Error in Main script section section. Error message: $($_.Exception.Message)"
    Write-Output "Error in Main script section section. Error message: $($_.Exception.Message)"

    Write-State-to-LogAnalytics -MessageType $([ReturnCode]::Error) `
                                -ScriptName "AdmFixIsses.ps1" `
                                -ScriptSection "Main Script" `
                                -InfoMessage "" `
                                -WarnMessage "" `
                                -ErrorMessage $_.Exception.Message

    throw "Script exit with errors."
}

#endregion
#######################################################################################################################
    