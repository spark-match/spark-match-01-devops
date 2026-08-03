# AGENTS.md — Guía para agentes de IA en `spark-match-01-devops`

> Documento para agentes de IA (OpenCode, GitHub Copilot, Claude Code, etc.) que operan sobre este repositorio. Refleja las convenciones observadas en el repo y el flujo de trabajo vigente.

## 1. Propósito y estructura del repositorio

`spark-match-01-devops` es el **catálogo único** de CI/CD compartida para la organización `spark-match`. No contiene código de aplicación (no Node, Python, Terraform ni SAM propios): su superficie es exclusivamente infraestructura declarativa de pipelines (workflows reutilizables y composite actions) y de governance (ruleset de la organización + scripts de reconciliación).

### 1.1 Estructura

- `.github/workflows/`: reusable workflows (`workflow_call`). Prefijo `reusable-` = consumible; sin prefijo = CI interna de este repo.
- `.github/actions/`: composite actions (primitivas atómicas). Consumidas por las reusables o por repos externos.
- `.github/ISSUE_TEMPLATE/`: bug + feature + docs issue templates.
- `.github/dependabot.yml`: bump de pull requests semanales para GitHub Actions.
- `.github/CODEOWNERS`: paths explícitos, sin catch-all (`*`).
- `.github/release-please-config.json`: Conventional Commits → section mapping para el release pull request.
- `.github/PULL_REQUEST_TEMPLATE.md`: checklist 11-tipos de Conventional Commits.
- `docs/`: convenciones de diseño (cache-key, governance standard, versioning).
- `scripts/`: operaciones idempotentes que aplican governance a la organización via la API de GitHub (gh).
- `governance/`: desired state del ruleset de la organización (manifest JSON + JSON Schema).
- `tests/`: bats tests por subject. Helpers compartidos en `tests/bats/helpers/`.

### 1.2 Naming conventions

- **Workflows reusables**: prefijo `reusable-` obligatorio. Encapsula tecnología (terraform, node, sonar, etc.) + responsabilidad (plan, apply, build, test).
- **Composite actions**: una carpeta por action bajo `.github/actions/<name>/`, con `action.yml` + opcional `*.sh` ejecutable.
- **Scripts**: kebab-case, ejecutable, shebang `#!/usr/bin/env bash` + `set -euo pipefail`.
- **Tests**: archivo bats por subject, bajo `tests/bats/<subject>.bats`.

### 1.3 Modelo de consumo

- **Reusables**: consumidos desde repos `spark-match/*` vía `uses: spark-match/spark-match-01-devops/.github/workflows/reusable-<name>.yml@main`.
- **Composite actions**: consumidas por las reusables (mismo repo, path `./.github/actions/<name>`) o por repos externos (`@main`).
- **Governance**: aplicada a la organización via `scripts/configure-repo-rulesets.sh`. No se aplica manualmente vía la UI de GitHub.

## 2. Modelo de rama — `main` único

- **Single-branch, single-purpose.** Todos los pull requests van directo a `main`. No existe rama `dev` en este repo.
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
| `ecosystem` / `node` / `python` / `deploy` | workflows por capa |
| `governance` | manifest, schema, scripts de ruleset |
| `scripts` | scripts bash |
| `docs` | README, `docs/`, CONTRIBUTING |
| `ci` | `.github/workflows/` (CI de este repo) |
| `quality` | bats/shellcheck/schema infra |
| `reconciler` | tests del reconciler |
| `repo` | cambios estructurales del repo (no catalog) |
| `deps` | bumps de dependabot (pull requests automatizados) |

Tipos: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`.

## 4. Pull Request workflow

### 4.1 Push + crear pull request

```bash
git push -u origin <branch>
gh pr create \
  --base main \
  --head <branch> \
  --title "chore(workflows): remove 6 stale reusables (zero consumers in spark-match org)" \
  --body-file <body-file>
```

### 4.2 Body del pull request — plantilla sugerida

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

9 checks corren en cada pull request vía `.github/workflows/ci.yml`:

| Check | Qué valida |
|---|---|
| `actionlint` | sintaxis de Actions YAML |
| `gitleaks` | secret scan |
| `yamllint` | formato YAML no-workflow |
| `quality / bats` | tests bats en `tests/bats/` |
| `quality / manifest schema` | `governance/repository-governance.json` contra schema |
| `quality / shellcheck` | bash scripts en `scripts/` + `.github/actions/` |
| `commitlint` | convención de commits en cada pull request |
| `codeql-actions` | vulnerabilidades en YAML de Actions |
| `codeql` | sin language (reused workflow) |

Si un check falla, **arregla el código** antes de pedir review. No marques `Resolve conversation` ni `--admin` para saltar un check rojo.

### 4.4 Merge — squash + admin bypass (autorizado por el dueño de la organización)

CODEOWNERS reviewers suelen no estar disponibles. Cuando CI está verde:

```bash
gh pr merge <num> --repo spark-match/spark-match-01-devops \
  --squash --admin --delete-branch \
  --body "All 9 checks green. [resumen]. Merged via admin bypass."
