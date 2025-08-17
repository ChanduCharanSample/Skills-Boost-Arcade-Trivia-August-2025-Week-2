#!/bin/bash
# cloudcupcake.sh
# Automates setup for LLM + RAG Chat App with AlloyDB & LangChain

set -euo pipefail

echo "🚀 Starting Lab Automation Script: Build LLM & RAG Chat App with AlloyDB + LangChain"

# Detect Project ID
PROJECT_ID=$(gcloud config get-value project)
if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ ERROR: No project set. Please run: gcloud config set project PROJECT_ID"
  exit 1
fi
echo "✅ Using Project ID: $PROJECT_ID"

# Detect Region automatically (pick default compute region if available)
REGION=$(gcloud config get-value compute/region || echo "")
if [[ -z "$REGION" ]]; then
  echo "⚠️ No default region found. Falling back to us-central1."
  REGION="us-central1"
fi
echo "✅ Using Region: $REGION"

# Ask user for Zone (must belong to REGION)
read -rp "👉 Enter Zone (e.g., ${REGION}-b): " ZONE
if [[ -z "$ZONE" ]]; then
  echo "❌ Zone cannot be empty."
  exit 1
fi

gcloud config set compute/zone "$ZONE"

echo "✅ Configuration complete"
echo "   Project: $PROJECT_ID"
echo "   Region:  $REGION"
echo "   Zone:    $ZONE"

# -------------------------------
# Start Lab Automation Tasks
# -------------------------------

echo "⚙️ Enabling required APIs..."
gcloud services enable alloydb.googleapis.com \
  aiplatform.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com

echo "✅ APIs enabled"

# Create AlloyDB cluster + instance
CLUSTER_NAME="rag-cluster"
INSTANCE_NAME="rag-instance"

echo "⚙️ Creating AlloyDB cluster: $CLUSTER_NAME"
gcloud alloydb clusters create $CLUSTER_NAME \
  --region=$REGION \
  --network=default \
  --password=AlloyDB@123

echo "⚙️ Creating AlloyDB instance: $INSTANCE_NAME"
gcloud alloydb instances create $INSTANCE_NAME \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --cpu-count=2 \
  --memory-size=8GB

echo "✅ AlloyDB setup complete"

# Deploy RAG Chat App with Cloud Run (placeholder, adjust app repo)
APP_NAME="rag-chat-app"
IMAGE_NAME="$REGION-docker.pkg.dev/$PROJECT_ID/rag-repo/rag-app:latest"

echo "⚙️ Setting up Artifact Registry..."
gcloud artifacts repositories create rag-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="RAG app repo" || true

echo "⚙️ Building and pushing Docker image..."
gcloud builds submit --tag "$IMAGE_NAME" .

echo "⚙️ Deploying app to Cloud Run..."
gcloud run deploy $APP_NAME \
  --image="$IMAGE_NAME" \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated

echo "🎉 Deployment complete!"
echo "🔗 Visit your RAG Chat App at:"
gcloud run services describe $APP_NAME --region=$REGION --format='value(status.url)'
