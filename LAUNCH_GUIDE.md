# EmberForge: launch guide (what you still have to do)

Everything in the code is ready. What is left needs your Roblox account, so only you can do it. Work through the phases in order.
Tick the boxes as you go. Each phase says who does what.

Where things are:
- **Studio** = Roblox Studio, with Rojo connected (see SETUP.md section 1).
- **Creator Hub** = https://create.roblox.com/dashboard/creations (your experience > its pages).
- **Code** = files in this repo. Ask Claude to edit them, or do it yourself.

---

## Phase 0: Ownership check (personal account, 2 minutes)

You are the owner of the game and the assets, so nothing needs moving. Every player sees the Golems, pets and Quarry: the server loads each pack once and sends it to everyone.
The only thing to confirm is that the packs and the game belong to the **same account** (Roblox only lets the server load a model if the creator matches).

1. Creator Hub > your experience: check the creator shown is your account (not a group).
2. Open each pack in Creator Hub > Creations (the ids are in `src/Shared/Data/AssetData.lua`: Golem pack, pet pack, quarry pack) and check the creator is the same account.
3. If you ever move the game to a group later, re-upload the packs under the group first and update those ids, or Golems fall back to plain blocks (look for `[GolemAssets]` warnings in the Output).

- [ ] Game and packs are under the same personal account

---

## Phase 1: Publish the place (so saving works)

In Studio the game uses an in-memory save. A published place uses real DataStores.

1. Rojo: run `rojo serve` in this folder, open Studio, Plugins > Rojo > Connect. Make sure the latest code is synced.
2. Studio: File > **Publish to Roblox** (or "Publish to Roblox As..." the first time). Pick your experience, keep it **Private** for now.
3. Studio: File > **Experience Settings** (greyed out until you have published once; in older Studio versions this is Home > Game Settings):
   - **Security**: turn on **Enable Studio Access to API Services** (lets Studio talk to DataStores for testing).
   - **Max players**: not in Studio's Experience Settings any more. Set it in Creator Hub: your experience > **Configure > Places** > click your place > **Access** > **Maximum Visitor Count** = **20** > Save. (Roblox's default is higher, up to 50; the game is designed for 20 because every player can have 12 Golems on screen.)
   - **Basic Info**: paste the title and description from `marketing/CREATOR_HUB_COPY.md`. Pick the genre. Choose the devices you support (phone, computer, tablet, console if you have tested it).
4. Studio: File > Publish to Roblox again so the settings are saved with the place.

- [ ] Place published (private)
- [ ] Studio Access to API Services on
- [ ] Max players 20, title and description set

---

## Phase 2: Icon, thumbnails, page details

Creator Hub (create.roblox.com/dashboard/creations) > click your experience > left menu **Configure > Places** > click your start place (the one with the star). The left menu then has **Icon** and **Thumbnails**.

1. **Icon**: upload `marketing/upload/icon-512x512.png` (already 512x512; Roblox needs at least 512x512). On the **Icon** page click Change, choose the file, then Save Changes. It must pass moderation before others see it. Check it at 128x128 first.
2. **Thumbnails** (on the **Thumbnails** page, 16:9): upload `marketing/upload/thumbnail-1-heroes-1920x1080.png` first, so it is the main one. These are upscaled from 1376x768, which is fine for Roblox but a little soft; if you get a chance, regenerate or upscale them with an AI upscaler for a sharper result.
3. **A/B test**: add `marketing/upload/thumbnail-2-charge-1920x1080.png` as a second thumbnail and compare after launch (Creator Hub > Analytics). Roblox lets you order thumbnails and run a thumbnail test.
   More thumbnails help, but the draft screenshots in `marketing/draft-screenshots/` are not good enough (UI overlap, test avatar name, admin pad text). Take clean in-game screenshots instead: hatch a rare pet, a deployed Golem in its cave, the Quarry, and the Guild Hall, with the HUD hidden and a neutral avatar.
4. **Maturity questionnaire**: Creator Hub > click your experience > left menu **Configure > Questionnaire**. Answer honestly. Notes: cartoon mining only, filtered guild chat, paid random items (Royal Egg) have shown odds and are hidden where Roblox restricts them.
5. **Social links** (optional): your Roblox group, Discord, YouTube.

- [ ] Icon, thumbnails uploaded
- [ ] Questionnaire completed

---

## Phase 3: Monetisation (the part that needs your Creator Hub ids)

Until an id is set, that item shows "Coming soon" in game and nothing paid can be bought. You can launch without all of them. Start with the most important.

### 3a. Game Passes (permanent, one-time)
Creator Hub > your experience > **Monetization > Passes > Create a Pass**. For each: upload an image (the icon art works), set the name and price, switch **Item for sale** on, save. Open the pass and copy its numeric id from the URL.

