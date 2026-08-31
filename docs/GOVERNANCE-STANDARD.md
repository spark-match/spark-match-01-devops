# Governance Standard — Spark Match Organization

> **Scope:** this document defines the governance standard for every repository declared in `governance/repository-governance.json` under the `spark-match` GitHub organization. Consumer repositories under the personal `ahincho/` namespace are out of scope and follow their own local conventions.
>
> **Status:** this is the canonical reference. The declarative source of truth is `governance/repository-governance.json`; this document is the narrative companion that explains the rationale and how to apply it.

## 1. Executive summary

Every `spark-match/*` repository must enforce the same baseline governance: a single ruleset named `spark-match-default-branch-protection` that protects the default branch (and `dev` where applicable), blocks force-pushes and branch deletions, requires pull-request approval from a designated technical team via `CODEOWNERS`, allows only squash merges, and limits admin bypass to the pull-request context.

For current compliance, ask the reconciler — `./scripts/configure-repo-rulesets.sh --check` — which computes it against the live rulesets. A percentage used to sit here, dated 2026-07-26, and it was stale in both directions: it counted nine repositories when `.github` brought the total to ten, and it read as authoritative while `spark-match-02-infrastructure` sat in drift for three days.

## 2. The canonical ruleset

Every `spark-match/*` repository has exactly one ruleset named `spark-match-default-branch-protection`. Its shape is:

| Field | Value | Why |
|---|---|---|
| `target` | `branch` | Branch-level protection |
| `enforcement` | `active` | Rules apply, not advisory |
| `bypass_actors[0].bypass_mode` | `pull_request` | Admin bypass only inside a PR; direct pushes are blocked |
| `conditions.ref_name.include` | `["~DEFAULT_BRANCH"]` + `"refs/heads/dev"` if used | Only protects branches that actually carry code |
| `rules[].pull_request.required_approving_review_count` | `1` | One approval is enough |
| `rules[].pull_request.require_code_owner_review` | `true` | CODEOWNERS-based review (see § 3) |
| `rules[].pull_request.allowed_merge_methods` | `["squash"]` | Squash only; merge commits prohibited |
| `rules[].pull_request.dismiss_stale_reviews_on_push` | `true` | Stale reviews dismissed when new commits land |
| `rules[].pull_request.required_review_thread_resolution` | `true` | Unresolved threads block merge |
| `rules[].non_fast_forward` | present | Force-push blocked |
| `rules[].required_linear_history` | present | No merge commits reaching main |
| `rules[].deletion` | present | Branch deletion blocked at the API level |
| `rules[].required_status_checks` | per-repo | Strict mode: when a repo declares status checks in the manifest, the reconciler enforces `strict_required_status_checks_policy: true` so the head branch must be up-to-date before merge. Individual checks are repo-specific (see manifest). |

The full desired state for the three pilot repositories is encoded in `governance/repository-governance.json` (schema `spark-match.repository-governance/v2`).

### 2.1 Classic branch protection must NOT coexist with the ruleset

The ruleset covers everything classic branch protection covered, so a repository
should have **one** of the two, never both. When they coexist the more
restrictive one wins, and that breaks things in non-obvious ways.

The concrete case, found on 2026-08-06: `04-frontend`, `07-article` and
`08-deep-agent` had classic branch protection on `main` **in addition to** the
ruleset, with `enforce_admins: true`. That flag overrides the ruleset's
`bypass_actors` — not even an organization admin can get past it — so every pull
request sat waiting for a reviewer, with an error identical through the CLI and
the REST API:

> Those three were what showed up **looking only at the default branch**. The
> full sweep the same day found 9 branches across 5 repositories; the breakdown
> is below, under "Why every branch".

```
Repository rule violations found
Waiting on code owner review from spark-match/<team>
```

It is expensive to diagnose, because the message says *rule violations* while
the ruleset on its own would allow the merge. And it had been that way for a
while without anyone noticing, because the reconciler only queried `/rulesets`.

Since 2026-08-06 `configure-repo-rulesets.sh` **always** detects classic
protection, across **every branch** of the repository, not just the default one:

```bash
# See which repos have it (changes nothing; exits 1 if there is drift)
./scripts/configure-repo-rulesets.sh --check

# Remove it from one repo, leaving the ruleset as the single source
./scripts/configure-repo-rulesets.sh --apply --repos <repo> --prune-legacy-protection
```

