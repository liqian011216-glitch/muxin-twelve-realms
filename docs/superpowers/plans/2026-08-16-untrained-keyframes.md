# Untrained Breakaway Keyframes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce three reviewable 16:9 keyframes for the approved first-realm interaction while preserving the user's exact close-up woodblock visual identity.

**Architecture:** Preserve the user's image as the immutable visual reference, create the entry frame with lossless framing, and use built-in image editing for only the two poses absent from the source. No runtime or flow code changes until the user approves all three keyframes.

**Tech Stack:** Built-in ImageGen edit mode, local image inspection, PNG assets.

## Global Constraints

- The only identity reference is `codex-clipboard-0360002a-1223-420b-9771-4c220b46a11f.png`.
- Preserve the water buffalo, herdsman, clothing, straw hat, rope, paper grain, and black-gray/indigo/ochre overprinted woodcut style.
- Use a 16:9 landscape composition suitable for a full-screen horizontal game.
- The buffalo must naturally turn and run right; it must not slide backward while still facing left.
- Add no title, caption, counter, button, border, watermark, or interface text.
- Produce only the three keyframes in this plan; do not implement animation, clicking, Godot, React, or seek-game navigation.
- User approval of all three keyframes is required before runtime implementation.

---

### Task 1: Preserve the source and create the enlarged entry frame

**Files:**
- Create: `生成画面/第一境未牧互动/00-source-reference.png`
- Create: `生成画面/第一境未牧互动/01-entry-enlarged.png`

**Interfaces:**
- Consumes: `/var/folders/hv/dv6426hn3v5d70xmf7by925m0000gn/T/codex-clipboard-0360002a-1223-420b-9771-4c220b46a11f.png`.
- Produces: the immutable reference and a 16:9 entry image used as the visual anchor for Tasks 2 and 3.

- [ ] **Step 1: Copy the user image non-destructively into the project**

Copy the exact PNG bytes to `生成画面/第一境未牧互动/00-source-reference.png`. Do not overwrite an existing file; if present, compare hashes and stop if they differ.

- [ ] **Step 2: Inspect the source before editing**

Use `view_image` on `00-source-reference.png`. Confirm one left-facing black buffalo, one right-side herdsman, one taut rope, blank rice-paper background, and no text.

- [ ] **Step 3: Create the entry composition without redrawing subjects**

Frame the exact source at 16:9 so buffalo and herdsman fill most of the horizontal stage. Preserve all pixels of both figures and the rope; use the existing paper texture to fill any necessary outer margin. Save as `01-entry-enlarged.png`.

- [ ] **Step 4: Verify the entry asset**

Inspect `01-entry-enlarged.png` and confirm: 16:9 landscape, no cropped hooves/horns/hat/hands, no new objects or text, and identities match the source exactly.

- [ ] **Step 5: Commit the preserved reference and entry frame**

```bash
git add 生成画面/第一境未牧互动/00-source-reference.png 生成画面/第一境未牧互动/01-entry-enlarged.png
git commit -m "art: add untrained entry keyframe"
```

### Task 2: Create the maximum-pull keyframe

**Files:**
- Create: `生成画面/第一境未牧互动/02-max-pull.png`

**Interfaces:**
- Consumes: `00-source-reference.png` as edit target and `01-entry-enlarged.png` as framing reference.
- Produces: the approved fifth-click pose candidate.

- [ ] **Step 1: Run one built-in ImageGen edit for the pull pose**

Use this prompt with `00-source-reference.png` as the edit target:

```text
Use case: precise-object-edit
Asset type: 16:9 keyframe for a Chinese contemplative web game
Primary request: create the peak pulling moment immediately before the buffalo breaks free
Subject: preserve the exact same buffalo and herdsman; the buffalo strains harder toward the left with lowered shoulders and stronger forward force, the herdsman is pulled farther forward with bent knees and tense arms, and the rope is perfectly taut with a subtle vibration arc
Style/medium: preserve the original Song-style overprinted woodblock illustration, rice-paper grain, black-gray buffalo, indigo clothing, and restrained ochre accents
Composition/framing: same enlarged 16:9 framing as the entry keyframe; keep all horns, hooves, hat, hands, and rope visible
Constraints: change only the physical pull intensity and pose; preserve identities, anatomy, costume, palette, paper texture, line quality, and object count; no text, UI, border, watermark, dust cloud, broken rope, or extra figures
Avoid: photorealism, cartoon shading, 3D rendering, western comic style, backward anatomy, duplicated limbs
```