| Pass | Price (R$) | Code key (`ProductData.GamePasses`) |
|---|---|---|
| Copper Pad (3x) | 59 | `Pad_Copper` |
| Iron Pad (9x) | 259 | `Pad_Iron` |
| Gold Pad (25x) | 749 | `Pad_Gold` |
| Legend Pad (100x) | 1,599 | `Pad_Legend` |
| Offline Storage (24h) | 299 | `Storage24h` |
| Forge Skin: Basic | 200 | `Skin_Basic` |
| Forge Skins: Ember, Frost, Storm | 300 each | `Skin_Ember`, `Skin_Frost`, `Skin_Storm` |
| Forge Skin: Void | 400 | `Skin_Void` |

### 3b. Developer Products (can be bought many times)
Creator Hub > Monetization > **Developer Products > Create**. Same steps, copy the id.

| Product | Price (R$) | Code key (`ProductData.Products`) |
|---|---|---|
| Smelt Speed-Up | 25 | `SpeedUp_x1` |
| Smelt Speed-Up Pack | 200 | `SpeedUp_x10` |
| +5 Golem Slots (permanent, stackable) | 249 | `SlotPack_5` |
| Forge Slot Boost (7 days) | 149 | `SlotBoost_7d` |
| Material Magnet (24h) | 199 | `MaterialMagnet` |
| Event Catalyst | 400 | `EventCatalyst` |
| Lucky Boost (1h) | 49 | `LuckBoost_1h` |
| Growth Tonic (1h): Golems grow 2x faster | 99 | `GrowthTonic_1h` (id is 0 until you create the product) |
| Royal Egg / x5 / x10 | 99 / 449 / 849 | `RoyalEgg_x1`, `RoyalEgg_x5`, `RoyalEgg_x10` |
| Season Pass Standard / Premium | 699 / 1,299 | `SeasonPass_Standard`, `SeasonPass_Premium` |

### 3c. Put the ids in the code
Send the ids to Claude (for example "SpeedUp_x1 = 123456, Pad_Copper = 789012") and it will fill in `src/Shared/Data/ProductData.lua`, or edit the `id = 0` values yourself. Then sync Rojo and republish.

Tips: you can price things a little lower for launch week. Do not change a product's id once players have bought it.

- [ ] Passes created, ids in `ProductData.lua`
- [ ] Developer Products created, ids in `ProductData.lua`
- [ ] Bought each one yourself once in a test to confirm the item arrives (see Phase 4)

---

## Phase 4: Test on a real, published place

Studio hides several things (real DataStores, purchases, text filtering, other players). Test these before going public.

