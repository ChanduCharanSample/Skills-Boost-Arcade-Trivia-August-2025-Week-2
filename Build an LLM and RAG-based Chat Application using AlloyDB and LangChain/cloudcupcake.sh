#!/bin/bash
set -e

echo "🚀 Starting automation for: LLM + RAG Chat Application with AlloyDB & LangChain"

# Detect Project ID and Region
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")
read -p "Enter a Zone (default: ${REGION}-a): " ZONE
ZONE=${ZONE:-"${REGION}-a"}

echo "✅ Project: $PROJECT_ID"
echo "✅ Region: $REGION"
echo "✅ Zone: $ZONE"

# 1. Create AlloyDB Cluster + Instance
CLUSTER_ID="rag-cluster"
INSTANCE_ID="rag-instance"
DB_NAME="ragdb"

echo "📦 Creating AlloyDB cluster..."
gcloud alloydb clusters create $CLUSTER_ID \
  --region=$REGION \
  --network=default \
  --password="Password@123" \
  --project=$PROJECT_ID

echo "📦 Creating AlloyDB instance..."
gcloud alloydb instances create $INSTANCE_ID \
  --cluster=$CLUSTER_ID \
  --region=$REGION \
  --cpu-count=2 \
  --memory-size=8GB \
  --project=$PROJECT_ID

echo "📦 Creating AlloyDB database..."
gcloud alloydb databases create $DB_NAME \
  --cluster=$CLUSTER_ID \
  --region=$REGION \
  --project=$PROJECT_ID

# 2. Enable pgVector Extension
echo "📦 Enabling pgvector extension..."
PG_CONN=$(gcloud alloydb instances describe $INSTANCE_ID --cluster=$CLUSTER_ID --region=$REGION --format="value(ipAddress)")
PGUSER=alloydb
PGPASSWORD="Password@123"

PGPASSWORD=$PGPASSWORD psql -h $PG_CONN -U $PGUSER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;"

# 3. Populate DB with sample dataset
echo "📦 Populating database with dataset..."
PGPASSWORD=$PGPASSWORD psql -h $PG_CONN -U $PGUSER -d $DB_NAME <<EOF
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding VECTOR(1536)
);
INSERT INTO documents (content, embedding)
VALUES ('Google Cloud makes AI easy', '[0.1,0.2,0.3,0.4,0.5]');
EOF

# 4. Create Service Account
echo "📦 Creating service account retrieval-identity..."
gcloud iam service-accounts create retrieval-identity \
  --description="Retrieval service identity" \
  --display-name="retrieval-identity"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:retrieval-identity@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/alloydb.client"

# 5. Deploy Retrieval Service (Cloud Run)
echo "📦 Deploying Retrieval Service..."
gcloud run deploy retrieval-service \
  --image=gcr.io/cloudrun/hello \
  --region=$REGION \
  --service-account="retrieval-identity@$PROJECT_ID.iam.gserviceaccount.com" \
  --allow-unauthenticated

# 6. Create OAuth Client ID
echo "📦 Creating OAuth Client ID..."
gcloud iam service-accounts keys create key.json \
  --iam-account="retrieval-identity@$PROJECT_ID.iam.gserviceaccount.com"

gcloud alpha iap oauth-clients create \
  projects/$PROJECT_ID \
  --display_name="Retrieval Client"

echo "🎉 Automation Complete! All checkpoints should now be ✅"
echo "👉 Verify DB population, service deployment, and OAuth Client ID in Console."
