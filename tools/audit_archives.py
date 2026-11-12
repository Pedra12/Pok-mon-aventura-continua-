#!/usr/bin/env python3
"""Extract and inspect model archives uploaded to the repository."""
import json, zipfile
from pathlib import Path
from pygltflib import GLTF2

ROOT=Path(".")
OUT=ROOT/"zip_audit"
OUT.mkdir(exist_ok=True)
archives=[ROOT/"darko_with_pikachu_and_pokeballs.zip",ROOT/"pokemon_red_1996.zip"]
report={"archives":[]}
for archive in archives:
    item={"arquivo":archive.name,"existe":archive.exists()}
    if not archive.exists():
        report["archives"].append(item); continue
    item["bytes"]=archive.stat().st_size
    with zipfile.ZipFile(archive) as z:
        entries=[]
        extracted=OUT/archive.stem
        extracted.mkdir(parents=True,exist_ok=True)
        for info in z.infolist():
            name=info.filename
            entries.append({"path":name,"bytes":info.file_size,"diretorio":info.is_dir()})
            # Avoid path traversal and extract only regular files
            dest=(extracted/name).resolve()
            if info.is_dir() or not dest.is_relative_to(extracted.resolve()): continue
            dest.parent.mkdir(parents=True,exist_ok=True)
            with z.open(info) as src, open(dest,"wb") as dst:
                dst.write(src.read())
        item["entries"]=entries
        glbs=[]
        for p in extracted.rglob("*.glb"):
            g={"path":str(p.relative_to(extracted)),"bytes":p.stat().st_size}
            try:
                gl=GLTF2().load(str(p))
                nodes=gl.nodes or []
                g.update({"nodes":len(nodes),"meshes":len(gl.meshes or []),"skins":len(gl.skins or []),
                          "joints":[len(s.joints or []) for s in (gl.skins or [])],
                          "animations":[{"name":a.name or f"Animation_{i}","channels":len(a.channels or []),"samplers":len(a.samplers or [])} for i,a in enumerate(gl.animations or [])],
                          "node_names":[n.name for n in nodes if n.name]})
            except Exception as e: g["parse_error"]=str(e)
            glbs.append(g)
        item["glb_models"]=glbs
    report["archives"].append(item)
(OUT/"archive_report.json").write_text(json.dumps(report,indent=2,ensure_ascii=False))
# readable summary
lines=[]
for a in report["archives"]:
    lines += [f"## {a['arquivo']} ({a.get('bytes','?')} bytes)",f"Entries: {len(a.get('entries',[]))} | GLBs: {len(a.get('glb_models',[]))}"]
    for g in a.get("glb_models",[]):
        lines.append(f"- {g['path']}: {g.get('nodes','?')} nodes, {g.get('meshes','?')} meshes, skins={g.get('skins','?')} joints={g.get('joints',[])} animations={g.get('animations',[])}")
    lines.append("")
(OUT/"archive_report.md").write_text("\n".join(lines))
print("\n".join(lines))
