#!/bin/bash

if [ ! -d /etc/systemd/system ]; then
  mkdir -p /etc/systemd/system;
fi

if [ ! -d /home/composer ]; then
  mkdir -p /home/composer;
fi

cat <<EOF >/home/composer/docker-compose.yml
version: '3'
services:
  redis:
    image: redis:7.0.5
    restart: always
    volumes:
      - redisdata:/data
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.4.2
    volumes:
      - esdata:/usr/share/elasticsearch/data
    environment:
      # Comment out the line below for single-node
      - discovery.type=single-node
      # Uncomment line below below for a cluster of multiple nodes
      # - cluster.name=docker-cluster
      - xpack.ml.enabled=false
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms$${ELASTIC_MEMORY_SIZE} -Xmx$${ELASTIC_MEMORY_SIZE}"
    restart: always
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
  minio:
    image: minio/minio:RELEASE.2022-09-25T15-44-53Z
    volumes:
      - s3data:/data
    ports:
      - "9000:9000"
    environment:
      MINIO_ROOT_USER: $${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: $${MINIO_ROOT_PASSWORD}    
    command: server /data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    restart: always
  rabbitmq:
    image: rabbitmq:3.10-management
    environment:
      - RABBITMQ_DEFAULT_USER=$${RABBITMQ_DEFAULT_USER}
      - RABBITMQ_DEFAULT_PASS=$${RABBITMQ_DEFAULT_PASS}
    volumes:
      - amqpdata:/var/lib/rabbitmq
    restart: always
  opencti:
    image: opencti/platform:5.3.17
    environment:
      - NODE_OPTIONS=--max-old-space-size=8096
      - APP__PORT=8080
      - APP__BASE_URL=$${OPENCTI_BASE_URL}
      - APP__ADMIN__EMAIL=$${OPENCTI_ADMIN_EMAIL}
      - APP__ADMIN__PASSWORD=$${OPENCTI_ADMIN_PASSWORD}
      - APP__ADMIN__TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - APP__APP_LOGS__LOGS_LEVEL=error
      - REDIS__HOSTNAME=redis
      - REDIS__PORT=6379
      - ELASTICSEARCH__URL=http://elasticsearch:9200
      - MINIO__ENDPOINT=minio
      - MINIO__PORT=9000
      - MINIO__USE_SSL=false
      - MINIO__ACCESS_KEY=$${MINIO_ROOT_USER}
      - MINIO__SECRET_KEY=$${MINIO_ROOT_PASSWORD}
      - RABBITMQ__HOSTNAME=rabbitmq
      - RABBITMQ__PORT=5672
      - RABBITMQ__PORT_MANAGEMENT=15672
      - RABBITMQ__MANAGEMENT_SSL=false
      - RABBITMQ__USERNAME=$${RABBITMQ_DEFAULT_USER}
      - RABBITMQ__PASSWORD=$${RABBITMQ_DEFAULT_PASS}
      - SMTP__HOSTNAME=$${SMTP_HOSTNAME}
      - SMTP__PORT=25
      - PROVIDERS__LOCAL__STRATEGY=LocalStrategy
    ports:
      - "8080:8080"
    depends_on:
      - redis
      - elasticsearch
      - minio
      - rabbitmq
    restart: always
  worker:
    image: opencti/worker:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - WORKER_LOG_LEVEL=info
    depends_on:
      - opencti
    deploy:
      mode: replicated
      replicas: 3
    restart: always
  connector-export-file-stix:
    image: opencti/connector-export-file-stix:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=$${CONNECTOR_EXPORT_FILE_STIX_ID} # Valid UUIDv4
      - CONNECTOR_TYPE=INTERNAL_EXPORT_FILE
      - CONNECTOR_NAME=ExportFileStix2
      - CONNECTOR_SCOPE=application/json
      - CONNECTOR_CONFIDENCE_LEVEL=15 # From 0 (Unknown) to 100 (Fully trusted)
      - CONNECTOR_LOG_LEVEL=info
    restart: always
    depends_on:
      - opencti
  connector-export-file-csv:
    image: opencti/connector-export-file-csv:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=$${CONNECTOR_EXPORT_FILE_CSV_ID} # Valid UUIDv4
      - CONNECTOR_TYPE=INTERNAL_EXPORT_FILE
      - CONNECTOR_NAME=ExportFileCsv
      - CONNECTOR_SCOPE=text/csv
      - CONNECTOR_CONFIDENCE_LEVEL=15 # From 0 (Unknown) to 100 (Fully trusted)
      - CONNECTOR_LOG_LEVEL=info
    restart: always
    depends_on:
      - opencti
  connector-export-file-txt:
    image: opencti/connector-export-file-txt:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=$${CONNECTOR_EXPORT_FILE_TXT_ID} # Valid UUIDv4
      - CONNECTOR_TYPE=INTERNAL_EXPORT_FILE
      - CONNECTOR_NAME=ExportFileTxt
      - CONNECTOR_SCOPE=text/plain
      - CONNECTOR_CONFIDENCE_LEVEL=15 # From 0 (Unknown) to 100 (Fully trusted)
      - CONNECTOR_LOG_LEVEL=info
    restart: always
    depends_on:
      - opencti
  connector-import-file-stix:
    image: opencti/connector-import-file-stix:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=$${CONNECTOR_IMPORT_FILE_STIX_ID} # Valid UUIDv4
      - CONNECTOR_TYPE=INTERNAL_IMPORT_FILE
      - CONNECTOR_NAME=ImportFileStix
      - CONNECTOR_VALIDATE_BEFORE_IMPORT=true # Validate any bundle before import
      - CONNECTOR_SCOPE=application/json,text/xml
      - CONNECTOR_AUTO=true # Enable/disable auto-import of file
      - CONNECTOR_CONFIDENCE_LEVEL=15 # From 0 (Unknown) to 100 (Fully trusted)
      - CONNECTOR_LOG_LEVEL=info
    restart: always
    depends_on:
      - opencti
  connector-import-document:
    image: opencti/connector-import-document:5.3.17
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=$${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=$${CONNECTOR_IMPORT_DOCUMENT_ID} # Valid UUIDv4
      - CONNECTOR_TYPE=INTERNAL_IMPORT_FILE
      - CONNECTOR_NAME=ImportDocument
      - CONNECTOR_VALIDATE_BEFORE_IMPORT=true # Validate any bundle before import
      - CONNECTOR_SCOPE=application/pdf,text/plain,text/html
      - CONNECTOR_AUTO=true # Enable/disable auto-import of file
      - CONNECTOR_ONLY_CONTEXTUAL=false # Only extract data related to an entity (a report, a threat actor, etc.)
      - CONNECTOR_CONFIDENCE_LEVEL=15 # From 0 (Unknown) to 100 (Fully trusted)
      - CONNECTOR_LOG_LEVEL=info
      - IMPORT_DOCUMENT_CREATE_INDICATOR=true
    restart: always
    depends_on:
      - opencti
volumes:
  esdata:
  s3data:
  redisdata:
  amqpdata:
EOF


cat <<EOF >/etc/systemd/system/docker-compose.service
[Unit]
Description=Composer Service
Requires=docker.service network-online.target
After=docker.service network-online.target
[Service]
Restart=always
# Environment="HOME=/home/composer"
WorkingDirectory=/home/composer
# Remove old containers, images and volumes
ExecStart=/usr/bin/docker run --rm -v  /var/run/docker.sock:/var/run/docker.sock -v "/home/composer/.docker:/root/.docker" -v "/home/composer:/home/composer" -w="/home/composer" docker/compose:1.24.0 up
ExecStop=/usr/bin/docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "/home/composer/.docker:/root/.docker" -v "/home/composer:/home/composer" -w="/home/composer" docker/compose:1.24.0 rm -f
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF


# Autostart systemd service
sudo systemctl enable docker-compose.service
# Start systemd service now
sudo systemctl start docker-compose.service