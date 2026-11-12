#!/usr/bin/env python3
"""Audit GLB models: bounds, mesh statistics, skins and embedded animation clips."""
import json
from pathlib import Path
from pygltflib import GLTF2
import trimesh

ROOT = Path(".")
REPORTS = ROOT / "analysis_output"
REPORTS.mkdir(exist_ok=True)

def inspect(path):
    data = {"arquivo": path.name, "tamanho_bytes": path.stat().st_size}
    try:
        gltf = GLTF2().load(str(path))
        data["nos"] = len(gltf.nodes or [])
        data["malhas"] = len(gltf.meshes or [])
        data["materiais"] = len(gltf.materials or [])
        data["esqueletos"] = len(gltf.skins or [])
        node_names = [node.name or f"No_{i}" for i, node in enumerate(gltf.nodes or [])]
        parents = {}
        for parent_index, node in enumerate(gltf.nodes or []):
            for child_index in (node.children or []):
                parents[child_index] = parent_index
        data["hierarquia_nos"] = [
            {
                "indice": i,
                "nome": node_names[i],
                "pai_indice": parents.get(i),
                "pai_nome": node_names[parents[i]] if i in parents else None,
                "filhos": list(node.children or []),
                "mesh": node.mesh,
                "skin": node.skin
            }
            for i, node in enumerate(gltf.nodes or [])
        ]
        data["ossos_por_esqueleto"] = [len(skin.joints or []) for skin in (gltf.skins or [])]
        data["detalhes_esqueletos"] = [
            {
                "indice": si,
                "nome": skin.name or f"Esqueleto_{si}",
                "quantidade_ossos": len(skin.joints or []),
                "ossos": [
                    {
                        "ordem": ji,
                        "no_indice": node_index,
                        "nome": node_names[node_index] if node_index < len(node_names) else f"No_{node_index}"
                    }
                    for ji, node_index in enumerate(skin.joints or [])
                ],
                "skeleton_root": skin.skeleton,
                "skeleton_root_nome": node_names[skin.skeleton] if skin.skeleton is not None and skin.skeleton < len(node_names) else None
            }
            for si, skin in enumerate(gltf.skins or [])
        ]
        data["animacoes"] = []
        for i, anim in enumerate(gltf.animations or []):
            times = []
            for sampler in (anim.samplers or []):
                if sampler.input is not None and sampler.input < len(gltf.accessors):
                    accessor = gltf.accessors[sampler.input]
                    if accessor.min and accessor.max:
                        times.extend([float(accessor.min[0]), float(accessor.max[0])])
            duration = (max(times) - min(times)) if times else None
            paths = {}
            targets = []
            for channel in (anim.channels or []):
                target_path = channel.target.path if channel.target else "unknown"
                paths[target_path] = paths.get(target_path, 0) + 1
                target_node = channel.target.node if channel.target else None
                targets.append({
                    "no_indice": target_node,
                    "no_nome": node_names[target_node] if target_node is not None and target_node < len(node_names) else None,
                    "propriedade": target_path
                })
            data["animacoes"].append({
                "nome": anim.name or f"Animacao_{i+1}",
                "canais": len(anim.channels or []),
                "amostras": len(anim.samplers or []),
                "duracao_segundos": round(duration, 4) if duration is not None else None,
                "canais_por_tipo": paths,
                "nos_alvo_dos_canais": targets
            })
        data["tem_animacao"] = len(data["animacoes"]) > 0
        data["tem_esqueleto"] = len(gltf.skins or []) > 0
        vertices = 0
        primitives = 0
        for mesh in (gltf.meshes or []):
            for prim in (mesh.primitives or []):
                primitives += 1
                if prim.attributes and prim.attributes.POSITION is not None:
                    accessor = gltf.accessors[prim.attributes.POSITION]
                    if accessor.count:
                        vertices += accessor.count
        data["primitivas"] = primitives
        data["vertices_posicao_estimados"] = vertices
        try:
            scene = trimesh.load(str(path), force="scene", process=False)
            bounds = scene.bounds
            if bounds is not None:
                ext = bounds[1] - bounds[0]
                data["limites_min"] = [round(float(v), 5) for v in bounds[0]]
                data["limites_max"] = [round(float(v), 5) for v in bounds[1]]
                data["dimensoes_x_y_z"] = [round(float(v), 5) for v in ext]
                data["centro"] = [round(float(v), 5) for v in scene.centroid]
            else:
                data["dimensoes_erro"] = "O importador nao encontrou geometria visivel."
        except Exception as exc:
            data["dimensoes_erro"] = f"{type(exc).__name__}: {exc}"
    except Exception as exc:
        data["erro_leitura"] = f"{type(exc).__name__}: {exc}"
    return data

files = sorted(p for p in ROOT.rglob("*.glb") if ".git" not in p.parts and "analysis_output" not in p.parts)
results = [inspect(p) for p in files]
payload = {"total_arquivos_glb": len(results), "modelos": results}
(REPORTS / "relatorio_modelos.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

lines = [
    "# Relatorio tecnico dos modelos GLB",
    "",
    f"Arquivos analisados: **{len(results)}**",
    "",
    "Dimensoes X/Y/Z estao nas unidades originais do arquivo glTF; nao assumimos que sejam metros.",
    "",
    "| Arquivo | Dimensoes X/Y/Z | Vertices | Esqueleto | Ossos | Animacoes |",
    "|---|---:|---:|---:|---:|---:|"
]
for item in results:
    dims = item.get("dimensoes_x_y_z", item.get("dimensoes_erro", item.get("erro_leitura", "indisponivel")))
    dims = " x ".join(map(str, dims)) if isinstance(dims, list) else str(dims)
    bones = ",".join(map(str, item.get("ossos_por_esqueleto", []))) or "-"
    clips = ", ".join(a["nome"] for a in item.get("animacoes", [])) or "nenhuma detectada"
    lines.append(f"| {item['arquivo']} | {dims} | {item.get('vertices_posicao_estimados', '-')} | {'sim' if item.get('tem_esqueleto') else 'nao'} | {bones} | {clips} |")
lines += [
    "",
    "## Observacoes",
    "- 'Nenhuma detectada' significa que o GLB nao declara clipes no array animations.",
    "- Ter esqueleto/ossos nao significa que ja existam animacoes.",
    "- Este relatorio mede a caixa envolvente da geometria importada; nao cria nem altera os modelos.",
    "- As dimensoes devem ser conferidas visualmente no Godot antes de definir escala e colisores."
]
(REPORTS / "relatorio_modelos.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Analise concluida: {len(results)} arquivos GLB.")
for item in results:
    print(f"{item['arquivo']}: animacoes={len(item.get('animacoes', []))}, esqueleto={item.get('tem_esqueleto', False)}, dimensoes={item.get('dimensoes_x_y_z', 'indisponivel')}")
