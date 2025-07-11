#!/bin/bash

# Script to wait for Logstash to become available
# chmod +x wait-for-logstash.sh
# ./wait-for-logstash.sh

LS_HOST="localhost"
LS_PORT=9600
RETRY_INTERVAL=2  # seconds between retries
MAX_RETRIES=30    # max number of retries before giving up

echo "Waiting for Logstash to be available at ${LS_HOST}:${LS_PORT}..."

for ((i=1; i<=MAX_RETRIES; i++)); do
    response=$(curl -s -X GET "${LS_HOST}:${LS_PORT}")
    if [[ $? -eq 0 && "$response" == *"green"* ]]; then
        echo "Logstash is up! ✅"
        exit 0
    fi
    echo "Attempt $i/${MAX_RETRIES}: Logstash not available yet. Retrying in ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

echo "Logstash did not become available after $((RETRY_INTERVAL * MAX_RETRIES)) seconds. ❌"
exit 1
