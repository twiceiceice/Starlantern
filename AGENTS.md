# Project instructions

- Starlantern is a native single-player Godot game. Use Godot 4.7.2 and GDScript; version and download checksums live in tools/godot-version.json.
- Art direction: mature stylized adventure (2026-10-07 direction A), adult proportions, weathered cloth/leather/steel, open meadow and expedition camps. art/references/mature-rpg-2026-10-07/a-stylized-adventure.png is a concept target, not a game screenshot. The old rounded storybook C direction is superseded.
- CharacterView loads the shared 19-joint expedition_adult.glb; original mesh, three face/hair variants and 11 clips are authored in art/source/characters/build_adventurer.py (Python 3, no extra packages). Keep the GLB and .import settings in Git. Rebuild it after source edits. Second art pass adds smooth cloth, role-specific faces/armor, two-hand axe/cargo contact and distance-driven foot placement. Concept-level facial detail, body variety, cloth simulation and hammer/task-surface contact remain future work.
- CharacterHands/CharacterFeet apply visual IK after the animation; LimbIK never stretches bones. Reset bone poses before evaluating each animation frame. Foot placement queries environment layer 1 and releases anchors on jump, dodge and teleport; it must never move the gameplay collider or change damage timing. Axe origin is grip_r; left palm contact is tool-local (0, -0.22, 0).
- Core loop: march with a large caravan (one quest per stage; NPC crews do the rest), build a forward base, then secure the dungeon and let noncombat workers recover supplies. The caravan is numbers plus MultiMesh crowds, not individual AI.
- This is separate from ../starlantern (web prototype) and ../outputs/character-playground (older game). Do not modify them as part of ordinary Godot work.
- Keep gameplay independent of character mesh names. CharacterView is the replaceable presentation boundary.
- Rules belong in scripts/core and scripts/game; app wires nodes together; actors own movement and local state; ui presents state.
- Use native Godot scenes, CharacterBody3D, navigation and resources. Keep the architecture direct; no ECS, global event bus or networking until required.
- +Y up, 1 unit = 1 meter. Character visuals face +Z; Camera3D looks toward -Z. Use seconds for timers.
- scenes/world/windmeadow.tscn and forest_base.tscn are the active, editable levels; only one is loaded. tools/build_world.gd regenerates them from region_world_factory.gd (run without --headless: MultiMesh data needs a real renderer). Do not regenerate after manual scene edits without reconciling those changes. The original expedition_valley.tscn is preserved.
- RegionLayout terrain height is shared by rendering, collision, navigation and the caravan. Navigation excludes obstacles, river water and steep slopes. This is not dynamic voxel navigation; changes to terrain or obstacles must update the saved meshes.
- CampArt authors the shared workshop, kitchen, supply cart, fire, luggage and wagon details. Meshes are cached and merged per material; caravan trim/cargo stay MultiMesh. collider_specs is also the source of navigation footprints (overhead canopies are excluded). Reserve staged base props in region_world_factory before baking; keep central routes and quest posts accessible. These props do not implement crafting or cooking AI.
- Do not commit .godot, .tools, builds or captures. Commit generated .gd.uid files and required import settings.
- Keep model sources in art/source, runtime assets in assets, and third-party provenance in THIRD_PARTY_NOTICES.txt.
- Run tools/check.ps1 after gameplay edits. Inspect actual rendered frames after visual changes. Verify the exported executable when changing export/runtime dependencies.
- Do not claim interactive keyboard/mouse playtesting unless actually performed. Engine-driven input integration checks and rendered captures are distinct evidence.
- Do not claim the full old game was migrated. Track unimplemented work in docs/roadmap.md.
