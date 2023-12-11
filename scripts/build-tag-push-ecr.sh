#! /bin/bash

set -eu

if [ -z $DOCKER_BUILD_PATH ]; then
    DOCKER_BUILD_PATH=$WORKING_DIRECTORY
fi

echo "Building image"

docker build -t "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA" -f "$DOCKER_BUILD_PATH"/"$DOCKERFILE" "$DOCKER_BUILD_PATH"
docker push "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"

if [ ${CONTAINER_SIGN_KMS_KEY_ARN} != "none" ]; then
    cosign sign --key "awskms:///${CONTAINER_SIGN_KMS_KEY_ARN}" "$ECR_REGISTRY/$ECR_REPO_NAME:$GITHUB_SHA"
fi

MERGE_TIME=$(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S')

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
aws s3 cp template.zip "s3://$ARTIFACT_BUCKET_NAME/template.zip" --metadata "repository=$GITHUB_REPOSITORY,commitsha=$GITHUB_SHA", mergetime=$MERGE_TIME"
