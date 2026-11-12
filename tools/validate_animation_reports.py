#!/usr/bin/env python3
"""Valida os relatorios de animacao gerados pelo Godot antes de publicar o artefato."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "godot_validation"
FLYGON = ROOT / "flygon_clip_audit.json"
DETAIL = ROOT / "animation_detail_report.json"


def load_json(path):
    if not path.is_file():
        raise RuntimeError(f"Relatorio ausente: {path.name}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise RuntimeError(f"JSON invalido em {path.name}: {exc}") from exc


def main():
    flygon = load_json(FLYGON)
    detail = load_json(DETAIL)

    errors = flygon.get("errors", [])
    clips = flygon.get("clips", [])
    summary = flygon.get("summary", {})
    if errors:
        raise RuntimeError(f"Flygon reportou erros: {errors}")
    if len(clips) != 16 or summary.get("clip_count") != 16:
        raise RuntimeError(f"Flygon: esperados 16 clipes, encontrados {len(clips)}")
    if summary.get("expected_clip_count") != 16 or not summary.get("clip_count_matches_expected"):
        raise RuntimeError("Resumo de quantidade de clipes do Flygon inconsistente")

    flygon_names = set()
    for clip in clips:
        name = clip.get("name", "<sem nome>")
        flygon_names.add(name)
        if clip.get("duration_seconds", 0) <= 0 or clip.get("track_count", 0) <= 0:
            raise RuntimeError(f"Flygon/{name}: duracao ou quantidade de tracks invalida")
        if not clip.get("bones_changed_from_start"):
            raise RuntimeError(f"Flygon/{name}: nenhuma mudanca de osso detectada")
        if len(clip.get("root_samples", [])) != 5:
            raise RuntimeError(f"Flygon/{name}: amostragem incompleta")

    assets = detail.get("assets", [])
    detail_summary = detail.get("summary", {})
    if detail_summary.get("failures"):
        raise RuntimeError(f"Auditoria geral reportou falhas: {detail_summary['failures']}")

    flattened = []
    node_only = []
    for asset in assets:
        file_name = asset.get("file", "<arquivo sem nome>")
        if not asset.get("loaded"):
            raise RuntimeError(f"{file_name}: modelo nao carregou")
        if asset.get("errors"):
            raise RuntimeError(f"{file_name}: {asset['errors']}")
        for player in asset.get("animation_players", []):
            for clip in player.get("clips", []):
                flattened.append((file_name, clip))
                bones = clip.get("changed_bones", [])
                nodes = clip.get("changed_nodes", [])
                if not bones and not nodes:
                    raise RuntimeError(f"{file_name}/{clip.get('name')}: clipe sem movimento detectado")
                if not bones and nodes:
                    node_only.append(f"{file_name}: {clip.get('name')} ({len(nodes)} nos)")

    expected_total = detail_summary.get("clips_tested")
    if len(flattened) != expected_total:
        raise RuntimeError(
            f"Contagem divergente: resumo={expected_total}, relatorio={len(flattened)}"
        )
    if detail_summary.get("models_tested") != len(assets):
        raise RuntimeError("Contagem de modelos divergente no relatorio detalhado")
    if expected_total != 29:
        raise RuntimeError(f"Esperados 29 clipes ativos; encontrados {expected_total}")

    detailed_flygon = {
        clip.get("name")
        for file_name, clip in flattened
        if file_name == "flygon_go_fest_2021.glb"
    }
    if detailed_flygon != flygon_names:
        raise RuntimeError("Lista de clipes do Flygon diverge entre os dois relatorios")

    print(f"Relatorios JSON validos: Flygon {len(clips)}/16 clipes; geral {len(assets)} modelos e {len(flattened)} clipes.")
    print("Todos os clipes apresentam movimento estrutural em ossos ou nos.")
    if node_only:
        print("Clipes animados por nos (sem movimento de ossos detectado):")
        for item in node_only:
            print(f" - {item}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as exc:
        print(f"ERRO NA VALIDACAO DOS RELATORIOS: {exc}", file=sys.stderr)
        sys.exit(1)
