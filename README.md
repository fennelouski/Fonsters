# Fonsters

Cross-platform SwiftUI app for creating and sharing **deterministic creature avatars (Fonsters)** from text seeds. Same seed → same creature. Each Fonster is a 32×32 pixel creature driven by a text seed. Supports **iOS**, **macOS**, **watchOS**, **tvOS**, and **visionOS**.

## How it works

You enter or load any text (the "seed"). The app hashes it and draws a small pixel creature—no randomness, so the same seed always produces the same creature. You can try the [web version](https://nathanfennel.com/games/creature-avatar) or read the [blog post](https://nathanfennel.com/blog/creature-avatars) for more on the algorithm.

## What they look like

Same seed always gives the same creature. You can watch the creature "evolve" as the seed changes (use **Play** in the app, or export an animated GIF).

![Monster evolution example 1](assets/monster-evolution-1.png)
![Monster evolution example 2](assets/monster-evolution-2.png)

## Features

- **List and detail** — Create, name, and manage multiple Fonsters.
- **Editable name and seed** — Change the source text to change the creature.
- **Load random** — Quote, Words, UUID, or Lorem; fetches from API with local fallback when offline.
- **Prepend random** — Add new random text to the current seed (undoable).
- **Play** — In-app evolution animation (one frame per character of seed).
- **PNG / GIF export** — Share or save a static PNG or animated GIF (one frame per seed prefix).
- **Share and Import** — Share a URL with your seeds; import from a share link. Open from URL via `fonsters://` or universal links.
- **Platforms** — iOS, macOS, watchOS, tvOS, and visionOS (with 3D voxel view on visionOS).

## For developers

- **Current state and features:** **[DOCUMENTATION.md](DOCUMENTATION.md)** — what works on each platform, file map, algorithm notes.
- **Remaining work / to-dos:** See the "Remaining work / to-dos" section in **DOCUMENTATION.md**. All planned items are completed; only optional/future items and environment notes are listed there.
- **App icons** — Icons for all platforms are generated from art in `Graphics/`. After changing any source image, regenerate assets with:
  ```bash
  ./Scripts/generate_platform_icons.sh
  ```
  Details and requirements: **[Scripts/README.md](Scripts/README.md)**.
- **watchOS simulator** — If the Watch app target fails with a simulator runtime version error, install or update the watchOS (and iOS) simulator runtimes in **Xcode → Settings → Platforms**. See [DOCUMENTATION.md](DOCUMENTATION.md) for details.
