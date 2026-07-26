# node-ci

Demonstrates a minimal caller for the Node pipeline: `eslint.yml` ->
`node-test.yml` -> `node-build.yml`. Adds `gitleaks.yml` as a parallel
secret scan. This is the canonical pipeline for an Angular / Vite /
Next.js / NestJS frontend or backend.

## What this example covers

- 4 reusables in a layered DAG: `lint -> test -> build` with
  `gitleaks` running in parallel to all of them.
- `needs:` declared so jobs run in order; cancel-in-progress keeps
  fast feedback.
- `node-version: '24'` set explicitly (current LTS at time of
  writing); the recipe defaults to `24` too, but pinning in the
  caller is defensive against future default changes.
- `permissions: contents: read` minimum scope.

## What you must change to make it yours

1. **`working-directory`** if `package.json` is not at the repo root
   (e.g. monorepo).
2. **`lint-script`, `test-script`, `build-script`** to match your
   `package.json` names (defaults: `lint`, `test`, `build`).
3. **`pkg-manager`** if you use pnpm / yarn / bun instead of npm.
4. **`pre-test-script`** if your test runner needs a precompile step
   (Angular's `prebuild` hook is a common case).
5. **`eslint-version`** if you pin a major that is not 10.

## Required secrets

`GITLEAKS_LICENSE` (org-level Dependabot secret bucket — typically
already configured in `spark-match`). The recipe reads it via
`secrets: inherit`; for cross-owner callers pass it explicitly:

```yaml
secrets:
  GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

If you fork the catalog and run these recipes from a different org,
you MUST pass the secret explicitly because GitHub drops `secrets:
inherit` across owners.

## Permissions matrix

This caller workflow grants only `contents: read`. The four recipes it
calls do not request additional permissions.

## Expected run time

- `eslint`: ~1 min (cached npm store; depends on lockfile size)
- `gitleaks`: ~30 s (parallel)
- `node-test`: ~1-2 min
- `node-build`: ~1-3 min (Angular builds take longer)

Total wall time with parallelism: ~2-3 min on a typical Angular SPA.

## Where to look in this repo

- `README.md` § Catalog → node — recipe descriptions.
- `docs/CACHE.md` — cache key convention v4 (all node recipes use the
  same key shape).
