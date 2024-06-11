# Upload Action

This is an action that allows you to upload a built SAM application to S3 and ECR using GitHub Actions.

The action packages, signs, and uploads the application to the specified ECR and S3 bucket.

## Action Inputs

| Input                      | Required | Description                                                                            | Example                                                                              |
|----------------------------|----------|----------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| artifact-bucket-name       | true     | The secret with the name of the artifact S3 bucket                                     | artifact-bucket-1234                                                                 |
| container-sign-kms-key-arn | false     | The secret with the name of the Signing Profile resource in AWS                        | signing-profile-1234                                                                 |
| working-directory          | false    | The working directory containing the SAM app and the template file                     | ./sam-ecr-app                                                                        |
| template-file              | false    | The name of the CF template for the application. This defaults to template.yaml        | custom-template.yaml                                                                 |
| role-to-assume-arn         | true     | The secret with the GitHub Role ARN from the pipeline stack                            | arn:aws:iam::0123456789999:role/myawesomeapppipeline-GitHubActionsRole-16HIKMTBBDL8Y |
| ecr-repo-name              | true     | The secret with the name of the ECR repo created by the app-container-repository stack | app-container-repository-tobytraining-containerrepository-i6gdfkdnwrrm               |
| dockerfile                 | false     | The Dockerfile to use for the build | Dockerfile
| checkout-repo                 | false     | Checks out the repo as the first step of the action. Default "true". | "true"

## Usage Example

Pull in the action in your workflow as below, making sure to specify the release version you require.

```yaml
- name: Deploy SAM app to ECR
  uses: alphagov/di-devplatform-upload-action-ecr@<version_number>
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

NOTE: In regards to Dependabot subcribers, Dependabot does not pick up and raise PRs for `PATCH` versions (i.e v3.8.1) of a release ensure consumers are nofitied.

### Breaking changes

Release a new major version as normal following semantic versioning.

### Preparing a release

When working on a PR branch, create a release with the target version, but append -beta to the post-fix tag name.

e.g.

`git tag v3.1-beta`

You can then navigate to the release page, and create a pre-release to validate that the tag is working as expected.
After you've merged the PR, then apply the correct tag for your release.

Please ensure all pre-release versions have been tested prior to creation, you are able to do this via updating `uses:`
property within a GitHub actions workflow to point to a branch name rather than the tag, see example below:

```
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