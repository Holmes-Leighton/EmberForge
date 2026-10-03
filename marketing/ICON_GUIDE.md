# Game icon: Midjourney cave + real Golems

Plan: Midjourney makes the lava cave. The real Golems come from Studio (green screen). Composite in Photopea / Photoshop.
Roblox icon = 512x512 (make it 1024x1024 and downscale).

## 1. Midjourney: cave background

Paste into Midjourney (V7). Generate 4-8, pick the one with the emptiest centre.

```
epic cartoon lava cave interior, wide cavern, glowing river of molten lava winding through the middle,
dark basalt rock walls and stalactites, wooden mine support beams, hanging lanterns, glowing orange
and blue crystal veins, floating embers and sparks, volumetric orange light and haze, large open flat
rocky floor in the lower centre left empty, stylised chunky toy-like game art, Roblox game icon
background, warm orange and deep brown palette, high detail, cinematic lighting, no characters, no text
--ar 1:1 --v 7 --s 250 --no characters, creatures, people, text, logo, watermark
```

Tips:
- Ask for the composition you need: "empty open ground in the foreground" and "lava glow behind the centre".
- Want the Golems to sit in warm light: add "strong orange rim light from behind".
- Vary with `--chaos 10-20` if all 4 look the same.

## 2. Golems from Studio

Reference capture: `icon-golems-greenscreen-reference.jpg` (all 13 on green, built with GolemModel, same code as the game).

To make a high-resolution one:
1. Open the place, press Play, and let the Golems load (about 10 seconds).
2. Run the script `tools/icon_stage.lua` in the Client command bar (or ask Claude to).
3. Maximise the Studio viewport, hide UI, and capture. A taller viewport (square-ish) gives a better icon crop.
4. In Photopea/Photoshop: Select > Color Range (green) to cut them out, or use "Remove background".

Layout: a V. Gargoyle at the front point, then two arms of six going back. Left arm (front to back): Clockwork, Frost, Coral, Void, Storm in a Jar, Dragonbone. Right arm: Patchwork, Stone, Woven, Alchemist, Storm, Ember (Ember at the very back, with the halo).

Known issue: a few Golems show small floating brown/grey blocks near the shoulders. These are tier add-on placeholders in the models. Paint them out or hide them before capturing.

## 3. Composite

1. Cave at 1024x1024 as the bottom layer.
2. Golems cut-out above; scale so the Gargoyle (front) and Ember (back right, haloed) read clearly; keep the lava glow behind the V.
3. Add a soft orange glow behind the group (Outer Glow / a blurred orange layer set to Screen).
4. Add a darker vignette. Add a soft ground shadow under each Golem.
5. Tint the Golems slightly toward orange (Color Balance or a Soft Light layer) so they match the cave lighting.
6. Optional: a bold logo-style "EmberForge" title. Check it stays readable at 128 px.
