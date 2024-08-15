#!/usr/bin/env bash
set -euo pipefail

# This only gets set if there is a tag on the current commit.
GIT_TAG=$(git describe --tags --first-parent --always)
# Cleaning the commit message to remove special characters
COMMIT_MSG=$(echo "${COMMIT_MESSAGE}" | tr '\n' ' ' | tr -dc '[:alnum:]- ' | cut -c1-50)
# Gets merge time to main - displaying it in UTC timezone
MERGE_TIME=$(TZ=UTC0 git log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M:%S')

# Sanitise commit message and search for canary deployment instructions
MSG=$(echo "${COMMIT_MESSAGE}" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
if [[ $MSG =~ "[skip canary]" || $MSG =~ "[canary skip]" || $MSG =~ "[no canary]" ]]; then
  SKIP_CANARY_DEPLOYMENT=1
else
  SKIP_CANARY_DEPLOYMENT=0
fi

echo "Running sam build on template file"
sam build --template-file="${TEMPLATE_FILE}"
mv .aws-sam/build/template.yaml cf-template.yaml

if grep -q "CONTAINER-IMAGE-PLACEHOLDER" cf-template.yaml; then
  echo 'Replacing "CONTAINER-IMAGE-PLACEHOLDER" with new ECR image ref'
  sed -i "s|CONTAINER-IMAGE-PLACEHOLDER|${DOCKER_TAG}|" cf-template.yaml
else
  echo 'WARNING!!! Image placeholder text "CONTAINER-IMAGE-PLACEHOLDER" not found - uploading template anyway'
fi

if grep -q "GIT-SHA-PLACEHOLDER" cf-template.yaml; then
  echo 'Replacing "GIT-SHA-PLACEHOLDER" with new ECR image tag'
  sed -i "s|GIT-SHA-PLACEHOLDER|$GITHUB_SHA|" cf-template.yaml
fi

zip template.zip cf-template.yaml

OBJECT_VERSION="$(aws s3api put-object \
  --bucket "${ARTIFACT_BUCKET_NAME}" \
  --key template.zip \
  --body template.zip \
  --metadata "repository=${GITHUB_REPOSITORY},commitsha=${GITHUB_SHA},committag=${GIT_TAG},commitmessage=${COMMIT_MSG},mergetime=${MERGE_TIME},skipcanary=${SKIP_CANARY_DEPLOYMENT},commitauthor='${GITHUB_ACTOR}',release=${VERSION_NUMBER}" \
  --query VersionId --output text)"
echo "::notice title=Template uploaded to S3::ecr_repo: ${ECR_REPO_NAME}, object: template.zip, version: ${OBJECT_VERSION}"
echo "version_id=${OBJECT_VERSION}" >> "${GITHUB_OUTPUT}"
