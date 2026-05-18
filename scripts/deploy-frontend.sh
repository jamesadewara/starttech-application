#!/bin/bash
set -e

ENVIRONMENT=${1:-production}
BUCKET_NAME=${2:-$FRONTEND_S3_BUCKET}
DISTRIBUTION_ID=${3:-$CLOUDFRONT_DISTRIBUTION_ID}

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: S3 bucket name required"
  exit 1
fi

echo "Deploying frontend to S3..."
echo "Environment: $ENVIRONMENT"
echo "Bucket: $BUCKET_NAME"

cd "$(dirname "$0")/../frontend"

# Build
echo "Building..."
npm ci
REACT_APP_API_URL=$(aws ssm get-parameter --name "/starttech/$ENVIRONMENT/api-url" --query 'Parameter.Value' --output text) \
  npm run build

# Deploy to S3 with cache headers
echo "Syncing to S3..."
aws s3 sync build/ s3://$BUCKET_NAME \
  --delete \
  --cache-control "max-age=31536000,immutable" \
  --exclude "index.html" \
  --exclude "service-worker.js"

aws s3 cp build/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront
if [ -n "$DISTRIBUTION_ID" ]; then
  echo "Invalidating CloudFront cache..."
  aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/index.html" "/service-worker.js" "/*"
fi

echo "Frontend deployment complete!"