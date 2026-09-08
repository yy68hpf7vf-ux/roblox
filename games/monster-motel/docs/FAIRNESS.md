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

| Constant | What it decides |
|---|---|
| `CarryWalkSpeed` | How fast you move while carrying a stolen guest |
| `NormalWalkSpeed` | How fast everyone moves otherwise |
| `TagRange` | How close a victim must get to make a thief drop their guest |
| `StealCooldownPerVictim` | How many guests one thief may take from one motel per night |
| `NewPlayerGrace` | How long a new player cannot be robbed at all |
| `MinimumGuestsToRob` | The floor below which nobody can be robbed |
| `DayDuration` / `NightDuration` | When raiding is possible |

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

## What the store does sell

Speed of your own progress, and nothing else:

- **2x Cash** and **VIP** — more rent from your own guests
- **Auto Collect** — removes the walk to your own front desk
- **+5 Rooms** — a bigger motel
- **Night Owl** — earns while you are offline
- **Express Lane** — guests arrive twice as often, at **exactly the same odds**
- **Cash drops** and a **2x rent boost** — consumables, sized against your own rent

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