It surfaces as the `legacy-protection` state, counts as drift under `--check`,
and is a hard failure under `--strict`. Each branch produces its own entry, so a
repository running both layers appears twice. Removing it requires the explicit
flag, on the same principle as `--prune-unexpected`: the reconciler does not
destroy rules it did not create unless asked to on the command line.

Before each deletion the full payload is saved to `--backup-dir` as
`<repo>-legacy-protection-<branch>.json`, and **if the backup fails, nothing is
deleted**. That is the same contract rulesets already had before a `PUT`. A
`DELETE` on `/branches/{b}/protection` has no undo.

### The policy: rulesets plus CODEOWNERS, and nothing else

The organization manages branch protection with **two mechanisms, and only
two**:

1. **Rulesets**, declared in `governance/repository-governance.json` and applied by the reconciler.
2. **CODEOWNERS**, which decides who reviews what (section 3).

Classic branch protection **is not part of the standard and must be removed
wherever it exists**. It adds nothing the ruleset does not cover, no versioned
file declares it, and its `enforce_admins` breaks the bypass without leaving any
trace of why.

A repository having it is not a pending decision for its team to revisit: it is
debt to remove. That is precisely why `--check` treats it as drift.

### Why every branch, not just the default one

The first version of this detection only looked at `default_branch`. With that
scope it would not have found the classic protection on the `dev` branch of
`spark-match-06-article`, which had to be removed by hand that same day.

The full sweep across the organization on 2026-08-06 returned this:

| | |
|---|---|
| Branches with classic protection | 9, across 5 repositories |
| On the default branch | 5 |
| **On other branches** | **4**, all on `dev` |
| With `enforce_admins: true` | 5, all on the default branch |

The narrow scope was missing almost half the findings. Candidates come from
three sources that are merged and deduplicated: the `?protected=true` listing,
the default branch, and the refs the manifest declares. The first narrows the
work but **does not decide**, because that filter also returns branches
protected by a ruleset alone; the classic endpoint decides, and a 404 there
means no classic layer.

**The general lesson**: a declarative manifest only guarantees what it knows how
to query. This one claimed to declare "the desired state of branch protection
across the organization" while ignoring one of the two surfaces where that
protection lives. And when it finally did query it, it queried in a single
place.

## 3. The canonical CODEOWNERS

The canonical pattern is **a catch-all first, then explicit paths that override
it**. Every path that deserves a named owner still gets its own line; the
catch-all exists so that the paths nobody remembered to list are not left
ownerless.

```
*                    @spark-match/<tech-team>          <- floor, never the whole answer
/README.md           @spark-match/<tech-team> @spark-match/product-owners
/governance/         @spark-match/<tech-team> @spark-match/product-owners
```

Order matters and only in one direction: **for any given file, the last matching
pattern wins, and it wins outright.** GitHub does not accumulate owners across
patterns. The catch-all is therefore a floor, not a tax — every later, more
specific line replaces it completely.

> **Policy change, 2026-08-07.** This section used to say *"explicit paths, no
> catch-all"*, and gave two reasons. The first — predictability, a new file
> should not silently inherit a reviewer — still stands and is why the specific
> lines are kept. The second was simply wrong: it claimed *"GitHub accumulates
> owners from every matching pattern"*, so that `* @team-a` plus
> `/README.md @team-b` would demand both on the README. It does not.
>
> That mattered, because the prohibition rested on the wrong half.
>
> The cost of *not* having a catch-all is now measured rather than theorised. On
> 2026-08-07, `spark-match-02-infrastructure` had `bootstrap/` — where the IAM
> policies applied to the Terraform roles live — with **no owner at all**, along
> with `tasks/` and ten of its sixteen modules. `require_code_owner_review` over
> an unowned path is satisfied trivially: the gate is there, it reports green,
> and it is guarding nothing. The rule "if you create a new path, add a line"
> depends on somebody remembering, and it had gone ten modules unremembered.
>
> That is a fail-open failure, and the reason for the change: a floor that is
> occasionally too broad is safer than a hole that reads as a pass. The residual
> cost is real but smaller — ownership is less obvious to a reader, and paths
> nobody chose get a default owner. `tests/bats/` guards against the specific
> case that bit us, an unowned top-level directory.
>
> **To reverse this**, drop the catch-all from every repository's CODEOWNERS and
> restore explicit-only paths — but pair it with a check that fails when a path
> has no owner, or the same hole comes back the next time somebody adds a
> directory in a hurry.

### Header template

