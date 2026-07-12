# Spark Match — DevOps (Pipelines Reutilizables)

Repositorio central de **pipelines de CI/CD** para todos los proyectos Spark Match. Aquí viven los **reusable workflows** de GitHub Actions que los demás repos consumen.

> **Patrón:** Un repo central de pipelines → muchos repos que solo "llaman" al pipeline central. Esto evita duplicación, facilita mantenimiento y asegura consistencia entre proyectos.

---

## 📁 Estructura

```
spark-match-01-devops/
├── .github/
│   ├── CODEOWNERS              # devops + product-owners aprueban cambios
│   └── workflows/
│       ├── ci.yml                # CI: lint + security checks (en PR) — interno
│       ├── quality-checks.yml    # Lint + typecheck + tests (Node + Py) — reusable
│       ├── terraform-plan.yml    # Plan de Terraform (read-only, en PR) — reusable
│       ├── terraform-apply.yml   # Apply de Terraform (write, en merge) — reusable
│       ├── sam-deploy.yml        # SAM build + deploy con OIDC — reusable
│       ├── latex-build.yml       # Compilar LaTeX → PDF (en PR) — reusable
│       └── latex-release.yml     # Compilar + tag + release (en merge) — reusable
├── .yamllint.yml                 # Config de yamllint
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🔄 Workflows disponibles

### 1. `quality-checks.yml`

Lint + typecheck + tests para repos Node y/o Python, con soporte para monorepos (`shared/`, `contexts/*/`, `events/*/`).

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working-directory` | string | `.` | Carpeta con `package.json`/`pyproject.toml` |
| `node-version` | string | `20` | Versión de Node.js |
| `python-version` | string | `3.12` | Versión de Python (si hay `pyproject.toml`) |
| `run-shared-tests` | string | `'true'` | Correr tests en `shared/` (`'true'`/`'false'`) |
| `run-contexts-tests` | string | `'true'` | Correr tests en `contexts/` |
| `run-events-tests` | string | `'true'` | Correr tests en `events/` |
| `run-py-tests` | string | `'true'` | Correr `pytest` (si hay `pyproject.toml`) |
| `package-manager` | choice | `npm` | `npm` o `pnpm` |

**Comportamiento:**

- Detecta automáticamente si hay `package.json` → ejecuta job `node-quality`.
- Detecta automáticamente si hay `pyproject.toml` → ejecuta job `python-quality` (con `uv`).
- Cada job es **opt-out**, nunca rompe por ausencia de tooling.

**Ejemplo de uso:**

```yaml
# 03-backend/.github/workflows/ci.yml
jobs:
  quality-checks:
    uses: spark-match/01-devops/.github/workflows/quality-checks.yml@main
    with:
      working-directory: .
      node-version: '20'
      run-shared-tests: 'true'
      run-contexts-tests: 'true'
    secrets: inherit
```

**GitHub Secret requerido:** ninguno (solo lectura del repo).

---

### 2. `sam-deploy.yml`

