# AGENTS.md — Guía para agentes de IA en `spark-match-01-devops`

> Documento para agentes de IA (OpenCode, GitHub Copilot, Claude Code, etc.) que operan sobre este repositorio. Refleja las convenciones observadas en el repo y el flujo de trabajo vigente.

## 1. Qué es este repo

Catálogo único de **CI/CD compartido para la organización `spark-match`**. Aloja:

- **23 reusables** en `.github/workflows/` (consumidos por repos `spark-match/*` vía `uses:`).
- **2 composite actions** en `.github/actions/` (primitivas atómicas: `validate-workflow-inputs`, `run-pytest-with-args`).
- **2 scripts org-admin** en `scripts/` (`configure-repo-rulesets.sh` + `audit-codeowners-ruleset.sh`).
- **Docs** en `docs/` (CACHE, GOVERNANCE-STANDARD, VERSIONING).
- **113 tests bats** en `tests/bats/`.
- **Governance declarativa** en `governance/` (manifest JSON + schema).

Este repo **no contiene código de aplicación** (no Node, Python, Terraform, ni SAM propios). Es 100% infra-as-code de pipelines + governance.

## 2. Modelo de rama — `main` único

- **Single-branch, single-purpose.** Todos los PRs van directo a `main`. No existe rama `dev` en este repo.
- **Branch directo desde `main`** con Conventional Commits scope:
  ```bash
  git checkout main
  git pull --ff-only
  git checkout -b chore/<scope>-<short-desc>
  ```
- **El nombre de la branch debe reflejar el tipo + scope**:
  - `feat/composite-action-add`, `fix/quality-cache-key`
  - `chore(workflows): ...` → `chore/remove-stale-shared-reusables`
  - `docs(readme): ...` → `docs/clarify-cache-section`
- **Branch se borra en merge** (regla `delete_branch_on_merge=true` del ruleset). Limpia local y remoto después:
  ```bash
  git checkout main
  git pull --ff-only
  git branch -D <branch>
  git fetch --prune
  ```

## 3. Convención de commits — Conventional Commits 1.0.0

```bash
git commit -m "chore(workflows): remove 6 stale reusables (zero consumers)"
```

Scopes usados en este repo:

| Scope | Aplicación |
|---|---|
| `composite` | composite actions |
| `workflows` | reusable workflows |
| `ecosystem` / `node` / `python` / `deploy` | recipes por capa |
| `governance` | manifest, schema, scripts de ruleset |
| `scripts` | scripts bash |
| `docs` | README, `docs/`, CONTRIBUTING |
| `ci` | `.github/workflows/` (CI de este repo) |
| `quality` | bats/shellcheck/schema infra |
| `reconciler` | tests del reconciler |
| `repo` | cambios estructurales del repo (no catalog) |

Tipos: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`.

## 4. Pull Request workflow

### 4.1 Push + crear PR

```bash
git push -u origin <branch>
gh pr create \
  --base main \
  --head <branch> \
  --title "chore(workflows): remove 6 stale reusables (zero consumers in spark-match org)" \
  --body-file <body-file>
```

### 4.2 Body del PR — plantilla sugerida

```markdown
## Summary
[1-3 frases describiendo el cambio]

### Deleted / Added / Modified
| File | Change |
|------|--------|
| `path/to/file` | descripción de 1 línea |

### Docs cleanup (si aplica)
- `README.md`: ...
- `docs/VERSIONING.md`: ...
- `examples/...`: ...

### Impact
[Net diff + efecto en el catalog: "Catalog: 38 → 33 workflows", "Test suite: 124 bats unchanged", etc.]
```

### 4.3 Checks requeridos — todos deben pasar

8 checks corren en cada PR vía `.github/workflows/ci.yml`:

| Check | Qué valida |
|---|---|
| `actionlint` | sintaxis de Actions YAML |
| `gitleaks` | secret scan |
| `yamllint` | formato YAML no-workflow |
| `quality / bats` | 113 bats tests |
| `quality / manifest schema` | `governance/repository-governance.json` contra schema |
| `quality / shellcheck` | bash scripts en `scripts/` + `.github/actions/` |
| `Analyze (actions)` (CodeQL) | vulnerabilidades en YAML de Actions |
| `CodeQL` | sin language (reused workflow) |

Si un check falla, **arregla el código** antes de pedir review. No marques `Resolve conversation` ni `--admin` para saltar un check rojo.

### 4.4 Merge — squash + admin bypass (autorizado por org owner)

CODEOWNERS reviewers suelen no estar disponibles. Cuando CI está verde:

```bash
gh pr merge <num> --repo spark-match/spark-match-01-devops \
  --squash --admin --delete-branch \
  --body "All 8 required checks green. [resumen del cambio]. Merged via admin bypass — owner approval only (CODEOWNERS reviewers unavailable)."
