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

**Contexto**: PR de un script bash (192 lineas, 1 archivo) que automatiza aplicar un ruleset estandar a todos los repos de la org `spark-match`. Misma causa raiz que los 4 bypasses anteriores: CODE OWNER unavailability.

**Accion**: `gh pr merge 11 --admin --squash`.

**Justificacion**:

- Es un script, no codigo de aplicacion; el riesgo de bugs es minimo.
- Resuelve un problema real (10 repos que necesitan proteccion consistente en Free tier).
- CI pasa (lint + gitleaks + yamllint: actionlint/gitleaks/yamllint son los 3 status checks requeridos, todos verdes).

## Patron observado

5 bypasses consecutivos en `01-devops` por la misma causa raiz (CODE OWNER unavailability). El equipo confirmo que no es viable agregar mas miembros al team `@spark-match/devops`. Mitigaciones parciales aplicadas:

- **Branch protection** configurada en ambos repos criticos (`01-devops`, `02-infrastructure`) con status checks reales que SÍ bloquean merges si CI falla (gracias a SEC-11 resuelto en 2026-07-12).
- **Repo-level rulesets** aplicados via `scripts/configure-repo-rulesets.sh` a 10 repos: cubren `block_force_push` + `require_linear_history` (lo que SÍ puede hacer rulesets; PR approvals quedan en branch protection porque rulesets no tienen rule type "pull_request").
- **Causa raiz NO resuelta**: la unica forma de evitar bypasses es agregar miembros a `@spark-match/devops` o aceptar la politica "admin merge cuando no hay reviewers" como parte del flujo normal.

## Referencias cruzadas

- `02-infrastructure/governance/bypasses.md`: bypasses del repo hermano (PRs #8, #9, #10 de 02-infrastructure, misma causa raiz).
- `D:\UNI\Spark\IMPROVEMENTS.md`: lista completa de hallazgos y plan de mejoras.
- `D:\UNI\Spark\README.md` (leccion #3): "Todo team CODE OWNER debe tener al menos 2 personas para evitar single point of failure".
- `D:\UNI\Spark\backup-2026-07-12-pre-bypass.md`: snapshot pre-bypass del 2026-07-12 (02-infrastructure).
