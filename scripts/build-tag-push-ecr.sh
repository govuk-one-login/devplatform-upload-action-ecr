#! /bin/bash

set -eu

: "${CUSTOM_TAG:=}"
: "${DOCKER_BUILD_PATH:=.}"

$PUSH_LATEST_TAG && CUSTOM_TAG=latest

echo "Building image"

docker build \
  ${DOCKER_PLATFORM:+--platform $DOCKER_PLATFORM} \
  ${CUSTOM_TAG:+--tag $ECR_REGISTRY/$ECR_REPO_NAME:$CUSTOM_TAG} \
  --tag "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA" \
  --file "$DOCKERFILE" \
  "$DOCKER_BUILD_PATH"

docker push "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"

if [[ $CUSTOM_TAG ]]; then
  docker push "$ECR_REGISTRY/$ECR_REPO_NAME:$CUSTOM_TAG"
fi

if [[ $CONTAINER_SIGN_KMS_KEY_ARN ]]; then
  cosign sign --key "awskms:///${CONTAINER_SIGN_KMS_KEY_ARN}" "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"
fi

$BUILD_AND_PUSH_IMAGE_ONLY && exit

# This only gets set if there is a tag on the current commit.
GIT_TAG=$(git describe --tags --first-parent --always)

# Cleaning the commit message to remove special characters
COMMIT_MSG=$(echo "$COMMIT_MESSAGE" | tr "\n" " " | tr -dc "[:alnum:]- " | cut -c1-50)

# Gets merge to main UTC timestamp
MERGE_TIME=$(TZ=UTC0 git log -1 --format=%cd --date=format-local:"%Y-%m-%d %H:%M:%S")

# Sanitise commit message and search for canary deployment instructions
MSG=$(echo "$COMMIT_MESSAGE" | tr "\n" " " | tr "[:upper:]" "[:lower:]")
if [[ $MSG =~ \[(skip canary|no canary|canary skip)\] ]]; then
  SKIP_CANARY_DEPLOYMENT=1
else
  SKIP_CANARY_DEPLOYMENT=0
fi

echo "Running sam build on template file"
sam build --template-file="$TEMPLATE_FILE" ${SAM_BASE_DIR:+--base-dir=$SAM_BASE_DIR}
mv .aws-sam/build/template.yaml cf-template.yaml

if grep -q "CONTAINER-IMAGE-PLACEHOLDER" cf-template.yaml; then
  echo "Replacing 'CONTAINER-IMAGE-PLACEHOLDER' with new ECR image ref"
  sed -i "s|CONTAINER-IMAGE-PLACEHOLDER|$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA|" cf-template.yaml
elif grep -q "GIT-SHA-PLACEHOLDER" cf-template.yaml; then
  echo "Replacing 'GIT-SHA-PLACEHOLDER' with new ECR image tag"
  sed -i "s|GIT-SHA-PLACEHOLDER|$GITHUB_SHA|" cf-template.yaml
else
  echo "WARNING!!! Image placeholder text not found - uploading template anyway"
fi

zip template.zip cf-template.yaml
aws s3 cp template.zip "s3://$ARTIFACT_BUCKET_NAME/template.zip" --metadata "repository=$GITHUB_REPOSITORY,commitsha=$GITHUB_SHA,committag=$GIT_TAG,commitmessage=$COMMIT_MSG,mergetime=$MERGE_TIME,skipcanary=$SKIP_CANARY_DEPLOYMENT,commitauthor='$GITHUB_ACTOR',release=$VERSION_NUMBER"
