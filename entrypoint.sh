#!/bin/sh

set -e

if [ -z "$USE_AWS_FOR_DESTINATION" ]; then
  USE_AWS_FOR_DESTINATION=true
else
  USE_AWS_FOR_DESTINATION=`echo "${USE_AWS_FOR_DESTINATION}" | tr '[:upper:]' '[:lower:]'`
fi

if [ "$USE_AWS_FOR_DESTINATION" = true ]; then
  if [ -z "$AWS_DESTINATION_S3_BUCKET" ]; then
    echo "AWS_DESTINATION_S3_BUCKET is not set. Quitting."
    exit 1
  fi

  # Default to us-east-1 if AWS_REGION not set.
  if [ -z "$AWS_DESTINATION_REGION" ]; then
    AWS_REGION="us-east-1"
    AWS_DESTINATION_REGION_STRING="--region ${AWS_REGION} "
  fi

  if ! [ -z "$DESTINATION_DIR" ]; then
    DESTINATION_DIR="/${DESTINATION_DIR}"
  fi

  DESTINATION_STRING="s3://${AWS_DESTINATION_S3_BUCKET}${DESTINATION_DIR}"
else
  if [ -z "$DESTINATION_DIR" ]; then
    DESTINATION_STRING="."
  else
    DESTINATION_STRING=$DESTINATION_DIR
  fi
fi

if [ -z "$USE_AWS_FOR_SOURCE" ]; then
  USE_AWS_FOR_SOURCE=false
else
  USE_AWS_FOR_SOURCE=`echo "${USE_AWS_FOR_SOURCE}" | tr '[:upper:]' '[:lower:]'`
fi

echo "${USE_AWS_FOR_SOURCE}"

if [ "$USE_AWS_FOR_SOURCE" = true ]; then
  if [ -z "$AWS_SOURCE_S3_BUCKET" ]; then
    echo "AWS_SOURCE_S3_BUCKET is not set. Quitting."
    exit 1
  fi

  if [ -z "$AWS_SOURCE_REGION" ]; then
    AWS_SOURCE_REGION_STRING="--source-region ${AWS_REGION} "
  fi

  if ! [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR="/${SOURCE_DIR}"
  fi

  SOURCE_STRING="s3://${AWS_SOURCE_S3_BUCKET}${SOURCE_DIR}"
else
  if [ -z "$SOURCE_DIR" ]; then
    SOURCE_STRING="."
  else
    SOURCE_STRING=$SOURCE_DIR
  fi
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
fi

# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
# https://github.com/jakejarvis/s3-sync-action/issues/1
aws configure --profile s3-sync-action-bidirectional <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

echo "${SOURCE_STRING}"
echo "${DESTINATION_STRING}" | sed 's/./& /g'
echo "${AWS_SOURCE_REGION_STRING}"
echo "${AWS_DESTINATION_REGION_STRING}"

echo "aws s3 sync ${SOURCE_STRING} ${DESTINATION_STRING} ${AWS_SOURCE_REGION_STRING}${AWS_DESTINATION_REGION_STRING}\
              --profile s3-sync-action-bidirectional \
              --no-progress $*"

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
sh -c "aws s3 sync ${SOURCE_STRING} ${DESTINATION_STRING} ${AWS_SOURCE_REGION_STRING}${AWS_DESTINATION_REGION_STRING}\
              --profile s3-sync-action-bidirectional \
              --no-progress $*"

# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action-bidirectional <<-EOF > /dev/null 2>&1
null
null
null
text
EOF
