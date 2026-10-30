# Upload Action

This is an action that allows you to upload a built SAM application to S3 and ECR using GitHub Actions.

The action packages, signs, and uploads the application to the specified ECR and S3 bucket.

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

## Image provenance

To make it easy to identify the source of an image (for example when triaging findings in AWS Inspector),
the action links every image it builds back to the source repository.

### OCI labels

The following [OCI image annotation labels](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
are baked into the image config at build time. Unlike the S3 object metadata (which stays with `template.zip`),
these are tagged with the image and are surfaced by ECR and AWS Inspector:

| Label                                 | Value                                      |
| ------------------------------------- | ------------------------------------------ |
| `org.opencontainers.image.source`     | Source repository URL (e.g. `https://github.com/<owner>/<repo>`) |
| `org.opencontainers.image.revision`   | The commit SHA (`github.sha`)              |
| `org.opencontainers.image.version`    | The `version-number` input, falling back to the commit SHA |
| `org.opencontainers.image.created`    | The image build timestamp (UTC)            |

You can inspect them on a pulled image with:

```shell
docker inspect --format '{{json .Config.Labels}}' <image> | jq
```

### Source repository tag

In addition to the commit SHA tag, the image is pushed with a tag derived from the source repository
(`github.repository`) using the current workflow context. Because Docker tags cannot contain `/` or
uppercase characters, the `owner/repo` value is sanitised — for example `govuk-one-login/my-app`
becomes the tag `govuk-one-login_my-app`. When container signing is enabled, this tag is signed
alongside the SHA tag.

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
