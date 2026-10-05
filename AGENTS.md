# Project instructions

- Starlantern is a native single-player Godot game. Use Godot 4.7.2 and GDScript; version and download checksums live in tools/godot-version.json.
- Art direction: C, rounded storybook 3D. The current procedural characters are placeholders, not finished models.
- Core loop: march with a large caravan (one quest per stage; NPC crews do the rest), build a forward base, then secure the dungeon and let noncombat workers recover supplies. The caravan is numbers plus MultiMesh crowds, not individual AI.
- This is separate from ../starlantern (web prototype) and ../outputs/character-playground (older game). Do not modify them as part of ordinary Godot work.
- Keep gameplay independent of character mesh names. CharacterView is the replaceable presentation boundary.
- Rules belong in scripts/core and scripts/game; app wires nodes together; actors own movement and local state; ui presents state.
- Use native Godot scenes, CharacterBody3D, navigation and resources. Keep the architecture direct; no ECS, global event bus or networking until required.
- +Y up, 1 unit = 1 meter. Character visuals face +Z; Camera3D looks toward -Z. Use seconds for timers.
- scenes/world/expedition_valley.tscn is the saved, editable level. tools/build_world.gd regenerates it from world_factory.gd (run it without --headless: MultiMesh data needs a real renderer); do not regenerate after manual level edits without reconciling those changes.
- Existing navigation is a flat, obstacle-excluded mesh. It is not dynamic voxel navigation. Changes to level obstacles must update or rebake navigation.
- Do not commit .godot, .tools, builds or captures. Commit generated .gd.uid files and required import settings.
- Keep model sources in art/source, runtime assets in assets, and third-party provenance in THIRD_PARTY_NOTICES.txt.
- Run tools/check.ps1 after gameplay edits. Inspect actual rendered frames after visual changes. Verify the exported executable when changing export/runtime dependencies.
- Do not claim interactive keyboard/mouse playtesting unless actually performed. Engine-driven input integration checks and rendered captures are distinct evidence.
- Do not claim the full old game was migrated. Track unimplemented work in docs/roadmap.md.
