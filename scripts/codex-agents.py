#!/usr/bin/env python3
"""Genera los roles de agente de Codex a partir de los agentes de Claude Code.

La fuente de verdad es plugins/accurate-media/agents/<nombre>.md. Este script escribe
codex/agents/<nombre>.toml (formato de rol de Codex: name, description,
developer_instructions) para los agentes que también se usan desde Codex.

Uso:
    scripts/codex-agents.py          # regenera los .toml
    scripts/codex-agents.py --check  # exit 1 si algún .toml está desfasado (lo usa validate.sh)
"""
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "plugins" / "accurate-media" / "agents"
DESTINO = RAIZ / "codex" / "agents"
AGENTES_CODEX = ["backend-engineer", "frontend-engineer"]

NOTA_CODEX = """\
> Estás corriendo en Codex, no en Claude Code. Las skills `normas` y `pruebas` las tienes si
> instalaste el marketplace con `scripts/instalar-codex.sh`; si no, aplica las convenciones del repo.
> No tienes al orquestador ni a los demás agentes del equipo: lo que pondrías en `Traspaso`,
> repórtaselo al dev al final.

"""


def separar(md: str) -> tuple[dict, str]:
    lineas = md.splitlines()
    if not lineas or lineas[0] != "---":
        raise ValueError("sin frontmatter")
    fin = lineas.index("---", 1)
    campos = {}
    for linea in lineas[1:fin]:
        clave, _, valor = linea.partition(":")
        campos[clave.strip()] = valor.strip()
    return campos, "\n".join(lineas[fin + 1:]).strip() + "\n"


def generar(nombre: str) -> str:
    campos, cuerpo = separar((ORIGEN / f"{nombre}.md").read_text(encoding="utf-8"))
    instrucciones = NOTA_CODEX + cuerpo
    if "'''" in instrucciones:
        raise ValueError(f"{nombre}: el cuerpo contiene ''' y rompería el TOML")
    return (
        f"# GENERADO por scripts/codex-agents.py desde plugins/accurate-media/agents/{nombre}.md\n"
        "# No lo edites a mano: edita el .md y regenera.\n"
        f"name = {json.dumps(campos['name'], ensure_ascii=False)}\n"
        f"description = {json.dumps(campos['description'], ensure_ascii=False)}\n"
        f"developer_instructions = '''\n{instrucciones}'''\n"
    )


def main() -> int:
    revisar = "--check" in sys.argv
    DESTINO.mkdir(parents=True, exist_ok=True)
    desfasados = []
    for nombre in AGENTES_CODEX:
        esperado = generar(nombre)
        archivo = DESTINO / f"{nombre}.toml"
        actual = archivo.read_text(encoding="utf-8") if archivo.exists() else None
        if actual == esperado:
            continue
        if revisar:
            desfasados.append(str(archivo.relative_to(RAIZ)))
        else:
            archivo.write_text(esperado, encoding="utf-8")
            print(f"escrito {archivo.relative_to(RAIZ)}")
    if desfasados:
        print("desfasados (corre scripts/codex-agents.py): " + ", ".join(desfasados), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