Build + deploy de un stack SAM con **OIDC** + **environment approval gate**, para llamar desde cualquier repo que tenga `template.yaml` + `samconfig.toml`.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working-directory` | string | `.` | Carpeta con `template.yaml` |
| `aws-region` | string | `us-east-1` | Región AWS |
| `sam-config-env` | string | `dev` | Bloque de `samconfig.toml` a usar |
| `deploy-role-arn-secret` | string | `AWS_SAM_DEPLOY_ROLE_ARN` | Secret con ARN del role OIDC para deploy |
| `s3-bucket-secret` | string | `AWS_SAM_ARTIFACTS_BUCKET` | Secret con bucket de artifacts SAM |
| `s3-prefix` | string | `spark-match-backend` | Prefijo S3 para artifacts |
| `node-version` | string | `20` | Node para Lambda Layers |
| `python-version` | string | `3.12` | Python para Lambda Layers Python |
| `sam-version` | string | `1.143.0` | Versión de SAM CLI |
| `no-disable-rollback` | bool | `false` | Pasar `--no-disable-rollback` (recomendado en prod) |
| `no-fail-on-empty-changeset` | bool | `true` | Pasar `--no-fail-on-empty-changeset` |
| `environment` | string | `=sam-config-env` | GH Environment (approval gate) |
| `extra-args` | string | `''` | Args extra para `sam deploy` |

**GitHub Secrets requeridos:**

- `<deploy-role-arn-secret>` con ARN del role IAM con permisos de deploy SAM.
- `<s3-bucket-secret>` con el nombre del bucket de artifacts (creado por TF en Fase 2).

**Concurrencia:** usa `concurrency` group `sam-deploy-<working-directory>-<env>` para evitar deploys simultáneos al mismo environment.

**Ejemplo de uso:**

```yaml
# 03-backend/.github/workflows/deploy.yml
jobs:
  sam-deploy:
    uses: spark-match/01-devops/.github/workflows/sam-deploy.yml@main
    secrets: inherit
    with:
      working-directory: .
      sam-config-env: ${{ github.event.inputs.environment || 'dev' }}
      environment: ${{ github.event.inputs.environment || 'dev' }}
```

---

### 3. `terraform-plan.yml`

Ejecuta `terraform plan` en Pull Requests con un **role IAM de solo lectura** (vía OIDC).
**N-environment aware**: pensado para correr en una matrix `[dev, staging, prod, ...]` con secrets y backends distintos por env.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `environment` | string | `''` (basename de `working-directory`) | Identificador del env. Se usa para naming del artifact y header del sticky comment. |
| `working-directory` | string | `.` | Carpeta con el `.tf` |
| `aws-region` | string | `us-east-1` | Región AWS |
| `plan-role-arn-secret` | string | `AWS_PLAN_ROLE_ARN` | Nombre del GitHub Secret con el ARN del role de plan. Por env: `AWS_PLAN_ROLE_ARN_DEV`, `_PROD`. |
| `terraform-version` | string | `1.10.0` | Versión de Terraform |
| `backend-bucket` | string | `''` | Bucket S3 para state (vacío = sin backend) |
| `backend-key` | string | `terraform.tfstate` | Path del state file |
| `tfvars-file` | string | `''` | Archivo tfvars explícito (e.g. `prod.tfvars`). Vacío = auto-load `terraform.tfvars`. |
| `var-files` | string | `''` | Lista CSV de tfvars adicionales (additive). |
| `target` | string | `''` | `-target=...` para limitar scope del plan. |
| `extra-args` | string | `''` | Args extra raw para `terraform plan`. |
| `comment-on-pr` | boolean | `true` | Postear sticky comment en el PR (header por env). |

**Outputs:**

| Output | Descripción |
|---|---|
| `plan-exit-code` | 0 = no changes / error, 2 = changes |
| `has-changes` | `true` si hay cambios, `false` en otro caso |
| `environment` | Identificador del env (resuelto desde inputs) |

**Ejemplo de uso (matrix N envs):**

```yaml
name: CI - Terraform Plan
on:
  pull_request:
    branches: [main, dev]
jobs:
  plan:
    strategy:
      fail-fast: false
      matrix:
        include:
          - environment: dev
            working-directory: live/dev
            backend-bucket: spark-match-tfstate-dev
            backend-key: dev/terraform.tfstate
            plan-role-arn-secret: AWS_PLAN_ROLE_ARN_DEV
          - environment: prod
            working-directory: live/prod
            backend-bucket: spark-match-tfstate-prod
            backend-key: prod/terraform.tfstate
            plan-role-arn-secret: AWS_PLAN_ROLE_ARN_PROD
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-plan.yml@main
    secrets: inherit
    with:
      environment: ${{ matrix.environment }}
      working-directory: ${{ matrix.working-directory }}
      backend-bucket: ${{ matrix.backend-bucket }}
      backend-key: ${{ matrix.backend-key }}
      plan-role-arn-secret: ${{ matrix.plan-role-arn-secret }}
      tfvars-file: ${{ matrix.tfvars-file }}
