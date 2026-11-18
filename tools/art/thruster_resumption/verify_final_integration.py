"""Bind a two-family source import to its exact exercised native art.

Old native profile paths remain defaults. New FX revisions can provide fresh
profiles; capture and evidence paths are resolved through their actual hashes.
"""
import argparse
from pathlib import Path
import hashlib
import json
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "tech-priests_src"
EVIDENCE = ROOT / "docs/art/thruster-resumption-20261117/animation-capture"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def module_body(path):
    text = path.read_text(encoding="utf-8-sig").replace("__model-visual-review__", "__tech-priests__")
    start = re.search(r"(?m)^do$", text)
    assert start is not None, "Missing generated family block: " + str(path)
    assert all(not line.strip() or line.lstrip().startswith("--")
               for line in text[:start.start()].splitlines()), "Executable prefix outside tested family blocks"
    return text[start.start():].strip()


def resolve_profile(value):
    """Accept an absolute/relative profile path or a local-validation basename."""
    value = Path(value)
    if value.is_absolute() or value.exists():
        return value.resolve()
    candidate = ROOT.parent / "local-validation" / value
    assert candidate.is_dir(), "Native profile does not exist: " + str(candidate)
    return candidate.resolve()


def evidence_label(profile):
    name = profile.name
    if name.startswith("thruster-art-"):
        name = name[len("thruster-art-"):]
    return re.sub(r"-\d{8}$", "", name)


def select_bound_evidence(preferred, candidates, predicate, description):
    candidates = list(dict.fromkeys([preferred, *candidates]))
    matches = [path for path in candidates if path.is_file() and predicate(path)]
    if preferred in matches:
        return preferred
    assert len(matches) == 1, description + ": expected one hash-bound receipt; found " + str(matches)
    return matches[0]


def native_evidence(profile, preparation_sha):
    preferred = EVIDENCE / evidence_label(profile) / "native-power-art-validation.json"
    candidates = EVIDENCE.glob("native-*/native-power-art-validation.json")
    return select_bound_evidence(preferred, candidates,
        lambda path: read(path).get("preparation_sha256") == preparation_sha,
        "Native image evidence for " + profile.name)


