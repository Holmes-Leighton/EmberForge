# Creator Hub copy (title, description, genre, update text)

Everything here is based on features that exist in the game today (see FEATURE_WALKTHROUGH.md). Edit the bracketed bits.

## Title

Pick one. The game's name stays EmberForge; the extra words help search.

1. **EmberForge: Golem Idle** (recommended: says what it is)
2. EmberForge: Forge Golems
3. EmberForge

## Description (limit 1000 characters; this is 768)

```
Forge stone GOLEMS, send them to work in lava caves, and watch your riches grow, even while you're away!

⛏️ Mine ore, smelt it, and craft Golems at the Anvil: Ember, Stone, Frost, Storm and Void
🤖 Collect 13 kinds, including special Golems with unique skills like the Gargoyle, Clockwork and Dragonbone
✨ Fuse 4 identical Golems into Elite, then Supreme versions
🥚 Hatch and raise cute pets that boost your mining
🏠 Build your own Forge and Quarry, upgrading from a tiny shed to a grand kiln
🤝 Trade with friends, join a Guild, and climb the ranked ladder
🔥 Hourly events and surprise surges: every hour is a different bonus!

Your Golems keep mining while you're offline. Come back to collect!

👍 Like and ⭐ Favourite to get updates.
```

Notes:
- The first line is what shows in search results, so it carries the hook.
- Emoji are fine in descriptions but render differently by device; keep them only at line starts.
- Leave the codes out of the description (they would be copied around). Put them in the update text.

## Genre and tags

Roblox lets you pick a genre and sub-genre in Creator Hub; the closest fits:
- Genre: **Simulation** (if offered, "Tycoon" is a second choice)
- Sub-genre: pick the closest of **Idle / Crafting / Collecting**
- Keep search words in the description and title instead: idle, golem, forge, crafting, mining, pets, trading, guilds.

Maturity questionnaire (answer honestly; this is the likely outcome):
- No violence beyond cartoon mining, no scary content, no chat beyond the guild chat (Roblox text-filtered).
- Random paid items: the Royal Egg is hidden where Roblox restricts paid random items, and egg odds are always shown. Say so if the questionnaire asks.

## Update text (shown on the page and used for announcements)

### Launch update

```
🔥 EmberForge has launched! 🔥

Forge Golems, collect pets, build your Forge and Quarry, join a Guild and climb the ladder.

NEW:
• 13 Golem types, including 8 special Golems with unique skills
• Elite and Supreme fusion
• Pets with growth stages (Baby to Elder)
• Player-built Quarry
• Guilds, trading and the Market
• Hourly events and surprise surges

CODES: EMBERFORGE, LAUNCH, GOLEMS (open the Rewards menu to redeem)

Tell us what you want next in the comments! 👇
```

### Template for later updates

```
🔥 [Update name] 🔥

NEW:
• [feature 1: one short line]
• [feature 2]

FIXES:
• [fix 1]

[New code or event, optional]

Thanks for playing! Leave feedback in the comments 👇
```

## Page checklist

- [ ] Icon uploaded (`marketing/upload/icon-512x512.png`), checked at 128 px
- [ ] Thumbnail uploaded (`marketing/upload/thumbnail-1-heroes-1920x1080.png`); optionally A/B test against `thumbnail-2-charge-1920x1080.png`
- [ ] Add 2 to 3 more thumbnails from clean new in-game screenshots (the drafts have UI overlap and test names)
- [ ] Title and description pasted
- [ ] Genre and maturity questionnaire completed
- [ ] Servers: set max players, enable friends joining
- [ ] Confirm the codes in `CodeData.lua` match the update text before posting