1. **Solo, in the Roblox app**: set the experience to Private, then in Studio use Home > Test > **Clients and Servers** (or just open the game from Creator Hub > Play). Play from a brand-new account if you can: welcome screen, Starter Pad, Anvil, Forge, Deploy, Collect (checklist in SETUP.md section 5).
2. **Anvil prompt**: check the E prompt works with the anvil on a real client (TODO.md lists this as open).
3. **Purchases**: buying is free for you as the owner in Studio, but test one Developer Product and one pass on the published place to confirm the receipt grants the item.
4. **Two players**: ask a friend to join (keep it private and add them as a collaborator or give them access in the experience's permissions). Check: seeing each other's pets and forge, trade request accept and decline, guild invite, guild chat, Guild Hall.
5. **Save and rejoin**: play, leave, rejoin: Golems, coins and offline earnings should be there.
6. **Offline earnings**: leave a Golem deployed, close the game for a while, rejoin: check the collect summary.
7. **Developer Console**: press F9 in game (or Creator Hub > Analytics > Errors). Fix anything red.
8. Ask Claude to fix anything you find. Republish after each fix.

- [ ] Solo new-player run OK
- [ ] Purchases tested
- [ ] Two-player features tested
- [ ] Save/rejoin and offline earnings OK
- [ ] No red errors in the console

---

## Phase 5: Final settings before public

| Task | Where |
|---|---|
| Add admin UserIds (the owner and Studio are admins by default) | `GameConfig.ADMIN_USER_IDS` in `src/Shared/Data/GameConfig.lua` |
| Confirm codes (EMBERFORGE, LAUNCH, GOLEMS) are what you want to announce | `src/Shared/Data/CodeData.lua` |
| Season dates are correct (UTC, 2026) | `src/Shared/Data/SeasonData.lua` |
| Audio (ids of 0 are silent; use your own or licensed audio) | `src/Shared/Data/AudioData.lua` |
| Golem animations are optional; the code-driven swing is the fallback | `AssetData.lua` |
| Trading limit: accounts must be 7 days old to trade or use the Market | `TRADE_MIN_ACCOUNT_AGE_DAYS` |

Then run the automated tests once (`python tests/run_tests.py`, needs the `luau` runtime; see TODO.md) and republish.

- [ ] Admin ids, codes, season dates checked
- [ ] Final republish done

---

## Phase 6: Go live

1. Make the experience public. On the experience **Overview** page in Creator Hub, the **Access: Private** link near the top is where you change it. Next to it, **Audience Reach** shows who can find the game; the banner "Expand your audience reach" asks you to set up **ID verification** to reach more players, so do that before launch day if you want the widest audience. If you want a soft launch, share it with friends first for a day.
2. Open the game page as a logged-out or friend account to check the icon, thumbnails, title and description look right.
3. Post the launch update text from `marketing/CREATOR_HUB_COPY.md` (on your experience page in Creator Hub, look for the updates / events section; this is optional and the page name varies).
4. Share the link with friends, in your group and on social posts. The first few hundred plays set up how Roblox recommends you.

- [ ] Public
- [ ] Page checked
- [ ] Launch update posted

---

## Phase 7: First week after launch

- **Watch Analytics** (Creator Hub > Analytics): concurrent players, retention (day 1, day 7), session length, and the **Errors** tab. Day-1 retention is the number that matters most early.
- **Fix crashes first**, then confusing first-minute moments (look at where new players leave).
- **Compare thumbnails** after a few thousand impressions, keep the winner.
- **Use live ops** (SETUP.md section 3): admins can run `/event xp 2 24`, announce, and gift from the Admin panel without an update.
- **Update on a schedule** (weekly or fortnightly). Even a small update with a new code keeps players returning.
- **Revisit balance** with real data (TODO.md): Ascension costs, ladder tiers, build prices, trading-safety numbers.
- **Moderation**: the Admin panel has kick, ban and mute. Check reports there.
- **Later ideas** (TODO.md): distinct biomes, Golem animations, economy dashboard.

---

## Pushing updates after launch

Players only get a change when you **publish** it. Saving in Studio or committing to git does not update the live game.

Every time:
1. **Make the change** (ask Claude, or edit the file in VS Code).
2. **Sync into Studio**: `rojo serve` running, Studio > Plugins > Rojo > Connect. Check the new code is in Studio before you publish; the published place contains whatever is in Studio at that moment.
3. **Test**: press Play (and Clients and Servers if it touches multiplayer). Check the Output for red errors. Run `python tests/run_tests.py` if you can.
4. **Commit to git** so you can always get back to this version (`git commit`; ask Claude to do it).
5. **Publish**: Studio > File > **Publish to Roblox**. That is the push.
6. **Roll out to running servers**: servers that are already open keep the old version until they empty and close, so players trickle onto the new one over a few hours. To force it sooner: Creator Hub > click your experience > **Configure > Server Management**, select the place, and click **Restart Servers**. You can restart only outdated servers and delay the restart 1 to 60 minutes so players get a warning; players are moved to fresh servers on the new version. Do that only for important fixes, since it interrupts players. Mention it in the update log first if you can.
7. **Post the update**: on your experience page / social channels (use the template in `marketing/CREATOR_HUB_COPY.md`), and add a new code if you have one.
8. **Watch** Analytics > Errors for the next hour or two.

Safer ways to update:
- **Test place**: duplicate the experience as a second private "EmberForge Test" place, publish risky changes there first, and play it. Use a separate DataStore or test accounts so you do not touch real player data.
- **Undo a bad update**: Version History (in Creator Hub, on your place under Configure > Places; it is not in the Studio File menu) lets you revert to an earlier published version.
- **Never change these on a live game**: the numeric ids in `ProductData.lua` once players have bought them, or the names/shape of saved player data. Changing how data is saved needs a migration so old players do not lose progress; ask Claude to write one and test it first.
- **Remote tuning without an update**: admins can change event bonuses and some numbers live (SETUP.md section 3), so small balance tweaks do not need a publish.
- **Small updates often** beat big ones: one feature or fix per publish makes problems easy to find.

- [ ] I know the 8 steps and where Version History is

---

## If something goes wrong

| Problem | Likely cause and fix |
|---|---|
| Golems look like plain blocks | Asset not owned by the game's owner/group, or not published. Check the Output for `[GolemAssets]` warnings; re-upload under the right owner and update the id in `AssetData.lua`. |
| Progress not saving | Studio Access to API Services off (only matters in Studio), or the place was never published. |
| An item shows "Coming soon" | Its `id` in `ProductData.lua` is still 0. |
| Bought something and did not get it | Check the id matches the right product, and look in the Developer Console for receipt errors. |
| Guild chat shows nothing | Text filtering only runs on a published place; test there. |
| Pets or builds not visible to others | Test with two real players on the published place; report it with the Output log. |
