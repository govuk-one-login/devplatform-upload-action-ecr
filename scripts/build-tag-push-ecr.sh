#! /bin/bash

set -euo pipefail

if [[ "$BUILD_AND_PUSH_IMAGE_ONLY" == "false" ]] && [[ -z "${ARTIFACT_BUCKET_NAME:-}" ]]; then
    echo "ERROR: No bucket name provided...Exiting"
    exit 1
fi

if [ -z $DOCKER_BUILD_PATH ]; then
    DOCKER_BUILD_PATH=$WORKING_DIRECTORY
fi

# Tag to use for the image: the override if supplied, otherwise the commit SHA
IMAGE_TAG="${IMAGE_TAG_OVERRIDE:-$GITHUB_SHA}"

# When a tag is pinned, skip build/push/sign if that tag is already in ECR
SKIP_IMAGE_UPLOAD="false"
if [ -n "${IMAGE_TAG_OVERRIDE:-}" ]; then
    echo "Image tag override supplied: $IMAGE_TAG_OVERRIDE"
    if DESCRIBE_OUTPUT=$(aws ecr describe-images \
        --repository-name "$ECR_REPO_NAME" \
        --image-ids imageTag="$IMAGE_TAG" 2>&1); then
        echo "Image $ECR_REPO_NAME:$IMAGE_TAG already exists in ECR - skipping build, push and signing"
        SKIP_IMAGE_UPLOAD="true"
    elif [[ "$DESCRIBE_OUTPUT" == *ImageNotFoundException* ]]; then
        echo "Image $ECR_REPO_NAME:$IMAGE_TAG not found in ECR - it will be built and pushed"
    else
        echo "ERROR: Unable to check whether $ECR_REPO_NAME:$IMAGE_TAG exists: $DESCRIBE_OUTPUT"
        exit 1
    fi
fi

if [ "$SKIP_IMAGE_UPLOAD" == "false" ]; then

echo "Building image"

PLATFORM_OPTION=""

if [ -n "${DOCKER_PLATFORM}" ]; then
    echo "Using platform option as --platform ${DOCKER_PLATFORM}"
    PLATFORM_OPTION="--platform ${DOCKER_PLATFORM}"
else
    echo "No platform option supplied, using defaults."
fi

TAG_OPTION=""
if [ "$PUSH_LATEST_TAG" == "true" ]; then
    echo "Tagging option supplied $ECR_REGISTRY/$ECR_REPO_NAME:latest"
    TAG_OPTION="--tag $ECR_REGISTRY/$ECR_REPO_NAME:latest"
fi

TARGET_OPTION=""
if [ -n "${DOCKER_TARGET}" ]; then
    echo "Using target option as --target ${DOCKER_TARGET}"
    TARGET_OPTION="--target ${DOCKER_TARGET}"
fi

IFS=',' read -r -a ARGS <<< "${DOCKER_BUILD_ARGS:-}"
DOCKER_BUILD_ARGS_EXPANDED=()
for BUILD_ARG in "${ARGS[@]}"; do
    [[ -n "$BUILD_ARG" ]] && DOCKER_BUILD_ARGS_EXPANDED+=(--build-arg "$BUILD_ARG")
done
IFS=',' read -r -a SECRETS <<< "${DOCKER_BUILD_SECRETS:-}"
DOCKER_BUILD_SECRETS_EXPANDED=()
for BUILD_SECRET in "${SECRETS[@]}"; do
    IFS='=' read -r KEY VALUE <<<"$BUILD_SECRET"
    if [[ -n "$KEY" && -z ${!KEY+x} ]]; then # check that KEY is nonempty and variable with the name of the value of KEY is not set
        printf -v "$KEY" "%s" "$VALUE" # set the variable with the name of the value of KEY to the value of VALUE
        export "$KEY" # export the variable with the name of the value of KEY
        DOCKER_BUILD_SECRETS_EXPANDED+=(--secret id="$KEY")
    fi
done

