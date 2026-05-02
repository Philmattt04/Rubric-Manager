#!/bin/bash
set -e

BUCKET="rubriques-gwoupbousol-org"
DISTRIBUTION_ID=$(cd infra && terraform output -raw cloudfront_id)

echo "Building Flutter web..."
flutter build web --release

echo "Syncing to S3..."
aws s3 sync build/web/ "s3://$BUCKET/" \
  --delete \
  --cache-control "max-age=31536000, immutable" \
  --exclude "index.html" \
  --exclude "flutter_service_worker.js" \
  --exclude "manifest.json"

# index.html and service worker must never be cached by browsers
aws s3 cp build/web/index.html "s3://$BUCKET/index.html" \
  --cache-control "no-cache, no-store, must-revalidate"

aws s3 cp build/web/flutter_service_worker.js "s3://$BUCKET/flutter_service_worker.js" \
  --cache-control "no-cache, no-store, must-revalidate"

aws s3 cp build/web/manifest.json "s3://$BUCKET/manifest.json" \
  --cache-control "no-cache, no-store, must-revalidate"

echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*"

echo "Done. App is live at https://rubriques.gwoupbousol.org"
