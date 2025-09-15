# Usage: .\generate-logstash-columns.ps1 -CsvPath "gpu-z-log.csv" -ConfPath "logstash.conf"

param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    [Parameter(Mandatory = $true)]
    [string]$ConfPath
)

# Read the first non-empty line (header)
$header = Get-Content $CsvPath | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1

Write-Output "Header line from CSV:"
Write-Output $header

# Split columns, trim, and normalize names
$columns = $header -split "," | ForEach-Object {
    $col = $_.Trim()
    $col = $col -replace '\(.*?\)', ''
    $col = $col -replace '%', 'Percent'
    $col = $col -replace '\[.C]', 'Celsius'
    $col = $col -replace '\[', ''
    $col = $col -replace '\]', ''
    $col = $col -replace '\s+', ' '
    # Remove trailing/leading spaces and special chars
    $col = $col.Trim()
    # Replace spaces and dashes with underscores
    $col = $col -replace '[- ]+', '_'
    # Remove any remaining non-alphanumeric/underscore chars (if any)
    $col = $col -replace '[^A-Za-z0-9_]', ''
    # If empty (e.g. trailing comma), use a placeholder
    if ($col -eq "") { $col = "Extra_Empty_From_CSV" }
    $col
}

Write-Output "`nNormalized column names:"
$columns | ForEach-Object { Write-Output $_ }

# Build the Logstash columns array
$columnsArray = ($columns | ForEach-Object { '"{0}"' -f $_ }) -join ",`n    "
$logstashColumns = "columns => [`n    $columnsArray`n]"

Write-Host "`nGenerated columns array for Logstash:"
Write-Host $logstashColumns

# Infer types from original column names
$convertMap = @{}
$headerColumns = $header -split ","

for ($i = 0; $i -lt $headerColumns.Count; $i++) {
    $orig = $headerColumns[$i].Trim()
    $norm = $columns[$i]

    if ($norm -eq "Extra_Empty_From_CSV") { continue }

    if ($orig -match '\[MHz\]' -or $orig -match '\[W\]' -or $orig -match '\[V\]' -or $orig -match '\[°C\]' -or $orig -match '\[C\]') {
        $convertMap[$norm] = "float"
    } elseif ($orig -match '\[MB\]' -or $orig -match '\[RPM\]' -or $orig -match '\[%\]') {
        $convertMap[$norm] = "integer"
    }
    # Add more rules as needed
}

Write-Output "`nInferred convert map:"
$convertMap.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output "$($_.Key) => $($_.Value)" }

# Build convert block
if ($convertMap.Count -gt 0) {
    $convertBlock = "convert => {`n"
    foreach ($kv in $convertMap.GetEnumerator() | Sort-Object Name) {
        $convertBlock += '      "{0}" => "{1}"' -f $kv.Key, $kv.Value
        $convertBlock += "`n"
    }
    $convertBlock += "    }"
} else {
    $convertBlock = ""
}

# Update logstash.conf in place
# Replace the existing columns array in the conf file
$conf = Get-Content $ConfPath -Raw
$confNew = $conf -replace '(?s)(columns\s*=>\s*\[).*?(\])', "columns => [`n    $columnsArray`n    ]"
# Also update the existing strip array in the conf file
$stripArray = ($columns  | Where-Object { $_ -ne 'Extra_Empty_From_CSV' } | ForEach-Object { '"{0}"' -f $_ }) -join ",`n    "
$confNew = $confNew -replace '(?s)(strip\s*=>\s*\[).*?(\])', "strip => [`n    $stripArray`n    ]"
# Also update the existing convert block in the conf file
$confNew = $confNew -replace '(?s)(convert\s*=>\s*\{).*?(\})', $convertBlock

$confNew = $confNew.TrimEnd("`r", "`n")
Set-Content $ConfPath $confNew

Write-Host "`nlogstash.conf updated with new columns from CSV."
