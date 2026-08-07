# AGENTS.md — guide for AI agents working on `spark-match-01-devops`

> For AI agents (OpenCode, GitHub Copilot, Claude Code and the like) operating on this repository. It reflects the conventions actually observed in the repo and the workflow currently in force.

## 1. Purpose and structure of the repository

`spark-match-01-devops` is the **single catalog** of shared CI/CD for the `spark-match` organization. It contains no application code — no Node, Python, Terraform or SAM of its own. Its entire surface is declarative pipeline infrastructure (reusable workflows and composite actions) plus governance (the organization ruleset and the reconciliation scripts).

### 1.1 Structure

- `.github/workflows/`: reusable workflows (`workflow_call`). The `reusable-` prefix means consumable; no prefix means internal CI for this repo.
- `.github/actions/`: composite actions (atomic primitives), consumed by the reusables or by external repositories.
- `.github/ISSUE_TEMPLATE/`: bug, feature and docs issue templates.
- `.github/dependabot.yml`: weekly bump pull requests for GitHub Actions.
- `.github/CODEOWNERS`: a catch-all floor first, then explicit paths that override it (see `docs/GOVERNANCE-STANDARD.md` § 3).
- `.github/release-please-config.json`: Conventional Commits to section mapping for the release pull request.
- `.github/PULL_REQUEST_TEMPLATE.md`: checklist covering the 11 Conventional Commit types.
- `docs/`: design conventions (cache-key, governance standard, versioning).
- `scripts/`: idempotent operations that apply governance to the organization through the GitHub API (`gh`).
- `governance/`: desired state of the organization ruleset (JSON manifest plus JSON Schema).
- `tests/`: bats tests per subject. Shared helpers under `tests/bats/helpers/`.

### 1.2 Naming conventions

- **Reusable workflows**: the `reusable-` prefix is mandatory. The name encapsulates the technology (terraform, node, sonar, and so on) plus the responsibility (plan, apply, build, test).
- **Composite actions**: one folder per action under `.github/actions/<name>/`, with an `action.yml` and optionally an executable `*.sh`.
- **Scripts**: kebab-case, executable, shebang `#!/usr/bin/env bash` plus `set -euo pipefail`.
- **Tests**: one bats file per subject, under `tests/bats/<subject>.bats`.

### 1.3 Consumption model

- **Reusables**: consumed from `spark-match/*` repositories via `uses: spark-match/spark-match-01-devops/.github/workflows/reusable-<name>.yml@main`.
- **Composite actions**: consumed by the reusables (same repo, path `./.github/actions/<name>`) or by external repositories (`@main`).
- **Governance**: applied to the organization via `scripts/configure-repo-rulesets.sh`. Never applied by hand through the GitHub UI.

## 2. Branch model — a single `main`

- **Single-branch, single-purpose.** Every pull request targets `main` directly. There is no `dev` branch in this repository.
- **Branch straight off `main`**, named with a Conventional Commits scope:
  ```bash
  git checkout main
  git pull --ff-only
  git checkout -b chore/<scope>-<short-desc>
  ```
- **The branch name must reflect the type plus scope**:
  - `feat/composite-action-add`, `fix/quality-cache-key`
  - `chore(workflows): ...` → `chore/remove-stale-shared-reusables`
  - `docs(readme): ...` → `docs/clarify-cache-section`
- **Branches are deleted on merge** (`delete_branch_on_merge=true` in the ruleset). Clean up local and remote afterwards:
  ```bash
  git checkout main
  git pull --ff-only
  git branch -D <branch>
  git fetch --prune
  ```

## 3. Commit convention — Conventional Commits 1.0.0

```bash
git commit -m "chore(workflows): remove 6 stale reusables (zero consumers)"
```

Scopes used in this repository:

| Scope | Applies to |
|---|---|
| `composite` | composite actions |
| `workflows` | reusable workflows |
| `ecosystem` / `node` / `python` / `deploy` / `frontend` | workflows by layer |
| `governance` | manifest, schema, ruleset scripts |
| `scripts` | bash scripts |
| `docs` | README, `docs/`, CONTRIBUTING |
| `ci` | `.github/workflows/` (this repo's own CI) |
| `quality` | bats / shellcheck / schema infrastructure |
| `reconciler` | reconciler tests |
| `repo` | structural changes to the repo (not the catalog) |
| `deps` | dependabot bumps (automated pull requests) |

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `revert`. `perf` and `revert` were added to the base set, inherited from `@commitlint/config-conventional`.

`.commitlintrc.json` is the authoritative list, and the pre-commit hook enforces
it locally before CI does. Two rules bite often enough to be worth naming: the
scope must come from the table above — `readme` is not a scope, `repo` is — and
the subject must be lowercase, which a filename like `VERSIONING.md` in the
subject line will violate.

## 4. Pull Request workflow

### 4.1 Push and open the pull request

```bash
git push -u origin <branch>
gh pr create \
  --base main \
  --head <branch> \
  --title "chore(workflows): remove 6 stale reusables (zero consumers in spark-match org)" \
  --body-file <body-file>
```

### 4.2 Pull request body — suggested template

```markdown
## Summary
[1-3 sentences describing the change]

### Deleted / Added / Modified
| File | Change |
|------|--------|
| `path/to/file` | one-line description |

### Docs cleanup (if applicable)
- `README.md`: ...
- `docs/VERSIONING.md`: ...

### Impact
[Net diff plus effect on the catalog: "Catalog: 38 → 33 workflows", and so on]
```

### 4.3 Required checks — all must pass

Checks run on every pull request via `.github/workflows/ci.yml` and
`codeql-actions.yml`. `gh pr checks <num>` is the authoritative list; what each
one validates:

| Check | What it validates |
|---|---|
| `actionlint` | Actions YAML syntax |
| `gitleaks` | secret scan |
| `yamllint` | non-workflow YAML formatting |
| `quality / bats` | bats tests under `tests/bats/` |
| `quality / manifest schema` | `governance/repository-governance.json` against its schema |
| `quality / shellcheck` | bash scripts under `scripts/` and `.github/actions/` |
| `commitlint` | commit convention. The job name is identical on the pull request and on the push to main — the context is `lint-commits / commitlint` in both, and that is what the ruleset requires |
| `codeql-actions` | vulnerabilities in Actions YAML |
| `Code scanning` | aggregated CodeQL results over Actions |

If a check fails, **fix the code** before asking for review. Do not click
`Resolve conversation`, and do not reach for `--admin`, to get past a red check.

### 4.4 Merge — squash plus admin bypass (authorized by the organization owner)

CODEOWNERS reviewers are often unavailable. Once CI is green:

**For accounts with `admin:org` scope (ordinary users):**

```bash
gh pr merge <num> --repo spark-match/spark-match-01-devops \
  --squash --admin --delete-branch \
  --subject "chore(scope): lowercase subject that passes commitlint" \
  --body "All checks green. [summary]. Merged via admin bypass."
```

> **Pass `--subject` explicitly, always.** A squash merge uses the pull request
> **title** as the commit subject, while the pull-request-side commitlint check
> lints the *branch* commits. A title that violates the convention therefore
> passes on the pull request and fails afterwards, on the push to main, when
> there is nothing left to do: the branch is protected against force-push and
> the bad subject is on main permanently. This happened on 2026-08-05 with
> `fix(bootstrap):`, an invalid scope.
>
> The body has the same trap through a different rule: `footer-max-line-length`
> is 100, so a long unwrapped line in the merge body fails the same way. That
> one happened on 2026-08-07.

**For Enterprise Managed User (EMU) accounts:**

`gh pr merge --admin` fails with `GraphQL: Unauthorized: As an Enterprise
Managed User, you cannot access this content (mergePullRequest)`. The workaround
goes straight to the REST API with the token from `gh auth token`, using native
PowerShell and no `--admin`:

```powershell
$token = (gh auth token).Trim()
$sha = (gh pr view <num> --repo spark-match/spark-match-01-devops --json headRefOid -q .headRefOid)
$msg = Get-Content C:\path\to\merge-msg.txt -Raw  # multi-line, each line <=100 chars
$payload = @"
{"merge_method":"squash","commit_message":$(($msg | ConvertTo-Json -Compress)),"sha":"$sha"}
"@
Invoke-WebRequest -Uri "https://api.github.com/repos/spark-match/spark-match-01-devops/pulls/<num>/merge" `
  -Method PUT `
  -Headers @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json"; User-Agent = "opencode" } `
  -Body $payload -ContentType "application/json" -UseBasicParsing
```

> **The critical REST API merge pitfall**: when the `PUT` body carries only
> `commit_message`, GitHub uses the **pull request title as the merge commit's
> `commit_title`**. The pull-request-side commitlint check
> (`lint-commits / commitlint`) validates only the git commit messages on the
> branch, **not the title**. So a title with `camelCase` (`statusChecks`, say)
> or breaking any other rule is inherited by the squash commit and fails
> `lint-commits / commitlint` on the push to main. The check on the pull request
> passed; the one after the merge failed.
>
> **The fix**: send `commit_title` **and** `commit_message` separately.
> `commit_title` explicitly lowercase, `commit_message` multi-line. Both fields
> in the same JSON payload:
>
> ```powershell
> $payload = '{"merge_method":"squash","commit_title":"fix(scope): subject (#NN)","commit_message":"\n\nBody line 1.\nBody line 2.","sha":"' + $sha + '"}'
> ```
>
> Sending both fields is the **only** real defence. PR #276 added
> `lint-commits / commitlint-main` as a required status check believing it
> covered this, but a required status check is evaluated against the pull
> request's head SHA and decides whether the merge may happen: a check that only
> runs *after* the merge cannot gate *the* merge. Worse, that context never
> appeared on a pull request at all — the job carried the branch name in its own
> name — so it left every pull request hanging and forced `--admin`. Removed on
> 2026-08-06.
>
> The post-merge run still exists and still turns `main` red on a bad subject.
> It warns; it does not prevent.

> **Active line-length rules** (`.commitlintrc.json` plus the defaults inherited
> from `@commitlint/config-conventional`):
>
> | Rule | Limit | Applies to | State |
> |---|---|---|---|
> | `header-max-length` | 100 chars | Subject (`type(scope)!: subject`) | Active (`[2, always, 100]`) |
> | `body-max-line-length` | — | Body | **Disabled** (`[0]` in `.commitlintrc.json`) |
> | `footer-max-line-length` | 100 chars | Footer | Active (inherited default) |
>
> **What that means in practice**: commitlint's parser (`@commitlint/parse` plus
> `conventional-commits-parser`) classifies post-header content as body or
> footer opportunistically. A long line that passes as body in one run can be
> classified as footer in another and trip `footer-max-line-length`.
>
> **Keep every line of the commit message at 100 characters or fewer.**
> `body-max-line-length` is disabled here deliberately, because we want freedom
> in the body — but the parser gives no guarantee that post-header content is
> treated as body on every run. This is not theoretical: a merge body with one
> unwrapped line failed exactly this way on 2026-08-07, after the subject had
> been passed correctly.

**Examples of valid messages** (every line ≤100 chars; separate with a literal `\n` in JSON, or with real lines in a file):

```
fix(quality): allow x.y.z major >=1 in release-please manifest bats regex

Required for release-please to cut 1.x.y release PRs.
Test now accepts both 0.x.y and 1.x.y patterns.
```

```
feat!: refresh agents.md for v1.0.0 release

Documents REST API workaround for EMU accounts.
Adds commitlint line-limit rules reference.

BREAKING CHANGE: AGENTS.md v1 contract.
```

**Practical rule for merges via the REST API**: write the message into a plain
text file (every line ≤100 chars) and read it with `Get-Content -Raw`. Never
concatenate strings with `+`, because PowerShell tokenises `"..."` containing
special characters unpredictably. The same applies to `gh pr create --body "..."`
— always use `--body-file` (see § 4.1).

`--admin` is authorized **only** after confirming CI is green. Never use it to skip a failing check.

### 4.5 Squash-merge REST API checklist (EMU workaround)

To avoid the pitfall documented in § 4.4 (pull request title becoming the commit subject), run this checklist **before** the `PUT`:

```powershell
# 1. Validate the PR title against the rules commitlint will apply
$title = gh pr view <N> --repo <owner>/<repo> --json title -q .title
if ($title -cmatch '[A-Z]') { Write-Error "title has uppercase (commitlint subject-case)"; exit 1 }
if ($title.Length -gt 100) { Write-Error "title >100 chars (commitlint header-max-length)"; exit 1 }
if ($title -match '\(#\d+\)\s*$') { Write-Error "title has trailing (#NN); commitlint rejects it in the subject"; exit 1 }

# 2. Build the payload with commit_title AND commit_message SEPARATE
$sha = (gh pr view <N> --repo <owner>/<repo> --json headRefOid -q .headRefOid)
$msg = Get-Content C:\path\to\merge-msg.txt -Raw   # multi-line, each line <=100 chars
$payload = @"
{"merge_method":"squash","commit_title":"$title","commit_message":$(($msg | ConvertTo-Json -Compress)),"sha":"$sha"}
"@

# 3. PUT
Invoke-WebRequest -Uri "https://api.github.com/repos/<owner>/<repo>/pulls/<N>/merge" `
  -Method PUT `
  -Headers @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json"; User-Agent = "opencode"; "X-GitHub-Api-Version" = "2022-11-28" } `
  -Body $payload -ContentType "application/json" -UseBasicParsing
```

**Specific mistakes to avoid**:

| Failure | Symptom | Fix |
|---|---|---|
| `commit_message` alone, without `commit_title` | The merge commit subject becomes the PR title. If that title has `camelCase`, `commitlint` fails on the push to main — it warns, after the merge has already happened | Send `commit_title` and `commit_message` separately |
| PR title ending in `(#NN)` | The inherited subject ends with `(#NN)`, which trips the character limit described in § 4.4 | Put `(#NN)` in `commit_title` only, never in `commit_message` |
| `commit_message` as one long line (>100 chars) | Fails `header-max-length` or `footer-max-line-length` | Split into several lines, each ≤100 chars |
| `git commit -m` with concatenated strings (`+`) | PowerShell tokenises `"..."` containing special characters unpredictably | Use `Get-Content -Raw` from a file |

**Mandatory pre-flight for squash-merging a release-please pull request** (#275, #277, #281 and the like): the title is `release X.Y.Z`, which passes every check and needs no editing. The `commit_message` still has to be multi-line, not one concatenated 200-character line.

## 5. Style conventions

### 5.1 General

- **No decorative emojis**: never as visual ornament in code, commits, pull request messages or documentation. The symbols used as bullet markers in section 10 are structural indicators and are allowed.
- **Code in English**: variables, functions, classes, files and every other source identifier. Commit messages (Conventional Commits) too.
- **Documentation in English.** This reversed on 2026-08-07; the rule here used to require Spanish. `AGENTS.md`, `docs/VERSIONING.md` and `docs/GOVERNANCE-STANDARD.md` were translated that day. The other repositories still document in Spanish and will follow later, so expect the organization to be mixed for a while — this is a migration in progress, not an inconsistency to "fix" by translating a repository nobody asked for.
- **Mind the special characters**: where Spanish text remains, `ñ` and accented vowels must be correctly encoded as UTF-8, or they turn into mojibake in the Windows PowerShell 5.1 console.
- **Do NOT add comments unless explicitly asked.** The repo follows the self-documenting-code rule.
- **Mimic existing patterns** before inventing new ones. If an existing workflow uses `permissions: contents: read`, the new one does too.
- **Do not introduce new dependencies** without justifying them in the pull request body.
- **Pin by version or branch, NOT by SHA.** For third-party actions use `@vN` (floating major, `actions/checkout@v4`) when the action publishes `v`-prefixed tags. When it does not — `ludeeus/action-shellcheck` only has `2.0.0` — use the exact version `@N.N.N`. Documented exceptions:
  - **Self-actions** (our own composite actions): always `@main`.
  - **anchore/sbom-action**: pinned to `@v0.24.0` (minor pinned) because the 0.x line carries breaking changes between minors.
- The guard against SHA-pinning lives in `tests/bats/no-sha-pinning.bats` (3 cases: third-party, self, and this policy text). If it fails, the pull request is blocked.
- **Naming convention — kebab-case is mandatory** for identifiers, except secrets and OS environment variables, which use `SNAKE_CASE`:
  - **`kebab-case`** for:
    - **Job IDs** (`jobs: <id>:`) and filenames (`reusable-<name>.yml`).
    - **Step IDs** (`- id: <id>`).
    - **Inputs** of `workflow_call` or a composite action (`inputs.<name>:`, `with: <name>: value`).
    - **Outputs** (`outputs.<name>:`).
    - **Display names** of workflow, job and step (`name: <name>`). `${{ inputs.x }}` templates are joined with `-`, no spaces.
    - **Referencias a marcas/herramientas** dentro de `name:`, comentarios, descripciones de inputs y mensajes `::error::`. Marcas y herramientas van en kebab:
      - `SonarCloud` -> `sonar-cloud`
      - `CodeQL` -> `codeql`
      - `LaTeX` -> `latex`
      - `ESLint` -> `eslint`
      - `TFLint` -> `tflint`
      - `SBOM` -> `sbom`
      - `CycloneDX` -> `cyclonedx`, except where it is a literal JSON schema value (`bomFormat == CycloneDX`)
      - `Terraform` -> `terraform` (lowercase, one word)
  - **`SNAKE_CASE`** (uppercase with underscores) for:
    - **Secrets** (`secrets.SOME_SECRET`, `secrets.GITLEAKS_LICENSE`, `secrets.AWS_PLAN_ROLE_ARN`). Inherited from the environment: the env vars GitHub Actions exposes for secrets follow the POSIX uppercase convention.
    - **Env vars passed to the OS** inside `env:` blocks (`env: SBOM_DIR: ...`). POSIX convention: env vars exported to the OS use `UPPER_SNAKE_CASE`.
  - **`kebab-case` — the exception for workflow-level env vars**: when exporting an env var to the workflow runtime with `echo "key=value" >> "$GITHUB_ENV"`, typically from a bash step inside `run:`, the variable name is lowercase kebab-case, matching the YAML identifiers. This covers `lower-os`, `env-name`, `cache-path`, `pkg-install-cmd` and `pkg-run-cmd`, read later via `${{ env.lower-os }}`. The reason is consistency with the step that creates them and readability inside `${{ }}` expressions. No uppercase, no underscores, no mixing styles here.
  - **Deliberate exceptions** (not kebab):
    - External URLs: `https://sonarcloud.io`, `https://github.com/anchore/sbom-action` — do not break links.
    - Third-party action names: `actions/checkout`, `anchore/sbom-action`, `github/codeql-action` — do not break marketplace refs.
    - GitHub event names: `pull_request`, `push`, `workflow_call`, `workflow_dispatch`, `release`, `schedule` — reserved schema words.
    - **Literal schema values**: `CycloneDX` as the JSON value of `bomFormat`, `cyclonedx-json` as the `format:` value in anchore/sbom-action — keep the contract with the external schema.
  - **Transition rules**:
    - A previous `name:` in Title Case (`"Compile LaTeX document"`) becomes `compile-latex-document`.
    - Embedded templates: `"name": "eslint-${{ inputs.environment-name }}"` — hyphen, not space.
    - For a parenthesised description like `(OIDC, plan role)`, kebab-case the contents and join with hyphens: `configure-aws-credentials-oidc-plan-role`.

### 5.2 How to add a new reusable workflow

> Pattern established in PR #254 (Tier 3) and first applied in
> `spark-match-02-infrastructure` (PRs #104 and #105).
>
> **Cross-repo pin**: the rule in force is `@main`, per `docs/VERSIONING.md`
> (single-main-branch model, decided 2026-07). The `vX.Y.Z` tags exist for
> release-please traceability but are NOT the required pin for internal
> callers. This sub-section historically recommended `@vX.Y.Z`; that guidance
> is superseded and the current contract is `@main`. See item 8 below.

A reusable workflow (`on: workflow_call`) encapsulates logic shared across
repositories. To add one:

1. **Create the file** at `.github/workflows/reusable-<name>.yml` (`reusable-`
   prefix plus kebab-case, see § 5.1).
2. **Inputs versus secrets**:
   - `workflow_call.inputs` for non-sensitive values (paths, flags, toggles).
   - `workflow_call.secrets` for credentials (App IDs, tokens).
   - Both need a `description`, a `default` when optional, and an explicit
     `required`.
3. **No dynamic secret lookup**: `${{ secrets[inputs.foo] }}` is forbidden by
   GitHub Actions (PR #256). Declare `workflow_call.secrets` and forward them
   from the caller.
4. **Do not define `concurrency`**: GitHub Actions rejects a reusable workflow
   that declares its own concurrency block (PR #255). The caller owns it.
5. **Minimum permissions**: `contents: read` by default. Escalate to `write`
   only when creating branches, tags or releases. Remember that a reusable
   cannot escalate beyond what the caller grants — if the caller gives less
   than the reusable declares, GitHub aborts the whole run as
   `startup_failure`, with no logs and no published check context.
6. **Dogfooding is mandatory**: an internal caller in 01-devops
   (`commitlint.yml`, `release-please.yml`) must consume the reusable via
   `uses: ./.github/workflows/...`. That validates its shape against the bats
   suite BEFORE it is exposed cross-repo.
7. **Bats tests**: add them to `tests/bats/reusable-ci-workflows.bats`, or a new
   file per domain. Cover:
   - `workflow_call` declared.
   - Every input has an explicit `type`.
   - Every action pinned to its major (`@vN`, never a SHA).
   - The internal caller consumes the reusable.
   - The internal caller does NOT duplicate the reusable's steps.
   - The reusable does NOT define `concurrency`.
   - The internal caller DOES define `concurrency`.
   - For reusables taking secrets: the caller forwards them via a `secrets:`
     block, and the reusable consumes them via `${{ secrets.<name> }}`.
8. **Cross-repo pin**: `uses: spark-match/spark-match-01-devops/.github/workflows/reusable-<name>.yml@main`,
   per `docs/VERSIONING.md` (single-main-branch model, decided 2026-07). The
   `vX.Y.Z` tags exist for release-please traceability but are NOT the required
   pin for internal callers. If spark-match ever wants to offer stable versions
   to third-party repositories, that would go through a dedicated release
   process — see `docs/VERSIONING.md` § "When SemVer would be justified".
9. **Document it in the README catalog.** `tests/bats/readme-fidelity.bats`
   enforces the correspondence in both directions, so a reusable that is not
   documented will fail the build, and a documented one that no longer exists
   will too.

**Anti-patterns**:

- `uses: ./...` cross-repo — it only works same-repo, and fails at runtime.
- Inputs that change canonical paths; hardcode those instead.
- `permissions: write` by default.
- Reusing legacy input names that imply dynamic secret lookup.
- Skipping the dogfooding step, so no internal caller consumes the reusable.
- Publishing a reusable with no bats tests.

**Reference**: PR #254 introduced the pattern, with bugs fixed in #255 and #256.
PRs #104 and #105 in `spark-match-02-infrastructure` were the first cross-repo
consumers.

### 5.3 Reusable workflows

- **Top-level only** in `.github/workflows/`. Subfolders break `uses: ./...` — a GitHub Actions limitation.
- Every workflow exposes an `environment-name` input, even when it is only informational.
- Inputs go in `workflow_call.inputs` with `description`, `type`, `required` and `default`.
- For deploy workflows: gate via a GitHub Environment plus an `AWS_DEPLOY_ROLE_ARN` secret, or its equivalent. The calling repository defines the Environment.
- **Cross-owner secrets**: pass them explicitly through a `secrets:` block in the calling repository. GitHub blocks `secrets: inherit` across different owners.
- **Env-isolate** any `${{ inputs.* }}` used inside a `run:` block — this is the CodeQL guard against code injection:
  ```yaml
  env:
    INPUTS_FOO: ${{ inputs.foo }}
  run: |
    echo "${INPUTS_FOO}"
  ```
- **Job names must be static.** A required status check is identified by its
  name, so a `name:` containing an expression — the branch, the actor, the SHA —
  publishes a different context on every run, and the ruleset waits forever for
  one that never arrives. This is not hypothetical: `commitlint-${{ ... }}` left
  every pull request stuck on "Expected — waiting for status to be reported"
  until it was made static on 2026-08-06. `tests/bats/reconciler-status-checks.bats`
  guards it.

### 5.4 Composite actions

- `.github/actions/<name>/action.yml`, one directory per action.
- No runtime dependencies beyond GitHub's official actions.

### 5.5 Scripts

- Shebang `#!/usr/bin/env bash` plus `set -euo pipefail` at the top.
- Every script documents its usage in a header, with examples.
- `--dry-run` wherever possible; every idempotent script must support it.
- Cover with bats tests when the logic is non-trivial.

### 5.6 Tests

- bats tests under `tests/bats/<subject>.bats`, discovered automatically via `tests/bats/*.bats` (see `quality.yml`).
- Shared helpers in `tests/bats/helpers/`.
- **Verify every guard in both directions.** Break the invariant on purpose and
  confirm the test fails, then restore it. A test only ever seen green proves
  nothing: on 2026-08-07 the guard forbidding a CODEOWNERS catch-all was found
  to match `^[[:space:]]+\*`, requiring whitespace before an asterisk that is
  always written at column 0. It had been passing against a file carrying
  exactly what it claimed to forbid.
- Commands:
  ```bash
  bats tests/bats/
  shellcheck scripts/*.sh .github/actions/*/action.sh
  ```

### 5.7 Pre-commit hook vs CI commitlint

The local `.githooks/commit-msg` hook and the CI commitlint are **not
identical**. The hook is an approximate proxy; CI is canonical. Knowing the
differences avoids two opposite mistakes: reaching for `--no-verify` when you
should not, and refusing to when you should.

| Case | Local pre-commit | CI commitlint | Action |
|---|---|---|---|
| `feat!:` (bang after type/scope) | **FAILS** (the regex does not support `!`) | OK | `--no-verify` is safe |
| `(#NN)` at the end of the subject | **FAILS** (not covered by the regex) | OK | `--no-verify` is safe |
| `camelCase` in the subject (`statusChecks`) | OK (does not check case) | **FAILS** (`subject-case`) | Do NOT use `--no-verify`; let CI catch it and fix it |
| Body or footer lines over 100 chars | OK (header-only check) | **FAILS** (`footer-max-line-length`) | Do NOT use `--no-verify`; fix the wrapping |
| Scope outside the enum | **FAILS** | **FAILS** | Do NOT use `--no-verify`; change the scope |
| `subject-empty` | **FAILS** | OK (`scope-empty: [0]`) | `--no-verify` is safe |
| Type outside the enum | **FAILS** | **FAILS** | Do NOT use `--no-verify`; change the type |

**The operating rule**:

- If pre-commit rejects because of the **bang `!`** or **`(#NN)`**: use `git commit --no-verify` with confidence. CI supports both and will pass.
- If pre-commit rejects for **any other reason**: do NOT use `--no-verify`. The hook and CI agree, and the commit is genuinely invalid. Fix it.
- If CI rejects while pre-commit passed: CI is canonical. Read the log — it is usually a length rule the hook does not check with the same precision.

**One-step workaround for bang and `(#NN)`**: `git commit --no-verify -F <message-file>` with a plain text file, every line ≤100 chars. The file avoids PowerShell's unpredictable tokenisation.

## 6. CODEOWNERS and paths

This repo uses **a catch-all `*` first, then explicit paths that override it**.
For any given file the last matching pattern wins, outright — GitHub does not
accumulate owners across patterns. The catch-all is a floor so that no path is
ever ownerless; the explicit lines are how ownership gets decided on purpose.
See `docs/GOVERNANCE-STANDARD.md` § 3 for the reasoning and how to reverse it.

> This section previously said the opposite, and gave GitHub's supposed
> accumulation as the reason. That was wrong on the facts, and the policy
> inverted on 2026-08-07.

**When you add a new path**: add it to CODEOWNERS in the same pull request. The
catch-all means the path is not left unowned, but it also means nobody
*decided* who owns it.

Current paths:

- `/README.md`, `/LICENSE`, `/SECURITY.md`, `/CONTRIBUTING.md`, `/CODE_OF_CONDUCT.md`, `/CHANGELOG.md`, `/AGENTS.md` → dual-owned (`@devops` + `@product-owners`)
- `/.github/`, `/scripts/`, `/governance/`, `/tests/`, `/.githooks/`, `/.commitlintrc.json`, `/.gitleaks.toml` → `@devops`
- `/docs/` → dual-owned
- `/.yamllint.yml`, `/.gitignore`, `/.shellcheckrc`, `/.release-please-manifest.json` → `@devops`
- everything else → `@devops`, via the catch-all

## 7. Governance — keeping `governance/` in sync

The organization ruleset lives in `governance/repository-governance.json` (the
declaration), `scripts/configure-repo-rulesets.sh` (the executor) and
`scripts/audit-codeowners-ruleset.sh` (the divergence detector).

When changing governed paths:

```bash
# After editing governance/repository-governance.json:
./scripts/configure-repo-rulesets.sh --check --repos spark-match-01-devops
./scripts/configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops
```

Never apply the manifest by hand through the GitHub UI — that creates
divergence.

> **The manifest is what the tool WRITES.** Declaring fewer `statusChecks` than
> a repository actually requires does not describe reality, it destroys it: the
> next `--apply` removes the difference. On 2026-08-07 this manifest declared 8
> checks for `spark-match-02-infrastructure` against 21 live, so running the
> tool as designed would have dropped thirteen gates. Derive the list from what
> pull requests actually publish (`gh pr checks <n>`), not from reading the
> workflow files.

## 8. Releases — release-please, automatically

`.github/workflows/release-please.yml` cuts a release pull request on every push
to `main`, based on the conventional commits. Merging it creates the git tag and
a GitHub release. The current version lives in `.release-please-manifest.json`.

**Never bump versions by hand.** The flow is:

1. Pull request with a conventional commit → merged to main
2. release-please opens a release pull request with the version bump and CHANGELOG
3. Merging that → tag plus GitHub release

## 9. Common troubleshooting

### `gitleaks` not installed locally
The `.githooks/pre-commit` hook skips with a warning. **CI still catches secrets** through the `gitleaks` job, so this never blocks a pull request.

### PowerShell versus bash
This dev environment runs PowerShell 5.1, but Git and bash commands work transparently. **To call `gh api` with a URL containing `?`**, use a variable:
```powershell
$url = "/repos/owner/repo/contents?ref=main"
gh api "$url"   # not: gh api "/repos/owner/repo/contents?ref=main"
```

### `gh pr checks` shows no checks
If the pull request was just created, wait 15-30s and retry. To see the runs:
```bash
gh api "/repos/spark-match/spark-match-01-devops/actions/runs?event=pull_request&per_page=10"
```

### `--admin` rejected by `gh pr merge`
Check that:
1. `gh auth status` shows the `admin:org` or `repo` scope, with the `ahincho` account active.
2. CI is genuinely green — every check `pass`, none `pending`.

### A required check that never reports
The pull request sits forever on "Expected — waiting for status to be reported",
and the only way out is `--admin`. Three causes, all seen in this organization:

- **The job name carries an expression**, so the published context differs on every run (§ 5.3).
- **A `paths:` filter can skip the workflow.** A check that does not run does not report, and a required context that never arrives blocks the merge permanently. Filter *inside* the job instead: a first step that decides whether there is work and exits green when there is none.
- **The context is required but the workflow was renamed or deleted.** `configure-repo-rulesets.sh --check` will not catch this; compare the ruleset against `gh pr checks <n>` on a real pull request.

## 10. What you must NOT do

- Create a `dev` branch or a long-lived feature branch.
- Write vague commit messages (`update`, `fix stuff`, `wip`).
- `--force` push to `main`, or to any shared branch.
- Edit `.github/CODEOWNERS` without adding the matching entry in the same pull request.
- Use `--admin` to get past red checks and merge with CI failing.
- Add new dependencies (`pip install`, `npm install`) without justification.
- Revert third-party action pins to 40-character SHAs. § 5.1 established `@vN`, `@N.N.N` or `@main` (PR #210).
- Move reusables into subfolders of `.github/workflows/` — it breaks `uses:`.
- **Silence a check instead of fixing what it found.** `--soft-fail`, `|| true`, `continue-on-error` and a bare skip all turn a gate into decoration, and the green they produce is indistinguishable from a real one. If a finding is genuinely acceptable, suppress that specific finding with the reason written next to the code.
- **Quote a count in prose.** Numbers of tests, workflows or compliant repositories have to be hand-synced with a tree that changes weekly, and they fail silently when they fall behind. Point at the command that computes them.

## 11. Current catalog

Do not transcribe an inventory here. The tree is the catalog:

```bash
ls .github/workflows/reusable-*.yml   # consumable recipes
ls .github/actions/                   # composite actions
```

`README.md` carries the documented catalog with a description per recipe, and
`tests/bats/readme-fidelity.bats` enforces the correspondence in both
directions — every reusable on disk is documented, and nothing documented is a
ghost.

A table used to sit here claiming "21 reusables", broken down by layer. There
were 27 on disk by the time anyone checked, and the list of active consumers
below it named branches that no longer existed. Neither error broke anything;
both misled whoever read the section to find out what was available.

**Cross-repo secrets** (organization level, `visibility=all`): `RELEASE_PLEASE_APP_ID`, `RELEASE_PLEASE_APP_PRIVATE_KEY`, `GITLEAKS_LICENSE` and `SONAR_TOKEN` live at the organization level to avoid duplicating them per consumer. A new repository adopting 01-devops reusables only needs the `spark-match-bot` GitHub App installed — no manual secret bootstrap.

**CodeQL exclusion**: `.github/codeql/codeql-config.yml` excludes `js/actions/unpinned-3rd-party-action` (legacy) and `actions/unpinned-tag` (active in `actions` mode). Both rules push toward the SHA-pinning this repo deliberately forbids (§ 5.1). `tests/bats/codeql-config.bats` guards against regression.

For a live inventory:

```bash
ls .github/workflows/reusable-*.yml
ls .github/actions/*/action.yml
ls scripts/*.sh
ls tests/bats/*.bats
```

## 12. Operational references

- [`README.md`](README.md) — overview plus the workflow catalog
- [`docs/VERSIONING.md`](docs/VERSIONING.md) — branch model plus per-repo consumer mapping
- [`docs/GOVERNANCE-STANDARD.md`](docs/GOVERNANCE-STANDARD.md) — ruleset and CODEOWNERS rationale
- [`docs/CACHE.md`](docs/CACHE.md) — the v4 cache-key convention
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — detailed local setup
- [`SECURITY.md`](SECURITY.md) — disclosure process and SLA
- [`scripts/README.md`](scripts/README.md) — flags for each script

---

## 13. Lessons learned (2026-08-04)

**Cosmetic problems do not justify a history rewrite.** The real defence is the
§ 4.5 checklist — send `commit_title` and `commit_message` separately. The
required check added in PR #276 never worked at all; see § 4.4. What follows is
the log of the 2026-08-04 rewrite, a one-off not to be repeated, and the lessons
worth keeping from it.

### 13.1 Log of the rewrite

`main` was rewritten with `git rebase -i aa52bf7`, five manual amends and a
force-push, to clean up four historical commits that violated `commitlint`
(three with a body over 100 chars, one with `statusChecks` in camelCase). The
§ 10 policy was overridden by explicit decision of the org owner. The
consequences:

- **Tags `v1.0.0`, `v1.0.1`, `v1.0.2`** re-created on the post-rewrite SHAs, and their GitHub releases re-created with SBOMs. The previous versions pointed at commits that no longer existed.
- **Archive branch `archive/pre-rewrite-2026-08-04`** preserves the pre-rewrite state on origin.
- **The ruleset was temporarily disabled** during the force-push (`enforcement: disabled`) and re-applied with `--apply` afterwards.
- **PR #279** (`release 2.0.0`), auto-generated by release-please, which read the force-push as new commits — closed as a duplicate.
- **PR #281** (`release 1.0.3`), auto-generated after the first legitimate post-rewrite push — merged normally with an SBOM.
- **`CHANGELOG.md`** still references old SHAs like `b1bbd59` and `20d4582`. Not regenerated in that cycle; still pending a cleanup pull request.

**Do not repeat this without explicit approval from the org owner.** The rewrite
cost an interactive rebase, an amend per commit, a force-push, re-tagging,
re-creating releases with SBOMs and re-applying the ruleset. A cosmetic
improvement in the UI does not justify that recurring effort.

### 13.2 The reusable lessons — what is actually worth remembering

**1. Status check name mismatch** (the original cause of PRs #273 and #274): the
manifest carried names that did not match what the workflows report. Before
merging a manifest change, validate against a real pull request with
`gh pr checks <n>` — not by reading the workflow files. `reconciler-status-checks.bats`
locks the real names so the next agent cannot overwrite them with placeholders.

**2. The REST API merge pitfall**: documented in § 4.4 and § 4.5. ALWAYS send
`commit_title` and `commit_message` separately in `PUT /pulls/N/merge`. Send only
`commit_message` and GitHub uses the pull request title as the commit subject,
inheriting any `camelCase`. PR #276 tried to make this fail-closed with a
required check, but it was unreachable that way (§ 4.4): the checklist is the
defence.

**3. Pre-commit hook versus CI commitlint**: the hook is an approximate proxy.
Documented in § 5.7. If it rejects on the **bang `!`** or **`(#NN)`**,
`--no-verify` is safe. Any other reason: do not use it, the commit is genuinely
invalid.

**4. Release-please after a rebase**: following a force-push, release-please
reads the new SHAs as new commits and can auto-cut an incorrect release pull
request — PR #279 is the example. The diff between the last tag and HEAD is
empty, but release-please uses `git log`, which sees every SHA. Mitigation: keep
the manifest current BEFORE the rewrite, or close the auto-cut pull request
immediately.

**5. A post-rewrite CHANGELOG keeps dead SHAs**: the `https://github.com/.../commit/<SHA>`
links point at commits that no longer exist. Pending cleanup: regenerate the
CHANGELOG, or accept the broken links.

**6. A green check is not evidence until you know what it measures.** Four cases
in this organization, all found on 2026-08-07, all fail-open:

- checkov ran with `--soft-fail`, `|| true` and `continue-on-error` — 262 of 262 green across twenty pull requests, and its green meant "the job finished", not "no findings";
- `paths:` filters meant 57 of 161 files triggered none of the 20 required contexts;
- the guard forbidding a CODEOWNERS catch-all matched `^[[:space:]]+\*` and could never fire on a real one;
- a CloudFront `minimum_protocol_version` that AWS silently ignores, so the config claimed TLS 1.2 while the distribution accepted TLSv1.

The shared shape: the signal was looking somewhere other than where the risk
was. When adding a check, break the thing it watches on purpose and confirm it
goes red.

### 13.3 Defence in depth already implemented

| Defence | Origin | What it blocks |
|---|---|---|
| REST API merge checklist (§ 4.5) | PR #276 — the required check it added was withdrawn on 2026-08-06 | a squash merge landing a bad subject on main |
| `reconciler-status-checks.bats` | PR #274 | governance regression: a manifest with placeholder names |
| § 4.4, the REST API pitfall | PR #278 | the next agent not knowing about it |
| § 5.7, pre-commit versus CI table | PR #282 | `--no-verify` used where it should not be |
| § 13, this section | PR #282 | cycling through the same mistakes |
| `readme-fidelity.bats` | 2026-08-07 | the catalog drifting from the tree |

**Further defences worth having** (not implemented, low priority):

- The local pre-commit hook could validate `commit_title` before a pull request is pushed, not just the local commit message.
- `release-please.yml` could use `release-type: simple` to avoid incorrect bumps in force-push scenarios.

---

**Maintained by**: opencode and the `spark-match` org owner. Last reviewed: 2026-08-07.