```

`--admin` se autoriza **solo** después de confirmar CI verde. No usar para skippear checks fallidos.

## 5. Convenciones de estilo

### 5.1 General

- **NO agregar comentarios a menos que se pidan explícitamente.** El repo sigue la regla de "self-documenting code".
- **Mimic existing patterns** antes de inventar nuevos. Si un recipe existente usa `permissions: contents: read`, el nuevo también.
- **No introducir dependencias nuevas** sin justificación en el PR body.
- **Pin por versiones o branches, NO por SHA**. Para third-party actions usar `@vN` (major flotante, e.g. `actions/checkout@v4`) cuando el action publica tags con prefijo `v`. Si el action NO publica tags con prefijo `v` (e.g. `ludeeus/action-shellcheck` solo tiene `2.0.0`), usar la versión exacta `@N.N.N` (e.g. `ludeeus/action-shellcheck@2.0.0`). Excepciones documentadas:
  - **Self-actions** (nuestras propias composite actions): siempre `@main`.
  - **Anchore/sbom-action**: pinneado a `@v0.17.7` (minor pinned) porque la línea 0.x tiene breaking changes entre minors.
- La guardia contra SHA-pinning vive en `tests/bats/no-sha-pinning.bats` (3 casos: third-party, self, AGENTS.md policy text). Si el guard falla, el PR se bloquea.

### 5.2 Workflows reusables

- **Top-level only** en `.github/workflows/`. Subcarpetas rompen `uses: ./...` (limitación de GH Actions).
- Cada recipe expone un input `environment-name` (incluso si es informativo).
- Inputs van en `workflow_call.inputs` con `description`, `type`, `required`, `default`.
- Para recipes de deploy: gate vía GH Environment + secret `AWS_DEPLOY_ROLE_ARN` (o equivalente). El caller define el Environment.
- **Cross-owner secrets**: pasar explícitamente vía bloque `secrets:` en el caller. GitHub bloquea `secrets: inherit` entre owners distintos.
- **Env-isolate** cualquier `${{ inputs.* }}` usado dentro de `run:` (CodeQL guard contra code injection):
  ```yaml
  env:
    INPUTS_FOO: ${{ inputs.foo }}
  run: |
    echo "${INPUTS_FOO}"
  ```

### 5.3 Composite actions

- `.github/actions/<name>/action.yml` (un directorio por action).
- Sin deps de runtime fuera de las actions oficiales de GitHub.

### 5.4 Scripts

- Shebang `#!/usr/bin/env bash` + `set -euo pipefail` al top.
- Cada script declara su uso en un header con ejemplos.
- `--dry-run` cuando sea posible (todo script idempotente debe soportarlo).
- Cubrir con bats tests si la lógica es no-trivial.

### 5.5 Tests

- bats tests bajo `tests/bats/<subject>.bats`. Descubrimiento automático vía `tests/bats/*.bats` (ver `quality.yml`).
- Helpers compartidos en `tests/bats/helpers/`.
- Comandos:
  ```bash
  bats tests/bats/
  shellcheck scripts/*.sh .github/actions/*/action.sh
  ```

## 6. CODEOWNERS y paths

Este repo **NO usa catch-all `*`** porque GitHub acumula code owners de todas las reglas que matchean. Cada path está listado explícitamente en `.github/CODEOWNERS`.

**Al agregar un path nuevo**: agregarlo al CODEOWNERS en el mismo PR. Si no, el PR queda con CODEOWNERS coverage incompleto.

Paths actuales:

- `/README.md`, `/LICENSE`, `/SECURITY.md`, `/CONTRIBUTING.md`, `/CODE_OF_CONDUCT.md`, `/CHANGELOG.md` → dual-owned (`@devops` + `@product-owners`)
- `/.github/`, `/scripts/`, `/governance/`, `/tests/` → `@devops`
- `/docs/` → dual-owned
- `/.yamllint.yml`, `/.gitignore`, `/.shellcheckrc`, `/.release-please-manifest.json` → `@devops`

## 7. Governance — sincronizar con `governance/`

El ruleset del org vive en `governance/repository-governance.json` (declarativo) + `scripts/configure-repo-rulesets.sh` (ejecutor) + `scripts/audit-codeowners-ruleset.sh` (drift detector).

Al modificar paths bajo gobernanza:

