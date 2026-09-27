# Atlas migration batching and Merge Queue proof

2026-09-27. All experiments used this synthetic repository in
`san-wonderful-tests`. No Wonderful monorepo branch was changed.

## Recommendation

Use a **reviewed migration batch PR** as the unit that enters GitHub Merge
Queue. A trusted coordinator starts from current `main`, merges the original PR
head commits with merge commits, resolves only generated `atlas.sum` conflicts,
and asks Atlas to assign new versions to PR-owned SQL. It preserves the SQL
bytes and records each old-to-new path and SHA-256. Full CI runs on the batch's
merge-group SHA. The queue uses the `MERGE` method, so GitHub recognizes the
original PR commits as merged when the batch lands.

This replaces the synthetic one-PR-at-a-time coordinator's repeated full CI
with one full CI run for a batch. Merge Queue tests the combined result after
unrelated `main` changes. The batch builder still serializes the cheap Atlas
history rewrite, but does not serialize full monorepo CI per migration PR.

## Live results

| Case | Result |
| --- | --- |
| Merge Queue and ancestry | The active [ruleset](.github/main-ruleset.json) requires `validate-batch` and Merge Queue with the `MERGE` method. [Batch PR #3](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/3) passed [merge-group CI](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/actions/runs/36337978883). GitHub marked both source [PR #1](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/1) and [PR #2](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/2) merged automatically. |
| Two Atlas checksum conflicts and base movement | Source [PR #5](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/5) and [PR #6](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/6) each changed both Atlas directories from the same base. The composer encountered conflicts in both `atlas.sum` files, allocated four new SQL paths, preserved their bytes in [the manifest](BATCH_MANIFEST.tsv), and validated the combined history and schemas. Unrelated [PR #9](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/9) landed on `main` before [batch PR #10](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/10). The batch passed [CI on the newer merge-group SHA](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/actions/runs/36338760979), merged, and GitHub marked both source PRs merged. |
| Thirty-PR burst | Thirty source [PRs #11–#40](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pulls?q=is%3Apr+is%3Amerged) started from one `main` SHA, each adding SQL in two Atlas directories. Composition took **122 seconds**. [Batch PR #41](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/pull/41) passed [merge-group CI](https://github.com/san-wonderful-tests/atlas-batch-queue-proof-20260927/actions/runs/36339455771) and merged. All **30/30** original PRs were marked merged. The [batch manifest](batch-manifests/proof-batch-load-30.tsv) maps all **60** source SQL files to distinct final paths; each final file's SHA-256 matched its source. Both Atlas directories validate on merged `main`. |

For the thirty-PR burst, nearest-rank creation-to-merge latency was **7m 54s
median**, **10m 10s p95**, and **10m 18s max** (minimum 5m 06s). The PRs were
created sequentially over roughly five minutes, so these figures include
creation time and do not represent simultaneous arrival. The batch PR took
100 seconds from opening to merge; its PR check took 28 seconds and merge-group
check took 24 seconds. The local composer took 122 seconds. These are tiny
synthetic migrations and CI jobs, not a full monorepo throughput result.

## Why the capacity model changes

Sixty developers at five PRs a day mean 300 total PRs/day, or **12.5 PRs/hour**
on average. In the worst case, all are migration PRs. With a 20-minute full CI
run and one merge group at a time, a batch must average more than **4.17 source
PRs** merely to keep up. A target of eight source PRs per batch gives about
24 source PRs/hour before composition and queue overhead. Keep a maximum wait
for quiet periods and raise the batch size when backlog grows; cap batch size
at 30 until real CI measurements justify more. Code PRs sharing Merge Queue
reduce this capacity, so the 300-PR/day arrival test must include them.

The measured 30-PR burst establishes that GitHub can accept this batch shape
and preserve original PR states. It does **not** establish a 20-minute CI
duration, five-directory cost, or 24-hour sustained capacity.

## Production contract and remaining gates

1. A narrowly scoped GitHub App owns batch branches, the batch eligibility
   status, and queue entry. It admits only source PRs whose required reviews and
   ordinary CI are current for their exact head SHA. A migration PR cannot
   enter Merge Queue directly; code-only PRs retain their normal path. The
   test repo has no App or enforced source-review gate.
2. The builder runs trusted code from `main` in a disposable checkout. It never
   executes candidate scripts with the App credential. It rejects edits to
   existing migration history and conflicts outside `atlas.sum`; it verifies
   all original SQL bytes after Atlas allocates versions. Production must cover
   all five Wonderful Atlas directories and quarantine one bad PR without
   blocking the rest of a batch. The current lab composer aborts the whole
   batch on a rejected PR.
3. Read-only merge-group CI runs the full monorepo checks and Atlas validation
   for all five directories on the exact tree GitHub will merge. External GORM
   loaders run without the App credential. The batch PR uses a merge commit so
   original PRs close as merged. This repo validates only two synthetic Atlas
   directories with short CI.
4. A durable worker reconciles open source PRs, batch branches, and Merge Queue
   entries after cancellation or API failure. It records source head SHAs and
   batch manifests, retries idempotently, and alerts on stranded work. The lab
   composer was invoked manually; worker recovery remains unproven.
5. Before Wonderful rollout, run 30 simultaneous PRs across five directories
   and a 24-hour 300-PR arrival simulation with representative full CI and code
   PR traffic. Include incompatible SQL, duplicate filenames, immutable-history
   edits, non-checksum conflicts, bad reviews, runner cancellation, API limits,
   and `main` moving during CI. Require zero lost or duplicated migrations, no
   stale-base merge, a measured sustained rate above 12.5 migration PRs/hour
   with headroom, and p95 burst latency under 30 minutes.

**Release decision:** the batch and Merge Queue shape is promising and passed
the synthetic 30-PR proof. It is not yet approved for Wonderful deployment
because the credential/review gate, bad-PR isolation, durable recovery,
five-directory coverage, and real full-CI load test are still open.
