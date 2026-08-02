# Versionado de 01-devops

> **Decision (2026-07)**: NO usamos SemVer en el corto plazo.

## Modelo: single-main-branch con smoke test del caller

Una sola rama `main` es la fuente canónica de todos los reusables. Los callers
siempre referencian `@main`:

- Caller deploy a **dev** → `uses: .../terraform-apply.yml@main` (mismo reusable, ambiente seleccionado via `environment-name`)
- Caller deploy a **prod** → `uses: .../terraform-apply.yml@main` (mismo reusable, ambiente seleccionado via `environment-name`)

La distincion dev/prod vive en:

1. El **input `environment-name`** que el caller pasa al recipe (gate de GH Environment).
2. El **secret `*_DEPLOY_ROLE_ARN`** que el caller inyecta (ARN distinto por ambiente).
3. El **workflow caller** del repo consumidor que arma el job con la combinacion env + ARN correcta.

## Por que este modelo (en vez de pin por ambiente)

Consolidar sobre `main` elimina la doble fuente de verdad que producia el modelo
anterior (`dev` para probar, `main` para prod):

- **Un cambio se prueba en el caller real, no en un ambient proxy.** El PR contra `main` referencia el SHA del recipe que se va a mergear; el caller corre sus tests contra ese SHA exacto antes de aprobar.
- **Drift reducido.** No hay periodo donde `dev` y `main` divergen silenciosamente, ni riesgo de olvidar promover un fix.
- **Reglas unicas.** El ruleset + CODEOWNERS (transicion gradual a `required_reviewers` por team; el plan historico vivia en un doc externo que se retiro) protege la unica rama que importa.
- **Rollback trivial.** `git revert` + push restaura el estado anterior sin coordination entre ramas.

## Trade-off

- Cada PR contra `main` requiere que **al menos un caller canonico** (definido en § "Como prueba de cambios") valide el cambio antes del merge. Si el caller esta apagado o no puede validar (e.g. AWS cost), el reviewer exige evidencia explicita (logs de `act`, salida de tests locales, dry-run output).
- Un cambio mal hecho en `main` afecta a **todos los callers simultaneamente**. Esto es exactamente lo que el CODEOWNERS + reviewer obligatorio mitiga.
- No hay anillo de prueba "barato" antes de prod. La mitigacion es la regla de smoke test obligatoria + cherry-pick rapido si algo falla (no hay nada que re-promover).

## Cuando se justificara SemVer

Si en algun momento queremos publicar versiones estables de los reusables para terceros (no solo los repos internos de spark-match), se haria un tag `vX.Y.Z` en `main` despues de un periodo de smoke test con los callers canonicos. Esto requeriria:

1. PR para configurar el proceso de release (crear GitHub Action que taggee automaticamente, etc.)
2. Migrar los callers a usar la version fija.
3. Mantener un CHANGELOG.md con breaking changes.

Mientras tanto, los callers internos referencian `@main` y confian en el ruleset + CODEOWNERS + reviewer obligatorio.

## Catalogo de recipes (v4 cache-key convention)

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
+-- terraform-validate.yml       # Atomic (ecosystem): terraform init -backend=false + validate
+-- tflint.yml                   # Atomic (ecosystem): tflint --recursive
+-- checkov.yml                  # Atomic (ecosystem): checkov SCA
+-- trivy.yml                    # Atomic (ecosystem): Trivy fs/image/config scan (SHA-pinned v0.36.0)
+-- sbom-release.yml             # Internal: CycloneDX SBOM attached to GitHub Release on release:published (anchore/sbom-action v0.17.7)
+-- eslint.yml                   # Atomic (node): npm run <lint-script>, eslint-version parametrizable
+-- python-ci.yml                # Atomic (python): uv + ruff + mypy + pytest (or-cog-agent, otros proyectos Python uv-based)
+-- container-deploy-ecr.yml     # Atomic (deploy): docker buildx + ECR push (or-cog-agent, otros proyectos container-based)
+-- migrations-dry-run.yml       # Atomic (ecosystem): node-pg-migrate --dry-run contra Postgres service container
+-- latex-build.yml              # Atomic (article-side): latexmk → PDF
+-- latex-release.yml            # Atomic (article-side): release of compiled PDF
```

### Por que no usamos subcarpetas (limitacion de GH Actions)

GitHub Actions requiere que los reusable workflows esten en **top-level** de `.github/workflows/`. La referencia `uses: ./path/to/subfolder/file.yml` falla con `invalid value workflow reference: workflows must be defined at the top level of the .github/workflows/ directory`. Por eso todos los reusables viven al mismo nivel que `ci.yml`, `codeql.yml`, etc. El layer (ecosystem / node / deploy) se codifica en el **documento VERSIONING (este archivo)** + etiquetas en el nombre del job (`actionlint (env=...)`).

### Convencion de inputs

Todas las recipes aceptan al menos `environment-name` (informativo: loggeado en el job name y steps). Las recipes de deploy lo usan ademas como **GH Environment gate** (caller debe tener un GH Environment con ese nombre y el secret AWS_DEPLOY_ROLE_ARN/CFN_ROLE_ARN dentro).

### Reglas del catalogo

- **Sin acoplamiento interno entre layers.** Cada recipe es invocable independiente. Un caller puede usar solo `actionlint.yml` + `python-ci.yml` sin tomar `yamllint.yml` o `eslint.yml`.
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
   PR contra `main`. Mapeo canonico (todos los callers usan `@main`):
   - `python-ci.yml`: `orion-cognitive-agent` (caller canonico de produccion)
   - `eslint.yml`, `node-test.yml`: `orion-frontend`
   - `container-deploy-ecr.yml`: `orion-cognitive-agent`
   - `terraform-plan.yml`, `terraform-apply.yml`, y los ecosystem
     recipes de Terraform (`terraform-validate`,
     `tflint`, `checkov`): `orion-infrastructure`
   - `latex-build.yml`, `latex-release.yml`: `spark-match-07-article`
   - `actionlint.yml`, `gitleaks.yml`, `yamllint.yml`:
     `ci.yml` local (ver punto 1)
3. Si la PR cambia un input o agrega un paso al recipe, el reviewer exige
   smoke test explicito del caller correspondiente antes de aprobar el
   merge. Es responsabilidad del PR author declarar la evidencia en la
   descripcion del PR (logs de `act`, output de tests, captura del
   caller corriendo contra el SHA de la PR). No automatizable cross-owner
   sin reintroducir la dependencia que esta arquitectura evito.
