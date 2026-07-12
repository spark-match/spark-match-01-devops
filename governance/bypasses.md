# Bypass log

Este archivo registra todos los merges que se realizaron **sin cumplir los requirements de branch protection** (CODEOWNERS, approvals) usando permisos de admin.

## Contexto

El `require_code_owner_reviews=true` en branch protection requiere que un CODE OWNER apruebe el PR antes de mergear. Cuando el autor de un PR es CODE OWNER (o admin), no puede aprobar su propio PR. El admin bypass es la unica via para mergear en estos casos.

Solo admins del repo pueden ejecutar el bypass con `gh pr merge --admin`.

## Formato

| Fecha       | Repo   | PR  | Autor   | Razon del bypass                                | Aprobado por |
|-------------|--------|-----|---------|-------------------------------------------------|--------------|
| YYYY-MM-DD  | repo   | #N  | autor   | razon corta                                     | admin name   |

## Entradas

### 2026-07-11 - ahincho

| Repo                       | PR  | Autor   | Razon                                                                  | Aprobado por |
|----------------------------|-----|---------|------------------------------------------------------------------------|--------------|
| spark-match-01-devops      | #7  | ahincho | Reusables Terraform N-env aware (devops sin disponibilidad)             | ahincho      |
| spark-match-01-devops      | #8  | ahincho | Restructuracion CODEOWNERS sin catch-all (devops sin disponibilidad)   | ahincho      |

**Contexto**: PRs creados por `ahincho` (admin y CODE OWNER de devops). CODEOWNERS requeria aprobacion de `@spark-match/devops` pero el autor no puede aprobar su propio PR y los demas miembros del equipo (`dbarretol`) no estaban disponibles al momento del merge.

**Accion**: ambos PRs mergeados con `gh pr merge --admin` (admin bypass con `enforce_admins=false`).

**Justificacion**:

- PR #7 es bloqueante para PR #8 de `02-infrastructure` (caller referencia `@main` del reusable, version vieja hasta que se mergee).
- PR #8 elimina la acumulacion de CODEOWNERS en paths tecnicos (mejora de governance).
- Ambos PRs tienen CI passing y no introducen cambios destructivos.
- Bypass es trazable en git history (commits y merge commits).

