# Monetization

This game makes money. It does it without the patterns that get games moderated
and players' parents angry, because those patterns are not actually the ones that
earn the most over a game's life — they earn the most in week one and then the
retention curve collapses.

Everything here is configured in `src/shared/Config/Monetization.lua`.

## Setting it up

Every `assetId` in that file ships as `0`. Nothing with a `0` appears in the store
and nothing prompts — the server logs one warning at startup listing what is
unconfigured, and the Store window explains itself.

1. Publish the place.
2. Create the passes and developer products on the Creator Dashboard.
3. Paste each id into `Monetization.lua`.

The store fills itself in from that table. There is no second list to update.

## What is for sale

**Gamepasses** — one-time, permanent, account-wide.

| Pass | Effect |
|---|---|
| 2x Crystals | Every sale pays double. |
| VIP | +50% Crystals, a chat tag, and access to the VIP Vault seam. |
| Auto Mine | Your pick swings on its own, at the normal speed. |
| +2 Pet Slots | Two more equipped pets. Stacks with Kennel from the Core Shop. |
| Mega Backpack | Double capacity on whatever pack you carry. |

**Developer products** — consumable.

| Product | Effect |
|---|---|
| Crystal packs (4 sizes) | 20 minutes / 1 hour / 3 hours / 10 hours of your *current* income. |
| 2x Crystals, 30 minutes | Stacks up to 4 hours of stored time. |

Crystal packs are sized against the buyer's own income rather than being a fixed
number, and the **exact** figure is on the button before the Robux prompt opens.
A fixed pack is a great deal at rebirth 0 and an insult at rebirth 8; this one
stays worth the same.

## Rules this build follows

**Nothing random is sold for Robux.** Eggs are the only RNG in the game and they
cost Crystals. You can buy Crystals — but the path from money to a rare pet always
runs through a decision the player makes. This is the single most important line
in the file, and it is the one most simulators cross.

**Odds are printed, exact, and identical for everyone.** The hatch screen renders
percentages computed from the same weight table `PetService` rolls against, so
they cannot drift apart. There is no per-player luck value, no pity counter, no
first-hatch boost that quietly disappears, and no "increased chance" that is not a
number.

**No fake urgency.** No countdown timers, no "offer ends in", no crossed-out
prices, no limited-time bundles. Prices and contents are fixed and identical for
every player.

**No offers triggered by frustration.** Nothing in this codebase watches for a
player running out of Crystals, dying, hesitating, or failing, and shows them a
purchase prompt in response. Purchase prompts open when a player presses a buy
button. That is the only way they open.

**Passes are speed, not access.** The free path reaches every zone, every pet,
every rebirth and every Core Shop upgrade. The VIP Vault is the one gamepass zone
and it sits *between* two free zones in value, so it is a shortcut that Nova Reach
overtakes shortly after.

**Cores cannot be bought.** The prestige track — the thing long-term players
actually care about — is entirely on the gameplay side of the line.

**Receipts are granted exactly once, and saved immediately.** `ProcessReceipt`
checks the PurchaseId against a history in the player's profile, returns
`NotProcessedYet` if the profile has not loaded (so Roblox retries rather than
taking the money for nothing), and forces a save the moment a grant lands.

## Retention, and where the line is

Retention features here are real: a daily streak, a playtime ladder, rotating
quests, codes, leaderboards, a prestige track. They work because they pay people
for coming back, not because they punish people for leaving.

Two specific choices worth keeping:

- **The daily streak has a two-day grace window.** Miss one evening and the streak
  survives. A streak that breaks the first time someone has a busy Tuesday
  converts a good habit into an obligation, and it hurts the players who can least
  control their own schedule.
- **The playtime ladder ends.** Twelve rungs across an hour, then it stops and
  says so. It does not dangle a larger prize to keep someone in the server, and it
  never rewards idling over playing.

## What is deliberately absent

Written down so nobody adds them back by accident:

- Loot boxes bought with Robux
- Hidden, approximate, or per-player drop rates
- Countdown timers, flash sales, "was/now" pricing
- Purchase prompts triggered by running out of currency or by hesitation
- Energy or lives systems that gate play behind waiting or paying
- Progression walls tuned so that buying is the reasonable way past them
- Pay-to-win against other players (there is no PvP, and swing speed is a constant)
- Anything that makes a player's screen misrepresent what they are buying