```
# CODEOWNERS - Spark Match <N>-<slug>
#
# Approval policy (configured via the ruleset):
#   - dev:  required_approving_review_count: 1
#           require_code_owner_review: true
#   - main: required_approving_review_count: 1
#           require_code_owner_review: true
#
# Code owners for this repo:
#   @spark-match/<tech-team>     Members: <list>
#   @spark-match/product-owners  Members: <list>  (governance paths only)
#
# Convention:
#   - Every path in the repo is listed explicitly.
#   - If you create a new path, add a line here before merging it.
#
# On precedence: for any given file, the LAST matching pattern wins, and it
# wins outright -- GitHub does not accumulate owners across patterns. A
# catch-all placed first is overridden by every later, more specific line.
#
# Note: the author of a pull request cannot approve their own, not even as a
# code owner (a GitHub rule). A pull request opened by <user> needs approval
# from any other member of the team.
```

### Path patterns

Critical paths (governance, README, LICENSE) are always listed and double-owned by `@spark-match/product-owners`:

```
/README.md                                  @spark-match/<tech-team> @spark-match/product-owners
/CONTRIBUTING.md                            @spark-match/<tech-team> @spark-match/product-owners
/LICENSE                                    @spark-match/<tech-team> @spark-match/product-owners
```

All other paths are owned only by the technical team of the repo:

```
/.github/                                    @spark-match/<tech-team>
/scripts/                                    @spark-match/<tech-team>
```

If the repo has no `/scripts/`, omit that line. The point is: every directory and file that exists must appear in the file.

### Bringing a repository up to the pattern

This section used to describe migrating **away** from `* @team` toward
explicit-only paths. Since the policy change of 2026-08-07 the direction is
reversed: the catch-all stays as a floor and the explicit lines sit on top of
it. The work is the same either way, and it is mechanical:

1. Run `--check --repos <repo>` to confirm the current state.
2. List every top-level directory and file: `git ls-files | awk -F/ '{print $1}' | sort -u`.
3. Make sure a `*` line exists and comes **first**, owned by the repository's technical team.
4. Add one explicit line per path that deserves a named owner — governance and community docs get `@product-owners` alongside the technical team. Every one of these must come **after** the catch-all, or it will not take effect.
5. Compare the result against step 2: an unlisted path is not an error any more, but it does mean nobody chose its owner. Decide, then list it or leave it to the floor deliberately.
6. Open a pull request; it needs approval from another team member (self-approval is impossible).
7. Re-run `--check` to confirm the change introduced no drift.

### Reference implementation: `spark-match-01-devops`

The catalog repo (`spark-match-01-devops`) is the canonical example of a fully-migrated explicit-paths `CODEOWNERS`. As of 2026-07-26 every tracked path is listed explicitly:

| Path | Owner(s) | Why |
|---|---|---|
| `/README.md`, `/LICENSE`, `/SECURITY.md`, `/CONTRIBUTING.md`, `/CODE_OF_CONDUCT.md`, `/CHANGELOG.md`, `/docs/` | `@devops` + `@product-owners` | Governance / community docs. Double-owned because they encode policy decisions, not just technical content. |
| `/.github/`, `/scripts/`, `/governance/`, `/tests/`, `/.yamllint.yml`, `/.gitignore`, `/.shellcheckrc`, `/.release-please-manifest.json` | `@devops` | Technical artifacts. Single-owned because no policy decisions in them. |

The header comment in the file lists the PRs that introduced each new path so future maintainers can audit why a path exists.

## 4. Team assignment per repository

| Repository | Required tech team | Audited members | Notes |
|---|---|---|---|
| `spark-match/.github` | `@spark-match/devops` | dbarretol, ahincho | Organization profile |
| `spark-match-00-knowledge-base` | `@spark-match/tech-leads` | ahincho, dbarretol | Documentation |
| `spark-match-01-devops` | `@spark-match/devops` | dbarretol, ahincho | DevOps catalog (this repo) |
| `spark-match-02-infrastructure` | `@spark-match/devops` | dbarretol, ahincho | Terraform |
| `spark-match-03-backend` | `@spark-match/backend-devs` | ahincho, BriyitHT | Backend API |
| `spark-match-04-frontend` | `@spark-match/frontend-devs` | ahincho, BriyitHT | Frontend |
| `spark-match-05-data-pipeline` | `@spark-match/ai-devs` | FabiTaparaQuispe, ahincho, nikolaiasencios | Data |
| `spark-match-06-article` | `@spark-match/article-authors` | dbarretol, FabiTaparaQuispe, ahincho, BriyitHT, nikolaiasencios | LaTeX |
| `spark-match-07-deep-agent` | `@spark-match/ai-devs` | FabiTaparaQuispe, ahincho, nikolaiasencios | Agents |

