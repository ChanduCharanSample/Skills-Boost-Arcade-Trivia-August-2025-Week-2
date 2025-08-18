#!/bin/bash

YELLOW='\033[0;33m'
NC='\033[0m'

pattern=(
"**********************************************************"
"**                 S U B S C R I B E  TO                **"
"**                   CLOUDCUPCAKE-1217                  **"
"**                                                      **"
"**********************************************************"
)

# Set region explicitly for lab
gcloud config set compute/region us
gsutil mb -l us gs://$DEVSHELL_PROJECT_ID-bucket/

# Reset Dataflow API
gcloud services disable dataflow.googleapis.com
sleep 40
gcloud services enable dataflow.googleapis.com
sleep 40

# Run docker with variables
docker run -it \
  -e DEVSHELL_PROJECT_ID=$DEVSHELL_PROJECT_ID \
  -e LOCATION=us \
  python:3.9 /bin/bash -c '
    pip install "apache-beam[gcp]"==2.42.0 && \
    python -m apache_beam.examples.wordcount --output OUTPUT_FILE && \
    BUCKET=gs://'$DEVSHELL_PROJECT_ID'-bucket && \
    python -m apache_beam.examples.wordcount --project $DEVSHELL_PROJECT_ID \
      --runner DataflowRunner \
      --staging_location $BUCKET/staging \
      --temp_location $BUCKET/temp \
      --output $BUCKET/results/output \
      --region us
  '

for line in "${pattern[@]}"; do
    echo -e "${YELLOW}${line}${NC}"
done

pattern=(
"**********************************************************"
"**                                                      **"
"**            LAB COMPLETED SUCCESSFULLY!               **"
"**                                                      **"
"**********************************************************"
)

for line in "${pattern[@]}"; do
    echo -e "${YELLOW}${line}${NC}"
done
