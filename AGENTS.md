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
| `ecosystem` / `node` / `python` / `deploy` / `frontend` | workflows por capa |
| `governance` | manifest, schema, scripts de ruleset |
| `scripts` | scripts bash |
| `docs` | README, `docs/`, CONTRIBUTING |
| `ci` | `.github/workflows/` (CI de este repo) |
| `quality` | bats/shellcheck/schema infra |
| `reconciler` | tests del reconciler |
| `repo` | cambios estructurales del repo (no catalog) |
| `deps` | bumps de dependabot (pull requests automatizados) |

Tipos: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `revert`. `perf` y `revert` se añadieron al set base — heredados de `@commitlint/config-conventional`.

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

9 checks corren en cada pull request vía `.github/workflows/ci.yml` + `codeql-actions.yml`:

| Check | Qué valida |
|---|---|
| `actionlint` | sintaxis de Actions YAML |
| `gitleaks` | secret scan |
| `yamllint` | formato YAML no-workflow |
| `quality / bats` | tests bats en `tests/bats/` |
| `quality / manifest schema` | `governance/repository-governance.json` contra schema |
| `quality / shellcheck` | bash scripts en `scripts/` + `.github/actions/` |
| `commitlint` | convención de commits en cada pull request (PR-side) |
| `commitlint-main` | convención de commits en el push a main (post-merge, required desde #276) |
| `codeql-actions` | vulnerabilidades en YAML de Actions |
| `Code scanning` | resultados agregados de CodeQL sobre Actions |

Si un check falla, **arregla el código** antes de pedir review. No marques `Resolve conversation` ni `--admin` para saltar un check rojo.

### 4.4 Merge — squash + admin bypass (autorizado por el dueño de la organización)

CODEOWNERS reviewers suelen no estar disponibles. Cuando CI está verde:

**Para cuentas con scope `admin:org` (usuarios normales):**

```bash
gh pr merge <num> --repo spark-match/spark-match-01-devops \
  --squash --admin --delete-branch \
  --body "All 9 checks green. [resumen]. Merged via admin bypass."
```

**Para cuentas Enterprise Managed Users (EMU):**

`gh pr merge --admin` falla con `GraphQL: Unauthorized: As an
Enterprise Managed User, you cannot access this content
(mergePullRequest)`. Workaround directo via REST API con el token de
`gh auth token` y PowerShell nativo (sin `--admin`):

```powershell
$token = (gh auth token).Trim()
$sha = (gh pr view <num> --repo spark-match/spark-match-01-devops --json headRefOid -q .headRefOid)
$msg = Get-Content C:\path\to\merge-msg.txt -Raw  # multi-line, cada linea <=100 chars
$payload = @"
{"merge_method":"squash","commit_message":$(($msg | ConvertTo-Json -Compress)),"sha":"$sha"}
"@
Invoke-WebRequest -Uri "https://api.github.com/repos/spark-match/spark-match-01-devops/pulls/<num>/merge" `
  -Method PUT `
  -Headers @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json"; User-Agent = "opencode" } `
  -Body $payload -ContentType "application/json" -UseBasicParsing
```

> **Pitfall crítico REST API merge**: cuando el body de la solicitud PUT
> solo contiene `commit_message`, GitHub usa el **PR title como
> `commit_title`** del merge commit. El PR-side commitlint check
> (`lint-commits / commitlint-{branch}`) solo valida los mensajes de los
> git commits del PR, **no el PR title**. Resultado: si el PR title
> tiene `camelCase` (e.g. `statusChecks`) o viola otras reglas
> (`subject-case` lower-case, etc.), el commit del merge squash las hereda
> y falla `lint-commits / commitlint-main` en el push a main. El check
> PR-side pasó pero el check post-merge falló.
>
> **Solución operativa**: enviar `commit_title` Y `commit_message` por
> separado. `commit_title` lower-case explícito, `commit_message`
> multi-line (body). Ambos campos en el mismo payload JSON:
>
> ```powershell
> $payload = '{"merge_method":"squash","commit_title":"fix(scope): subject (#NN)","commit_message":"\n\nBody line 1.\nBody line 2.","sha":"' + $sha + '"}'
> ```
>
> Adicionalmente, `lint-commits / commitlint-main` es **required
> status check** en el ruleset de este repo (agregado en PR #276). Si
> un merge produce un commit con subject que viola commitlint, el push
> a main queda pegado en rojo hasta que se arregle.

> **Reglas activas de longitud de línea** (`.commitlintrc.json` + defaults de `@commitlint/config-conventional`):
>
> | Regla | Límite | Aplica a | Estado |
> |---|---|---|---|
> | `header-max-length` | 100 chars | Subject (`type(scope)!: subject`) | Activo (`[2, always, 100]`) |
> | `body-max-line-length` | — | Body | **Deshabilitado** (`[0]` en `.commitlintrc.json`) |
> | `footer-max-line-length` | 100 chars | Footer | Activo (default heredado) |
>
> **Implicancia operativa**: el parser de commitlint
> (`@commitlint/parse` + `conventional-commits-parser`) clasifica
> oportunísticamente el contenido post-header como body o footer.
> Una línea larga que en una corrida pasa como body puede ser
> clasificada como footer en otra y disparar `footer-max-line-length`.
> **Mantener TODAS las líneas del commit message ≤100 chars** para
> comportamiento determinístico. La regla `body-max-line-length`
> está explícitamente deshabilitada en este repo porque queremos
> libertad en el body, pero el parser no garantiza que el contenido
> post-header sea tratado como body en todas las corridas.

**Ejemplos de mensajes válidos** (cada línea ≤100 chars, separar con `\n` literal en el JSON o con líneas reales en un archivo):

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

**Regla práctica para merges vía REST API**: escribir el mensaje en
un archivo de texto plano (cada línea ≤100 chars) y leerlo con
`Get-Content -Raw`. Nunca concatenar strings con `+` porque
PowerShell tokeniza `"..."` con caracteres especiales de forma
impredecible. Lo mismo aplica a `gh pr create --body "..."` —
usar siempre `--body-file` (ver §4.1).

`--admin` se autoriza **solo** después de confirmar CI verde. No usar para skippear checks fallidos.

### 4.5 Squash-merge REST API checklist (EMU workaround)

Para evitar el pitfall documentado en §4.4 (PR title → commit subject), ejecutar este checklist **antes** de hacer el PUT:

```powershell
# 1. Validar PR title contra las reglas que commitlint-main va a aplicar
$title = gh pr view <N> --repo <owner>/<repo> --json title -q .title
if ($title -cmatch '[A-Z]') { Write-Error "title has uppercase (commitlint subject-case)"; exit 1 }
if ($title.Length -gt 100) { Write-Error "title >100 chars (commitlint header-max-length)"; exit 1 }
if ($title -match '\(#\d+\)\s*$') { Write-Error "title has trailing (#NN) (commitlint no acepta en subject)"; exit 1 }

# 2. Construir payload con commit_title Y commit_message SEPARADOS
$sha = (gh pr view <N> --repo <owner>/<repo> --json headRefOid -q .headRefOid)
$msg = Get-Content C:\path\to\merge-msg.txt -Raw   # multi-line, cada linea <=100 chars
$payload = @"
{"merge_method":"squash","commit_title":"$title","commit_message":$(($msg | ConvertTo-Json -Compress)),"sha":"$sha"}
"@

# 3. PUT
Invoke-WebRequest -Uri "https://api.github.com/repos/<owner>/<repo>/pulls/<N>/merge" `
  -Method PUT `
  -Headers @{ Authorization = "Bearer $token"; Accept = "application/vnd.github+json"; User-Agent = "opencode"; "X-GitHub-Api-Version" = "2022-11-28" } `
  -Body $payload -ContentType "application/json" -UseBasicParsing
```

**Errores específicos a evitar**:

| Falla | Síntoma | Fix |
|---|---|---|
| `commit_message` solo (sin `commit_title`) | El merge commit subject = PR title. Si PR title tiene `camelCase`, falla `commitlint-main` en push a main | Enviar `commit_title` + `commit_message` separados |
| PR title con `(#NN)` al final | En §4.4 el subject heredado termina con `(#NN)^{1,2}` que es BODY char límite | Agregar `(#NN)` solo en `commit_title`, no en `commit_message` |
| `commit_message` con una sola línea larga (>100 chars) | Falla `header-max-length` o `footer-max-line-length` en commitlint-main | Dividir en múltiples líneas, cada una ≤100 chars |
| Usar `git commit -m` con strings concatenadas (`+`) | PowerShell tokeniza `"..."` con caracteres especiales de forma impredecible | Usar `Get-Content -Raw` desde un archivo |

**Pre-flight obligatorio para squash-merge de PR de release-please** (PR #275, #277, #281, etc.): el PR title es `release X.Y.Z` que pasa todos los checks. No requiere edición. Pero el `commit_message` debe ser multi-line (no una línea concatenada de 200+ chars).

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

### 5.2 Cómo añadir un nuevo reusable workflow

> Patrón establecido en PR #254 (Tier 3) y aplicado por primera vez en
> `spark-match-02-infrastructure` (PR #104, #105).
>
> **Pin cross-repo**: la regla vigente es `@main` per
> `docs/VERSIONING.md` (single-main-branch model, decision 2026-07). Los
> tags `vX.Y.Z` existen por trazabilidad de release-please pero NO son
> el pin requerido para callers internos. Esta sub-sección históricamente
> recomendaba `@vX.Y.Z`; esa guía queda derogada y el contrato actual es
> `@main`. Ver §5.2 item 8 abajo.

Un reusable workflow (`on: workflow_call`) encapsula lógica reutilizable
cross-repo. Para añadir uno:

1. **Crear archivo** en `.github/workflows/reusable-<name>.yml` (prefijo
   `reusable-` + kebab-case, ver §5.1).
2. **Inputs vs secrets**:
   - `workflow_call.inputs` para valores NO sensibles (paths, flags, toggles).
   - `workflow_call.secrets` para credenciales (App IDs, tokens).
   - Inputs y secrets deben tener `description` + `default` (si opcional) +
     `required` explícito.
3. **NO lookup dinámico de secrets**: `${{ secrets[inputs.foo] }}` está
   prohibido por GH Actions (PR #256). Usar `workflow_call.secrets`
   declarados y forwardear desde el caller.
4. **NO definir `concurrency`**: GH Actions rechaza reusable workflows
   que definan su propio concurrency block (PR #255). El caller lo posee.
5. **Permisos mínimos**: `contents: read` por default. Escalar a `write`
   solo si crea branches / tags / releases.
6. **Dogfooding obligatorio**: el caller interno de 01-devops
   (`commitlint.yml`, `release-please.yml`) debe consumir el reusable
   via `uses: ./.github/workflows/...`. Esto valida el shape contra
   la suite de bats ANTES de exponerlo cross-repo.
7. **Tests bats**: añadir en `tests/bats/reusable-ci-workflows.bats`
   (o archivo nuevo por dominio). Cubrir:
   - `workflow_call` declarado.
   - Cada input tiene `type` explícito.
   - Cada action pinneada al major (`@vN`, NO SHA).
   - Caller interno consume el reusable.
   - Caller interno NO duplica steps del reusable.
   - Reusable NO define `concurrency`.
   - Caller interno SÍ define `concurrency`.
   - Para reusables con secrets: caller forwardea ambos secrets via
     `secrets:` block, reusable los consume via `${{ secrets.<name> }}`.
8. **Pin cross-repo**: `uses: spark-match/spark-match-01-devops/.github/
   workflows/reusable-<name>.yml@main` per `docs/VERSIONING.md`
   (single-main-branch model, decision 2026-07). Los tags `vX.Y.Z`
   existen por trazabilidad de release-please pero NO son el pin
   requerido para callers internos. Si en el futuro spark-match
   quisiera ofrecer versiones estables a repos third-party (no
   spark-match org), se haría vía un proceso de release dedicado
   (ver `docs/VERSIONING.md` § "Cuando se justificara SemVer").
9. **Documentar en §11**: añadir a la tabla de reusables, contar
   correctamente. Bumpear el `package-name` en `.github/release-please-
   config.json` si aplica.

**Anti-patterns**:

- `uses: ./...` cross-repo (solo funciona same-repo, error en runtime).
- Inputs que cambian paths canónicos (hardcodear en su lugar).
- `permissions: write` por defecto.
- Reutilizar nombres de inputs legacy que impliquen lookup dinámico
  de secrets.
- Olvidar el auto-dogfooding (caller interno no consume el reusable).
- Publicar reusable sin bats tests.

**Referencia**: PR #254 introduce el patrón (con bugs corregidos en
#255 y #256). PR #104 y #105 en `spark-match-02-infrastructure` son los
primeros consumers cross-repo.

### 5.3 Workflows reusables

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

### 5.4 Composite actions

- `.github/actions/<name>/action.yml` (un directorio por action).
- Sin deps de runtime fuera de las actions oficiales de GitHub.

### 5.5 Scripts

- Shebang `#!/usr/bin/env bash` + `set -euo pipefail` al top.
- Cada script declara su uso en un header con ejemplos.
- `--dry-run` cuando sea posible (todo script idempotente debe soportarlo).
- Cubrir con bats tests si la lógica es no-trivial.

### 5.6 Tests

- bats tests bajo `tests/bats/<subject>.bats`. Descubrimiento automático vía `tests/bats/*.bats` (ver `quality.yml`).
- Helpers compartidos en `tests/bats/helpers/`.
- Comandos:
  ```bash
  bats tests/bats/
  shellcheck scripts/*.sh .github/actions/*/action.sh
  ```

### 5.7 Pre-commit hook vs CI commitlint

El hook local `.githooks/commit-msg` y el CI commitlint **no son idénticos**. El hook local es un proxy aproximado; el CI es canónico. Conocer las diferencias evita dos errores opuestos: (1) usar `--no-verify` cuando NO se debe, (2) confiar en `--no-verify` cuando sí se debe.

| Caso | Pre-commit local | CI commitlint | Acción |
|---|---|---|---|
| `feat!:` (bang después de type/scope) | **FALLA** (regex no soporta `!`) | OK | `--no-verify` (es seguro) |
| `(#NN)` al final del subject | **FALLA** (regex no lo incluye) | OK | `--no-verify` (es seguro) |
| `camelCase` en subject (e.g. `statusChecks`) | OK (no chequea lowercase) | **FALLA** (`subject-case`) | NO usar `--no-verify`; confiar en CI para catch + arreglar |
| Body o footer con líneas >100 chars | OK (header-only check) | **FALLA** (`footer-max-line-length`) | NO usar `--no-verify`; confiar en CI para catch + arreglar |
| Scope fuera de enum | **FALLA** | **FALLA** | NO usar `--no-verify`; cambiar el scope |
| `subject-empty` | **FALLA** | OK (`scope-empty: [0]`) | `--no-verify` (es seguro) |
| Type fuera de enum (`feat`, `fix`, etc.) | **FALLA** | **FALLA** | NO usar `--no-verify`; cambiar el type |

**Regla operativa**:

- Si el pre-commit rechaza por **bang `!`** o **`(#NN)`**: usar `git commit --no-verify` con confianza. El CI commitlint SÍ soporta ambos y va a pasar.
- Si el pre-commit rechaza por **cualquier otra razón**: NO usar `--no-verify`. El pre-commit y el CI están de acuerdo; el commit es genuinamente inválido. Arreglar el commit.
- Si el CI rechaza pero el pre-commit pasó: el CI es canónico. Confiar en el CI. Mirar el log para entender qué falló (probablemente `body-max-line-length` o `header-max-length` que el pre-commit no chequea con la misma precisión).

**Workaround de un solo paso para bang y (#NN)**: usar `git commit --no-verify -F <message-file>` con un archivo de texto plano (cada línea ≤100 chars). El archivo evita la tokenización impredecible de PowerShell.

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

21 reusables distribuidos así (post-cleanup #201/#202/#203 + #207 rename + Tier 3 #254/#255/#256):

| Capa | Cantidad | Reusables |
|---|---:|---|
| Ecosystem | 9 | `actionlint`, `codeql`, `gitleaks`, `quality`, `terraform-validate`, `tflint`, `sonar-terraform`, `sonar-typescript`, `yamllint` |
| Node | 4 | `eslint`, `node-build`, `node-test`, `node-typecheck` |
| Deploy | 4 | `migrations-dry-run`, `terraform-apply`, `terraform-destroy` (emergency), `terraform-plan` |
| Article | 2 | `latex-build`, `latex-release` |
| **CI/CD shared** | **2** | **`reusable-commitlint`, `reusable-release-please`** |

5 workflows internos (no consumibles — son CI/CD de este repo): `ci`, `codeql-actions`, `commitlint`, `release-please`, `sbom`.

4 composite actions (en `.github/actions/`): `bats-runner`, `codeql-fail-on-alerts`, `setup-actionlint`, `validate-workflow-inputs`.

Consumidores activos (verificado en `main` + `dev` de cada repo):
- `spark-match-02-infrastructure`: terraform-{plan,apply}, tflint, gitleaks, sonar-terraform, terraform-validate, **commitlint, release-please (Tier 3, post-#104/#105)**, v1.0.0 publicado
- `spark-match-03-backend`: sonar-typescript, migrations-dry-run, codeql
- `spark-match-04-frontend` (dev): actionlint, gitleaks, eslint, node-{test,typecheck,build}, sonar-typescript, yamllint
- `spark-match-07-article`: latex-{build,release}

22 bats tests en `tests/bats/`, 331/331 verde en último CI run.

**Secrets cross-repo (org-level, visibility=all)**: `RELEASE_PLEASE_APP_ID`, `RELEASE_PLEASE_APP_PRIVATE_KEY`, `GITLEAKS_LICENSE`, `SONAR_TOKEN` viven a nivel organización para evitar duplicación por consumer. Los nuevos repos que añadan reusables de 01-devops solo necesitan instalar la GitHub App `spark-match-bot` (no bootstrap manual de secrets).

**CodeQL exclusion**: `.github/codeql/codeql-config.yml` excluye `js/actions/unpinned-3rd-party-action` (legacy) y `actions/unpinned-tag` (activa en `actions` mode). Ambas reglas alientan SHA-pinning que el repo prohíbe deliberadamente (ver §5.1). El guard `tests/bats/codeql-config.bats` previene regresión.

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

## 13. Lessons learned (2026-08-04)

**Cosmético NO requiere rewrite.** El fix de `commitlint-main` required (PR #276) es la defensa real. Lo que sigue es la bitácora del rewrite de 2026-08-04 (one-off, no repetir) y las lecciones reutilizables que dejó.

### 13.1 Bitácora del rewrite

La rama `main` fue reescrita con `git rebase -i aa52bf7` + 5 amend manuales + force-push para limpiar 4 commits históricos con `commitlint` violatorio (3 con body >100 chars, 1 con `statusChecks` camelCase). Política AGENTS.md §10 fue ignorada por decisión explícita del org owner. Consecuencias:

- **Tags `v1.0.0`, `v1.0.1`, `v1.0.2`** re-creados en los SHAs post-rewrite. Las releases de GitHub correspondientes también se re-crearon con SBOM. Las versiones anteriores apuntaban a commits eliminados.
- **Archive branch `archive/pre-rewrite-2026-08-04`** preserva el estado pre-rewrite en origin, accesible vía `git checkout archive/pre-rewrite-2026-08-04`.
- **Ruleset fue deshabilitado temporalmente** durante el force-push (`enforcement: disabled`), re-aplicado con `--apply` post-push. Todo el flujo quedó in-sync (1-devops + 2-infra).
- **PR #279** (`release 2.0.0`) auto-generado por release-please al ver el force-push como "nuevos commits" — cerrado como duplicado (manifest sigue en 1.0.2, contenido sin cambios).
- **PR #281** (`release 1.0.3`) auto-generado por release-please tras el primer push legítimo post-rewrite — mergado legitimamente con SBOM.
- **CHANGELOG.md** todavía referencia SHAs antiguos tipo `b1bbd59`, `20d4582`, etc. — no regenerado en este ciclo. Pendiente de un PR de cleanup.

**No repetir sin aprobación explícita del org owner.** El rewrite costó múltiples pasos manuales (rebase interactivo, amend por commit, force-push, re-tag, re-crear releases con SBOM, re-aplicar ruleset). El valor pragmático (cosmético en UI) no justifica el esfuerzo recurrente.

### 13.2 Lecciones reutilizables (lo que SÍ vale la pena recordar)

**1. Status check name mismatch** (causante original de las PRs #273, #274): el manifest tenía nombres que no correspondían a los que los workflows reportan. Antes de mergear un cambio al manifest, validar contra `gh api /repos/$REPO/actions/runs?per_page=10` + `/jobs`. Los 8 bats tests en `reconciler-status-checks.bats` lockean los nombres reales para que el próximo agente no pueda sobrescribirlos con placeholders.

**2. REST API merge pitfall** (causante del cosmético): documentado en §4.4 + §4.5. SIEMPRE enviar `commit_title` + `commit_message` separados en `PUT /pulls/N/merge`. Si solo envías `commit_message`, GitHub usa el PR title como commit subject y hereda cualquier `camelCase`. El fix de PR #276 (`commitlint-main` required + bats test 3) hace fail-closed el sistema.

**3. Pre-commit hook vs CI commitlint**: el pre-commit es un proxy aproximado. Documentado en §5.7. Si pre-commit rechaza por **bang `!`** o **`(#NN)`**: `--no-verify` es seguro. Cualquier otra razón: NO usar `--no-verify`, el commit es genuinamente inválido.

**4. Release-please después de rebase**: tras un force-push, release-please ve las nuevas SHAs como "commits nuevos" y puede auto-cutear un PR de release incorrecto (PR #279 ejemplo). El diff entre el último tag y HEAD está vacío pero release-please usa `git log` que incluye todas las SHAs. Mitigación: mantener el manifest actualizado ANTES del rewrite, o cerrar el PR auto-cut inmediatamente.

**5. CHANGELOG.md post-rewrite queda con SHAs muertos**: los links de CHANGELOG.md (`https://github.com/.../commit/<SHA>`) siguen apuntando a SHAs que ya no existen en historia. Trabajo de cleanup pendiente: regenerar CHANGELOG.md o aceptar los links rotos.

### 13.3 Defense in depth ya implementada

| Defensa | Origen | Bloquea |
|---|---|---|
| `commitlint-main` required | PR #276 | squash merge con subject malo en push a main |
| 8 bats tests en `reconciler-status-checks.bats` | PR #274 | regresión de governance (manifest con placeholder names) |
| §4.4 doc del REST API pitfall | PR #278 | próximo agente sabe el pitfall |
| §4.5 checklist pre-merge | PR #282 | script de validación antes del PUT |
| §5.7 tabla pre-commit vs CI | PR #282 | tentación de `--no-verify` mal usada |
| §13 este archivo | PR #282 | ciclar a través de los mismos errores |

**Defense adicional recomendada** (no implementada, baja prioridad):

- Pre-commit hook local podría validar `commit_title` antes de push de un PR (no solo el commit msg local).
- `release-please.yml` podría tener `release-type: simple` para evitar bumps incorrectos en force-push scenarios.

---

**Mantenido por**: opencode + el org owner de `spark-match`. Última revisión: 2026-08-04.