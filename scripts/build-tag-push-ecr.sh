#! /bin/bash

set -eu

if [ -z $DOCKER_BUILD_PATH ]; then
    DOCKER_BUILD_PATH=$WORKING_DIRECTORY
fi

echo "Building image"

PLATFORM_OPTION=""

if [ -n "${DOCKER_PLATFORM}" ]; then
    echo "Using platform option as --platform ${DOCKER_PLATFORM}"
    PLATFORM_OPTION="--platform ${DOCKER_PLATFORM}"
else
    echo "No platform option supplied, using defaults."
fi

docker build \
    --tag "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA" \
    $PLATFORM_OPTION \
    --file "$DOCKER_BUILD_PATH"/"$DOCKERFILE" \
    "$DOCKER_BUILD_PATH"

docker push "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"

if [ ${CONTAINER_SIGN_KMS_KEY_ARN} != "none" ]; then
    cosign sign --key "awskms:///${CONTAINER_SIGN_KMS_KEY_ARN}" "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"
fi

# This only gets set if there is a tag on the current commit.
GIT_TAG=$(git describe --tags --first-parent --always)
# Cleaning the commit message to remove special characters
COMMIT_MSG=$(echo $COMMIT_MESSAGE | tr '\n' ' ' | tr -dc '[:alnum:]- ' | cut -c1-50)
# Gets merge time to main - displaying it in UTC timezone
MERGE_TIME=$(TZ=UTC0 git log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M:%S')

# Sanitise commit message and search for canary deployment instructions
MSG=$(echo $COMMIT_MESSAGE | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
if [[ $MSG =~ "[skip canary]" || $MSG =~ "[canary skip]" || $MSG =~ "[no canary]" ]]; then
    SKIP_CANARY_DEPLOYMENT=1
else
    SKIP_CANARY_DEPLOYMENT=0
fi

echo "Running sam build on template file"
cd $WORKING_DIRECTORY
sam build --template-file="$TEMPLATE_FILE"
mv .aws-sam/build/template.yaml cf-template.yaml

if grep -q "CONTAINER-IMAGE-PLACEHOLDER" cf-template.yaml; then
    echo "Replacing \"CONTAINER-IMAGE-PLACEHOLDER\" with new ECR image ref"
    sed -i "s|CONTAINER-IMAGE-PLACEHOLDER|$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA|" cf-template.yaml
else
    echo "WARNING!!! Image placeholder text \"CONTAINER-IMAGE-PLACEHOLDER\" not found - uploading template anyway"
fi
zip template.zip cf-template.yaml
aws s3 cp template.zip "s3://$ARTIFACT_BUCKET_NAME/template.zip" --metadata "repository=$GITHUB_REPOSITORY,commitsha=$GITHUB_SHA,committag=$GIT_TAG,commitmessage=$COMMIT_MSG,mergetime=$MERGE_TIME,skipcanary=$SKIP_CANARY_DEPLOYMENT,commitauthor=$GITHUB_ACTOR,release=$VERSION_NUMBER"
