# The growing local Fonster world

The lobby is now an explorable native neighborhood. Its relaxed gathering feel
is inspired by Nathan's Mii Plaza reference; all scenery, creatures, rigs, fur,
and motion are original procedural geometry.

Open **Launch Neighborhood.command** for a twelve-companion preview with all
areas open and separate synthetic memories. **Launch Lobby.command** opens the
persistent local lobby, beginning with Coral, Moss, Iris, and Orbit. Use **Add
local Fonster** to enroll more of the existing gallery companions. This is a
local prototype roster, not a production pet migration or online population.

| Companions here | New space |
| --- | --- |
| 1–2 | Gathering garden |
| 3–4 | Bench walk |
| 5–7 | Fountain plaza |
| 8–9 | Willow park, stepping stones and picnic table |
| 10–12 | Little neighborhood with three pastel houses |

The world radius expands from 3 to 8.2 scene units. Enrollment is additive and
persists in a separate versioned local archive. It never removes a pet, changes
appearance/seed identity, or rewards daily attendance. The temporary visitor
slot keeps the existing snapshot review, end-visit, privacy and friendship
behavior. Online invitations, shared presence, and building interiors remain
future work.

Choose an area to walk there with the selected friend. Click a path for a solo
walk; drag to orbit the view. Whole world, Follow, turn and zoom buttons provide
keyboard/accessibility alternatives. `[` and `]` turn the camera when the
request editor is not focused. Rest on a bench directs the selected Fonster to
an available seat; another physical action or a walk interrupts resting.

Routing uses swept clearance and a small deterministic A* grid around fountain,
trees, benches, picnic table, houses and nearby companions. Blocked routes
replan against current companion positions. Rectangle/circle segment checks
prevent corner clipping, and walkers reach each waypoint before turning.
Companions keep their distance and make small side steps to pass. Automatic social moments require nearby companions and defer to deliberate
walks and bench approaches.
The world has one bounded animation clock, and fountain water, walking, poses
and following camera all pause under Pause, Still, Reduce Motion, background or
Low Power. Explicit Still/Reduce Motion navigation makes a static placement.
Camera movement from an explicit user gesture is immediate, with no transition.

Group views above six members use 2,800 head fibres and lower appendage density,
with the same resolved coat colours, face grooming, actual 3D fibres, closed
volumetric head, smile and original articulated rig. The solo portrait keeps its
full fur detail. Appearance descriptors, legacy 2D raster, PNG/GIF exports and
existing links are unchanged.

Verification commands:

```
script/verify_world.sh
script/verify_phase2.sh
script/verify_social.sh
script/verify_motion.sh
script/verify_appearance.sh
script/build_and_run.sh --verify --lobby --world-members 12 \
  --personality-file evidence/world-preview/personality.json \
  --lobby-probe-file evidence/world-preview-probe.json
```

`--world-members` is a bounded (2–12), non-persistent visualization fixture.
`--world-area` selects an unlocked area and places two synthetic companions
there for scene previews. Build/run resolves
relative archive and capture arguments against the repository before Finder
launches the process. Scripted captures use task-local archives; no new external
services, user permissions, assets or software are required.
