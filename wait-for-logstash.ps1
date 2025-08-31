# wait-for-logstash.ps1
# Script to wait for Logstash to become available (Windows PowerShell)

$LS_HOST = "localhost"
$LS_PORT = 9600
$RETRY_INTERVAL = 2    # seconds between retries
$MAX_RETRIES = 30      # max number of retries before giving up

Write-Output "Waiting for Logstash to be available at $LS_HOST`:$LS_PORT..."

for ($i = 1; $i -le $MAX_RETRIES; $i++) {
    try {
        $response = Invoke-RestMethod -Uri "http://$LS_HOST`:$LS_PORT" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response -match "green") {
            Write-Output "Logstash is up!"
            exit 0
        }
    }
    catch {
        # Ignore errors and continue retrying
    }

    Write-Output "Attempt $i/${MAX_RETRIES}: Logstash not available yet. Retrying in ${RETRY_INTERVAL}s..."
    Start-Sleep -Seconds $RETRY_INTERVAL
}

Write-Output "Logstash did not become available after $($RETRY_INTERVAL * $MAX_RETRIES) seconds."
exit 1