**Reviewers presentes al momento del bypass**: ninguno (Fabi habia aprobado product-owners en PR #7 pero el CODE OWNER requerido era devops, no product-owners).

### 2026-07-11 - ahincho (sync dev to main)

| Repo                       | PR  | Autor   | Razon                                                                  | Aprobado por |
|----------------------------|-----|---------|------------------------------------------------------------------------|--------------|
| spark-match-01-devops      | #9  | ahincho | Sync de `dev` a `main` (PRs #7 y #8 ya mergeados en dev)               | ahincho      |

**Contexto**: Despues de mergear PR #7 y #8 a dev, se necesitaba propagar esos cambios a main para que el resto de los repos (consumers de los reusables) tuvieran la version actualizada. Sin el sync, los callers que pinean a `@main` seguirian viendo el codigo viejo.

**Accion**: 

1. Backup del BP actual de `main`: `required_approving_review_count=1, require_code_owner_reviews=true, enforce_admins=true, require_last_push_approval=true`.
2. Relajacion temporal: `require_code_owner_reviews=false, required_approving_review_count=0`.
3. `gh pr merge 9 --admin --squash`.
4. Restauracion del BP al estado original.

**Justificacion**:

- Sync es un PR "mecanico" (no tiene cambios de logica), solo mueve commits de dev a main.
- CI passing en PR #9 (reusables Terraform).
- Riesgo bajo: reverte facilmente con `git revert` si algo sale mal.

### 2026-07-11 - ahincho (fix checkout ordering)

| Repo                       | PR  | Autor   | Razon                                                                  | Aprobado por |
|----------------------------|-----|---------|------------------------------------------------------------------------|--------------|
| spark-match-01-devops      | #10 | ahincho | Fix de orden de `checkout` en reusables (rompio CI de 02-infra PR #8)   | ahincho      |

**Contexto**: Despues del sync de dev a main (PR #9), un bug en el orden de los steps de los reusable workflows (`actions/checkout@v6` se llamaba despues de `defaults.run.working-directory`) rompio el CI del PR #8 de `02-infrastructure`. El fix era trivial pero el PR quedaba bloqueado por la misma falta de reviewers disponibles.

**Accion**: `gh pr merge 10 --admin --squash`.

**Justificacion**:

- Fix es bloqueante para el trabajo de `02-infrastructure`.
- Cambio minimo: 2 archivos (terraform-plan.yml, terraform-apply.yml), solo reorden de steps.
- CI passing.

### 2026-07-12 - ahincho (script de rulesets para toda la org)

| Repo                       | PR  | Autor   | Razon                                                                  | Aprobado por |
|----------------------------|-----|---------|------------------------------------------------------------------------|--------------|
| spark-match-01-devops      | #11 | ahincho | Script `configure-repo-rulesets.sh` (misma causa raiz)                  | ahincho      |
| spark-match-01-devops      | #12 | ahincho | Update `bypasses.md` con PR #9, #10, #11                                | ahincho      |

**Contexto**: PR de un script bash (192 lineas, 1 archivo) que automatiza aplicar un ruleset estandar a todos los repos de la org `spark-match`. Misma causa raiz que los 4 bypasses anteriores: CODE OWNER unavailability.

**Accion**: `gh pr merge 11 --admin --squash`. PR #12 es la actualizacion de este mismo log.

**Justificacion**:

- Es un script, no codigo de aplicacion; el riesgo de bugs es minimo.
- Resuelve un problema real (10 repos que necesitan proteccion consistente en Free tier).
- CI pasa (lint + gitleaks + yamllint: actionlint/gitleaks/yamllint son los 3 status checks requeridos, todos verdes).

### 2026-07-12 - ahincho (migracion a rulesets como unica fuente de verdad)

| Repo                       | PR  | Autor   | Razon                                                                  | Aprobado por |
|----------------------------|-----|---------|------------------------------------------------------------------------|--------------|
| spark-match-01-devops      | #13 | ahincho | Upgrade script v2: `pull_request` rule + `require_code_owner_review`   | ahincho      |
| spark-match-01-devops      | #14 | ahincho | Add `bypass_actors` (OrganizationAdmin) al ruleset                     | ahincho      |

**Contexto**: PR #13 mejora el script `configure-repo-rulesets.sh` para incluir la regla `pull_request` completa (PR approvals, code owner review, dismiss stale, conversation resolution, allowed merge methods). Esto cubre TODO lo que hacia branch protection clasica. Adicionalmente, se decidio migrar a ruleset como UNICA fuente de verdad: branch protection clasica fue removida de `01-devops` y `02-infrastructure`.

**Descubrimiento critico durante PR #13**: `gh pr merge --admin` NO bypasea las reglas de un ruleset, solo las de branch protection clasica. Sin `bypass_actors` configurado, un admin no puede mergear un PR que no cumple las reglas del ruleset, incluso con `--admin`. Esto bloqueo el merge de PR #13 mismo. **PR #14 resuelve esto** agregando `bypass_actors: [{actor_type: "OrganizationAdmin", bypass_mode: "always"}]` al ruleset, que es el unico mecanismo oficial documentado por GitHub para permitir bypass.

**Acciones ejecutadas**:

1. `gh pr merge 13 --admin --squash` FALLO con "Repository rule violations found".
2. Update ruleset de 01-devops con `bypass_actors` via `gh api -X PUT`.
3. `gh pr merge 13 --admin --squash` EXITOSO.
4. Script actualizado (PR #14) para incluir `bypass_actors` en el JSON del ruleset.
5. Aplicado a 10 repos con `--delete-existing` (los 10 tienen el mismo `bypass_actors` ahora).
6. `gh pr merge 14 --admin --squash` EXITOSO.

**Branch protection clasica removida de 4 branches**:

- `spark-match-01-devops/branches/dev/protection`: DELETED
- `spark-match-01-devops/branches/main/protection`: DELETED
- `spark-match-02-infrastructure/branches/dev/protection`: DELETED
- `spark-match-02-infrastructure/branches/main/protection`: DELETED

**Verificacion post-migracion**: `GET /repos/.../rules/branches/{dev|main}` para `01-devops` y `02-infrastructure` retorna las 4 reglas activas (pull_request + non_fast_forward + required_linear_history + required_status_checks) con `ruleset_source: <repo>` y `ruleset_id: <id>`. La proteccion sigue activa, pero ahora viene 100% del ruleset.

## Estado final de la proteccion (2026-07-12)

| Mecanismo | Estado |
|---|---|
| Branch protection clasica (`/branches/X/protection`) | **Removida** de 01-devops y 02-infrastructure |
| Repo-level rulesets | **Activa** en 10 repos, con `bypass_actors` para admin |
| Single source of truth | **Si** - el ruleset |

## Patron observado (actualizado)

7 bypasses consecutivos en `01-devops` por la misma causa raiz (CODE OWNER unavailability). El equipo confirmo que no es viable agregar mas miembros al team `@spark-match/devops`. Mitigaciones aplicadas:

- **Repo-level rulesets** aplicados via `scripts/configure-repo-rulesets.sh` a 10 repos: cubren `block_force_push` + `require_linear_history` + `pull_request` (con approvals, code owner, dismiss stale, conversation resolution) + `required_status_checks` (donde aplique). Equivalente a branch protection clasica, pero con las ventajas de rulesets (capas, status, auditabilidad, etc.).
- **`bypass_actors`** configurado en cada ruleset: OrganizationAdmin puede mergear PRs que no cumplen las reglas (workflow documentado en este log).
- **Causa raiz NO resuelta**: la unica forma de evitar bypasses es agregar miembros a `@spark-match/devops` o aceptar la politica "admin merge cuando no hay reviewers" como parte del flujo normal.

## Referencias cruzadas

- `02-infrastructure/governance/bypasses.md`: bypasses del repo hermano (PRs #8, #9, #10 de 02-infrastructure, misma causa raiz).
- `D:\UNI\Spark\IMPROVEMENTS.md`: lista completa de hallazgos y plan de mejoras.
- `D:\UNI\Spark\README.md` (leccion #3): "Todo team CODE OWNER debe tener al menos 2 personas para evitar single point of failure".
- `D:\UNI\Spark\backup-2026-07-12-pre-bypass.md`: snapshot pre-bypass del 2026-07-12 (02-infrastructure).
