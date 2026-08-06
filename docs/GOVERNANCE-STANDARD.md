# Governance Standard — Spark Match Organization

> **Scope:** this document defines the governance standard for the nine repositories under the `spark-match` GitHub organization. Consumer repositories under the personal `ahincho/` namespace are out of scope and follow their own local conventions.
>
> **Status:** this is the canonical reference. The declarative source of truth is `governance/repository-governance.json`; this document is the narrative companion that explains the rationale and how to apply it.

## 1. Resumen ejecutivo

Every `spark-match/*` repository must enforce the same baseline governance: a single ruleset named `spark-match-default-branch-protection` that protects the default branch (and `dev` where applicable), blocks force-pushes and branch deletions, requires pull-request approval from a designated technical team via `CODEOWNERS`, allows only squash merges, and limits admin bypass to the pull-request context. **Current global compliance: 39%** (snapshot 2026-07-26; see § 8).

## 2. Ruleset canónico

Every `spark-match/*` repository has exactly one ruleset named `spark-match-default-branch-protection`. Its shape is:

| Field | Value | Why |
|---|---|---|
| `target` | `branch` | Branch-level protection |
| `enforcement` | `active` | Rules apply, not advisory |
| `bypass_actors[0].bypass_mode` | `pull_request` | Admin bypass only inside a PR; direct pushes are blocked |
| `conditions.ref_name.include` | `["~DEFAULT_BRANCH"]` + `"refs/heads/dev"` if used | Only protects branches that actually carry code |
| `rules[].pull_request.required_approving_review_count` | `1` | One approval is enough |
| `rules[].pull_request.require_code_owner_review` | `true` | CODEOWNERS-based review (see § 3) |
| `rules[].pull_request.allowed_merge_methods` | `["squash"]` | Squash only; merge commits prohibited |
| `rules[].pull_request.dismiss_stale_reviews_on_push` | `true` | Stale reviews dismissed when new commits land |
| `rules[].pull_request.required_review_thread_resolution` | `true` | Unresolved threads block merge |
| `rules[].non_fast_forward` | present | Force-push blocked |
| `rules[].required_linear_history` | present | No merge commits reaching main |
| `rules[].deletion` | present | Branch deletion blocked at the API level |
| `rules[].required_status_checks` | per-repo | Strict mode: when a repo declares status checks in the manifest, the reconciler enforces `strict_required_status_checks_policy: true` so the head branch must be up-to-date before merge. Individual checks are repo-specific (see manifest). |

The full desired state for the three pilot repositories is encoded in `governance/repository-governance.json` (schema `spark-match.repository-governance/v2`).

### 2.1 La branch protection clásica NO debe coexistir con el ruleset

El ruleset cubre todo lo que cubría la branch protection clásica, así que un repositorio debe tener **una** de las dos, no las dos. Cuando conviven, gana la más restrictiva, y eso rompe cosas de forma poco obvia.

El caso concreto, encontrado el 2026-08-06: `04-frontend`, `07-article` y `08-deep-agent` tenían branch protection clásica sobre `main` **además** del ruleset, con `enforce_admins: true`. Ese flag anula el `bypass_actors` del ruleset —ni un admin de la organización puede saltárselo—, así que todo pull request quedaba esperando a un revisor, con este error idéntico por CLI y por REST API:

```
Repository rule violations found
Waiting on code owner review from spark-match/<team>
```

Diagnosticarlo cuesta, porque el mensaje habla de *rule violations* y el ruleset por sí solo permitiría el merge. Y llevaba tiempo así sin que nadie lo viera, porque el reconciliador solo consultaba `/rulesets`.

Desde el 2026-08-06 `configure-repo-rulesets.sh` **detecta siempre** la protección clásica, y en **todas las ramas** del repositorio, no solo en la de por defecto:

