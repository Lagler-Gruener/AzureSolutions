<#
    .SYNOPSIS
       Initial script to check rg memberships.
        
    .DESCRIPTION
        Script was executed by Azure Logic App.
        Script check the following:
            
            

    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
            -Az.Accounts  (tested with Version: 1.7.5)
            -Az.Storage   (tested with Version: 1.14.0)
            -Mappingtool (tested with version: 1.0)  

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
    [object] $ConfigTableData
)

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest

Get-Variable-Assets-static

#endregion
#######################################################################################################################

