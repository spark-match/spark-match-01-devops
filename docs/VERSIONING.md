# Versionado de 01-devops

> **Decision (2026-07)**: NO usamos SemVer en el corto plazo.

## Modelo: pin por ambiente

Los callers referencian el reusable de la rama que corresponde al ambiente destino:

- Caller deploy a **dev** → `uses: .../terraform-apply.yml@dev` (reusable de la rama `dev` de `01-devops`)
- Caller deploy a **prod** → `uses: .../terraform-apply.yml@main` (reusable de la rama `main` de `01-devops`)

## Por que este modelo (en vez de SemVer)

Queremos que los cambios en `01-devops` se prueben primero contra deploys a dev (donde romper esta permitido) antes de promoverlos a `main` (que afecta deploys a prod). Es la misma logica que aplicamos al codigo de aplicacion: `dev` es donde se cocina, `main` es lo estable para prod.

## Trade-off

- Un cambio en `01-devops@dev` solo rompe los deploys a dev. Prod no se ve afectado.
- La promocion a `main` del reusable es deliberada (via PR aprobado) = release de facto.
- Si un caller no respeta el pin por ambiente y deja todo en `@main`, un cambio mal hecho en `01-devops@main` afecta dev y prod simultaneamente. **Auditar cada consumer para que tenga callers separados por env.**

## Cuando se justificara SemVer

Si en algun momento queremos publicar versiones estables de los reusables para terceros (no solo los repos internos de spark-match), se haria un tag `vX.Y.Z` en `main` despues de un periodo de prueba en `dev`. Esto requeriria:

1. PR para configurar el proceso de release (crear GitHub Action que tagge automaticamente, etc.)
2. Migrar los callers a usar la version fija.
3. Mantener un CHANGELOG.md con breaking changes.

Mientras tanto, los callers internos referencian `@dev` o `@main` segun el ambiente destino.

## Catalogo de recipes (v3)

Estructura actual bajo `.github/workflows/`:

```
.github/workflows/
+-- ci.yml                       # Self-test: PR-triggered wrapper que llama los atomic reusables
+-- codeql.yml                   # Reusable: CodeQL matrix (lenguaje 'actions', weekly + push + PR)
+-- terraform-plan.yml           # Reusable: tf plan (N-env, OIDC, sf-sticky-comments)
+-- terraform-apply.yml          # Reusable: tf apply con approval gate (N-env, OIDC)
+-- actionlint.yml               # Atomic (ecosystem): GH Actions syntax validation
+-- gitleaks.yml                 # Atomic (ecosystem): secret scanning (gitleaks v1 pin)
+-- yamllint.yml                 # Atomic (ecosystem): YAML files
+-- terraform-fmt.yml            # Atomic (ecosystem): terraform fmt
+-- terraform-validate.yml       # Atomic (ecosystem): terraform init -backend=false + validate
+-- tflint.yml                   # Atomic (ecosystem): tflint --recursive
+-- checkov.yml                  # Atomic (ecosystem): checkov SCA
+-- eslint.yml                   # Atomic (node): npm run <lint-script>, eslint-version parametrizable
+-- python-ci.yml                # Atomic (python): uv + ruff + mypy + pytest (or-cog-agent, otros proyectos Python uv-based)
+-- sam-deploy.yml               # Atomic (deploy): sam build + deploy, samconfig env, layers build
+-- angular-spa-deploy.yml       # Atomic (deploy): Angular SPA -> S3 + CloudFront, build + sync + invalidate
+-- container-deploy-ecr.yml     # Atomic (deploy): docker buildx + ECR push (or-cog-agent, otros proyectos container-based)
+-- migrations.yml               # Atomic (deploy): invokes orion-identity-migrate-<env> Lambda (synchronous, {applied, alreadyApplied, missing} summary parser)
+-- migrations-dry-run.yml       # Atomic (ecosystem): node-pg-migrate --dry-run contra Postgres service container
+-- aws-lambda-invoke.yml        # Atomic (deploy): generic Lambda invoke (custom summary via jq). Generic sibling of migrations.yml; no role-specific UX
+-- seed-users-advisors.yml      # Atomic (deploy): invokes orion-seed-users-<env> Lambda con payload {"group":"advisors"}, parsea {created, skipped, errors}
+-- seed-users-supervisors.yml   # Atomic (deploy): idem advisors pero con payload {"group":"supervisors"}
+-- seed-users-agents.yml        # Atomic (deploy): idem advisors pero con payload {"group":"agents"}
+-- latex-build.yml              # Atomic (article-side): latexmk → PDF
+-- latex-release.yml            # Atomic (article-side): release of compiled PDF
```