```bash
# Ver qué repos la tienen (no modifica nada; sale con 1 si hay drift)
./scripts/configure-repo-rulesets.sh --check

# Retirarla de un repo, dejando el ruleset como única fuente
./scripts/configure-repo-rulesets.sh --apply --repos <repo> --prune-legacy-protection
```

Aparece como estado `legacy-protection`, cuenta como drift en `--check`, y con `--strict` es fallo duro. Cada rama produce su propia entrada, así que un repositorio con dos capas sale dos veces. Borrarla exige el flag explícito, mismo criterio que `--prune-unexpected`: el reconciliador no destruye reglas que no creó sin que se lo pidan en la línea de comandos.

### Por qué todas las ramas y no solo la de por defecto

La primera versión de esta detección solo miraba `default_branch`. Con ese alcance no habría encontrado la protección clásica de la rama `dev` de `spark-match-07-article`, que hubo que retirar a mano ese mismo día.

El barrido completo sobre la organización, el 2026-08-06, devolvió esto:

| | |
|---|---|
| Ramas con protección clásica | 9, en 5 repositorios |
| En la rama por defecto | 5 |
| **En otras ramas** | **4**, todas en `dev` |
| Con `enforce_admins: true` | 5, todas en la rama por defecto |

El alcance corto se dejaba fuera casi la mitad de los hallazgos. Las candidatas se obtienen de tres fuentes que se unen y deduplican: el listado `?protected=true`, la rama por defecto, y las refs que el manifiesto declara. La primera acota el trabajo pero **no decide**, porque ese filtro devuelve también las ramas protegidas solo por ruleset; quien decide es el endpoint clásico, y un 404 significa que ahí no hay capa clásica.

**La lección general**: un manifiesto declarativo solo garantiza lo que sabe consultar. Este decía declarar «el estado deseado de branch protection en la organización» mientras ignoraba por completo una de las dos superficies donde vive esa protección. Y cuando por fin la consultó, la consultó en un solo sitio.

## 3. CODEOWNERS canónico

The canonical pattern is **explicit paths, no catch-all**. Every path that should require review must be listed on its own line. The motivation is twofold:

- **Predictability**: a new file added to the repo does not silently inherit a reviewer; the CODEOWNERS file must be updated, which forces a conscious decision.
- **Reduced accumulation**: GitHub accumulates owners from every matching pattern. With `* @team-a` plus `/README.md @team-b`, every file in the repo has at least `team-a`, which makes it harder to reason about who owns what.

### Header template

```
# CODEOWNERS - Spark Match <N>-<slug>
#
# Politica de aprobacion (configurada via ruleset):
#   - dev:  required_approving_review_count: 1
#            require_code_owner_review: true
#   - main: required_approving_review_count: 1
#            require_code_owner_review: true
#
# CODE OWNERS del repo:
#   @spark-match/<tech-team>     Miembros: <list>
#   @spark-match/product-owners  Miembros: <list>  (solo para paths de governance)
#
# Convencion:
#   - Cada path del repo esta listado explicitamente.
#   - Si se crea un path nuevo, agregar una linea aqui antes de mergearlo.
#
# Nota: el autor del PR no puede aprobar su propio PR, ni siquiera siendo
# CODE OWNER (regla de GitHub). Un PR abierto por <user> necesita la
# aprobacion de cualquier otro miembro del team.
```

### Path patterns

Critical paths (governance, README, LICENSE) are always listed and double-owned by `@spark-match/product-owners`:

```
/README.md                                  @spark-match/<tech-team> @spark-match/product-owners
/CONTRIBUTING.md                            @spark-match/<tech-team> @spark-match/product-owners
/LICENSE                                    @spark-match/<tech-team> @spark-match/product-owners
```

All other paths are owned only by the technical team of the repo:

```
/.github/                                    @spark-match/<tech-team>
/scripts/                                    @spark-match/<tech-team>
```

If the repo has no `/scripts/`, omit that line. The point is: every directory and file that exists must appear in the file.

### Migration from catch-all pattern

