# Putting the store live

Everything in the store is already built, wired and tested. What it does not have
is asset ids, because a gamepass is an object on Roblox's servers and only the
account that owns the experience can create one. This is the walkthrough.

Nothing here is optional-but-recommended: with all ids at `0` the store is empty
by design, and no player can buy anything.

## Before you start

**Publish the place.** File → Publish to Roblox As… → create a new experience.
Gamepasses and developer products belong to an experience, so there is nothing to
attach them to until this is done.

While you are there: File → Game Settings → Security → **enable API Services**, or
nothing saves. A player who buys a pass and loses their motel is worse than one
who cannot buy at all.

## 1. Create the nine gamepasses

Creator Dashboard → your experience → **Monetization → Passes** → Create a Pass.

Each one needs a name, a description and a price. The names and descriptions
below are the ones the in-game store already shows, so keeping them identical
means a player sees the same words on the Roblox prompt as on the button they
clicked. The prices are a starting point, not a rule.

| Pass | Suggested price | What it does |
|---|---|---|
| 2x Cash | 199 R$ | Every guest pays double rent, forever |
| VIP | 399 R$ | +50% rent, chat tag, gold sign, 2-guest VIP Lounge |
| Auto Collect | 199 R$ | Rent skips the safe and the walk to the desk |
| +5 Rooms | 149 R$ | Five rooms above the cap at every rating |
| Night Owl | 249 R$ | Earns while offline, up to 8 hours banked |
| Express Lane | 199 R$ | Guests arrive twice as often, same odds |
| The Night Manager | 199 R$ | Signature guest, $30K/s, permanent |
| Madame Vacancy | 499 R$ | Signature guest, $75K/s, permanent |
| The Owner's Cousin | 999 R$ | Signature guest, $160K/s, permanent |

**The three Signature prices have to ascend with their income.** They pay $30K,
$75K and $160K per second, so if the middle one ever costs more than the top one
it is strictly dominated and nobody will buy it. That is the only pricing
constraint the design actually imposes; the rest is yours to move.

Do not price the Signatures as if they were the best thing in the game. They are
not, deliberately — the best Mythic pays $210K/s and Celebrities pay up to $2.5M/s,
and neither can be bought at any price. See [FAIRNESS.md](FAIRNESS.md).

## 2. Create the five developer products

Same page, **Developer Products** tab. These are consumable and repeatable, which
is why they are products rather than passes.

| Product | Suggested price | What it grants |
|---|---|---|
| Small Cash Drop | 25 R$ | ~20 minutes of your current rent |
| Medium Cash Drop | 75 R$ | ~1 hour |
| Large Cash Drop | 199 R$ | ~3 hours |
| Huge Cash Drop | 499 R$ | ~10 hours |
| 2x Rent – 30 minutes | 49 R$ | Doubles rent for 30 minutes |

The cash drops scale with the buyer's own rent rather than paying a flat number,
and the exact figure is printed on the button before the prompt opens. Nobody
finds out afterwards that their drop was worth four minutes at the rate they now
earn.

## 3. Paste the ids

Open `src/shared/Config/Monetization.lua`. The first thing in the file is this,
and it is the only part you need to touch:

```lua
local ASSET = {
	-- Gamepasses
	doublecash = 0,
	vip = 0,
	autocollect = 0,
	extrarooms = 0,
	nightowl = 0,
	sig_nightmanager = 0,
	sig_madamevacancy = 0,
	sig_cousin = 0,
	expresslane = 0,

	-- Developer products
	cash_small = 0,
	cash_medium = 0,
	cash_large = 0,
	cash_huge = 0,
	boost_2x_30 = 0,
}
```

**Where the numbers are.** For a pass, open it from the dashboard and read the
number out of the URL: `.../game-pass/1234567890/2x-Cash` → `1234567890`. For a
product, the dashboard lists the id in the table; there is no URL to read.

**Take the id from the item's own page, not the experience's.** The place id in
your address bar while editing is a different number, and pasting it makes every
ownership check quietly answer "no" — which looks exactly like a player lying
about having bought something.

You do not have to do all fourteen at once. Every id is independent: fill one in
and that item appears in the store on its own, the rest stay hidden.

## 4. Check, rebuild, republish

```bash
tools/check.sh
```

Two of those checks exist for this step specifically. One fails if any two items
share an id — the likeliest mistake when pasting fourteen numbers, and a bad one,
because a duplicate hands out two passes for a single purchase. The other fails
if an item is missing from the `ASSET` block, so "edit one table" stays true as
the store grows.

Then:

```bash
cd games/monster-motel
rojo build -o MonsterMotel.rbxl
```

Open it and publish over your existing place. **The file is read when the server
starts, so nothing changes on a running server until you republish.**

## 5. Test a purchase before you tell anyone

In Studio, Test → Clients and Servers. Studio purchase prompts do not charge
Robux, so you can run the whole flow for free.

Worth actually doing, in this order:

1. Buy a **cash drop** and check the number in your wallet matches the number the
   button promised.
2. Buy the **same product twice**. Receipts are deduplicated by purchase id, so
   the second is a genuine second grant — but if you ever see one purchase grant
   twice, stop and tell me.
3. Buy a **gamepass** and confirm it applies without rejoining.
4. Rejoin and confirm it is still there.

Step 4 is the one people skip. A pass that works until you rejoin is a pass that
did not work.

## If a pass does not apply

Check the server log first. The game is loud about this on purpose:

- `no asset id set for: …` — that item is still at `0`, or you edited the file
  and did not republish.
- `ownership check ... failed 3 times` — a Roblox API problem, not yours. The
  server retries the whole sweep five times with a widening gap; a confirmed pass
  is never taken away by a later failed check.
- `gamepass "x" has no entry in the ASSET block` — a typo in the block, named.

If a player insists they bought something and does not have it, the pass is
attached to their Roblox account, not their save. Rejoining re-runs the check.
Nothing about a purchase is stored in the profile, which is the reason a wiped
save can never cost somebody Robux.
