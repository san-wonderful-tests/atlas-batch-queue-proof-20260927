# Atlas batch and Merge Queue proof

This synthetic repository tests whether reviewed migration PR commits can be
combined in one batch and merged through GitHub Merge Queue while preserving
the original PRs as merged. It does not represent Wonderful production CI.

The active ruleset requires the `validate-batch` check on PRs and merge groups.
The workflow validates two independent Atlas migration directories against
PostgreSQL 17, including desired-schema drift. The batch proof will merge
original PR commits into a batch branch, reallocate their SQL versions, and
regenerate both `atlas.sum` files before adding the batch PR to Merge Queue.

To compose a batch locally, start a new branch at `origin/main` and run
`scripts/compose-batch.sh <candidate-ref>...`. The script keeps each candidate
head in the batch's commit ancestry, refuses conflicts outside `atlas.sum`,
allocates new Atlas versions for PR-owned SQL, and records the source-to-final
mapping in a branch-specific `batch-manifests/*.tsv` file. It validates the combined history and desired
schemas before the batch PR is queued. This is a test harness; it does not yet
verify GitHub reviews or run with a production GitHub App.
