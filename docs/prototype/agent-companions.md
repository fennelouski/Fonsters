# Agent companions: local prototype

Open `Launch Agent Studio.command` on the Air. It builds the existing macOS target and opens twelve fluffy Fonsters with separate preview memories. Prepare a little plan, review the actions, and choose **Let them explore**. The status strip shows its source and progress. Open Agent Studio again to see the action history and the source of learned rituals. Escape or any direct creature interaction takes control back immediately.

This implements the owner's choice of **Everything** for Fonster influence: movement, expressive reactions, chosen Fonster feelings, local friendships, and gradual personality learning. Each scope has its own switch. Changes invalidate an already reviewed plan. Agent Studio plans require a deliberate local start; there is no unattended connection or default agent at launch. The separately enabled [Fonster Social companion](social-presence.md) can renew finite local plans while the app is active. It always excludes human reflection, and direct creature interaction stops it.

## What is real now

The simulated pilot drives the actual native RealityKit creatures, navigation, paired ball game, quiet company, feelings, and bounded personality tendencies. A reviewed local `.fonster-agent.json` action file uses exactly the same executor. These are local snapshot companions, including any invited visitor; no action contacts another person's device. The agent controls one owned Fonster. A peer can respond to a local social action, but its private personality is never trained by that action.

**Simulated pilot** and **Reviewed local file** are distinct sources. A file's agent label is unverified display text. Muse, Grok Bot, Dots, Hermes, and Claude are inspirations and potential future adapters; none has been connected or authenticated. No provider API capability is assumed.

## Local file handoff

Prepare a plan and use **Save agent template…** to get the current Fonster's random, non-sensitive public ID and valid example actions. An agent can edit this JSON; the human imports and reviews the entire plan before starting it. The file has a five-minute lifetime. For a new plan, use a new random `programID`, current ISO 8601 UTC `createdAt`, and `expiresAt` no more than five minutes later. Importing a plan alone causes no action. Saving creates a fresh template with a new plan ID and current lifetime; every human-reflection step is removed, so a private cue cannot leave through this handoff.

The version 1 envelope has exactly these fields:

```json
{
  "version": 1,
  "programID": "random UUID for this plan",
  "fonsterID": "public UUID from the exported example",
  "agentLabel": "My companion pilot",
  "createdAt": "current ISO 8601 UTC timestamp",
  "expiresAt": "ISO 8601 UTC timestamp within five minutes",
  "actions": [{ "kind": "react", "reaction": "greet" }]
}
```

These placeholder strings illustrate the envelope; export an actual example for a runnable file. Maximum file size is 16 KB, maximum twelve actions, and maximum two minutes of active execution. Ordinary actions are at least eight seconds apart; navigation gets eighteen seconds. A new plan cannot reset the action rate limit. A bounded cache rejects recently started plan IDs in the current session; a relaunch still requires a fresh local import and explicit start. The entire plan is validated at review and start, and its target, peers, scopes, expiry and reflection permissions are checked again on every action. Unknown keys and incompatible optional fields are rejected.

| Kind | Required fields | Meaning |
| --- | --- | --- |
| `react` | `reaction` | `greet`, `play`, `rest`, `blink`, `look`, `hop`, `spin`, `stretch`, `highFive`, `rub`, or `fetch` |
| `explore` | `area` | An unlocked `garden`, `benches`, `plaza`, `park`, or `neighborhood` |
| `feeling` | `feeling` | A Fonster's `neutral`, `bright`, `curious`, `cozy`, `quiet`, or `low` feeling |
| `greet`, `playTogether`, `quietTogether` | `peerID` | A present local companion's public UUID, different from the owned Fonster |
| `bench` | none | Approach an available bench |
| `reflect` | `reflectionField`, `cue`; optionally `peerID` | An exact match for a human-selected, enabled broad cue and audience |

`fetch` also requires movement permission. Reflection with a local companion also requires friendship permission. There are no arbitrary positions, URLs, scripts, prompts, credentials, private identifiers, or executable payloads. No networking, filesystem watching, socket, web server, or shell execution is reachable from a native agent action.

## Human reflection is separate

All three reflection fields start **off**, independently of the Fonster influence switches. The human must choose and enable each cue:

| Field | Allowed coarse cues |
| --- | --- |
| `feeling` | `bright`, `quiet` |
| `activity` | `focused`, `resting` |
| `travel` | `outAndAbout`, `exploring` |

The audience is **This Mac only** by default. **Local companions** permits a response from a peer already in this local preview. Neither option is a public network audience. There is no exact location, GPS access, camera emotion inference, reading of tasks or conversations, or background activity ingestion. The agent cannot choose a different human cue from the one the human selected.

Reflection creates a transient reaction. It does not change the Fonster's saved feeling or a visit file, and it produces no personality learning. Human cues are not persisted in the agent ritual archive or exported to other people. Changing or revoking a field cancels the plan and clears ongoing agent motion. Revoking agent control also turns all reflection fields off. Reflection choices are session-only; reopening starts them off again.

## Personality and interruptions

Owner rituals stay in the existing personality archive unchanged. Agent ritual counts live in a separate version 1 file, keyed by a random public Fonster ID, with source counts for simulation and reviewed local files. No human cue, raw action file, agent label, prompt or conversation is retained there. Learning is capped at one contribution per minute, three per app session per Fonster, and six per local calendar day. A daily cap and last-learning time survive reopening. Agent contributions add a small, bounded influence to greeting warmth and play energy; owner interactions remain the stronger influence. A deliberately exported visit can contain these two current temperament values, but never the source counters or human context.

A single replaceable action drives animation. Direct interactions, selecting another creature/friend, room rebuilds, changing permissions and revocation stop the old plan. Pause, Still mode, Reduce Motion, background and Low Power hold automatic execution, without time catch-up or learning while held. Still mode and Reduce Motion allow explicit, rate-limited **Next static pose** actions; no animation queue is created.

Unreadable or newer agent archives are preserved. Only temporary agent ritual changes are used in that case. Existing appearance descriptors, seed identity, 2D portraits, PNG/GIF exports, original links, SwiftData/iCloud data, and user records are unchanged.

## Later integration boundary

A future agent adapter should expose this finite action vocabulary and a small public world state, with an explicit owner grant, scope, short lifetime, rate limits and revocation. The human's private task/conversation/location data must remain outside the action interface. Live human reflection needs separate per-field consent, selected audience and revocation; public presence needs an additional opt-in. Online friends need recipient consent, verified ownership and the presence/revocation rules already described in `visits-and-friendships.md`.

MCP is one possible adapter transport, not a connection implemented by this prototype. The [official MCP tools specification](https://modelcontextprotocol.io/specification/2026-07-28/server/tools) describes structured tools and validation; the [official MCP specification](https://modelcontextprotocol.io/specification/2026-07-28) discusses explicit user consent and data protection. Provider-specific supported APIs must be verified against that provider's official documentation before implementing any adapter. No accounts, grants, credentials, deployments, public social service, or third-party requests were created here.