Every team has at least two members, which guarantees the author of any PR has a potential reviewer who is not themselves.

## 5. Onboarding a new repository

1. **Create the repository** with internal visibility and `main` as the default branch.
2. **Write `CODEOWNERS`** following the template in § 3: catch-all first, then the explicit lines.
3. **Add the repository to the manifest**: edit `governance/repository-governance.json` with an entry carrying `refs`, `reviewerTeam`, `filePatterns` and `statusChecks`.
4. **Dry run**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --dry-run --apply --repos <new-repo>
   ```
   Confirms the payload is valid against both the schema and the API.
5. **Apply**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --apply --repos <new-repo>
   ```
   The script creates the ruleset (`POST`) or updates it (`PUT`), saving a backup under `backups/rulesets/<timestamp>/`.
6. **Smoke test**: open a no-op pull request touching one path at the root and one under a subdirectory. Confirm CODEOWNERS requests review from the right team.

> **A caveat on `statusChecks`.** This field is what the reconciler *writes*, so
> it is the desired state, not a record of what a repository happens to have.
> Declaring fewer checks than the live ruleset requires means the next `--apply`
> silently removes the difference. On 2026-08-07 this manifest declared 8 checks
> for `spark-match-02-infrastructure` against 21 actually required, so running
> the tool as designed would have dropped thirteen gates. Derive the list from
> what the pull requests actually publish -- `gh pr checks <n>` -- not from
> reading the workflow files.

## 6. Migrating a legacy repository to the standard

1. **Audit the current state**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --check --repos <repo>
   ```
   This reports drift across bypass_mode, merge methods, the deletion rule, codeowner_review, and classic branch protection on any branch. Read the CODEOWNERS by hand as well: the reconciler does not look inside that file.
2. **Manual backup** of the current ruleset, as defence in depth:
   ```bash
   gh api repos/spark-match/<repo>/rulesets > backups/<repo>-pre-standards.json
   ```
3. **Apply**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --apply --repos <repo>
   ```
   The reconciler backs up automatically, then `PUT`s. If the API rejects the payload it reports `failed` and the ruleset is left untouched.
