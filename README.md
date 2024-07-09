# Upload Action

This is an action that allows you to upload a built SAM application to S3 and ECR using GitHub Actions.

The action packages, signs, and uploads the application to the specified ECR and S3 bucket.

## Action Inputs

| Input | Description | Required | Default | Example |
| ----- | ----------- | -------- | ------- | ------- |
| role-to-assume-arn | The secret with the ARN of the role to assume (required) eg secrets.GH_ACTIONS_ROLE_ARN | true | | arn:aws:iam::0123456789999:role/myawesomeapppipeline-GitHubActionsRole-16HIKMTBBDL8Y |
| container-sign-kms-key-arn | The secret with the ARN of the key to sign container images e.g. secrets.CONTAINER_SIGN_KMS_KEY | false | "none" | arn:aws:kms:eu-west-2:0123456789999:key/ab12cd34-6e5f-7gh8-i90j-05aaa12345ab |
| build-and-push-image-only | Only run docker build, push and signing steps. Skip packaging and artifact uploads | false | "false" | |
| template-file | The name of the CF template for the application. This defaults to template.yaml | false | template.yaml | custom-template.yaml |
| working-directory | The working directory containing the app | false | . | ./sam-ecr-app |
| artifact-bucket-name | The secret with the name of the artifact S3 bucket (required) eg secrets.ARTIFACT_SOURCE_BUCKET_NAME | true | | artifact-bucket-1234 |
| ecr-repo-name | The secret with the name of the ECR Repo (required) eg secrets.ECR_REPOSITORY | true | | app-container-repository-containerrepository-i6gdfkdnwrrm |
| dockerfile | The Dockerfile to use for the build | false | Dockerfile | |
| docker-build-path | The Dockerfile path to use for the build | false | | |
| docker-platform | The target architecture for the image build | false | "" | |
| checkout-repo | Checks out the repo as the first step of the action. Default "true".  | false | "true" | |
| private-docker-registry | Private Docker registry URL | false | "" | |
| private-docker-login-username | Login username to the private docker registry | false | "" | |
| private-docker-login-password | Login password to the private docker registry | false | "" | |
| push-latest-tag | Float 'latest' tag to the latest image version. This requires tag immutability disabled, a typical use case is test-image-repository containers | false | "false" | |
| version-number | The version number of the application being deployed. This defaults to ""' | false | "" | |

## Usage Example

Pull in the action in your workflow as below, making sure to specify the release version you require.

```yaml
- name: Deploy SAM app to ECR
  uses: govuk-one-login/devplatform-upload-action-ecr@<version_number>
  with:
    artifact-bucket-name: ${{ secrets.ARTIFACT_SOURCE_BUCKET_NAME }}
    container-sign-kms-key-arn: ${{ secrets.CONTAINER_SIGN_KMS_KEY }}
    working-directory: ./sam-ecr-app
    template-file: custom-template.yaml
    role-to-assume-arn: ${{ secrets.GH_ACTIONS_ROLE_ARN }}
    ecr-repo-name: ${{ secrets.ECR_REPOSITORY }}
```

## Requirements

- pre-commit:

  ```shell
  brew install pre-commit
  pre-commit install -tpre-commit -tprepare-commit-msg -tcommit-msg
  ```

## Releasing updates

We follow [recommended best practices](https://docs.github.com/en/actions/creating-actions/releasing-and-maintaining-actions) for releasing new versions of the action.

### Non-breaking changes

Release a new minor or patch version as appropriate. Then, update the base major version release (and any minor versions)
to point to this latest commit. For example, if the latest major release is v2 and you have added a non-breaking feature,
release v2.1.0 and point v2 to the same commit as v2.1.0.

NOTE: Until v3 is released, you will need to point both v1 and v2 to the latest version since there are no breaking changes between them.

NOTE: In regards to Dependabot subscribers, Dependabot does not pick up and raise PRs for `PATCH` versions (i.e v3.8.1) of a release ensure consumers are notified.

### Breaking changes

Release a new major version as normal following semantic versioning.

### Bug fixes

Once your PR is merged and the bug is fixed, make sure to float tags affected by the bug to the latest stable commit.

For example, let's say commit `abcd001` introduced a bug and is tagged with `v2.3.1`.  You then merge commit `dcba002` with a fix to your solution:

:bug: `abcd001` `v2.3.1`

:white_check_mark: `dcba002`

Instead of creating a new tag for the fix, you can update the `v2.3.1` tag to the latest stable commit with the following command:
```
git tag -s -af v2.3.1 dcba002
git push origin v2.3.1 -f
```

:bug: `abcd001`

:white_check_mark:`dcba002` `v2.3.1`

This will make sure users benefit from the fix immediately, without the need to manually bump their action version.

### Preparing a release

When working on a PR branch, create a release with the target version, but append -beta to the post-fix tag name.

e.g.

`git tag v3.1-beta`

You can then navigate to the release page, and create a pre-release to validate that the tag is working as expected.
After you've merged the PR, then apply the correct tag for your release.

Please ensure all pre-release versions have been tested prior to creation, you are able to do this via updating `uses:`
property within a GitHub actions workflow to point to a branch name rather than the tag, see example below:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Upload and tag
        uses: govuk-one-login/devplatform-upload-action-ecr@<BRANCH_NAME>
```
