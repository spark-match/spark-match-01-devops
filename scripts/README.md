# Scripts de soporte para `01-devops`

## `create-pr.{ps1,sh}`

Helper para crear PRs con body bien formateado (markdown plano, sin JSON con `\n` literales).

### Por que existe

`gh pr create` tiene varios gotchas con el body del PR:

1. **`gh pr create --body "<texto>"`**: a veces interpreta caracteres especiales (em-dash, backticks, acentos) de forma inesperada, especialmente en PowerShell con quoting complicado.
2. **`gh api POST .../pulls --input pr-body.json`**: si el JSON contiene `\n` literales en el campo `body`, GitHub los renderiza como **texto literal** `\n` en vez de saltos de linea. Esto sucedió en PRs #30 y #38.

La forma robusta es **escribir el body en un archivo markdown y pasarlo con `--body-file`**.

### Uso (PowerShell)

```powershell
.\create-pr.ps1 `
  -Base dev `
  -Head feat/mi-feature `
  -Title "feat: mi feature" `
  -BodyFile .\pr-body.md `
  -Assignee ahincho `
  -Labels enhancement,infrastructure
```

### Uso (bash / Git Bash / Linux / macOS)

```bash
./create-pr.sh \
  --base dev \
  --head feat/mi-feature \
  --title "feat: mi feature" \
  --body-file ./pr-body.md \
  --assignee ahincho \
  --labels enhancement,infrastructure
```

### Opciones

| Opcion | Descripcion |
|---|---|
| `--base` | Branch base (required) |
| `--head` | Branch head (required) |
| `--title` | Titulo del PR (required) |
| `--body-file` | Path al archivo markdown con el body (required) |
| `--assignee` | GitHub assignee (default: ninguno) |
| `--labels` | Labels separados por coma (default: ninguno) |
| `--repo` | Override del repo owner/name (default: auto-detect desde `git remote get-url origin`) |
| `--no-wait` | (solo bash) No esperar a que terminen los checks |

### Ejemplo de `pr-body.md`

```markdown
## Resumen

Cierra items B11/B12/C9-C12 del IMPROVEMENTS.md. Instancia \`module.security\` y \`module.endpoints\` en \`live/dev/main.tf\` (Fase 1.5).

## Cambios

### \`live/dev/main.tf\` (+77 lineas)

- **\`module.security\`**: KMS CMK per-env + 3 SGs (lambda/rds/endpoints) + 4 IAM roles OIDC.
- **\`module.endpoints\`**: solo S3 gateway endpoint (gratis).

## Cerrar

- [x] Items B11, B12 (security module bugs)
- [x] Items C9-C12 (Phase 1.5)
```

### Que hace el script

1. Valida que `--body-file` exista.
2. Auto-detecta el repo desde `git remote get-url origin` (formato `git@github.com:owner/repo.git` o `https://github.com/owner/repo.git`).
3. Construye los args para `gh pr create` y los ejecuta.
4. (Opcional) Espera a que los status checks terminen y muestra el resultado.

### Requisitos

- `gh` CLI autenticado con cuenta que tenga push access al repo
- El branch HEAD debe estar pusheado al remote
- PowerShell 5.1+ (Windows) o bash 4+ (Linux/macOS)