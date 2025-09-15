
# Usage: .\generate-logstash-columns.ps1 -CsvPath "gpu-z-log.csv" -ConfPath "logstash.conf"

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    [Parameter(Mandatory = $true)]
    [string]$ConfPath
)

function Get-CsvHeader {
    param([string]$Path)
    # Returns the first non-empty line from the CSV file
    return Get-Content $Path | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
}

function Convert-ColumnName {
    param([string]$col)
    # Remove parentheses and their contents
    $col = $col -replace '\(.*?\)', ''
    # Replace percent sign with 'Percent'
    $col = $col -replace '%', 'Percent'
    # Replace [°C] with 'Celsius'
    $col = $col -replace '\[\u00B0C\]', 'Celsius'
    # Remove brackets
    $col = $col -replace '\[', ''
    $col = $col -replace '\]', ''
    # Collapse multiple spaces
    $col = $col -replace '\s+', ' '
    $col = $col.Trim()
    # Replace spaces and dashes with underscores
    $col = $col -replace '[- ]+', '_'
    # Remove any remaining non-alphanumeric/underscore chars (if anything left)
    $col = $col -replace '[^A-Za-z0-9_]', ''
    if ($col -eq "") { $col = "Extra_Empty_From_CSV" }
    return $col
}

function Get-ColumnType {
    param([string]$orig)
    # Returns the inferred type for a column based on its original name
    if ($orig -match '\[MHz\]' -or $orig -match '\[W\]' -or $orig -match '\[V\]' -or $orig -match '\[°C\]' -or $orig -match '\[C\]') {
        return "float"
    }
    elseif ($orig -match '\[MB\]' -or $orig -match '\[RPM\]' -or $orig -match '\[%\]') {
        return "integer"
    }
    else {
        return $null
    }
}

function Format-LogstashArray {
    param([string[]]$columns)
    return ($columns | ForEach-Object { '"{0}"' -f $_ }) -join ",`r`n    "
}

function Format-ConvertBlock {
    param([hashtable]$convertMap)
    if ($convertMap.Count -eq 0) { return "" }
    $block = "convert => {`r`n"
    foreach ($kv in $convertMap.GetEnumerator() | Sort-Object Name) {
        $block += '      "{0}" => "{1}"' -f $kv.Key, $kv.Value + "`r`n"
    }
    $block += "    }"
    return $block
}

# Main script logic
$header = Get-CsvHeader -Path $CsvPath
Write-Output "Header line from CSV:"
Write-Output $header

$headerColumns = $header -split ","
$columns = @()
$convertMap = @{}

for ($i = 0; $i -lt $headerColumns.Count; $i++) {
    $orig = $headerColumns[$i].Trim()
    $norm = Convert-ColumnName $orig
    $columns += $norm
    $type = Get-ColumnType $orig
    if ($norm -ne "Extra_Empty_From_CSV" -and $type) {
        $convertMap[$norm] = $type
    }
}

Write-Output "`r`nNormalized column names:"
$columns | ForEach-Object { Write-Output $_ }

# Build Logstash config blocks
$columnsArray = Format-LogstashArray -columns $columns
$stripArray = Format-LogstashArray -columns ($columns | Where-Object { $_ -ne 'Extra_Empty_From_CSV' })
$convertBlock = Format-ConvertBlock -convertMap $convertMap

Write-Host "`r`nGenerated columns array for Logstash:"
Write-Host "columns => [`r`n    $columnsArray`r`n]"

Write-Output "`r`nInferred convert map:"
$convertMap.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output "$($_.Key) => $($_.Value)" }

# Update logstash.conf in place
$conf = Get-Content $ConfPath -Raw
$confNew = $conf -replace '(?s)(columns\s*=>\s*\[).*?(\])', "columns => [`r`n    $columnsArray`r`n    ]"
$confNew = $confNew -replace '(?s)(strip\s*=>\s*\[).*?(\])', "strip => [`r`n    $stripArray`r`n    ]"
$confNew = $confNew -replace '(?s)(convert\s*=>\s*\{).*?(\})', $convertBlock
$confNew = $confNew.TrimEnd("`r", "`n")
Set-Content $ConfPath $confNew

Write-Host "`r`nlogstash.conf updated with new columns from CSV."