```

**Notas:**

- Cada job de la matrix produce un **artifact con nombre distinto** (`terraform-plan-{env}-pr-{N}`) y un **sticky comment con header por env** (`terraform-plan-dev`, `terraform-plan-prod`), evitando colisiones.
- El fix clave: `has-changes` ahora es `false` cuando `plan` retorna exit 0 (no changes). La versión vieja tenia el logica invertida.

### 4. `terraform-apply.yml`

Ejecuta `terraform plan` + `terraform apply` con **role IAM de escritura** (vía OIDC).
Soporta GH Environment como approval gate, opcionalmente con `auto-approve` para dev.
Soporta `drift-only` para correr solo plan (útil para cron jobs de drift detection).
**N-environment aware**: pensado para invocarse 1 vez por env desde el caller.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `environment` | string | `''` (basename de `working-directory`) | Identificador del env. Usado para naming, concurrency, display. |
| `gh-environment` | string | `''` | GH Environment para approval gate. Falls back to `environment`. |
| `working-directory` | string | `.` | Carpeta con el `.tf` |
| `aws-region` | string | `us-east-1` | Región AWS |
| `apply-role-arn-secret` | string | `AWS_APPLY_ROLE_ARN` | Nombre del GitHub Secret con el ARN. Por env: `AWS_APPLY_ROLE_ARN_DEV`, `_PROD`. |
| `terraform-version` | string | `1.10.0` | Versión de Terraform |
| `backend-bucket` | string | `''` | Bucket S3 para state |
| `backend-key` | string | `terraform.tfstate` | Path del state file |
| `tfvars-file` | string | `''` | Archivo tfvars explícito |
| `var-files` | string | `''` | Lista CSV de tfvars adicionales |
| `target` | string | `''` | `-target=...` para scope reducido |
| `extra-args` | string | `''` | Args extra raw para `terraform plan` |
| `auto-approve` | boolean | `false` | `true` salta el approval gate (el GH Environment no debe tener reviewers). Solo para dev. |
| `drift-only` | boolean | `false` | `true` corre solo plan, NO aplica. Útil para cron de drift detection. |

**Outputs:**

| Output | Descripción |
|---|---|
| `apply-success` | `true`/`false` |
| `has-changes` | `true`/`false` |
| `environment` | Identificador del env |

**Concurrencia:** Group `${{ inputs.environment || working-directory }}-apply-${{ working-directory }}`. Evita applies concurrentes al mismo env/dir.

**Ejemplo de uso (2-env):**

```yaml
name: CD - Terraform Apply
on:
  push:
    branches: [dev, main]
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, prod]
jobs:
  apply-dev:
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'dev'
       || (github.event_name == 'push' && github.ref == 'refs/heads/dev')
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-apply.yml@main
    secrets: inherit
    with:
      environment: dev
      gh-environment: dev
      working-directory: live/dev
      backend-bucket: spark-match-tfstate-dev
      backend-key: dev/terraform.tfstate
      apply-role-arn-secret: AWS_APPLY_ROLE_ARN_DEV
      auto-approve: true
  apply-prod:
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
       || (github.event_name == 'push' && github.ref == 'refs/heads/main')
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-apply.yml@main
    secrets: inherit
    with:
      environment: prod
      gh-environment: production
      working-directory: live/prod
      backend-bucket: spark-match-tfstate-prod
      backend-key: prod/terraform.tfstate
      apply-role-arn-secret: AWS_APPLY_ROLE_ARN_PROD
      auto-approve: false