```

El body del merge commit está limitado a 100 chars por línea (regla
`body-max-line-length` heredada de `@commitlint/config-conventional`).
Si el resumen excede ese límite, partirlo en varias líneas con
`\n` o usar `--body-file` apuntando a un archivo con el texto
pre-formateado.

`--admin` se autoriza **solo** después de confirmar CI verde. No usar para skippear checks fallidos.

## 5. Convenciones de estilo

### 5.1 General

- **Sin emojis decorativos**: no usar emojis como adorno visual en código, commits, mensajes de pull request ni documentación. Los símbolos usados como marcadores de bullets en la sección 10 son indicadores estructurales y están permitidos.
- **Código en inglés**: variables, funciones, clases, archivos y demás identificadores del código fuente van en inglés. Los mensajes de commit (Conventional Commits) también.
- **Comentarios y documentación en español**: los comentarios en código (cuando se permitan, ver regla "sin comentarios" más abajo) y los archivos de explicación como `AGENTS.md`, `VERSIONING.md`, `CONTRIBUTING.md`, `docs/` y secciones de README que documenten procesos se escriben en español.
- **Cuidar caracteres especiales**: ñ, tildes (á, é, í, ó, ú, ü) y demás caracteres diacríticos deben estar correctamente codificados en UTF-8 para evitar mojibake en consola Windows PowerShell 5.1.
- **NO agregar comentarios a menos que se pidan explícitamente.** El repo sigue la regla de "self-documenting code".
- **Mimic existing patterns** antes de inventar nuevos. Si un workflow existente usa `permissions: contents: read`, el nuevo también.
- **No introducir dependencias nuevas** sin justificación en el pull request body.
- **Pin por versiones o branches, NO por SHA**. Para third-party actions usar `@vN` (major flotante, e.g. `actions/checkout@v4`) cuando el action publica tags con prefijo `v`. Si el action NO publica tags con prefijo `v` (e.g. `ludeeus/action-shellcheck` solo tiene `2.0.0`), usar la versión exacta `@N.N.N` (e.g. `ludeeus/action-shellcheck@2.0.0`). Excepciones documentadas:
  - **Self-actions** (nuestras propias composite actions): siempre `@main`.
  - **Anchore/sbom-action**: pinneado a `@v0.24.0` (minor pinned) porque la línea 0.x tiene breaking changes entre minors.
- La guardia contra SHA-pinning vive en `tests/bats/no-sha-pinning.bats` (3 casos: third-party, self, AGENTS.md policy text). Si el guard falla, el pull request se bloquea.
- **Naming convention — kebab-case obligatorio** en identificadores (excepto secretos y env vars del OS, que van en `SNAKE_CASE`):
  - **`kebab-case`** para:
    - **Job IDs** (`jobs: <id>:`) y nombres de archivo (`reusable-<name>.yml`).
    - **Step IDs** (`- id: <id>`).
    - **Inputs** de `workflow_call` o composite action (`inputs.<name>:`, `with: <name>: value`).
    - **Outputs** (`outputs.<name>:`).
    - **Display names** de workflow, job, y step (`name: <name>` en `workflow_call`, `jobs`, y `steps`). Plantillas `${{ inputs.x }}` se concatenan con `-` (sin espacios).
    - **Referencias a marcas/herramientas** dentro de `name:`, comentarios, descripciones de inputs y mensajes `::error::`. Marcas y herramientas van en kebab:
      - `SonarCloud` -> `sonar-cloud`
      - `CodeQL` -> `codeql`
      - `LaTeX` -> `latex`
      - `ESLint` -> `eslint`
      - `TFLint` -> `tflint`
      - `SBOM` -> `sbom`
      - `CycloneDX` -> `cyclonedx` (excepto donde es valor literal de schema JSON, e.g. `bomFormat == CycloneDX`)
      - `Terraform` -> `terraform` (lowercase, una sola palabra)
  - **`SNAKE_CASE`** (uppercase con guion bajo) para:
    - **Secretos** (`secrets.SOME_SECRET`, `secrets.GITLEAKS_LICENSE`, `secrets.AWS_PLAN_ROLE_ARN`). Convención heredada del entorno: las env vars que GitHub Actions expone para secrets siguen la convención POSIX de uppercase.
    - **Env vars pasadas al SO** dentro de `env:` blocks (`env: SBOM_DIR: ...`, `env: RUNNER_TEMP: ...`). Convención POSIX: env vars exportadas al OS van en `UPPER_SNAKE_CASE`.
  - **`kebab-case` (lowercase con guión) — excepción para env vars de workflow-level**: cuando se exporta una env var al runtime del workflow mediante `echo "key=value" >> "$GITHUB_ENV"` (típicamente desde un step bash dentro de `run:`), el nombre de la variable va en kebab-case lowercase, igual que el kebab-case de los identificadores YAML. Esto aplica a variables como `lower-os`, `env-name`, `cache-path`, `pkg-install-cmd`, `pkg-run-cmd` que son leídas vía `${{ env.lower-os }}` desde steps posteriores. La razón: consistencia con el identificador del step que las crea y legibilidad en `${{ }}` expressions. NO usar mayúsculas, ni guiones bajos, ni mezcla de estilos en este contexto.
  - **Excepciones intencionales** (no kebab):
    - URLs externas: `https://sonarcloud.io`, `https://github.com/anchore/sbom-action` (no romper links).
    - Nombres de acciones de terceros: `actions/checkout`, `anchore/sbom-action`, `github/codeql-action` (no romper refs de mercado).
    - Nombres de eventos de GitHub: `pull_request`, `push`, `workflow_call`, `workflow_dispatch`, `release`, `schedule` (son palabras reservadas del schema).
    - **Valores literales de schema**: `CycloneDX` como valor JSON de `bomFormat`, `cyclonedx-json` como valor de `format:` en anchore/sbom-action (mantener contrato con el schema externo).
  - **Reglas de transición**:
    - Si un nombre previo en `name:` usaba Title Case (e.g. `"Compile LaTeX document"`), kebab-casearlo: `compile-latex-document`.
    - Plantillas embebidas: `"name": "eslint-${{ inputs.environment-name }}"` (con guión, no espacio).
    - Para paréntesis con descripción (e.g. `(OIDC, plan role)`), kebab-case el contenido y unir con guión: `configure-aws-credentials-oidc-plan-role`.

