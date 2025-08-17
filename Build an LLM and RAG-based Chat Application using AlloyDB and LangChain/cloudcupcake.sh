#!/bin/bash
# cloudcupcake.sh
# Automates Qwiklabs lab: Continuous Delivery with Jenkins in Kubernetes Engine
# Subscribe to cloudcupcake :)

set -e

echo "🚀 Starting lab automation: Continuous Delivery with Jenkins in GKE"

# Enable required APIs
echo "✅ Enabling required services..."
gcloud services enable container.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com

# Variables
ZONE="us-central1-a"
CLUSTER_NAME="jenkins-cd"
PROJECT_ID=$(gcloud config get-value project)

echo "🔧 Configured PROJECT_ID=$PROJECT_ID ZONE=$ZONE CLUSTER_NAME=$CLUSTER_NAME"

# Create GKE Cluster
echo "⏳ Creating GKE cluster..."
gcloud container clusters create $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 2 \
  --machine-type e2-standard-2 \
  --scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform"

# Get credentials
echo "🔑 Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# Create namespace for Jenkins
kubectl create namespace jenkins || true

# Helm repo setup
echo "📦 Adding Helm repo for Jenkins..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
echo "⚙️ Installing Jenkins via Helm..."
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set persistence.enabled=false \
  --set controller.adminPassword=admin \
  --set controller.adminUser=admin

echo "⏳ Waiting for Jenkins service external IP..."
kubectl get svc -n jenkins jenkins -w
