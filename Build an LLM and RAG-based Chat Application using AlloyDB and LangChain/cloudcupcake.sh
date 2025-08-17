#!/bin/bash
# auto_rag_chat.sh - Complete automation for the GSP1226 lab (AlloyDB + LangChain RAG Chat App)

set -e
echo "🚀 Starting full lab automation for GSP1226..."

# 1. Enable required APIs
gcloud services enable alloydb.googleapis.com compute.googleapis.com iam.googleapis.com run.googleapis.com sqladmin.googleapis.com

# 2. Create AlloyDB cluster & primary instance
REGION="us-central1"
CLUSTER="rag-alloydb"
INSTANCE="primary"
NETWORK="default"
SAVE_PASSWORD="P@ssw0rd123!"
echo "Creating AlloyDB cluster..."
gcloud alloydb clusters create $CLUSTER --region=$REGION --network=$NETWORK
gcloud alloydb instances create $INSTANCE --region=$REGION --cluster=$CLUSTER --cpu=2 --memory=8GB --password=$SAVE_PASSWORD
echo "Waiting for AlloyDB to be ready..."
sleep 120

# 3. Set env vars and get IP
export PROJECT_ID=$(gcloud config get-value project)
ADB_IP=$(gcloud alloydb instances describe $INSTANCE --region=$REGION --cluster=$CLUSTER --format="value(ipAddress)")
export PGPASSWORD=$SAVE_PASSWORD
echo "AlloyDB IP: $ADB_IP"

# 4. Create PostgreSQL client on Cloud Shell (should already be available)
sudo apt-get update
sudo apt-get install -y postgresql-client

# 5. Initialize database & extensions
psql "host=$ADB_IP user=postgres sslmode=require" -c "CREATE DATABASE assistantdemo;"
psql "host=$ADB_IP user=postgres sslmode=require dbname=assistantdemo" -c "CREATE EXTENSION IF NOT EXISTS vector;"

# 6. Set up Python environment
sudo apt install -y python3.11-venv git
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip

# 7. Clone project repo & populate database
git clone https://github.com/GoogleCloudPlatform/genai-databases-retrieval-app.git
cd genai-databases-retrieval-app/retrieval_service
cp example-config.yml config.yml
sed -i "s/127.0.0.1/$ADB_IP/g" config.yml
sed -i "s/my-password/$PGPASSWORD/g" config.yml
sed -i "s/my_database/assistantdemo/g" config.yml
sed -i "s/my-user/postgres/g" config.yml
pip install -r requirements.txt
python run_database_init.py
cd ../..

# 8. Create service account and grant AI Platform access
gcloud iam service-accounts create retrieval-identity
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:retrieval-identity@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

# 9. Deploy retrieval service to Cloud Run
cd genai-databases-retrieval-app
gcloud alpha run deploy retrieval-service \
    --source=./retrieval_service/ \
    --no-allow-unauthenticated \
    --service-account retrieval-identity \
    --region=$REGION \
    --platform=managed \
    --quiet
export RETRIEVAL_URL=$(gcloud run services describe retrieval-service --region=$REGION --format="value(status.url)")

# 10. Verify service health
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $RETRIEVAL_URL

# 11. Launch sample LangChain app
cd llm_demo
pip install -r requirements.txt
export BASE_URL=$RETRIEVAL_URL
# Note: CLIENT_ID must be set manually in lab UI for OAuth features. Skip if not needed.
python run_app.py &
cd ~

# 12. All done!
echo "✅ Lab automation complete!"
echo "Access your LLM + RAG chat app via Cloud Shell Web Preview on port 8081."
echo "BASE_URL set to: $BASE_URL"
echo "Database assistantdemo initialized in AlloyDB!"