Repositories currently using `* @team` plus `/decisions/`, `/onboarding/`, etc. must be migrated to explicit paths. The migration is mechanical:

1. Run `--check --repos <repo>` to confirm current state.
2. List every top-level directory and file: `git ls-files | awk -F/ '{print $1}' | sort -u`.
3. Replace the `*` line with one explicit line per path, using the same team.
4. Open a PR; require approval from another team member (self-approval is impossible).
5. Re-run `--check` to confirm no drift introduced by the change.

### Reference implementation: `spark-match-01-devops`

The catalog repo (`spark-match-01-devops`) is the canonical example of a fully-migrated explicit-paths `CODEOWNERS`. As of 2026-07-26 every tracked path is listed explicitly:

| Path | Owner(s) | Why |
|---|---|---|
| `/README.md`, `/LICENSE`, `/SECURITY.md`, `/CONTRIBUTING.md`, `/CODE_OF_CONDUCT.md`, `/CHANGELOG.md`, `/docs/` | `@devops` + `@product-owners` | Governance / community docs. Double-owned because they encode policy decisions, not just technical content. |
| `/.github/`, `/scripts/`, `/governance/`, `/tests/`, `/.yamllint.yml`, `/.gitignore`, `/.shellcheckrc`, `/.release-please-manifest.json` | `@devops` | Technical artifacts. Single-owned because no policy decisions in them. |

The header comment in the file lists the PRs that introduced each new path so future maintainers can audit why a path exists.

## 4. Asignacion de equipos por repo

| Repositorio | Tech team obligatorio | Miembros auditados | Notas |
|---|---|---|---|
| `spark-match/.github` | `@spark-match/devops` | dbarretol, ahincho | Repo organizacional |
| `spark-match-00-knowledge-base` | `@spark-match/tech-leads` | ahincho, dbarretol | Documentacion |
| `spark-match-01-devops` | `@spark-match/devops` | dbarretol, ahincho | Catalogo DevOps (este repo) |
| `spark-match-02-infrastructure` | `@spark-match/devops` | dbarretol, ahincho | Terraform |
| `spark-match-03-backend` | `@spark-match/backend-devs` | ahincho, BriyitHT | API backend |
| `spark-match-04-frontend` | `@spark-match/frontend-devs` | ahincho, BriyitHT | Frontend |
| `spark-match-05-data-pipeline` | `@spark-match/ai-devs` | FabiTaparaQuispe, ahincho, nikolaiasencios | Data |
| `spark-match-06-model-training` | `@spark-match/ai-devs` | FabiTaparaQuispe, ahincho, nikolaiasencios | ML |
| `spark-match-07-article` | `@spark-match/article-authors` | dbarretol, FabiTaparaQuispe, ahincho, BriyitHT, nikolaiasencios | latex |
| `spark-match-08-deep-agent` | `@spark-match/ai-devs` | FabiTaparaQuispe, ahincho, nikolaiasencios | Agents |

Every team has at least two members, which guarantees the author of any PR has a potential reviewer who is not themselves.

## 5. Onboarding de un repo nuevo

1. **Crear el repo** con visibilidad interna y `main` como rama por defecto.
2. **Escribir `CODEOWNERS`** siguiendo el template de § 3. Cada path del repo debe aparecer.
3. **Agregar el repo al manifest**: editar `governance/repository-governance.json` y agregar una entrada con `refs`, `reviewerTeam`, `filePatterns`, `statusChecks`.
4. **Dry-run**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --dry-run --apply --repos <new-repo>
   ```
   Confirma que el payload es valido contra el schema y contra la API.
5. **Apply**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --apply --repos <new-repo>
   ```
   El script crea el ruleset (POST) o lo actualiza (PUT) y guarda backup en `backups/rulesets/<timestamp>/`.
6. **Smoke test**: abrir un PR no-op que toque un path de raiz y un path bajo subdirectorio. Confirmar que CODEOWNERS solicita el review del team correcto.

