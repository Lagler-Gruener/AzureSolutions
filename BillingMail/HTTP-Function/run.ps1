using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Azure Function was started by HTTP trigger request"

try {
    Write-Host "Get request body data and filename"
        $body = $Request.Body.Data
        $filename = $Request.Body.Filename

    Write-Host "Define datatable"
        $table = New-Object System.Data.DataTable
        $table.Columns.Add("Cost","Decimal") | Out-Null
        $table.Columns.Add("BillingMonth","datetime") | Out-Null
        $table.Columns.Add("CostCenter","string") | Out-Null
        $table.Columns.add("ResourceGroup","string") | Out-Null
        $table.Columns.add("Error","string") | Out-Null

    Write-Host "Add rows from request data to datatable"
        foreach ($item in $body.properties.rows)
        {
            if($item[4].Length -eq 0)
            {
                $r = $table.NewRow()
                $r.Cost = [math]::Round($item[0],2)
                $r.BillingMonth = [DateTime]::Parse($item[1]).ToShortDateString()
                $r.CostCenter = $item[3]
                $r.ResourceGroup = $item[4]   
                $r.Error = "No ResourceGroup"
                $table.Rows.Add($r)
            }
            else {
                if($null -eq $($item[3]))
                {
                    $findresult = $table.Select("CostCenter= 'No Tag defined'")
                    if($findresult.Length -eq 0)
                    {
                        $r = $table.NewRow()
                        $r.Cost = [math]::Round($item[0],2)
                        $r.BillingMonth = [DateTime]::Parse($item[1]).ToShortDateString()
                        $r.CostCenter = "No Tag defined"
                        $r.ResourceGroup = $item[4]   
                        $r.Error = ""
                        $table.Rows.Add($r)
                    }
                    else {
                        $findresult[0].Cost += [math]::Round($item[0],2)
                        $findresult[0].ResourceGroup += "$($item[4]);"
                    }
                }
                else {                
                    $findresult = $table.Select("CostCenter= '$($item[3])'")

                    if($findresult.Length -eq 0)
                    {
                        $r = $table.NewRow()
                        $r.Cost = [math]::Round($item[0],2)
                        $r.BillingMonth = [DateTime]::Parse($item[1]).ToShortDateString()
                        $r.CostCenter = $item[3]
                        $r.ResourceGroup = $item[4]   
                        $r.Error = ""
                        $table.Rows.Add($r)
                    }
                    else {
                        $findresult[0].Cost += [math]::Round($item[0],2)
                        $findresult[0].ResourceGroup += "$($item[4]);"
                    }
                }
            }
        }

        if($table.rows.count -eq 0)
        {
            $r = $table.NewRow()
            $r.Cost = "0,00"
            $r.BillingMonth = ""
            $r.CostCenter = ""
            $r.ResourceGroup = ""
            $r.Error = "No billable resources found"
            $table.Rows.Add($r)

            $r = $table.NewRow()
            $r.Cost = ""
            $r.BillingMonth = "01/01/1111"
            $r.CostCenter = ""
            $r.ResourceGroup = ""
            $r.Error = ""
            $table.Rows.Add($r)
        }
        elseif ($table.Rows.Count -eq 1) 
        {
            $r = $table.NewRow()
            $r.Cost = "0,00"
            $r.BillingMonth = "01/01/1111"
            $r.CostCenter = ""
            $r.ResourceGroup = ""
            $r.Error = ""
            $table.Rows.Add($r)
        }

    Write-Host "Convert datatable to .csv and .html"
        $csvfile = ($table | Select-Object BillingMonth, Cost, CostCenter,ResourceGroup, Error | ConvertTo-Csv)
        $htmlvariable = ($table | Select-Object Cost, CostCenter | ConvertTo-Json)

    Write-Host "Create temp file and upload to Azure blob"          
        $TempFile = New-TemporaryFile
        Add-Content -Path $TempFile.FullName -Value $csvfile

        $StorageAccountName = $env:AppStorageAccountName
        $StorageAccountKey = $env:AppStorageAccountKey
        $StorageAccountContainer = $env:AppStorageAccountContainer
        
        Write-Host "Storage Configuration settings"
        Write-Host $StorageAccountName
        Write-Host $StorageAccountContainer

            $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

            $csvfile = Set-AzStorageBlobContent -File $TempFile.FullName `
                                                -Container $StorageAccountContainer `
                                                -Blob $filename `
                                                -Context $ctx `
                                                -Force

        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body = $htmlvariable
        })
    
}
catch {

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::ExpectationFailed
        Body = "Error in Script"
    })

}