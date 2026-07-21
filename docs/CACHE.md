# Cache key convention

This document explains the canonical cache key used by all node-consuming
reusable workflows in `spark-match/spark-match-01-devops@main`, as well
as the inline test job in `ahincho/orion-frontend/.github/workflows/ci.yml`.

## 1. The convention

Every cache key targeting npm / pnpm / yarn / bun dependencies follows:

```
<os>-node-<nodeVersion>-<pkgmanager>-<env>[-<recipeTag>]-<H>
```

| Segment        | Source                              | Example        |
|----------------|--------------------------------------|----------------|
| `os`           | `lowercase(runner.os)` (set by shell) | `linux`        |
| `nodeVersion`  | `inputs.node-version`                | `24`           |
| `pkgmanager`   | `inputs.pkg-manager`                 | `npm`          |
| `env`          | `lowercase(inputs.environment-name)` | `dev`          |
| `recipeTag`    | recipe-specific (e.g. `eslint10`)    | `eslint10`     |
| `H`            | `sha256(lockfile)` (single file)     | `42f24408b…`  |

`recipeTag` is optional. Today only `eslint.yml` uses it (to invalidate the
cache when ESLint major is bumped without affecting other recipes in the
same env). All other recipes omit it.

### Examples

- Dev local deploy of an Angular SPA:
  `linux-node24-npm-dev-42f24408bd87f5097500676766b18b6738302fcdcc75650e1b817d948a6b0b95`
- Prod deploy (when added):
  `linux-node24-npm-prod-<H>` ← isolated from dev by the `env` segment
- ESLint v10 on dev:
  `linux-node24-npm-eslint10-dev-<H>`
- After rolling back to ESLint v9:
  `linux-node24-npm-eslint9-dev-<H>` ← isolated by `eslint<rev>`
- Windows runner:
  `windows-node24-npm-dev-<H>`
- pnpm consumer:
  `linux-node22-pnpm-dev-<H>`

## 2. Why this convention

### 2.1 `os` lowercased

`runner.os` exposes values `Linux`, `Windows`, `macOS`. Lowercasing keeps
keys consistent so `linux-node24-...` and `Linux-node24-...` do NOT
produce two separate cache blobs for the same content.

Lowercasing is done in a shell step because GH Actions expressions have
no `lower()` function (only `always`, `cancelled`, `contains`, `endswith`,
`failure`, `format`, `fromjson`, `hashfiles`, `join`, `startswith`,
`success`, `tojson`).

### 2.2 `pkgmanager` explicit

Without an explicit `pkgmanager` segment, two repos in the same monorepo
(one npm, one pnpm) would share `~/.npm` cache blobs even though the
content of `package-lock.json` differs. Including `pkgmanager` makes the
cache scope unambiguous.

### 2.3 `env` mandatory

`env` segments the cache per GitHub Environment (dev / prod / ci). This
prevents a `dev` deployment that uses `--omit=dev` (prod-style tree
shaking) from poisoning the `prod` cache, and vice versa. It also matches
the GH Environment that the workflow targets, which is the natural
review boundary.

### 2.4 Single lockfile hash, not glob

`hashFiles(format('{0}/{1}', working-directory, lockfile-name))` is
narrowed to one specific lockfile (`package-lock.json`, `pnpm-lock.yaml`,
etc.). Glob patterns like `**/package-lock.json` would invalidate the
cache every time a nested workspace added or removed a lockfile, even if
the user's own lockfile is untouched.

### 2.5 `setup-node@v7`'s built-in cache is disabled

`actions/setup-node@v7` (released v4+) auto-creates a cache when:
- the `packageManager` field is set in `package.json`, AND
- a lockfile is present at the cwd, AND
- `package-manager-cache` is not explicitly set to `false`.

The auto-created key uses format `node-cache-<os>-<arch>-<pkgmgr>-<H>`,
which:
- does not include `env` (collides dev ↔ prod),
- does not include `nodeVersion` (collides node-upgrades),
- cannot be customized to inject our `environment-name`.

Reusable workflows therefore set `package-manager-cache: false` on
`setup-node@v7` and manage the cache in a dedicated `actions/cache@v6`
step with the canonical key.

## 3. How to extend the convention

If you need a new layer (e.g. Python via `uv`, Python via `pip`), reuse
the same skeleton:

```
<os>-<runtime>-<runtimeVersion>-<pkgmanager>-<env>[-<recipeTag>]-<H>
```

Just keep the segment order stable and always end with `<H>` (the
content hash). New recipes that depart from the convention need a
documented rationale in `docs/CACHE.md`.

## 4. Cache restore strategy (`restore-keys`)

Every cache step declares a single `restore-keys` prefix that matches
the primary key minus the `<H>` hash:

```
${{ env.lower_os }}-node${{ inputs.node-version }}-${{ inputs.pkg-manager }}-${{ env.env_name }}-
```

This means: if the exact key is missing (e.g. new env added without a
prior cache), the recipe will fall back to ANY cache from the same
runner-os/node-version/pkgmanager/env combination. That fallback is
better than nothing but is expected to be slower (full install on top of
a partially-matching cache). Plan accordingly.

## 5. Manual cache inspection

The cache backend is opaque, so debugging is limited. Useful angles:

- The cache key is logged at the start of every `actions/cache@v6` step.
  Search the run log for `Cache hit for:` or `Cache restored from key:`.
- If you see `Cache not found` followed by `Cache size: ~X MB`, the
  primary key was missing AND no fallback matched → fresh install.
- If you see `Cache hit occurred on the primary key X, not saving cache`,
  the existing entry was reused (no upload) → fast path.
- Retention is 7 days by default; orphaned entries (e.g. after a
  breaking key refactor) are GC'd automatically.

## 6. Migration notes (v3 → v4)

PR #62 in `spark-match-01-devops` was the v3 → v4 transition. Cache keys
became strictly lowercase, included `pkgmanager`, and the `<H>` was
narrowed to a single file. Existing v3 entries are orphaned and will be
GC'd by the 7-day retention. No consumer (other than `orion-frontend`
which exercises both recipes daily) was affected; the consumer PR is
`ahincho/orion-frontend#13`.

## 7. Inline test job (orion-frontend/ci.yml)

The `unit tests` job in `orion-frontend/.github/workflows/ci.yml` follows
the same convention with the key hardcoded for clarity:

```yaml
key: linux-node24-npm-ci-${{ hashFiles('package-lock.json') }}
restore-keys: |
  linux-node24-npm-ci-
```

Switching to the new `node-test.yml` reusable workflow (PR #65 + consumer
PR #15) makes this exact same key dynamic from the recipe, so future
node-version bumps automatically re-key.