def compact_evidence(profile, receipt_path, receipt):
    label = evidence_label(profile).removeprefix("native-")
    preferred = EVIDENCE / label / "evidence-manifest.json"

    def matches(path):
        data = read(path)
        directory = Path(data.get("source_directory", ""))
        if not directory.is_absolute():
            directory = ROOT / directory
        return (directory.resolve() == receipt_path.parent.resolve() and
                data.get("master_sha256") == receipt["master_sha256"])

    return select_bound_evidence(preferred, EVIDENCE.glob("*/evidence-manifest.json"),
                                 matches, "Compact capture evidence for " + receipt["prototype"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--narrow-profile", type=Path,
        default=ROOT.parent / "local-validation/thruster-art-native-narrow-v11e-20261117",
        help="Tested narrow native profile path or local-validation basename")
    parser.add_argument("--wide-profile", type=Path,
        default=ROOT.parent / "local-validation/thruster-art-native-wide-v18g-20261117",
        help="Tested wide native profile path or local-validation basename")
    parser.add_argument("--out", type=Path, default=EVIDENCE / "final-integration.json",
        help="Output JSON path, or a directory in which to write final-integration.json")
    args = parser.parse_args(argv)
    profiles = [("void-fusion-thruster", resolve_profile(args.narrow_profile)),
                ("large-void-fusion-thruster", resolve_profile(args.wide_profile))]
    manifest_path = SOURCE / "graphics/entity/void-fusion-thrusters-v01/import-manifest.json"
    manifest = read(manifest_path)
    assert {f["prototype"] for f in manifest["families"]} == {name for name, _ in profiles}
    assert len(manifest["families"]) == len(profiles) == 2
    module = SOURCE / "prototypes/generated_graphics/void-fusion-thrusters-v01.lua"
    assert sha(module) == manifest["module_sha256"]
    late_import = SOURCE / "data-final-fixes.lua"
    late_text = late_import.read_text(encoding="utf-8")
    require = 'require("prototypes.generated_graphics.void-fusion-thrusters-v01")'
    assert late_text.count(require) == 1
    assert late_text.index(require) > late_text.index('require("prototypes.generated_graphics.thetazine-thruster-v04")')

    power_path = EVIDENCE / "native-power/validation.json"
    power = read(power_path)
    assert power["status"].startswith("PASS_")
    runtime = power["updated_runtime_source_hashes"]
    for filename, digest in runtime.items():
        assert sha(SOURCE / filename) == digest

    private_blocks, private_files, families = [], {}, []
    for prototype, profile in profiles:
        private = profile / "mods/model-visual-review_0.1.0"
        private_module = private / module.relative_to(SOURCE)
        private_manifest = read(private / manifest_path.relative_to(SOURCE))
        assert sha(private_module) == private_manifest["module_sha256"]
        private_blocks.append(module_body(private_module))
        assert len(private_manifest["families"]) == 1
        family = private_manifest["families"][0]
        assert family["prototype"] == prototype
        assert family == next(f for f in manifest["families"] if f["prototype"] == family["prototype"])
        preparation_path = profile / "capture-native-preparation.json"
        preparation = read(preparation_path)
        assert preparation["mode"] == "actual_power_coupled" and not preparation["pilot"]
        assert preparation["runtime_updates"] == runtime
        assert preparation["native_power_proof_sha256"] == sha(power_path)
        assert sha(private / "data-final-fixes.lua") == preparation["data_sha256"]
        assert sha(private / "scenarios/model-placement/control.lua") == preparation["control_sha256"]
        assert sha(private_module) == preparation["graphics_module_sha256"]
        assert sha(profile / "mods/tech-priests/control.lua") == preparation["private_observer_control_sha256"]
        for filename, digest in runtime.items():
            assert sha(profile / "mods/tech-priests" / filename) == digest
        bindings = preparation["capture_bindings"]
        assert len(bindings) == 1 and bindings[0]["prototype"] == prototype
        binding = bindings[0]
        assert binding["receipt_sha256"] == family["receipt_sha256"]
        assert binding["input_glb"] == family["input_glb"]
        assert binding["registration"] == family["registration"]
        for item in private_manifest["files"]:
            assert sha(private / item["file"]) == item["sha256"]
            assert sha(SOURCE / item["file"]) == item["sha256"]
            assert item["file"] not in private_files
            private_files[item["file"]] = item["sha256"]
        native = native_evidence(profile, sha(preparation_path))
        review = native.with_name("visual-fit-review.json")
        rv, nv = read(review), read(native)
        assert rv["status"].startswith("PASS_ACTUAL_NATIVE_")
        assert nv["status"] == "PASS_NATIVE_POWER_CONTROLLED_ART_REQUIRES_ACTUAL_IMAGE_FIT_REVIEW"
        assert nv["high_quality_actual_log_verified"]
        assert len(nv["families"]) == 1 and nv["families"][0]["prototype"] == prototype
        assert nv["families"][0]["registration"] == family["registration"]
        assert rv["native_validation_sha256"] == sha(native)
        assert rv["body_glb_sha256"] == family["input_glb"]["sha256"]
        assert rv["capture_receipt_sha256"] == family["receipt_sha256"]
        for filename, digest in rv["native_png_sha256"].items():
            assert sha(review.parent / filename) == digest
        assert len(rv["images_actually_viewed"]) >= 4
        receipt_path = Path(family["capture_receipt"])
        assert sha(receipt_path) == family["receipt_sha256"]
        receipt = read(receipt_path)
        assert receipt["prototype"] == prototype
        assert receipt["registration"] == family["registration"]
        assert receipt["input_glb"] == family["input_glb"]
        assert sha(Path(family["input_glb"]["path"])) == family["input_glb"]["sha256"]
        capture_profile_path = receipt_path.with_name("profile.json")
        assert sha(capture_profile_path) == receipt["binding"]["profile_sha256"]
        capture_profile = read(capture_profile_path)
        assert capture_profile["glb_sha256"] == family["input_glb"]["sha256"]
        geometry = capture_profile["geometry_handoff"]
        assert sha(Path(geometry["path"])) == geometry["sha256"]
        assert read(Path(geometry["path"]))["body_glb_sha256"] == family["input_glb"]["sha256"]
        underlay = capture_profile["underlay"]
        assert sha(Path(underlay["glb"])) == underlay["sha256"]
        # Historical narrow reviews bind the whole capture receipt rather than
        # repeating its well hash. The capture-profile hash above covers both.
        if "well_glb_sha256" in rv:
            assert rv["well_glb_sha256"] == underlay["sha256"]
        compact = compact_evidence(profile, receipt_path, receipt)
        compact_data = read(compact)
        for item in compact_data["files"]:
            assert sha(ROOT / item["source"]) == sha(ROOT / item["copy"]) == item["sha256"]
        assert sha(ROOT / compact_data["master_retained"]) == compact_data["master_sha256"]
        assert compact_data["master_sha256"] == receipt["master_sha256"]
        families.append({"prototype": family["prototype"], "body_glb_sha256": family["input_glb"]["sha256"],
                         "well_glb_sha256": underlay["sha256"], "geometry_handoff": geometry,
                         "tested_native_profile": str(profile),
                         "capture_receipt_sha256": family["receipt_sha256"], "registration": family["registration"],
                         "native_validation": {"file": native.relative_to(ROOT).as_posix(), "sha256": sha(native)},
                         "actual_image_review": {"file": review.relative_to(ROOT).as_posix(), "sha256": sha(review)},
                         "compact_source_evidence": {"file": compact.relative_to(ROOT).as_posix(), "sha256": sha(compact)}})
    assert module_body(module) == "\n\n".join(private_blocks)
    assert {i["file"]: i["sha256"] for i in manifest["files"]} == private_files
    assert len(manifest["files"]) == len(private_files) == 14

    result = {
        "status": "PASS_LOCAL_FUSION_SOURCE_IMPORT_AND_FINAL_NATIVE_ART_BINDING",
        "source_activation": {"file": late_import.relative_to(ROOT).as_posix(), "sha256": sha(late_import),
                              "require_count": 1, "scope": "Late graphics import after preserved Hydrogen and Thetazine imports."},
        "generated_module": {"file": module.relative_to(ROOT).as_posix(), "sha256": sha(module)},
        "import_manifest": {"file": manifest_path.relative_to(ROOT).as_posix(), "sha256": sha(manifest_path)},
        "private_module_equivalence": "Exact two tested family blocks after mod namespace normalization; no additional executable statements.",
        "png_equivalence": "All14 PNGs byte-identical to independently exercised private imports.",
        "runtime_source_hashes": runtime,
        "power_lifecycle_save_reload_proof": {"file": power_path.relative_to(ROOT).as_posix(), "sha256": sha(power_path)},
        "families": families,
        "actual_image_review_binding": "Both family-specific native fit reviews bind at least four viewed images to the exercised profiles and exact imported capture receipts.",
        "scope": "Local source activation with exact tested graphics/control identity. No normal-profile installation, release, commit, final owner artistic approval, animated rigid-body GLB or real background refraction is claimed."
    }
    out = args.out.resolve()
    if out.suffix.lower() != ".json":
        out = out / "final-integration.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(result["status"])
    print("Both tested Lua blocks,14 PNGs, current runtime sources, final capture evidence and native image reviews verified.")


if __name__ == "__main__":
    main()
