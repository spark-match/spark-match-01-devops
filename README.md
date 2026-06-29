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
│       ├── terraform-plan.yml    # Plan de Terraform (read-only, en PR)
│       ├── terraform-apply.yml   # Apply de Terraform (write, en merge)
│       ├── latex-build.yml       # Compilar LaTeX → PDF (en PR)
│       └── latex-release.yml     # Compilar + tag + release (en merge)
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🔄 Workflows disponibles

### 1. `terraform-plan.yml`

Ejecuta `terraform plan` en Pull Requests con un **role IAM de solo lectura** (vía OIDC).

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working-directory` | string | (required) | Carpeta con el `.tf` |
| `aws-region` | string | `us-east-1` | Región AWS |
| `plan-role-arn-secret` | string | `AWS_PLAN_ROLE_ARN` | Nombre del GitHub Secret con el ARN |
| `terraform-version` | string | `1.10.0` | Versión de Terraform |
| `backend-bucket` | string | `''` | Bucket S3 para state (vacío = sin backend) |
| `backend-key` | string | `terraform.tfstate` | Path del state file |
| `comment-on-pr` | boolean | `true` | Postear resumen en el PR |

**Ejemplo de uso (en el caller):**

```yaml
name: CI - Terraform Plan
on:
  pull_request:
    branches: [main]
    paths: ['**.tf', '**.tfvars', '.github/workflows/**']
jobs:
  plan:
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-plan.yml@main
    with:
      working-directory: live/prod
      aws-region: us-east-1
      backend-bucket: spark-match-tfstate-prod
      backend-key: prod/terraform.tfstate
```

### 2. `terraform-apply.yml`

Ejecuta `terraform apply` con **role IAM de escritura**. Requiere aprobación vía GitHub Environment.

**Inputs:**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working-directory` | string | (required) | Carpeta con el `.tf` |
| `aws-region` | string | `us-east-1` | Región AWS |
| `apply-role-arn-secret` | string | `AWS_APPLY_ROLE_ARN` | Nombre del GitHub Secret con el ARN |
| `terraform-version` | string | `1.10.0` | Versión de Terraform |
| `backend-bucket` | string | `''` | Bucket S3 para state |
| `backend-key` | string | `terraform.tfstate` | Path del state file |
| `environment` | string | `production` | GitHub Environment (approval gate) |

**Concurrencia:** Usa `concurrency` group para evitar applies concurrentes al mismo environment.

**Ejemplo de uso:**

```yaml
name: CD - Terraform Apply
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  apply:
    uses: spark-match/spark-match-01-devops/.github/workflows/terraform-apply.yml@main
    with:
      working-directory: live/prod
      aws-region: us-east-1
      backend-bucket: spark-match-tfstate-prod
      backend-key: prod/terraform.tfstate
      environment: production
```

### 3. `latex-build.yml`

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

### 4. `latex-release.yml`

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
| `spark-match-07-article` | `latex-build.yml`, `latex-release.yml` | ✅ |

---

## 🆕 Cómo agregar un nuevo pipeline

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