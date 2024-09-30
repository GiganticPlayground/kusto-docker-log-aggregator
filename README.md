# Kusto Docker Log Aggregator

## Overview

This tool sets up a simple Kusto emulator with Fluentd to pull all Docker logs into the Kusto emulator.

The purpose of this repository is to provide a local development environment for aggregating Docker logs using a Kusto emulator. This setup allows developers to test and debug their logging configurations and scripts in a controlled environment before deploying them to a production system. Additionally, it aims to help developers search through logs and dashboard complex systems by providing a way to visualize and analyze log data effectively using Azure Kusto Explorer.

## Log Flow Overview

The log aggregation process involves several steps to ensure that Docker logs are collected and sent to the Kusto emulator. Here's how it works:

1. **Docker Logging Driver**: Docker containers generate logs which are managed by the Docker logging driver. In this setup, the `json-file` logging driver is used to store logs in JSON format.
2. **File Tailing**: Fluentd, a log collector, is configured to tail these JSON log files. This is achieved by binding the Docker log directory into the Fluentd container, allowing Fluentd to access and read the log files.
3. **Log Processing**: Fluentd processes the tailed log files using a custom `kusto.lua` script. This script is responsible for formatting and preparing the logs for ingestion into the Kusto emulator.
4. **Log Ingestion**: The processed logs are then sent to the Kusto emulator, where they can be queried and analyzed using Kusto Query Language (KQL).

This setup ensures that all Docker logs are efficiently collected and made available for analysis in a local development environment.

**CAUTION:** The Fluentd configuration is a bit hacky because Fluentd does not natively support the Kusto emulator, as the Kusto emulator does not support log streaming. We had to create a custom `kusto.lua` script to handle aggregating the logs. However, if more than 10,000 logs are sent in 2 seconds, you will likely encounter issues. It is very possible that you would be limited before that number. This is for local development only.

## Important Note on Log Destination

It is important to note that in this setup, logs are not sent to Azure Data Explorer. Instead, they are ingested into a local Kusto emulator. This distinction is crucial for understanding the scope, limitations, and security of this tool:

- **Local Development**: The Kusto emulator is intended for local development and testing purposes. It allows developers to experiment with log aggregation and querying without the need for an Azure subscription.
- **Security**: You do not have to worry about your personal docker containers being ingested into ADX

This approach provides a cost-effective and convenient way to develop and test logging configurations before deploying them to a production environment that uses Azure Data Explorer.


## Prerequisites

- Docker
- Docker Compose
- Web browser

## Setup

To use this tool, follow these steps:

1. **Clone the repository:**
   ```sh
   git clone <repository-url>
   cd kusto-docker-log-aggregator
   ```

2. **Run Docker Compose to start the emulator and log collector:**
   ```sh
   docker compose up -d
   ```
   The log collector will collect all JSON logs and send them to the Kusto emulator.

3. **Open a browser and navigate to [Azure Data Explorer](https://dataexplorer.azure.com):** 
   - Login if needed with any Microsoft account.
   - **Alternative:** If you are using a Windows machine, you can download the [Azure Kusto Explorer desktop application](https://learn.microsoft.com/en-us/kusto/tools/kusto-explorer) for a more integrated experience.

4. **Add a connection to the Kusto emulator:**
   - Under the query section, add a connection to `http://localhost:8080/`.

5. **Run the following query to create the application logs table and ingestion mapping:**
   ```kusto
   // Create the table with columns 'timestamp' and 'event'
   .create table application_logs (timestamp: datetime, event: dynamic)
   // Create the ingestion mapping for JSON data
   .create table application_logs ingestion json mapping 'json_mapping' '[{"column":"timestamp", "path":"$[\'time\']", "datatype":"datetime"}, {"column":"event", "path":"$", "datatype":"dynamic"}]'
   ```

## Usage

Once the setup is complete, Docker logs will be collected and sent to the Kusto emulator. You can query the logs using the Azure Data Explorer interface.

### Example Queries

- **Retrieve all logs:**
  ```kusto
  application_logs
  | take 100
  ```

- **Filter logs by a specific time range:**
  ```kusto
  application_logs
  | where timestamp between(datetime(2023-01-01) .. datetime(2023-01-02))
  ```

- **Search for specific events:**
  ```kusto
  application_logs
  | where event contains "error"
  ```

## Example Log Generator

To generate example logs, you can use the following `docker-compose.yml` file located in `example_log_generator/docker-compose.yml`:

```yaml
version: '3.8'

services:
  log-generator:
    image: bash
    command: |
      /bin/sh -c "count=1; while true; do echo \"{\\\"counter\\\": $$count, \\\"date\\\": \\\"$$(date -u +'%Y-%m-%dT%H:%M:%SZ')\\\" }\"; sleep 1; count=$$((count+1)); done"
    logging:
      driver: json-file
      options:
        max-size: "512m"
        max-file: "3"
        labels: "serviceName,stackId"
        tag: '{ "imageName": "{{.ImageName}}", "containerName": "{{.Name}}", "containerId": "{{.ID}}" }'
    labels: 
      stackId: LOCAL-DEVELOPER-STACK
```

To start the log generator, navigate to the `example_log_generator` directory and run:

```sh
docker compose up -d
```

## Querying Logs in Azure Data Explorer

To see the counter count up in Azure Data Explorer, you can use the following query:

```kusto
application_logs
| extend log=parse_json(tostring(parse_json(tostring(event.log))))
| extend counter=log.counter
| order by timestamp desc
| limit 10
```

This query will parse the JSON logs, extract the `counter` field, and display the latest 10 logs ordered by timestamp.

## Docker Compose Configuration for Optimal Log Results

To enhance the log output for your containers, add the following configuration to each service in your `docker-compose.yml` file:

```yaml
logging:
  driver: json-file
  options:
    max-size: "512m"
    max-file: "3"
    labels: "serviceName,stackId"
    tag: '{ "imageName": "{{.ImageName}}", "containerName": "{{.Name}}", "containerId": "{{.ID}}" }'
labels: 
  stackId: LOCAL-DEVELOPER-STACK
```

Changes made:
1. Improved the section title for clarity.
2. Provided a more specific file reference (`docker-compose.yml`).
3. Enhanced the description for better readability.

## Troubleshooting

- **Logs not appearing in Kusto:**
  - Ensure Docker containers are running: `docker ps`
  - Check Fluentd logs for errors: `docker logs <fluentd-container-id>`

- **Connection issues:**
  - Verify that the Kusto emulator is accessible at `http://localhost:8080/`.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Fluentd](https://www.fluentd.org/)
- [Azure Data Explorer](https://dataexplorer.azure.com)
