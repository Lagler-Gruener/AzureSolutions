<#
    .SYNOPSIS
       Initial script to check rg memberships.
        
    .DESCRIPTION
        Script was executed by Azure Logic App.       
            
            

    .EXAMPLE
        -    

    .NOTES  
        Required modules: 
             

        Required permissions:          
            
                                   
#>

Write-Output "Import Mapping Tool"
Set-AzAutomationModule -Name "MappingTool" `
                       -ContentLinkUri "https://appmappingtoolstracc.blob.core.windows.net/sources/MappingTool.zip" `
                       -ResourceGroupName "RG-Sol-MappingTool" `
                       -AutomationAccountName "AppMappingTool-automacc"

Write-Output "Import Mapping Tool LogA"
Set-AzAutomationModule -Name "MappingToolLogA" `
                       -ContentLinkUri "https://appmappingtoolstracc.blob.core.windows.net/sources/MappingToolLogA.zip" `
                       -ResourceGroupName "RG-Sol-MappingTool" `
                       -AutomationAccountName "AppMappingTool-automacc"

Start-AzAutomationRunbook -Name "UpdateMappingTool" `
                          -AutomationAccountName "ppMappingTool-automacc" `
                          -ResourceGroupName "RG-Sol-MappingTool" `
                          -RunOn "MappingTool"