### 5.2 Workflows reusables

- **Top-level only** en `.github/workflows/`. Subcarpetas rompen `uses: ./...` (limitación de GitHub Actions).
- Cada workflow expone un input `environment-name` (incluso si es informativo).
- Inputs van en `workflow_call.inputs` con `description`, `type`, `required`, `default`.
- Para workflows de deploy: gate vía GitHub Environment + secret `AWS_DEPLOY_ROLE_ARN` (o equivalente). El repo que invoca define el Environment.
- **Cross-owner secrets**: pasar explícitamente vía bloque `secrets:` en el repo que invoca. GitHub bloquea `secrets: inherit` entre owners distintos.
- **Env-isolate** cualquier `${{ inputs.* }}` usado dentro de `run:` (codeql guard contra code injection):
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

**Al agregar un path nuevo**: agregarlo al CODEOWNERS en el mismo pull request. Si no, el pull request queda con CODEOWNERS coverage incompleto.

Paths actuales:

- `/README.md`, `/LICENSE`, `/SECURITY.md`, `/CONTRIBUTING.md`, `/CODE_OF_CONDUCT.md`, `/CHANGELOG.md`, `/AGENTS.md` → dual-owned (`@devops` + `@product-owners`)
- `/.github/`, `/scripts/`, `/governance/`, `/tests/`, `/.githooks/`, `/.commitlintrc.json`, `/.gitleaks.toml` → `@devops`
- `/docs/` → dual-owned
- `/.yamllint.yml`, `/.gitignore`, `/.shellcheckrc`, `/.release-please-manifest.json` → `@devops`

## 7. Governance — sincronizar con `governance/`

El ruleset de la organización vive en `governance/repository-governance.json` (declarativo) + `scripts/configure-repo-rulesets.sh` (ejecutor) + `scripts/audit-codeowners-ruleset.sh` (detector de divergencias).

Al modificar paths bajo gobernanza:

```bash
# Después de editar governance/repository-governance.json:
./scripts/configure-repo-rulesets.sh --check --repos spark-match-01-devops
./scripts/configure-repo-rulesets.sh --dry-run --apply --repos spark-match-01-devops
```

No aplicar el manifest manualmente vía la UI de GitHub — eso crea divergencias.

## 8. Releases — release-please automático

