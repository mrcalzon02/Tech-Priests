"""Package tested production adapters separately from isolated review control."""
import argparse
import json
from pathlib import Path
import shutil
from run_compressor_native_jig import sha
from checkpoint_assembler_v01 import write


def main():
    ap=argparse.ArgumentParser()
    for k in ('profile','reload-profile','verification'):ap.add_argument('--'+k,required=True)
    ap.add_argument('--repo',default='.')
    args=ap.parse_args();repo=Path(args.repo).resolve();profile=Path(args.profile).resolve();reload=Path(args.reload_profile).resolve();verification=Path(args.verification).resolve()
    out=repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v04-native-preservation'
    if out.exists():raise FileExistsError('Preserve native deliveries')
    native=json.loads((profile/'native-jig-receipt.json').read_text());proof=json.loads((verification/'native-verification.json').read_text());other=json.loads((reload/'native-jig-receipt.json').read_text());art=repo/'art/source-to-3d/metallic-hydrogen-chain/canister-assembler/v03-finish-and-states'
    if not native['passed'] or not proof['passed'] or native['results']!=other['results'] or not proof['native_clock']['passed'] or not proof['safe_prototype_normal_map_created']:raise RuntimeError('Native gate')
    if sha(art/'assembler-v03.blend')!=proof['model_source_sha256'] or sha(art/'captures/capture.json')!=proof['capture_sha256']:raise RuntimeError('Changed engineering source')
    out.mkdir(parents=True);(out/'.gitattributes').write_bytes(b'* -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\n')
    for source,target in [(profile/'native-jig-receipt.json','native-jig-receipt.json'),(reload/'native-jig-receipt.json','reload-jig-receipt.json'),(verification/'native-verification.json','native-verification.json'),(profile/'spec.json','spec.json')]:shutil.copy2(source,out/target)
    for name in ('tp-mh7-assembler_0.0.1','tp-mh7-pellet-decay_0.0.3'):shutil.copytree(profile/'mods'/name,out/'prototype-mods'/name)
    shutil.copytree(profile/'mods/tp-mh7-assembler-review_0.0.1',out/'isolated-review-mod/tp-mh7-assembler-review_0.0.1')
    mod=out/'prototype-mods/tp-mh7-assembler_0.0.1'
    for path,digest in native['production_mod_hashes'].items():
        if sha(mod/path)!=digest:raise RuntimeError('Packaged addon differs '+path)
    for path in out.rglob('*'):
        if path.suffix.lower() in ('.png','.jpg','.jpeg') and '/graphics/' not in path.as_posix():raise RuntimeError('Native screenshot pixels must stay private')
    write(out/'port_manifest.json',dict(machine='canister-assembler',native_entity='tp-mh7-canister-assembler',footprint=[4,4],ports=[],native_verified=True,fluid_boxes=0,item_inputs=['live formed metallicized pellet','empty pressure shell'],item_output='contained metallicized pellet; spent inputs return inert without consuming shell',engineering_source_sha256=proof['model_source_sha256']))
    checkpoint=dict(status='native_live_preservation_inserters_batch_reload_cadence_sound_binding_and_graphical_review_pass; ordinary_integration_pending',engineering_delivery='../v03-finish-and-states',source_sha256=proof['model_source_sha256'],native_sites=36,orientations=4,footprint=[4,4],fluid_boxes=0,
        actual_formed_pellet_and_shell_inserters_verified=True,mixed_quality_feeds_verified=True,three_station_batches_verified=True,sealing_uses_actual_crafting_progress=True,verified_actual_seals=proof['verified_actual_seals'],
        health_quality_phase_and_remaining_deadline_conserved=True,damaged_shell_condition_retained_on_unseal=True,expired_pellets_return_inert_without_shell_consumption=True,blocked_containment_preserves_remaining_time=True,destruction_releases_original_live_stock=True,
        missing_partner_stops_and_unformed_rejection_verified=True,tick400_reload_identical=True,safe_production_addon_normal_map_verified=True,native_cycle_ticks=960,native_source_cell_ticks=60,actual_two_loop_wraps_each_direction=True,
        native_audio_binding_verified=True,native_sound_phase_synchronization_verified=False,native_visual_crafting_phase_synchronization_verified=False,agent_graphical_review=True,clean_native_production_images=64,private_clock_counter_images=260,owner_approved=False,ordinary_chain_integrated=False,energy_and_recipe_economy_final=False,
        next=['Recover and inspect actual V14 reactor sources and original references; preserve ring/camera anchors while refining Minoris, Majoris and Maximus','Integrate the ordinary chain with final energy, recipes and UI, preserving live pellet state and verified cadence; visual/audio phase offsets require explicit treatment if process-synchronous presentation is needed','Finish remaining sprite-only buildings with practical hardware and fluid interfaces'])
    write(out/'CHECKPOINT.json',checkpoint)
    write(out/'VISUAL_REVIEW.json',dict(status='agent native review; owner acceptance not inferred',source_sha256=proof['model_source_sha256'],native_own_graphic_hashes=native['graphic_hashes'],reviewed_clean_production_images=64,private_native_image_hashes=proof['private_native_images'],
        findings=['Four full-resolution batch directions and the complete private production contact sheet were viewed. Original proportions/camera/body and +4px native shift are retained, with solid-only interfaces and no invented gameplay ports.','Actual working and stopped views show the three-station mechanism without stretching. Ordinary inserter pickup anywhere on the entity remains sufficient.','Two observed 960-tick animation wraps per direction establish cadence; the engine uses per-entity visual phase offsets. Exact graphics-to-seal and sound-to-seal phase synchronization is not claimed.'],owner_approved=False,native_pixels_published=False))
    (out/'README.md').write_text('# Canister assembler V04 native preservation review\n\nThirty-six actual 4x4 sites in four directions verify real formed-pellet and shell inserters, mixed-quality feeds, three-station batches, live decay before sealing, expiration into inert without consuming a shell, blocked containment, missing partners and rejection of unformed raw stock. Sealing follows actual native crafting progress at the three station phases. Seventy-three actual seals preserve health, quality, phase, remaining lifetime and original shell condition. Unsealing collected stock after a long contained wait resumes its exact remaining deadline. Destruction releases the original live item unchanged. Complete histories match after a real tick-400 save/reload.\n\nThe production addon keeps live stock outside native ingredient consumption and uses the existing seal operation. The engine consumes only a hidden clock token; disabled guarded presentation recipes cannot manufacture fresh stock. Production event adapters create no scenario, test stock or screenshots. A normal map loads with only the two production addons. The destructive isolated review world and continuous no-stock clock probe are separately packaged under isolated-review-mod; do not enable that fixture in an ordinary game.\n\nActual sound binding loads at the planned .65 working gain. The binary-exact .25 playback and 240 sequence entries give sixteen source cells sixty ticks each and a 960-tick loop. Private half-second counter screenshots observe two complete wraps per direction. Engine animation phase offsets vary per entity: these cadence checks do not establish exact graphics-to-seal or sound-to-seal phase synchronization.\n\nSixty-four clean production images were reviewed with the existing fixed camera/body proportions and +4px native shift. There are no external fluid boxes on this solid-input assembler. Native screenshots containing game pixels stay private; hashes are included. The editable V03 engineering source, GLB, textures and own captures remain in the preceding delivery.\n\nThis is agent-reviewed isolated integration, not owner acceptance or final ordinary-chain integration. Energy is void in the review prototype; final energy/recipe/economy/UI and treatment of any required process-synchronous visual/audio phase remain open. Three plasma reactors and the remaining sprite-only building scope still require work.\n',encoding='utf-8')
    write(out/'SHA256.json',{p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='SHA256.json'})
    path=repo/'docs/art/metallic-hydrogen-chain/PRODUCTION_CONTINUATION.json';d=json.loads(path.read_text());d.update(current_machine='plasma-reactor-minoris',current_candidate=str(out),assembler_native=checkpoint,next_steps=checkpoint['next'])
    for row in d['queue']:
        if row['id']=='canister-assembler':row['status']='V03 art/V04 native live-state preservation, production, cadence and graphical review saved; ordinary integration and phase-offset policy remain open'
    d['reactor_continuation']=dict(status='actual V14 source and original reference recovery required',reported_package='https://chatgpt.com/library?file_id=libfile_a3796cbd07d48191a3fe03c7f4645781&account_id=personal',native_source_recovered=False,order=['Minoris','Majoris','Maximus'],constraint='Use actual containment-ring center, projected ellipse and tilt as anchor. Preserve established ring/camera placement unless demonstrated evidence requires correction; reported completion is not source verification.')
    write(path,d);print('ASSEMBLER_NATIVE_CHECKPOINT',out,flush=True)


if __name__=='__main__':main()
