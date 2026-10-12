# Cue index

All files are requested, not generated. `current_bank` means the existing event loader is present; it does not mean generated replacements are approved.

| Cue | Priority | Trigger | Files | Length | Playback |
| --- | --- | --- | ---: | --- | --- |
| `fonsters.core.greet.v1` | P0 | Explicit greet/wave and voice audition | 3 | 0.3–0.7 s | One-shot; current_bank |
| `fonsters.core.play.v1` | P0 | Explicit play; existing hop/spin/fetch aliases may use this | 3 | 0.4–0.9 s | One-shot; current_bank |
| `fonsters.core.rest.v1` | P0 | Explicit rest; existing stretch/rub aliases may use this | 3 | 0.6–1.2 s | One-shot; current_bank |
| `fonsters.core.blink.v1` | P0 | Explicit blink action only, not every idle or tracked blink | 3 | 0.08–0.2 s | One-shot; current_bank |
| `fonsters.core.look.v1` | P0 | Explicit curious-look action, not every gaze update | 3 | 0.2–0.5 s | One-shot; current_bank |
| `fonsters.touch.stroke.v1` | P1 | Slow intentional pet stroke | 9 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.touch.cuddle.v1` | P1 | Gentle held contact after threshold | 9 | 0.6–1 s | One-shot; requires_wiring |
| `fonsters.touch.tickle.v1` | P1 | Brief belly tickle | 9 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.touch.highfive.v1` | P1 | Paw contact during high-five | 9 | 0.15–0.4 s | One-shot; requires_wiring |
| `fonsters.touch.quick_swipe.v1` | P1 | Quick swipe with playful recoil | 9 | 0.15–0.35 s | One-shot; requires_wiring |
| `fonsters.touch.head_pat.v1` | P1 | Gentle head or brow-area pat | 9 | 0.2–0.5 s | One-shot; requires_wiring |
| `fonsters.touch.paw_tap.v1` | P1 | Tap on a paw or appendage | 9 | 0.15–0.4 s | One-shot; requires_wiring |
| `fonsters.touch.release.v1` | P1 | End of a held cuddle or stroke | 9 | 0.2–0.45 s | One-shot; requires_wiring |
| `fonsters.expression.content.v1` | P2 | Sparse idle while selected and content | 9 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.expression.delight.v1` | P1 | Chosen happy feeling or a completed fun action | 9 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.expression.curious.v1` | P2 | New nearby object or chosen curiosity | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.expression.thoughtful.v1` | P2 | Pause before a deliberate action | 9 | 0.5–0.9 s | One-shot; requires_wiring |
| `fonsters.expression.sad.v1` | P2 | Explicitly chosen sad feeling | 9 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.expression.reassure.v1` | P2 | Owner asks for comfort | 9 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.expression.sleepy.v1` | P1 | Entering rest or sleep | 9 | 0.5–1.1 s | One-shot; requires_wiring |
| `fonsters.expression.wake.v1` | P1 | Explicit wake or end of rest | 9 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.expression.surprised.v1` | P2 | Friendly discovery, not an alarm | 9 | 0.2–0.5 s | One-shot; requires_wiring |
| `fonsters.gesture.wave.v1` | P1 | Explicit or debounced mirrored hand wave | 9 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.gesture.jump.v1` | P1 | One jump takeoff | 9 | 0.15–0.4 s | One-shot; requires_wiring |
| `fonsters.gesture.land.v1` | P1 | Gentle landing after a jump | 9 | 0.15–0.35 s | One-shot; requires_wiring |
| `fonsters.gesture.spin.v1` | P1 | One deliberate twirl | 9 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.gesture.stretch.v1` | P1 | One relaxed stretch | 9 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.gesture.thumbs_up.v1` | P1 | Debounced recognised thumbs up | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.gesture.peace.v1` | P1 | Debounced recognised peace-sign gesture | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.gesture.thumbs_down.v1` | P1 | Debounced thumbs down, no punishment | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.social.wave.v1` | P1 | One Fonster greets another | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.social.reply.v1` | P1 | Reply to a nearby greeting | 9 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.social.company.v1` | P2 | Companions sit quietly together | 9 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.social.play_invite.v1` | P2 | One companion invites play | 9 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.social.ball_catch.v1` | P2 | Creature catches a passed ball | 9 | 0.2–0.5 s | One-shot; requires_wiring |
| `fonsters.social.shared_delight.v1` | P2 | One creature reacts to shared fun | 9 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.social.farewell.v1` | P2 | A visitor walks away | 9 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.world.step_grass.v1` | P2 | Contact of a visible nearby foot on grass | 6 | 0.08–0.2 s | One-shot; requires_wiring |
| `fonsters.world.step_path.v1` | P2 | Contact of a visible nearby foot on a path | 6 | 0.08–0.2 s | One-shot; requires_wiring |
| `fonsters.world.step_sand.v1` | P2 | Contact of a visible nearby foot on sand | 6 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.world.step_snow.v1` | P2 | Contact of a visible nearby foot on snow | 6 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.world.bench_settle.v1` | P2 | Creature sits on a bench | 3 | 0.2–0.5 s | One-shot; requires_wiring |
| `fonsters.world.ball_bounce.v1` | P2 | Visible soft toy ball hits the ground | 4 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.world.ball_catch.v1` | P2 | Soft toy ball reaches a paw | 4 | 0.1–0.2 s | One-shot; requires_wiring |
| `fonsters.world.waypoint_place.v1` | P1 | Owner saves a waypoint | 3 | 0.2–0.4 s | One-shot; requires_wiring |
| `fonsters.world.waypoint_arrive.v1` | P1 | Camera finishes travel to a waypoint | 3 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.world.home_arrive.v1` | P2 | Camera finishes return to session home | 3 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.world.discovery.v1` | P2 | New area becomes visible | 3 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.world.door.v1` | P2 | A future building doorway is crossed | 3 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.world.leaf_rustle.v1` | P2 | Nearby tree moves gently | 3 | 0.3–0.7 s | One-shot; requires_wiring |
| `fonsters.dance.spotlight.v1` | P2 | Spotlight fades onto a creature | 4 | 0.5–1 s | One-shot; requires_wiring |
| `fonsters.dance.disco_entrance.v1` | P2 | Disco setting finishes entering | 4 | 1–2 s | One-shot; requires_wiring |
| `fonsters.dance.confetti.v1` | P2 | Visible confetti burst | 4 | 0.3–0.8 s | One-shot; requires_wiring |
| `fonsters.dance.balloon_arrival.v1` | P2 | Balloons drop into view | 4 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.dance.disco_ball.v1` | P2 | Disco ball lowers into view | 3 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.dance.lights_dim.v1` | P2 | Dance lighting finishes dimming | 3 | 0.25–0.5 s | One-shot; requires_wiring |
| `fonsters.dance.stage_exit.v1` | P2 | Dance scene returns to daylight | 3 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.launch.letter_emerge.v1` | P1 | Furry letter bodies crawl out behind F | 3 | 0.4–0.8 s | One-shot; requires_wiring |
| `fonsters.launch.letter_settle.v1` | P1 | Letter creatures form the word | 3 | 0.2–0.5 s | One-shot; requires_wiring |
| `fonsters.launch.f_fall.v1` | P1 | Large F contacts the floor | 3 | 0.35–0.65 s | One-shot; requires_wiring |
| `fonsters.launch.scatter.v1` | P1 | Other letters run away after F falls | 3 | 0.6–1.1 s | One-shot; requires_wiring |
| `fonsters.ui.select.v1` | P1 | Owner selects an avatar or panel | 3 | 0.08–0.15 s | One-shot; requires_wiring |
| `fonsters.ui.confirm.v1` | P1 | Successful local save or confirmed owner action | 1 | 0.2–0.4 s | One-shot; requires_wiring |
| `fonsters.ui.cancel.v1` | P1 | Owner cancels or takes control back | 1 | 0.1–0.2 s | One-shot; requires_wiring |
| `fonsters.ui.undo.v1` | P2 | An undo is successfully applied | 2 | 0.15–0.3 s | One-shot; requires_wiring |
| `fonsters.ui.panel_open.v1` | P2 | An interactive panel springs open | 2 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.ui.panel_close.v1` | P2 | An interactive panel closes | 2 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.ui.practice_begin.v1` | P2 | Owner explicitly starts imitation practice | 4 | 0.3–0.6 s | One-shot; requires_wiring |
| `fonsters.ui.practice_progress.v1` | P2 | Practice reaches a milestone, not every frame | 4 | 0.15–0.3 s | One-shot; requires_wiring |
| `fonsters.ui.movement_kept.v1` | P2 | Owner keeps a learned movement | 4 | 0.5–0.9 s | One-shot; requires_wiring |
| `fonsters.ui.search_focus.v1` | P2 | A deliberate search finishes arranging results | 2 | 0.1–0.25 s | One-shot; requires_wiring |
| `fonsters.world.fountain.v1` | P2 | Approved nearby fountain ambience | 1 | 8–12 s | Loop; requires_wiring |
| `fonsters.world.park.v1` | P2 | Approved park ambience | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.world.seaside.v1` | P2 | Approved shore ambience | 1 | 12–18 s | Loop; requires_wiring |
| `fonsters.world.moonlit.v1` | P2 | Approved moonlit garden ambience | 1 | 12–18 s | Loop; requires_wiring |
| `fonsters.world.river.v1` | P2 | Approved river ambience | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.weather.drizzle.v1` | P2 | Weather-driven gentle drizzle scene | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.weather.rain.v1` | P2 | Weather-driven ordinary rain scene | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.weather.breeze.v1` | P2 | Weather-driven mild breeze scene | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.weather.snow.v1` | P2 | Weather-driven snow scene | 1 | 10–15 s | Loop; requires_wiring |
| `fonsters.dance.groove_75.v1` | P2 | Owner starts an approved dance groove | 2 | 8–16 s | Loop; requires_wiring |
| `fonsters.dance.groove_95.v1` | P2 | Owner starts an approved dance groove | 2 | 8–16 s | Loop; requires_wiring |
| `fonsters.dance.groove_115.v1` | P2 | Owner starts an approved dance groove | 2 | 8–16 s | Loop; requires_wiring |
