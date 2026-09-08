# Fairness

Monster Motel is a game about robbing other players. That makes one design
question more important than every other one combined: **can somebody buy their
way to winning a fight with you?**

In this build the answer is no, and it is enforced in code rather than promised
in a description.

## The constants

Every number a raid depends on lives in `src/shared/Config/GameConfig.lua` as a
plain constant. Nothing multiplies them, nothing scales them per player, and no
code path reads a gamepass or a product when deciding any of them.

| Constant | What it decides | Can anything change it? |
|---|---|---|
| `CarryWalkSpeed` | How fast you move while carrying a stolen guest | **No. Nothing, at any price, in any currency.** |
| `TagRange` | How close a victim must get to make a thief drop their guest | No |
| `StealCooldownPerVictim` | How many guests one thief may take from one motel per night | No |
| `NewPlayerGrace` | How long a new player cannot be robbed at all | No |
| `MinimumGuestsToRob` | The floor below which nobody can be robbed | No |
| `DayDuration` / `NightDuration` | When raiding is possible | No |
| `NormalWalkSpeed` | How fast you move the rest of the time | Running Shoes, bought with **Cash** |

## Running Shoes, and why they are the exception

Running Shoes raise your normal walk speed from 16 to 24 across eight levels. That
is a real advantage and it is meant to be -- it is one of the things Cash is for.

Two properties keep it out of the fairness problem:

1. **It is bought with Cash, not Robux.** Every player can have all eight levels.
   Nothing in the Robux store sells speed, and the self-test enforces that.
2. **It does not apply while carrying.** `MovementService` is the only code in the
   game that writes `WalkSpeed`, and when a player is carrying a guest it writes
   `CarryWalkSpeed` flat, without reading their profile. Shoes get you to a door
   and get you home after a chase. They never help you outrun the person whose
   guest is on your back.

That second point is the load-bearing one. A chase is the moment the game is
actually about, and it resolves the same way for a player on their first night as
for one who has bought everything.

Door break time is the one number a player can move, and it reads **only the
defender's** lock level and Deadbolt level. The thief's rating, renovations,
purchases and pass ownership are not inputs to it. See
`EconomyService.breakSeconds`.

## How it is enforced

`Monetization.ForbiddenFields` lists field names no paid item may declare. The
self-test walks every gamepass and product against that list *and* against the
names of the constants above, and fails if any of them appears:

```
python3 tools/selftest.py <luau> games/monster-motel
```

So a future "+2 carry speed" pass does not quietly ship. It fails at a terminal,
with a message naming the item and the field.

## Signature guests

Three guests are sold outright as gamepasses. They are the strongest thing in the
store and the most likely place for a raiding game to go wrong, so they follow
three rules.

**They are beside the ladder, not on top of it.** The best Signature pays
$160K/s. The best Mythic pays $210K/s, and Celebrities pay up to $2.5M/s. Both of
those are earned only — a Mythic comes off your own arrivals road, a Celebrity has
to be carried home from the square in front of everybody. **The two best tiers in
the game cannot be bought at any price**, and the self-test fails if a config edit
ever changes that.

**They can be stolen.** A Signature standing in room four is an ordinary guest in
every respect a thief cares about. Selling theft immunity would be selling an
advantage in a raid, which is the line this whole document is about.

**Losing one does not lose the purchase.** The pass buys a permanent entitlement,
not an object. If you end a night without your Signature, `SignatureService` hands
it back at sunrise — and the thief keeps the copy they carried home. The raid was
real for both sides, and nobody is out of pocket for a bad night.

That last rule is deliberately delayed until sunrise rather than instant. Handing
it straight back would make stealing one pointless and would quietly be immunity
after all.

## What the store does sell

Speed of your own progress, and guests that never top the free ones:

- **2x Cash** and **VIP** — more rent from your own guests
- **Auto Collect** — removes the walk to your own front desk
- **+5 Rooms** — a bigger motel
- **Night Owl** — earns while you are offline
- **Express Lane** — guests arrive twice as often, at **exactly the same odds**
- **Cash drops** and a **2x rent boost** — consumables, sized against your own rent
- **Signature guests** — strong, permanent, stealable, and beaten by free content

A player who buys all of it has a richer motel. They break your door in the same
number of seconds, run home at the same speed, and are caught at the same range as
a player who has bought nothing.

## The protections, and why they are free

Three protections exist and none of them are for sale, because a protection you
can buy is just a wall in front of the people who most need it:

1. **Ten minutes of grace** after joining a server. New players get to build
   something before anyone can take it.
2. **A floor of three guests.** Nobody can be stripped bare, so a bad night is
   never a reason to quit the game.
3. **One guest per victim per night.** A thief cannot farm one motel; they have to
   spread the damage or spend the night elsewhere.

## The reasoning

This is not a moral position, it is a retention one.

A raiding game where the wallet decides the chase is a game where everyone who
loses the chase leaves. They are also the audience the paying players are showing
off *to* — take them away and the passes stop being worth buying, because a
crowded server is the entire product. Games in this genre die of exactly this,
usually about six weeks after the first pay-to-win pass ships.

Selling speed of progress is fine, and this game sells plenty of it. Selling an
advantage in a fight against another player is not, and this game cannot.
