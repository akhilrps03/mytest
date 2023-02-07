#!/bin/bash

BUCKET_NAME=$1

curl "http://metadata.google.internal/computeMetadata/v1/instance/?recursive=true" -H "Metadavor: Google" > meta.json

if [ $? -eq 0 ]; then
    echo "Fetched Metadata .."
	gsutil cp meta.json gs://${BUCKET_NAME}
else
    echo "Failed to Fetch Metadata .."
fi