```bash
# Después de editar governance/repository-governance.json:
./scripts/configure-repo-rulesets.sh --check --repos spark-match-01-devops
./scripts/configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops
```

No aplicar el manifest manualmente vía la UI de GitHub — eso crea drift.

## 8. Releases — release-please automático

`.github/workflows/release-please.yml` corta un "release PR" en cada push a `main` basándose en conventional commits. Mergear el release PR crea el git tag + GitHub Release. La versión actual vive en `.release-please-manifest.json`.

**No bumpear versiones manualmente.** El flujo es:
1. PR con conventional commit → merge a main
2. release-please crea release PR con version bump + CHANGELOG
3. Merge del release PR → tag + GH Release

## 9. Troubleshooting común

### `gitleaks` no instalado localmente
El pre-commit hook `.githooks/pre-commit` skipea con warning. **CI sigue catching secrets** vía el job `gitleaks`. No bloquea el PR.

### PowerShell vs bash
Este dev environment corre PowerShell 5.1 pero los comandos Git + bash funcionan transparentemente. **Para invocar `gh api` con URLs que contienen `?`**, usar variable:
```powershell
$url = "/repos/owner/repo/contents?ref=main"
gh api "$url"   # no: gh api "/repos/owner/repo/contents?ref=main"
```

### `gh pr checks` no muestra checks
Si PR está recién creado, esperar 15-30s y reintentar. Para ver runs:
```bash
gh api "/repos/spark-match/spark-match-01-devops/actions/runs?event=pull_request&per_page=10"
```

### `--admin` rechazado en `gh pr merge`
Verificar:
1. `gh auth status` muestra scope `admin:org` o `repo` + cuenta `ahincho` activa.
2. CI está realmente verde (todos los 8 checks `pass`, ninguno `pending`).

## 10. Lo que NO debes hacer

- ❌ Crear rama `dev` o feature branch de larga duración.
- ❌ Commits con mensajes vagos (`update`, `fix stuff`, `wip`).
- ❌ `--force` push a `main`.
- ❌ `git push --force` a cualquier rama compartida.
- ❌ Editar `.github/CODEOWNERS` sin agregar la entrada correspondiente en el mismo PR.
- ❌ Saltarse checks rojos con `--admin`.
- ❌ Agregar dependencias nuevas (`pip install`, `npm install`) sin justificación.
- ❌ Usar `@main` o `@vN` en `uses:` de third-party actions. SHA-pinning siempre.
- ❌ Mover reusables a subcarpetas de `.github/workflows/` (rompe `uses:`).

## 11. Estado actual del catalog (referencia rápida)

23 reusables distribuidos así (post-cleanup #201/#202/#203):

| Capa | Cantidad | Reusables |
|---|---:|---|
| Ecosystem | 6 | `actionlint`, `gitleaks`, `terraform-validate`, `tflint`, `sonar-terraform`, `sonar-typescript`, `yamllint` |
| Node | 4 | `eslint`, `node-build`, `node-test`, `node-typecheck` |
| Deploy | 4 | `migrations-dry-run`, `terraform-apply`, `terraform-destroy` (emergency), `terraform-plan` |
| Article | 2 | `latex-build`, `latex-release` |
| Self-only | 5 | `ci`, `codeql`, `codeql-actions`, `quality`, `release-please`, `sbom` |

(La suma de la tabla es 22; `terraform-destroy` está contado en Deploy.)

Consumidores activos (verificado en `main` + `dev` de cada repo):
- `spark-match-02-infrastructure`: terraform-{plan,apply}, tflint, gitleaks, sonar-terraform, terraform-validate
- `spark-match-03-backend`: sonar-typescript, migrations-dry-run, codeql
- `spark-match-04-frontend` (dev): actionlint, gitleaks, eslint, node-{test,typecheck,build}, sonar-typescript, yamllint
- `spark-match-07-article`: latex-{build,release}

## 12. Referencias operativas

- [`README.md`](README.md) — overview + tabla de recipes
- [`docs/VERSIONING.md`](docs/VERSIONING.md) — pin-by-environment + per-repo consumer mapping
- [`docs/GOVERNANCE-STANDARD.md`](docs/GOVERNANCE-STANDARD.md) — ruleset + CODEOWNERS rationale
- [`docs/CACHE.md`](docs/CACHE.md) — convención de cache key v4
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local setup detallado
- [`SECURITY.md`](SECURITY.md) — disclosure process + SLA
- [`scripts/README.md`](scripts/README.md) — flags de cada script

---

**Mantenido por**: opencode + el org owner de `spark-match`. Última revisión: 2026-08-02.