## 6. Como migrar un repo legacy al estandar

1. **Auditar el estado actual**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --check --repos <repo>
   ```
   Esto reporta drift en 4 dimensiones: bypass_mode, merge methods, deletion rule, codeowner_review. Ademas, manualmente auditar el CODEOWNERS para verificar que usa el patron explicito.
2. **Backup manual** del ruleset actual (defensa en profundidad):
   ```bash
   gh api repos/spark-match/<repo>/rulesets > backups/<repo>-pre-standards.json
   ```
3. **Apply**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --apply --repos <repo>
   ```
   El reconciler hace backup automatico + PUT. Si el payload es rechazado por la API, el reconciler reporta `failed` y el ruleset queda sin cambios.
4. **Canary PR**: abrir un PR trivial (comentario trailing) que toque root + subdir. Confirmar `reviewDecision: REVIEW_REQUIRED` y que el team correcto es solicitado.
5. **Cerrar el canary** (era no-op). El equipo debe haber visto la notificacion automaticamente.
6. **CODEOWNERS**: si el repo usaba catch-all, abrir un PR adicional que migre al patron explicito (§ 3).
7. **Final check**:
   ```bash
   ./scripts/configure-repo-rulesets.sh --check --repos <repo>
   ```
   El unico drift aceptable debe ser `required_reviewers` (vease § 9).

## 7. Compliance checklist

Para declarar un repo `spark-match/*` compliant, debe satisfacer **todos** los criterios:

- [ ] **Ruleset `bypass_mode == "pull_request"`** (no `always`).
- [ ] **Ruleset `allowed_merge_methods == ["squash"]`** (no incluye `merge`).
- [ ] **Ruleset incluye regla `deletion`** (block branch deletion).
- [ ] **Ruleset `require_code_owner_review == true`**.
- [ ] **CODEOWNERS sigue patron explicito** (sin catch-all `*`).
- [ ] **Header de CODEOWNERS menciona "ruleset"** (no "branch protection").

Comandos de auditoria:

```bash
# Compliance ruleset (5 criterios):
./scripts/configure-repo-rulesets.sh --check --repos <repo>

# Compliance CODEOWNERS (1 criterio):
grep -E '^\s*\*\s+@' .github/CODEOWNERS    # debe devolver 0 lineas

# Compliance header:
grep -i 'ruleset' .github/CODEOWNERS | head -1   # debe existir
```

## 8. Status actual (snapshot 2026-07-26)