- [ ] **Step 2: Inspect the pull result**

Verify the buffalo still faces left, the rope remains intact, the herdsman remains the same person, and the pose is visibly stronger than `01-entry-enlarged.png` without changing the art direction.

- [ ] **Step 3: Iterate only if one specific invariant fails**

If an invariant fails, run one targeted edit naming only that failure, then re-inspect. Do not broaden the prompt or create unrelated variants.

- [ ] **Step 4: Save the selected result in the workspace**

Copy the selected built-in output to `生成画面/第一境未牧互动/02-max-pull.png` so the project does not depend on the generated-images cache.

- [ ] **Step 5: Commit the maximum-pull keyframe**

```bash
git add 生成画面/第一境未牧互动/02-max-pull.png
git commit -m "art: add untrained maximum pull keyframe"
```

### Task 3: Create the right-running breakaway keyframe

**Files:**
- Create: `生成画面/第一境未牧互动/03-breakaway-run-right.png`

**Interfaces:**
- Consumes: `00-source-reference.png` for identity and `01-entry-enlarged.png` for framing.
- Produces: the approved post-breakaway, right-running pose candidate.

- [ ] **Step 1: Run one built-in ImageGen edit for the breakaway pose**

Use this prompt with `00-source-reference.png` as the edit target:

```text
Use case: precise-object-edit
Asset type: 16:9 keyframe for a Chinese contemplative web game
Primary request: depict the instant after the buffalo breaks free and turns naturally to run toward the right edge
Subject: preserve the exact same buffalo and herdsman; the buffalo now faces right in a believable running gait and moves ahead toward the right edge, the loose rope trails behind it, and the herdsman remains left of the buffalo recovering from lost tension with one short backward recoil
Style/medium: preserve the original Song-style overprinted woodblock illustration, rice-paper grain, black-gray buffalo, indigo clothing, and restrained ochre accents
Composition/framing: 16:9 landscape; leave open space at the right edge for the buffalo's exit path; keep buffalo, herdsman, loose rope, horns, hooves, hat, and hands visible
Constraints: change only the direction, running pose, character spacing, rope tension, and herdsman's recoil; preserve identities, anatomy, costume, palette, paper texture, line quality, and object count; no text, UI, border, watermark, dust cloud, snapped body parts, or extra figures
Avoid: buffalo facing left while moving right, mirrored Chinese clothing errors, photorealism, cartoon shading, 3D rendering, duplicated limbs
```

- [ ] **Step 2: Inspect the running result**

Verify the buffalo clearly faces and runs right, the pose is anatomically plausible, the same herdsman remains behind, and the loose rope no longer reads as held taut.

- [ ] **Step 3: Iterate only if one specific invariant fails**

If an invariant fails, run one targeted edit naming only that failure, then re-inspect.

- [ ] **Step 4: Save the selected result in the workspace**

Copy the selected built-in output to `生成画面/第一境未牧互动/03-breakaway-run-right.png`.

- [ ] **Step 5: Commit the right-running keyframe**

```bash
git add 生成画面/第一境未牧互动/03-breakaway-run-right.png
git commit -m "art: add untrained breakaway keyframe"
```

### Task 4: Visual review checkpoint

**Files:**
- Review: `生成画面/第一境未牧互动/01-entry-enlarged.png`
- Review: `生成画面/第一境未牧互动/02-max-pull.png`
- Review: `生成画面/第一境未牧互动/03-breakaway-run-right.png`

**Interfaces:**
- Consumes: the three completed keyframes.
- Produces: explicit user approval or targeted revision notes; no runtime code.

- [ ] **Step 1: Inspect all three files at full size**

Compare the buffalo head, horn shape, body markings, herdsman's face, clothing, hat, hands, rope, paper texture, and palette across all three images.

- [ ] **Step 2: Present images in interaction order**

Show `01-entry-enlarged.png`, `02-max-pull.png`, then `03-breakaway-run-right.png` with short labels only.

- [ ] **Step 3: Stop for user review**

Ask the user to approve or identify the first image that needs correction. Do not implement animation, clicks, or game navigation during this plan.
