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

## Workflows planeados (no implementados todavia)

`quality-checks.yml` y `sam-deploy.yml` aparecen en el README como spec pero **NO estan implementados** en este repo. Fueron archivos WIP en un stash que se perdio. Los repos que supuestamente los consumen (e.g. `spark-match-03-backend`) actualmente no usan reusables de 01-devops.

Si se implementan en el futuro, seguiran la convencion de pin por ambiente (un caller que los use desde dev los pinea a `@dev`, etc.).