`.github/workflows/release-please.yml` corta un "release pull request" en cada push a `main` basándose en conventional commits. Mergear el release pull request crea el git tag + un release de GitHub. La versión actual vive en `.release-please-manifest.json`.

**No bumpear versiones manualmente.** El flujo es:
1. Pull request con conventional commit → merge a main
2. release-please crea release pull request con version bump + CHANGELOG
3. Merge del release pull request → tag + release de GitHub

## 9. Troubleshooting común

### `gitleaks` no instalado localmente
El pre-commit hook `.githooks/pre-commit` skipea con warning. **CI sigue catching secrets** vía el job `gitleaks`. No bloquea el pull request.

### PowerShell vs bash
Este dev environment corre PowerShell 5.1 pero los comandos Git + bash funcionan transparentemente. **Para invocar `gh api` con URLs que contienen `?`**, usar variable:
```powershell
$url = "/repos/owner/repo/contents?ref=main"
gh api "$url"   # no: gh api "/repos/owner/repo/contents?ref=main"
```
### `gh pr checks` no muestra checks

Si el pull request está recién creado, esperar 15-30s y reintentar. Para ver runs:
```bash
gh api "/repos/spark-match/spark-match-01-devops/actions/runs?event=pull_request&per_page=10"
```

### `--admin` rechazado en `gh pr merge`
Verificar:
1. `gh auth status` muestra scope `admin:org` o `repo` + cuenta `ahincho` activa.
2. CI está realmente verde (todos los 9 checks `pass`, ninguno `pending`).

## 10. Lo que NO debes hacer

- Crear rama `dev` o feature branch de larga duración.
- Commits con mensajes vagos (`update`, `fix stuff`, `wip`).
- `--force` push a `main`.
- `git push --force` a cualquier rama compartida.
- Editar `.github/CODEOWNERS` sin agregar la entrada correspondiente en el mismo pull request.
- Saltarse checks rojos con `--admin` para aprobar un pull request con CI fallando.
- Agregar dependencias nuevas (`pip install`, `npm install`) sin justificación.
- Revertir el pin de las third-party actions a SHA de 40 chars. §5.1 introdujo `@vN`, `@N.N.N` o `@main` (PR #210); este bullet se mantiene solo si esa policy se revierte explícitamente.
- Mover reusables a subcarpetas de `.github/workflows/` (rompe `uses:`).

## 11. Estado actual del catalog (referencia rápida)

19 reusables distribuidos así (post-cleanup #201/#202/#203 + #207 rename):

| Capa | Cantidad | Reusables |
|---|---:|---|
| Ecosystem | 9 | `actionlint`, `codeql`, `gitleaks`, `quality`, `terraform-validate`, `tflint`, `sonar-terraform`, `sonar-typescript`, `yamllint` |
| Node | 4 | `eslint`, `node-build`, `node-test`, `node-typecheck` |
| Deploy | 4 | `migrations-dry-run`, `terraform-apply`, `terraform-destroy` (emergency), `terraform-plan` |
| Article | 2 | `latex-build`, `latex-release` |

5 workflows internos (no consumibles — son CI/CD de este repo): `ci`, `codeql-actions`, `commitlint`, `release-please`, `sbom`.

Consumidores activos (verificado en `main` + `dev` de cada repo):
- `spark-match-02-infrastructure`: terraform-{plan,apply}, tflint, gitleaks, sonar-terraform, terraform-validate
- `spark-match-03-backend`: sonar-typescript, migrations-dry-run, codeql
- `spark-match-04-frontend` (dev): actionlint, gitleaks, eslint, node-{test,typecheck,build}, sonar-typescript, yamllint
- `spark-match-07-article`: latex-{build,release}

Nota: los counts se desactualizan rápido. Para inventario en tiempo real:

```bash
ls .github/workflows/reusable-*.yml | wc -l
ls .github/actions/*/action.yml
ls scripts/*.sh
ls tests/bats/*.bats
```

## 12. Referencias operativas

- [`README.md`](README.md) — overview + tabla de workflows
- [`docs/VERSIONING.md`](docs/VERSIONING.md) — pin-by-environment + per-repo consumer mapping
- [`docs/GOVERNANCE-STANDARD.md`](docs/GOVERNANCE-STANDARD.md) — ruleset + CODEOWNERS rationale
- [`docs/CACHE.md`](docs/CACHE.md) — convención de cache key v4
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local setup detallado
- [`SECURITY.md`](SECURITY.md) — disclosure process + SLA
- [`scripts/README.md`](scripts/README.md) — flags de cada script

---

**Mantenido por**: opencode + el org owner de `spark-match`. Última revisión: 2026-08-03.