```

**Notas:**

- **`-lock=false` en el plan interno**: para que el `apply` (siguiente step) pueda adquirir el S3 native lockfile sin conflicto.
- **`auto-approve=true`** debe coincidir con un GH Environment SIN reviewers. NO usar en prod.
- **`drift-only=true`** postea el resumen pero no aplica. Ideal para `on: schedule: - cron: '0 8 * * *'`.

### 5. `latex-build.yml`

Compila un documento LaTeX y sube el PDF como artifact.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `root-file` | string | `main.tex` | Archivo LaTeX raíz |
| `artifact-name` | string | `latex-build` | Nombre del artifact |
| `retention-days` | number | `14` | Días de retención |
| `use-lualatex` | boolean | `false` | Usar LuaLaTeX en vez de pdfLaTeX |
| `shell-escape` | boolean | `false` | Habilitar shell-escape (¡cuidado!) |

**Ejemplo:**

```yaml
name: CI - Build PDF
on:
  pull_request:
    branches: [main]
    paths: ['**.tex', '**.bib', 'figures/**']
jobs:
  build:
    uses: spark-match/spark-match-01-devops/.github/workflows/latex-build.yml@main
    with:
      root-file: main.tex
      artifact-name: paper-pr-${{ github.event.pull_request.number }}
```

### 6. `latex-release.yml`

Compila LaTeX, auto-bumpea la versión patch desde el último tag, y publica un GitHub Release con el PDF.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `root-file` | string | `main.tex` | Archivo LaTeX raíz |
| `release-name-prefix` | string | `Release` | Prefijo del nombre del release |
| `release-body-template` | string | (empty) | Markdown adicional para el body |

**Ejemplo:**

```yaml
name: CD - Release on Merge
on:
  pull_request:
    types: [closed]
jobs:
  release:
    if: github.event.pull_request.merged == true
    uses: spark-match/spark-match-01-devops/.github/workflows/latex-release.yml@main
    with:
      root-file: main.tex
      release-name-prefix: Spark Match Paper