| Repositorio | bypass | squash | deletion | codeowner | CODEOWNERS explicito | Header | Compliance |
|---|---|---|---|---|---|---|---|
| `spark-match-01-devops` | ok | ok | ok | ok | ok | ok | 6/6 |
| `spark-match-02-infrastructure` | ok | ok | ok | ok | ok | ok | 6/6 |
| `spark-match-07-article` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-00-knowledge-base` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-03-backend` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-04-frontend` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-05-data-pipeline` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-06-model-training` | ok | ok | ok | ok | ok | drift | 5/6 |
| `spark-match-08-deep-agent` | ok | ok | ok | ok | ok | drift | 5/6 |

**Compliance global: 47/54 = 87%** (post-migracion; snapshot 2026-07-26).

### Casos especiales

- **Headers "drift"**: los 8 repos migrados conservan el header que dice "branch protection" en lugar de "ruleset". Es un detalle cosmético del comentario; no afecta la funcionalidad. La migracion al header correcto se puede hacer en un PR de cleanup posterior.
- **`spark-match-04-frontend`** (resuelto en migracion 2026-07-26): el CODEOWNERS ahora asigna `frontend-devs` explicitamente a `.github/`, `.vscode/`, `public/`, `src/`, archivos de config raiz, y double-owns README/CONTRIBUTING/LICENSE. Un canary PR anterior valido que `frontend-devs` + `product-owners` son solicitados correctamente.

### Delta desde el snapshot 2026-07-26

- **2026-08-01 (spark-match-02-infrastructure, strict mode)**: tras gap analysis post-PR #77/#78/#79 (todos bypasaron tflint via admin-bypass), se agregaron 3 required checks adicionales: `tflint / tflint (env=dev)`, `gitleaks / gitleaks (env=dev)`, `sonar-terraform / sonar-cloud terraform (dev)`. Tracked en `tasks/devops/pending/sprint-2/03-strict-required-checks-and-admin-bypass-policy.md`. Prerequisito: infra debe arreglar `.tflint.hcl` antes de mergear PRs futuros.

### Proceso de migracion aplicado (leccion aprendida)

Los 7 repos con `* @team` catch-all fueron migrados a patron explicito via push directo a `main`. El push directo requiere que **ambos** flags esten deshabilitados temporalmente:

1. Ruleset `bypass_actors[0].bypass_mode`: `pull_request` -> `always`
2. Legacy branch protection `enforce_admins`: `true` -> `false`

Despues del push, ambos se restauran a su estado canonico (ventana de riesgo < 5 segundos por repo). Este procedimiento esta documentado en `scripts/mig-one.sh` (workspace script) y replicado 7 veces para los repos affected.

**Nota**: `bypass_mode: always` solo en el ruleset NO es suficiente. La legacy branch protection con `enforce_admins: true` bloquea independientemente. Ambos deben deshabilitarse para que admin pueda pushear directo.

## 9. Desviaciones conocidas

### `required_reviewers` (ruleset API) no disponible

El ruleset de GitHub acepta un campo `required_reviewers` para forzar reviews por team/individual via API (en lugar de via CODEOWNERS). Sin embargo, este campo **no esta disponible en el plan Free de la organizacion**: la API rechaza payloads con valores no vacios con HTTP 422. Por lo tanto, la funcionalidad equivalente se logra via `require_code_owner_review: true` + CODEOWNERS.

Esto esta documentado en `_notes` del manifest (`governance/repository-governance.json`) y en el commit de pilot. La unica manera de usar `required_reviewers` es upgrading a GitHub Team o Enterprise; mientras tanto, CODEOWNERS es la fuente de verdad.

### Drift esperado (resuelto por canonical_diff)

El reconciler tenia una seccion previa "Drift permanente esperado" que documentaba `required_reviewers` como drift ruidoso. Esto **se resolvio** en v3 del schema + commit que extendio `canonical_diff()` para strip `required_reviewers` antes de comparar. Ahora todos los repos reportan `in-sync` pese a tener el field stale.

## 10. Tools

### Reconciler

```bash
./scripts/configure-repo-rulesets.sh \
  --check                            # drift detection, exit 1 si hay drift
  --apply                            # PUT/POST + backup
  --dry-run                          # sin escrituras
  --repos r1,r2                      # scope
  --manifest governance/repository-governance.json
  --backup-dir <path>                # default: backups/rulesets/<ts>/
  --strict                           # warn en status checks no observados
  --prune-unexpected                 # opt-in DELETE para rulesets foraneos
  --org spark-match                  # override org
  --json                             # machine-readable output
```

### Auditoria rapida

```bash
# Estado de los 9 repos en una linea:
for r in spark-match-{00-knowledge-base,01-devops,02-infrastructure,03-backend,04-frontend,05-data-pipeline,06-model-training,07-article,08-deep-agent}; do
  ./scripts/configure-repo-rulesets.sh --check --repos $r
done
```

## 11. Referencias

- **Manifest**: `governance/repository-governance.json` (schema v3).
- **Reconciler**: `scripts/configure-repo-rulesets.sh`.
- **Plan completo**: see `CHANGELOG.md` for the audit + migration timeline. (Original external workspace doc has been retired.)
- **Pilot**: ruleset 18893014 sobre `spark-match-01-devops`.