docker build \
    --tag "$ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG" \
    $TAG_OPTION \
    $PLATFORM_OPTION \
    $TARGET_OPTION \
    --file "$DOCKER_BUILD_PATH"/"$DOCKERFILE" \
    "${DOCKER_BUILD_ARGS_EXPANDED[@]}" \
    "${DOCKER_BUILD_SECRETS_EXPANDED[@]}" \
    "$DOCKER_BUILD_PATH"

docker push "$ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG"
if [ "$PUSH_LATEST_TAG" == "true" ]; then
    docker push "$ECR_REGISTRY/$ECR_REPO_NAME:latest"
fi

if [ ${CONTAINER_SIGN_KMS_KEY_ARN} != "none" ]; then
    curl -s https://raw.githubusercontent.com/sigstore/root-signing/refs/heads/main/targets/signing_config.v0.2.json | jq 'del(.rekorTlogUrls)' > /tmp/signing-config.json
    cosign sign --signing-config /tmp/signing-config.json --key "awskms:///${CONTAINER_SIGN_KMS_KEY_ARN}" "$ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG"
fi

fi # SKIP_IMAGE_UPLOAD


if [ "$BUILD_AND_PUSH_IMAGE_ONLY" == "false" ]; then
    # This only gets set if there is a tag on the current commit.
    GIT_TAG=$(git describe --tags --first-parent --always)
    # Cleaning the commit message to remove special characters
    COMMIT_MSG=$(echo $COMMIT_MESSAGE | tr '\n' ' ' | tr -dc '[:alnum:]- ' | cut -c1-50)
    # Gets merge time to main - displaying it in UTC timezone
    MERGE_TIME=$(TZ=UTC0 git log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M:%S')

    # Sanitise commit message and search for canary deployment instructions
    MSG=$(echo $COMMIT_MESSAGES | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
    if [[ $MSG =~ "[skip canary]" || $MSG =~ "[canary skip]" || $MSG =~ "[no canary]" ]]; then
        SKIP_CANARY_DEPLOYMENT=1
    else
        SKIP_CANARY_DEPLOYMENT=0
    fi

    if [[ $MSG =~ "[close circuit breaker]" || $MSG =~ "[end circuit breaker]" ]]; then
        CLOSE_CIRCUIT_BREAKER=1
    else
        CLOSE_CIRCUIT_BREAKER=0
    fi

    echo "Running sam build on template file"
    cd $WORKING_DIRECTORY
    sam build --template-file="$TEMPLATE_FILE"
    mv .aws-sam/build/template.yaml cf-template.yaml

    if grep -q "CONTAINER-IMAGE-PLACEHOLDER" cf-template.yaml; then
        echo "Replacing \"CONTAINER-IMAGE-PLACEHOLDER\" with new ECR image ref"
        sed -i "s|CONTAINER-IMAGE-PLACEHOLDER|$ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG|" cf-template.yaml
    else
        echo "WARNING!!! Image placeholder text \"CONTAINER-IMAGE-PLACEHOLDER\" not found - uploading template anyway"
    fi

    if grep -q "GIT-SHA-PLACEHOLDER" cf-template.yaml; then
        echo "Replacing \"GIT-SHA-PLACEHOLDER\" with new ECR image tag"
        sed -i "s|GIT-SHA-PLACEHOLDER|$IMAGE_TAG|" cf-template.yaml
    fi

    release_metadata=(
        "commitsha=$GITHUB_SHA"
        "committag=$GIT_TAG"
        "commitmessage='$COMMIT_MSG'"
        "mergetime=$MERGE_TIME"
        "commitauthor='$GITHUB_ACTOR'"
        "repository=$GITHUB_REPOSITORY"
        "skipcanary=$SKIP_CANARY_DEPLOYMENT"
        "closecircuitbreaker=$CLOSE_CIRCUIT_BREAKER"
    )

    [[ ${VERSION_NUMBER:-} ]] && release_metadata+=(
        "codepipeline-artifact-revision-summary=$VERSION_NUMBER"
        "release=$VERSION_NUMBER"
    )

    metadata=$(IFS="," ; echo "${release_metadata[*]}")
    column -ts= < <(tr "," "\n" <<< "$metadata")

    zip template.zip cf-template.yaml
    aws s3 cp template.zip "s3://$ARTIFACT_BUCKET_NAME/template.zip" --metadata "$metadata"
fi
