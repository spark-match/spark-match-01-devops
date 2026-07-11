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
