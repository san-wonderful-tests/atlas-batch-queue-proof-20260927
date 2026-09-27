# Atlas batch and Merge Queue proof

This synthetic repository tests whether reviewed migration PR commits can be
combined in one batch and merged through GitHub Merge Queue while preserving
the original PRs as merged. It does not represent Wonderful production CI.

The active ruleset requires the `validate-batch` check on PRs and merge groups.
The workflow validates two independent Atlas migration directories against
PostgreSQL 17, including desired-schema drift. The batch proof will merge
original PR commits into a batch branch, reallocate their SQL versions, and
regenerate both `atlas.sum` files before adding the batch PR to Merge Queue.