4. **Canary pull request**: open a trivial one (a trailing comment) touching both the root and a subdirectory. Confirm `reviewDecision: REVIEW_REQUIRED` and that the right team is requested.
5. **Close the canary** — it was a no-op. The team should have been notified automatically.
6. **CODEOWNERS**: bring the file up to the pattern in § 3 — catch-all first, explicit lines after it.
7. **Final check**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --check --repos <repo>
   ```
   The only acceptable drift is `required_reviewers` (see § 9).

## 7. Compliance checklist

To call a `spark-match/*` repository compliant it must satisfy **all** of these:

- [ ] **Ruleset `bypass_mode == "pull_request"`** (not `always`).
- [ ] **Ruleset `allowed_merge_methods == ["squash"]`** (does not include `merge`).
- [ ] **Ruleset includes the `deletion` rule** (branch deletion blocked).
- [ ] **Ruleset `require_code_owner_review == true`**.
- [ ] **No classic branch protection on any branch** (§ 2.1).
- [ ] **CODEOWNERS has a catch-all first**, so no path is left ownerless, with explicit lines after it for anything that deserves a named owner (§ 3).
- [ ] **The CODEOWNERS header says "ruleset"**, not "branch protection".

> Until 2026-08-07 the sixth item read *"CODEOWNERS follows the explicit pattern
> (no catch-all `*`)"*. It was inverted that day; § 3 records why and how to
> reverse it.

Audit commands:

```bash
# Ruleset compliance, plus classic-protection detection on every branch:
./scripts/configure-repo-rulesets.sh --check --repos <repo>

# CODEOWNERS: a catch-all must exist, and it must come first
grep -nE '^\s*\*\s+@' .github/CODEOWNERS    # must return at least one line

# Header wording:
grep -i 'ruleset' .github/CODEOWNERS | head -1   # must exist
```

## 8. Current status

There is no status table here, and that is deliberate.

The one that used to sit in this section was a snapshot dated 2026-07-26 with a
"global compliance: 87%" line under it. It aged badly in three separate ways:
`.github` was declared on 2026-08-06 and never appeared in it; the "explicit
CODEOWNERS" column became meaningless when the policy inverted on 2026-08-07;
and `spark-match-02-infrastructure` sat in drift for three days — 8 status
checks declared against 21 actually required — while the table still showed it
at full compliance.

A table of live state, transcribed by hand into a document, is a report that
cannot report. Ask the tool:

```bash
./scripts/configure-repo-rulesets.sh --check
```

Every repository should come back `in-sync`. That command reads the live
rulesets and every branch's classic protection, so it cannot be stale by
construction.

### Known cosmetic drift

The CODEOWNERS header comment in most repositories still says "branch
protection" where it should say "ruleset". It is a comment, so the reconciler
cannot see it and `--check` will never report it; the compliance checklist in
§ 7 keeps it as a manual item. It changes nothing functionally, and the fix is a
cleanup pull request per repository.

### Historical record: the 2026-07-26 migration

Kept because the procedure is instructive, **not because it is current** — it
migrated repositories *toward* explicit-only CODEOWNERS, which § 3 reversed on
2026-08-07.

Seven repositories were migrated by pushing directly to `main`, which required
**both** of these to be temporarily disabled:

1. Ruleset `bypass_actors[0].bypass_mode`: `pull_request` → `always`
2. Classic branch protection `enforce_admins`: `true` → `false`

Both were restored afterwards, with a risk window under five seconds per
repository.

**The lesson worth keeping**: setting `bypass_mode: always` on the ruleset alone
is *not* enough. Classic branch protection with `enforce_admins: true` blocks
independently of the ruleset — which is the same interaction that § 2.1
documents from the other direction, and the reason classic protection must be
removed rather than merely worked around.

> **Historical record, not the current procedure (updated 2026-08-06).** Step 2
> and its restoration no longer apply: classic branch protection is not part of
> the standard (§ 2.1), so putting `enforce_admins: true` back would recreate
> exactly the problem. Today the bypass is a single flag, the ruleset's. If a
> direct push is still blocked after setting it to `always`, that symptom gives
> away a classic layer, and the fix is to retire it with
> `--prune-legacy-protection` — not to disable and re-enable it.

## 9. Known deviations

### `required_reviewers` (ruleset API) is unavailable

The GitHub ruleset accepts a `required_reviewers` field to force reviews by team
or individual through the API, instead of via CODEOWNERS. That field is **not
available on the organization's Free plan**: the API rejects payloads carrying
non-empty values with HTTP 422. The equivalent behaviour is therefore achieved
with `require_code_owner_review: true` plus CODEOWNERS.

This is recorded in the manifest's `_notes` (`governance/repository-governance.json`)
and in the pilot commit. The only way to use `required_reviewers` is upgrading to
GitHub Team or Enterprise; until then, CODEOWNERS is the source of truth.

### Expected drift, resolved by `canonical_diff`

An earlier section here, "Expected permanent drift", documented
`required_reviewers` as noisy drift. That **was resolved** in schema v3, together
with the commit that extended `canonical_diff()` to strip `required_reviewers`
before comparing. Every repository now reports `in-sync` despite the field being
stale in the live payload.

## 10. Tools

### Reconciler

`--help` is the authoritative list. What each of the destructive flags does:

```bash
./scripts/configure-repo-rulesets.sh \
  --check                            # drift detection; exits 1 when there is drift
  --apply                            # PUT/POST plus backup
  --dry-run                          # no writes
  --repos r1,r2                      # scope
  --manifest governance/repository-governance.json
  --backup-dir <path>                # default: backups/rulesets/<ts>/
  --strict                           # escalate warnings to failures
  --prune-unexpected                 # opt-in DELETE of rulesets this script did not create
  --prune-legacy-protection          # opt-in DELETE of classic branch protection (§ 2.1)
  --org spark-match                  # override the organization
  --json                             # machine-readable output
```

Both `--prune-*` flags are opt-in for the same reason: the reconciler does not
destroy rules it did not create unless asked to on the command line. Each backs
the payload up first, and skips the deletion if the backup fails.

### Quick audit

```bash
# Every declared repository, one line each:
./scripts/configure-repo-rulesets.sh --check
```

With no `--repos`, the reconciler walks every repository in the manifest. Do not
hardcode the list here — it was wrong within two weeks of being written, when
`.github` was declared on 2026-08-06.

## 11. Referencias

- **Manifest**: `governance/repository-governance.json` (schema v3).
- **Reconciler**: `scripts/configure-repo-rulesets.sh`.
- **Plan completo**: see `CHANGELOG.md` for the audit + migration timeline. (Original external workspace doc has been retired.)
- **Pilot**: ruleset 18893014 sobre `spark-match-01-devops`.
