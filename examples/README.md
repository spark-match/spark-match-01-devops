# Examples

Realistic caller-side examples for every layer of the catalog. Each
subdirectory is a self-contained mini-repo that demonstrates one or more
reusables in a sensible configuration. Copy the parts you need into
your own repo and adapt.

## What lives here

| Directory | Demonstrates |
|---|---|
| [`caller-minimal/`](caller-minimal/) | Index of minimal caller examples for the 4 most common layers |

## Out of scope

| What | Where it lives |
|---|---|
| Full caller repos under `spark-match-03-backend`, `spark-match-04-frontend`, etc. | Those repos themselves. See each repo's `.github/workflows/ci.yml` for a real-world invocation. |
| Framework-specific recipes (Angular, Vite, Next.js, NestJS, Quarkus, Bedrock AgentCore) | Distributed across consumer repos. Each `*-deploy.yml` has its own canonical caller in one of the `spark-match-*` repos. |

## When to use these

Use `caller-minimal/` as a starting point when:

- Adding a new `spark-match/*` repo and you want to bootstrap its CI in 5 minutes.
- Adding a new recipe to the catalog and you want a smoke-test caller that exercises the inputs you care about.
- Onboarding a new developer who needs to see "what does a real caller look like" without trawling through 8 production repos.

Do NOT use these as the canonical caller for production. The production callers live in the actual consumer repos and may include org-specific overrides (e.g. custom cache keys, additional jobs).

## Adding a new example

1. Create `caller-minimal/<recipe-or-stack>/` with `README.md` + `.github/workflows/<workflow>.yml`.
2. The workflow file MUST pin `@main` (the catalog's current version), not a SHA or branch ref.
3. Add a row to the index in `caller-minimal/README.md`.
4. Open a PR. The PR template will pick this up as `docs(examples)`.
