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

## Catalogo de recipes (v4)

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
+-- node-test.yml                # Atomic (node): npm run <test-script>, vitest/jest, pre-test hook
+-- python-ci.yml                # Atomic (python): uv + ruff + mypy + pytest (or-cog-agent, otros proyectos Python uv-based)
+-- sam-deploy.yml               # Atomic (deploy): sam build + deploy, samconfig env, layers build
+-- angular-spa-deploy.yml       # Atomic (deploy): Angular SPA -> S3 + CloudFront, build + sync + invalidate
+-- container-deploy-ecr.yml     # Atomic (deploy): docker buildx + ECR push (or-cog-agent, otros proyectos container-based)
+-- latex-build.yml              # Atomic (article-side): latexmk → PDF
+-- latex-release.yml            # Atomic (article-side): release of compiled PDF
```

### Que cambio v3 -> v4 (PR #62, #65, #67)

| Cambio | Recetas afectadas | PR |
|---|---|---|
| Cache key: lowercase + pkgmanager + env + single lockfile hash | `eslint.yml`, `angular-spa-deploy.yml`, `sam-deploy.yml` | #62 |
| Disable `setup-node@v7` built-in auto-cache to avoid double-key | (las mismas) | #62 |
| Enriched deploy summary (CF domain, bundle fingerprint, sync counts) | `angular-spa-deploy.yml` | #67 |
| New `node-test.yml` reusable (vitest/jest) | new | #65 |

Detalles tecnicos de la convencion cache: ver [`docs/CACHE.md`](CACHE.md).

### `angular-spa-deploy.yml`

Build de un SPA Angular via `npm ci` + `npm run build`, sync a S3 con
`--delete`, y `cloudfront create-invalidation`. Inputs clave: `s3-bucket`,
`cloudfront-distribution-id`, `node-version`, `pkg-manager`, `lockfile-name`,
`build-script`, `artifact-path`, `api-url` (env var de frontend inyectada al
build). Secret: `AWS_DEPLOY_ROLE_ARN` (restringido al bucket + distribution
especifico via trust policy + inline IAM policy del modulo
`iam-angular-spa-deploy-dev` en `orion-infrastructure`).

Pattern complementario a `sam-deploy.yml`: este no usa SAM, sino
directamente `aws s3 sync` + `aws cloudfront create-invalidation`. Adecuado
para SPAs Angular/React/Vue estaticos sin backend serverless.

El step summary expone: bundle fingerprint (`main-*.js` + `styles-*.css`),
files in bundle, bundle bytes, S3 uploaded/deleted counts, CloudFront
domain (live URL), invalidation id.

### `node-test.yml`

Reusable para tests unitarios JS/TS (vitest/jest/mocha). Inputs clave:
`environment-name`, `node-version`, `pkg-manager`, `lockfile-name`,
`pre-test-script` (util para callers Angular que necesitan materializar
`api-config.generated.ts`), `test-script` (default `test`, los callers
pueden sobreescribir con flags, e.g. `test -- --watch=false`). Sin
secrets.

Cache key sigue la convencion canonica v4 (ver `docs/CACHE.md`). El job
se llama `unit tests (env=<env>)`. Caller tipico:
`orion-frontend` (Angular 22 + vitest) y futuros consumers como
`orion-backend` cuando exista.

### Por que no usamos subcarpetas (limitacion de GH Actions)

GitHub Actions requiere que los reusable workflows esten en **top-level** de `.github/workflows/`. La referencia `uses: ./path/to/subfolder/file.yml` falla con `invalid value workflow reference: workflows must be defined at the top level of the .github/workflows/ directory`. Por eso todos los reusables viven al mismo nivel que `ci.yml`, `codeql.yml`, etc. El layer (ecosystem / node / deploy) se codifica en el **documento VERSIONING (este archivo)** + etiquetas en el nombre del job (`actionlint (env=...)`).

### Convencion de inputs

Todas las recipes aceptan al menos `environment-name` (informativo: loggeado en el job name y steps). Las recipes de deploy lo usan ademas como **GH Environment gate** (caller debe tener un GH Environment con ese nombre y el secret AWS_DEPLOY_ROLE_ARN/CFN_ROLE_ARN dentro).

### Reglas del catalogo

- **Sin acoplamiento interno entre layers.** Cada recipe es invocable independiente. Un caller puede usar solo `actionlint.yml` + `sam-deploy.yml` sin tomar `yamllint.yml` o `eslint.yml`.
- **Secrets solo en recipes de deploy.** Las recipes de ecosystem y node no reciben secrets (checks de codigo estatico puro).
- **Cross-owner friendly.** Las recipes usan `secrets:` por nombre explicito (e.g. `AWS_DEPLOY_ROLE_ARN`) y esperan que el caller los pase con `secrets: inherit` o explicito. Esto evita el bloqueo de GitHub para callers cross-owner (ahincho/orion-backend -> spark-match).
- **Pin de herramientas externas.** actionlint v1.7.7, yamllint 1.35.1, eslint version parametrizable via input, terraform version parametrizable via input, sam-cli version parametrizable via input.

### Como prueba de cambios

1. `ci.yml` (self-test) corre los 3 ecosystem recipes sobre este repo en cada PR.
2. Cambios que afectan a recipes de `python/`, `node/` o `deploy/` requieren un caller externo para smoke test:
   - `python-ci.yml`: smoke test en `orion-cognitive-agent@dev`
   - `node/eslint.yml`: smoke test en `orion-frontend@dev`
   - `deploy/sam-deploy.yml`: smoke test en `orion-backend@dev`
   - `deploy/container-deploy-ecr.yml`: smoke test en `orion-cognitive-agent@dev`
   - `deploy/terraform-plan.yml` + `deploy/terraform-apply.yml`: smoke test en `orion-infrastructure@dev`
3. Una vez verde en `ci.yml` + smoke test en el caller externo, el cambio se promueve a `main` con un PR `dev` -> `main`.
