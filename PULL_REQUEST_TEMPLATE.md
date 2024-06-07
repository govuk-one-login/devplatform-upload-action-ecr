## Description

### Ticket number
[PSREDEV-XXX]

## GitHub Action Releases

We follow [recommended best practices](https://docs.github.com/en/actions/creating-actions/releasing-and-maintaining-actions) for releasing new versions of the action.

### Non-breaking Chanages:
Release a new minor or patch version as appropriate. Then, update the base major version release (and any minor versions)
to point to this latest commit. For example, if the latest major release is v2 and you have added a non-breaking feature,
release v2.1.0 and point v2 to the same commit as v2.1.0.

NOTE: Dependabot does not pick up and raise PRs for `PATCH` versions (i.e v3.8.1), please nofity teams in the relevant slack channels.

### Breaking Changes:
Release a new major version as normal following semantic versioning.

## Checklist

- [ ] Is my change backwards compatible? **_Please include evidence_**

- [ ] I have installed and run pre-commit

- [ ] I have updated the changelog

- [ ] I have tested this and added output to Jira
**_Comment:_**

- [ ] Automated tests added
**_Comment:_**

- [ ] Documentation added ([link]())
**_Comment:_**

- [ ] Delete any new stacks created for this ticket
**_Comment:_**

### Co-authored by