### `angular-spa-deploy.yml`

Build de un SPA Angular via `npm ci` + `npm run build`, sync a S3 con
`--delete`, y `cloudfront create-invalidation`. Inputs clave: `s3-bucket`,
`cloudfront-distribution-id`, `node-version`, `build-script`, `artifact-path`,
`api-url` (env var de frontend inyectada al build). Secret: `AWS_DEPLOY_ROLE_ARN`
(restringido al bucket + distribution especifico via trust policy + inline IAM
policy del modulo `iam-angular-spa-deploy-dev` en `orion-infrastructure`).

Pattern complementario a `sam-deploy.yml`: este no usa SAM, sino
directamente `aws s3 sync` + `aws cloudfront create-invalidation`. Adecuado
para SPAs Angular/React/Vue estaticos sin backend serverless.

### `aws-lambda-invoke.yml`

Invoca una Lambda arbitraria sincronamente via OIDC y falla el workflow
en cualquier StatusCode != 200 o FunctionError no vacio. Inputs clave:
`environment-name` (gate + concurrency key), `function-name` (target),
`payload` (default `{}`), `aws-region` (default `us-east-1`),
`timeout-minutes` (default 5), `summary-jq` (opcional: expression jq
para imprimir una linea de summary si el body parsea como JSON). Secret:
`AWS_DEPLOY_ROLE_ARN`.

