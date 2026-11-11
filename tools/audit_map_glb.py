#!/usr/bin/env python3
"""Auditoria estrutural do mapa GLB: hierarquia, transforms e limites por objeto."""
import json
from pathlib import Path
import numpy as np
from pygltflib import GLTF2

ROOT = Path(".")
OUT = ROOT / "analysis_output"
OUT.mkdir(exist_ok=True)
candidates = sorted(p for p in ROOT.rglob("*.glb") if ".git" not in p.parts and "analysis_output" not in p.parts and ("village" in p.name.lower() or "map" in p.name.lower()))
if not candidates:
    raise SystemExit("Nenhum GLB de mapa identificado pelo nome do arquivo.")

def local_matrix(node):
    if node.matrix and len(node.matrix) == 16:
        return np.array(node.matrix, dtype=float).reshape((4, 4), order="F")
    t = np.array(node.translation if node.translation else [0, 0, 0], dtype=float)
    q = np.array(node.rotation if node.rotation else [0, 0, 0, 1], dtype=float)
    sc = np.array(node.scale if node.scale else [1, 1, 1], dtype=float)
    x, y, z, w = q
    rot = np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0],
        [0, 0, 0, 1]
    ], dtype=float)
    scale = np.diag([sc[0], sc[1], sc[2], 1.0])
    trans = np.eye(4)
    trans[:3, 3] = t
    return trans @ rot @ scale

def transform_bounds(mn, mx, mat):
    corners = np.array([[x, y, z, 1] for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])])
    world = (mat @ corners.T).T[:, :3]
    return world.min(axis=0), world.max(axis=0)

all_maps = []
for path in candidates:
    gltf = GLTF2().load(str(path))
    nodes = gltf.nodes or []
    parents = {}
    for parent_i, node in enumerate(nodes):
        for child_i in (node.children or []):
            parents[child_i] = parent_i
    mesh_info = []
    for mi, mesh in enumerate(gltf.meshes or []):
        prims = []
        for pi, prim in enumerate(mesh.primitives or []):
            pos_index = prim.attributes.POSITION if prim.attributes else None
            acc = gltf.accessors[pos_index] if pos_index is not None else None
            prims.append({
                "primitiva": pi,
                "vertices": acc.count if acc else 0,
                "limites_locais_min": list(acc.min) if acc and acc.min else None,
                "limites_locais_max": list(acc.max) if acc and acc.max else None,
                "material": prim.material,
                "modo": prim.mode
            })
        mesh_info.append({"indice": mi, "nome": mesh.name or f"Mesh_{mi}", "primitivas": prims})
    objects = []
    global_min = np.array([np.inf, np.inf, np.inf])
    global_max = np.array([-np.inf, -np.inf, -np.inf])
    def visit(index, parent_world, depth):
        nonlocal_dummy = None
        node = nodes[index]
        world = parent_world @ local_matrix(node)
        entry = {
            "indice": index,
            "nome": node.name or f"No_{index}",
            "pai": parents.get(index),
            "profundidade": depth,
            "filhos": list(node.children or []),
            "mesh": node.mesh,
            "skin": node.skin,
            "transform_local": {
                "translation": list(node.translation) if node.translation else [0, 0, 0],
                "rotation_xyzw": list(node.rotation) if node.rotation else [0, 0, 0, 1],
                "scale": list(node.scale) if node.scale else [1, 1, 1]
            },
            "transform_world_matriz": np.round(world, 6).tolist()
        }
        if node.mesh is not None and node.mesh < len(mesh_info):
            bounds = []
            for prim in mesh_info[node.mesh]["primitivas"]:
                mn, mx = prim["limites_locais_min"], prim["limites_locais_max"]
                if mn and mx:
                    wmn, wmx = transform_bounds(mn, mx, world)
                    bounds.append({"min": np.round(wmn, 5).tolist(), "max": np.round(wmx, 5).tolist()})
                    global_min[:] = np.minimum(global_min, wmn)
                    global_max[:] = np.maximum(global_max, wmx)
            entry["limites_mundo_por_primitiva"] = bounds
        objects.append(entry)
        for child in (node.children or []):
            visit(child, world, depth + 1)
    roots = []
    if gltf.scenes:
        scene_index = gltf.scene or 0
        if scene_index < len(gltf.scenes):
            roots = list(gltf.scenes[scene_index].nodes or [])
    if not roots:
        roots = [i for i in range(len(nodes)) if i not in parents]
    for root in roots:
        visit(root, np.eye(4), 0)
    bounds_ok = np.all(np.isfinite(global_min)) and np.all(np.isfinite(global_max))
    result = {
        "arquivo": path.name,
        "tamanho_bytes": path.stat().st_size,
        "cena_ativa": gltf.scene,
        "nos": len(nodes),
        "malhas": len(gltf.meshes or []),
        "materiais": len(gltf.materials or []),
        "texturas": len(gltf.textures or []),
        "imagens": len(gltf.images or []),
        "raizes": roots,
        "limites_mundo_min": np.round(global_min, 5).tolist() if bounds_ok else None,
        "limites_mundo_max": np.round(global_max, 5).tolist() if bounds_ok else None,
        "dimensoes_mundo_xyz": np.round(global_max-global_min, 5).tolist() if bounds_ok else None,
        "malhas_detalhadas": mesh_info,
        "objetos_hierarquia": objects
    }
    all_maps.append(result)

payload = {"total_mapas": len(all_maps), "mapas": all_maps}
(OUT / "auditoria_mapa_detalhada.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
lines = ["# Auditoria detalhada do mapa", ""]
for m in all_maps:
    lines += [
        f"## {m['arquivo']}",
        f"- Dimensoes mundiais X/Y/Z: {m['dimensoes_mundo_xyz']}",
        f"- Limites minimos: {m['limites_mundo_min']}",
        f"- Limites maximos: {m['limites_mundo_max']}",
        f"- Nos: {m['nos']}; malhas: {m['malhas']}; materiais: {m['materiais']}; texturas: {m['texturas']}; imagens: {m['imagens']}",
        f"- Nos raiz da cena: {m['raizes']}",
        "",
        "| Profundidade | Objeto | Malha | Skin | Filhos |",
        "|---:|---|---:|---:|---:|"
    ]
    for obj in m["objetos_hierarquia"]:
        lines.append(f"| {obj['profundidade']} | {obj['nome']} | {obj['mesh']} | {obj['skin']} | {len(obj['filhos'])} |")
    lines.append("")
lines += [
    "## Limites desta auditoria",
    "- Os limites sao calculados a partir dos min/max dos accessors de vertices e das matrizes dos nos.",
    "- Objetos sem limites min/max nos accessors podem nao contribuir para a caixa global.",
    "- Isto nao confirma colisores fisicos, navegabilidade, interiores acessiveis ou pontos de spawn.",
    "- A unidade e a orientacao continuam sendo as declaradas no arquivo; a importacao no Godot ainda precisa ser testada."
]
(OUT / "auditoria_mapa_detalhada.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Auditoria do mapa concluida: {len(all_maps)} arquivo(s).")
for m in all_maps:
    print(f"{m['arquivo']}: nos={m['nos']}, malhas={m['malhas']}, dimensoes={m['dimensoes_mundo_xyz']}")
