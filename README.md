# GPU-Z Logstash

This project automates pushing GPU-Z data to ElasticSearch.

## First Usage

1. Run GPU-Z, go to `Sensors` tab and click on `Log to file`. Name the file `gpuz.txt` and place it next to the Docker compose file
2. Run the `generate-logstash-columns.ps1` PowerShell script to generate the Logstash configuration file with column names from the GPU-Z log file
3. Run `podman compose up -d` (or Docker equivalent) command on Windows

## To Update GPU-Z Version

The column names between different GPU-Z versions might change. So it's good idea to regenerate column names for the update.

1. Run `podman compose down` (or Docker equivalent) command on Windows
2. Close GPU-Z, delete `sincedb\gpuz.sincedb` and `gpuz.txt` files
3. Update and run GPU-Z
4. Run the `generate-logstash-columns.ps1` PowerShell script again
5. Run `podman compose up -d` (or Docker equivalent) command on Windows
