#!/bin/bash
echo "🚀 Starting GSP1226 Automation..."

# Detect project ID & region
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region)
echo "✅ Project: $PROJECT_ID"
echo "✅ Region: $REGION"

# Ask for zone
read -p "Enter your zone (example: us-central1-b): " ZONE

gcloud config set compute/zone $ZONE

# Task 1: Enable required APIs
echo "🔄 Enabling required APIs..."
gcloud services enable alloydb.googleapis.com compute.googleapis.com

# Task 2: Create VPC
echo "🔄 Creating VPC network..."
gcloud compute networks create alloydb-network --subnet-mode=auto

# Task 3: Create VM Instance
echo "🔄 Creating VM instance..."
gcloud compute instances create client-vm \
  --zone=$ZONE \
  --network=alloydb-network \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --tags=http-server,https-server

# Task 4: AlloyDB Cluster (manual password required)
echo "⚠️ STOP HERE: AlloyDB cluster creation requires a password."
echo "Run this manually (replace <PASSWORD>):"
echo "gcloud alloydb clusters create my-cluster --region=$REGION --network=alloydb-network --password=<PASSWORD>"

# Task 5: Continue automation once password step done
echo "👉 After creating cluster manually, run:"
echo "gcloud alloydb instances create my-instance --cluster=my-cluster --region=$REGION --cpu-count=2 --instance-type=PRIMARY"

echo "✅ Script finished automation up to AlloyDB password step."