Es el sibling generico de `migrations.yml`: cualquier recipe futura que
solo necesite "invoke esta Lambda y checkear 200 + sin FunctionError"
puede usar este sin copy-paste de los pasos de AWS config + invoke +
validation. NO declara `environment:` en su job (resuelto en callee
repo, no caller; PR #96 diagnostico completo). Los 3 recipes
`seed-users-{advisors,supervisors,agents}.yml` siguen el mismo patron
con su propio parser de summary `{created, skipped, errors}` porque la
UX role-specific (job display name, step labels) gana con ser bespoke.

### `seed-users-{advisors,supervisors,agents}.yml`

Invocan la Lambda `orion-seed-users-<env>` con payload
`{"group":"<role>"}` para sembrar los usuarios del rol correspondiente
en `identity.users`. Cada recipe es self-contained (no hace nested
reusable call a `aws-lambda-invoke.yml`) — la copia explicita del AWS
config + invoke + validate se prefiere sobre la indireccion de nested
reusables dado el tamano (~80 lineas) y el beneficio marginal de DRY.
Lambda contract: retorna `{created, skipped, errors: [{email, code,
message}]}`; cada recipe parsea ese shape y falla el step si
`errors.length > 0` (dumping cada entry para triage).

Los 3 recipes viven en concurrency groups separados
(`seed-users-advisors-<env>`, etc) para que advisors/supervisors/
agents puedan correr en paralelo sin race por el advisory lock del
DB. `cancel-in-progress: false` — nunca cancelar un seed a mitad
de vuelo (dejaria la DB inconsistente).

Target Lambda provisionada por `orion-infrastructure/modules/seed-users`
(role ARN + secret ARN + SSM param), deployada por `orion-backend` en
Stage 6 del user-management plan. Caller (orion-backend) es responsable
de declarar `environment: <env>` en workflow o preflight-job level.

### Por que no usamos subcarpetas (limitacion de GH Actions)

GitHub Actions requiere que los reusable workflows esten en **top-level** de `.github/workflows/`. La referencia `uses: ./path/to/subfolder/file.yml` falla con `invalid value workflow reference: workflows must be defined at the top level of the .github/workflows/ directory`. Por eso todos los reusables viven al mismo nivel que `ci.yml`, `codeql.yml`, etc. El layer (ecosystem / node / deploy) se codifica en el **documento VERSIONING (este archivo)** + etiquetas en el nombre del job (`actionlint (env=...)`).

### Convencion de inputs

Todas las recipes aceptan al menos `environment-name` (informativo: loggeado en el job name y steps). Las recipes de deploy lo usan ademas como **GH Environment gate** (caller debe tener un GH Environment con ese nombre y el secret AWS_DEPLOY_ROLE_ARN/CFN_ROLE_ARN dentro).

### Reglas del catalogo

- **Sin acoplamiento interno entre layers.** Cada recipe es invocable independiente. Un caller puede usar solo `actionlint.yml` + `sam-deploy.yml` sin tomar `yamllint.yml` o `eslint.yml`.
- **Secrets solo en recipes de deploy.** Las recipes de ecosystem y node no reciben secrets (checks de codigo estatico puro).
- **Cross-owner friendly.** Las recipes usan `secrets:` por nombre explicito (e.g. `AWS_DEPLOY_ROLE_ARN`) y esperan que el caller los pase con `secrets: inherit` o explicito. Esto evita el bloqueo de GitHub para callers cross-owner (ahincho/orion-backend -> spark-match).
- **Pin de herramientas externas.** actionlint v1.7.7, yamllint 1.35.1, eslint version parametrizable via input, terraform version parametrizable via input, sam-cli version parametrizable via input.

### Cache semantics (per-environment + per-Python-version)

A partir del recipe `python-ci.yml` v3.1, las dependencias gestionadas por
`uv` se cachean en GH Actions con una clave **compuesta**:

```
cache-key = setup-uv-ubuntu-latest-<cache-suffix>-<hash(pyproject+uv.lock)>
```

donde `<cache-suffix>` se deriva por defecto de
`environment-name` + `python-versions`. Esto garantiza tres
aislamientos:

| Dimension | Mecanismo | Razon |
|---|---|---|
| **per-ambiente** | `cache-suffix` incluye `environment-name` | `ci`, `dev`, `prod` no comparten cache aunque lockfiles colisionen (e.g. `--group bedrock` vs `--group market`) |
| **per-Python-version** | (a) `cache-suffix` incluye `python-versions` + (b) cada matrix leg es un job GH Actions separado | un caller que valida `python-versions: '"3.11","3.12"'` no envenena la cache de un pin `3.12`-only |
| **per-proyecto** | `cache-dependency-glob` hashea `pyproject.toml` + `uv.lock` | monorepos con multiples `working-directory` no comparten |

**Override:** un caller puede pasar `cache-suffix` explicitamente
(e.g. `'${{ inputs.environment-name }}-${{ inputs.python-versions }}-${{ github.run_id }}'`)
si quiere purga cache en cada run (raro; casi siempre no se necesita).

**Backward compatibility:** recipes con un solo `python-version` y un
solo `environment-name` ven `cache-suffix` igual al hash anterior. Los
callers existentes no requieren cambios.

> Ver tambien: `docs/PYTHON-CI.md` § 4 ("Cache key formula") para la
> referencia canonica del recipe `python-ci.yml`, y `docs/CACHE.md` § 1
> para la convencion cross-ecosystem (node, terraform, etc.).

### Como prueba de cambios

1. `ci.yml` corre los 3 ecosystem recipes (actionlint, gitleaks, yamllint)
   sobre este repo en cada PR. Detecta regresiones de lint/secret/yaml-format
   en el catalog mismo, pero **no** ejecuta los reusables de `python/`,
   `node/` ni `deploy/` — este repo no tiene proyecto Node, SAM, Python ni
   Terraform donde correrlos.
2. Cada recipe se valida cuando un caller repo la invoca desde su propio
   PR. Mapeo canonico (`dev` branch mientras la feature no esta en `main`,
   `@main` una vez promovida):
   - `python-ci.yml`: `orion-cognitive-agent@dev` (caller canonico de produccion)
   - `eslint.yml`, `node-test.yml`: `orion-frontend@dev`
   - `sam-deploy.yml`: `orion-backend@dev`
   - `container-deploy-ecr.yml`: `orion-cognitive-agent@dev`
   - `terraform-plan.yml`, `terraform-apply.yml`, y los ecosystem
     recipes de Terraform (`terraform-fmt`, `terraform-validate`,
     `tflint`, `checkov`, `cfn-nag`): `orion-infrastructure@dev`
   - `actionlint.yml`, `gitleaks.yml`, `yamllint.yml`, `lambda-permission-source-arn.yml`:
     `ci.yml` local (ver punto 1)
3. Si la PR cambia un input o agrega un paso al recipe, el reviewer pide
   smoke test explicito del caller correspondiente antes de promover
   `dev` -> `main`. Es responsabilidad del PR author, no automatizable
   sin reintroducir la dependencia cross-owner que esta arquitectura
   evito.