```

---

## 🛠️ Setup OIDC (una vez por repo caller)

Para que un caller use los workflows de Terraform, necesita:

1. **GitHub Secret** con el ARN del role IAM:
   ```bash
   gh secret set AWS_PLAN_ROLE_ARN \
     --repo spark-match/<repo-caller> \
     --body "arn:aws:iam::681526276858:role/spark-match-terraform-plan"
   ```

2. **Trust policy** del role IAM incluye el repo caller (ver `docs/oidc-setup/` en `spark-match-02-infrastructure`).

3. **GitHub Environment** (solo para apply) configurado con branch policy y reviewers.

---

## 📋 Repos que consumen estos pipelines

| Repo | Pipeline usado | Estado |
|---|---|---|
| `spark-match-02-infrastructure` | `terraform-plan.yml`, `terraform-apply.yml` | ✅ |
| `spark-match-03-backend` | `quality-checks.yml`, `sam-deploy.yml` | ✅ |
| `spark-match-07-article` | `latex-build.yml`, `latex-release.yml` | ✅ |
| `spark-match-08-deep-agent` | `quality-checks.yml` (planeado) | ⏳ |

---

## ➕ Cómo extender Terraform pipelines a N ambientes

Los reusables `terraform-plan.yml` y `terraform-apply.yml` están diseñados
para soportar N ambientes sin modificar el reusable. Solo se ajusta el caller.

### Para agregar un nuevo env (ejemplo: `staging`)

1. **Bucket S3** para el state:
   ```bash
   ENVIRONMENT=staging ./scripts/bootstrap-backend.sh
   ```

2. **GitHub Secrets** (1 por role + env):
   ```bash
   gh secret set AWS_PLAN_ROLE_ARN_STAGING  --body "arn:aws:iam::...:role/spark-match-terraform-plan-staging"
   gh secret set AWS_APPLY_ROLE_ARN_STAGING --body "arn:aws:iam::...:role/spark-match-terraform-apply-staging"
   ```

3. **GitHub Environments** `staging` (con branch policy `staging` y reviewers opcionales).

4. **Caller** — agregar entrada en la matrix de plan + nuevo job en apply:
   ```yaml
   # terraform-plan.yml
   jobs:
     plan:
       strategy:
         matrix:
           include:
             - environment: dev
               working-directory: live/dev
               backend-bucket: spark-match-tfstate-dev
               backend-key: dev/terraform.tfstate
               plan-role-arn-secret: AWS_PLAN_ROLE_ARN_DEV
             - environment: staging                # NUEVO
               working-directory: live/staging
               backend-bucket: spark-match-tfstate-staging
               backend-key: staging/terraform.tfstate
               plan-role-arn-secret: AWS_PLAN_ROLE_ARN_STAGING
             - environment: prod
               working-directory: live/prod
               backend-bucket: spark-match-tfstate-prod
               backend-key: prod/terraform.tfstate
               plan-role-arn-secret: AWS_PLAN_ROLE_ARN_PROD
       uses: spark-match/spark-match-01-devops/.github/workflows/terraform-plan.yml@main
       with:
         environment: ${{ matrix.environment }}
         working-directory: ${{ matrix.working-directory }}
         # ... (resto igual)
   ```

   ```yaml
   # terraform-apply.yml
   jobs:
     apply-staging:                                # NUEVO
       if: github.ref == 'refs/heads/staging' || ...
       uses: spark-match/spark-match-01-devops/.github/workflows/terraform-apply.yml@main
       secrets: inherit
       with:
         environment: staging
         gh-environment: staging
         working-directory: live/staging
         backend-bucket: spark-match-tfstate-staging
         backend-key: staging/terraform.tfstate
         apply-role-arn-secret: AWS_APPLY_ROLE_ARN_STAGING
         auto-approve: true
   ```

5. **IAM roles** — si querés estricto (recomendado), crear `spark-match-terraform-{plan,apply}-staging` con trust policy restringida.

### Lo que NO hay que tocar

- El reusable `terraform-plan.yml` y `terraform-apply.yml`.
- Otros callers (repos como `03-backend`).

---

1. Crear archivo `.github/workflows/<nombre>.yml` con `on: workflow_call`
2. Definir `inputs:` documentados
3. Definir `outputs:` si es relevante
4. Documentar en este README (tabla + ejemplo de uso)
5. Hacer PR → CODEOWNERS (`@spark-match/devops` + `@spark-match/product-owners`) aprueba
6. Consumir desde otros repos con `uses: spark-match/spark-match-01-devops/.github/workflows/<nombre>.yml@main`

---

## 🔐 Seguridad

- Los workflows usan **OIDC** (no access keys)
- Los roles IAM tienen permisos mínimos (read-only para plan, write para apply)
- Apply requiere **GitHub Environment approval** (no se ejecuta automáticamente)
- Los workflows validan formato (`fmt -check`) y config (`validate`) antes de plan/apply

---

## 🛡️ CI Lint & Security Checks

Este repo tiene su propio CI (`.github/workflows/ci.yml`) que corre en cada PR con **3 checks requeridos**:

| Check | Qué valida | Herramienta |
|---|---|---|
| **actionlint** | Sintaxis de workflows de GitHub Actions | `rhysd/actionlint` |
| **gitleaks** | Secretos commiteados por error | `gitleaks/gitleaks-action@v1` |
| **yamllint** | Sintaxis de archivos YAML genéricos | `yamllint` + `.yamllint.yml` |

Estos checks están configurados como **required status checks** en la branch protection de `main`. Cualquier PR debe pasar los 3 antes de poder mergearse.

### Configuración yamllint

El archivo `.yamllint.yml` configura reglas permisivas para evitar fricción:
- Líneas hasta 160 caracteres (workflows tienen líneas largas)
- Truthy values como `on`/`off` permitidos
- Comentarios flexibles

### Configuración gitleaks

Usa la versión `v1` (no requiere licencia para organizaciones).
Detecta access keys de AWS, tokens de GitHub, API keys, etc.

---

## 📝 Versionado

Los callers referencian este repo con `@main`. Para producción real, se recomienda:

```yaml
uses: spark-match/spark-match-01-devops/.github/workflows/terraform-plan.yml@v1.0.0
```

Y crear tags en este repo cuando los workflows cambien de forma breaking.

Por ahora, mientras el proyecto está en desarrollo, usamos `@main` para simplificar.

---

## Licencia

MIT — ver [LICENSE](LICENSE).