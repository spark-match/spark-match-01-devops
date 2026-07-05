# scripts/

Scripts de automatización operativa para los repos de la org `spark-match`.

| Script | Propósito |
|---|---|
| [`configure-merge-methods.sh`](./configure-merge-methods.sh) | Aplica una política uniforme de merge (squash-only por defecto) en todos los repos de la org. |

## Uso general

Todos los scripts siguen estas convenciones:

- **Idempotentes**: ejecutarlos 2+ veces produce el mismo resultado
- **`--dry-run`**: muestran qué harían sin aplicar cambios
- **Variables de entorno**: respetan overrides (`ORG=...`, etc.)
- **Requieren `gh` CLI**: autenticado con permisos de admin en la org

## Ejecutar un script

```bash
# Hacer ejecutable (solo la primera vez)
chmod +x scripts/configure-merge-methods.sh

# Dry-run (recomendado primero)
./scripts/configure-merge-methods.sh --dry-run

# Aplicar
./scripts/configure-merge-methods.sh
```

## Agregar un script nuevo

1. Crear archivo `.sh` en este directorio
2. Empezar con shebang `#!/usr/bin/env bash` y `set -euo pipefail`
3. Documentar en el header con comentarios `#`
4. Agregar fila en la tabla de arriba
5. Commit con `feat(scripts): <descripción corta>`
6. PR con review de `@spark-match/devops`
