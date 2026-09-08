# Balance

The economy in one line:

```
rent/sec        = sum(rent of housed guests)  x  rent multiplier
rent multiplier = renovations  x  Concierge  x  gamepasses  x  boost
guest price     = guest rent  x  payback seconds for its rarity
```

Two axes drive progress, and they are deliberately separate:

- **Rating** decides *who turns up* on the arrivals road (the odds table).
- **Rooms** decide *how many* of them can pay rent at once.

Neither is useful without the other, which is what stops the game from being a
single number going up.

## The dials

| Dial | Where | What it moves |
|---|---|---|
| `guest.rent` | `Config/Guests.lua` | The whole income curve |
| `Ratings.List[].weights` | `Config/Ratings.lua` | How often each rarity appears |
| `Ratings.PaybackSeconds` | `Config/Ratings.lua` | How long a guest takes to pay for itself |
| `Rooms.BaseCost` / `CostGrowth` | `Config/Rooms.lua` | How fast the motel can grow |
| `Prestige.StarDivisor` | `Config/Prestige.lua` | When the first renovation lands |

## Checking a change

```
python3 games/monster-motel/tools/balance.py
```

The arrivals road is random, so a single run is noise. This plays nine
free-to-play accounts forward against the real rarity weights and reports the
median time to each milestone, with the spread.

The simulated player never raids and is never raided. Theft is a wash across a
server -- one motel's loss is another's gain -- so leaving it out measures the
economy rather than the dice.

## Current output

```
Monster Motel progression -- median of 9 runs, free-to-play, no raiding

     10.0 min   5 rooms                  +/-   2.2 min
     15.4 min   Two Star                 +/-   2.2 min
     38.2 min   Three Star               +/-   4.6 min
     52.2 min   10 rooms                 +/-   6.6 min
     87.2 min   Four Star                +/-  14.2 min
    128.0 min   renovate for 1 star      +/-  16.2 min
    136.4 min   15 rooms                 +/-  17.4 min
    164.4 min   Five Star                +/-  18.2 min
    217.2 min   renovate for 3 stars     +/-  22.2 min
    365.2 min   Six Star                 +/-  36.6 min
    418.2 min   20 rooms                 +/-  25.4 min
    420.0 min   renovate for 10 stars    +/-  28.2 min
    681.0 min   The Last Motel           +/-  96.4 min

One full run for shape:

      0.0 min   start
     10.0 min   5 rooms
     15.4 min   Two Star
     37.6 min   Three Star
     53.4 min   10 rooms
     91.0 min   Four Star
    135.4 min   renovate for 1 star
    143.6 min   15 rooms
    171.2 min   Five Star
    214.8 min   renovate for 3 stars
    338.0 min   Six Star
    409.2 min   20 rooms
    411.6 min   renovate for 10 stars
    681.0 min   The Last Motel

Summary
  first rating upgrade   15.4 min
  final rating           681.0 min

Ignores quests, dailies, codes, the Celebrity Arrival and every gamepass,
all of which a real player has. Treat these as the slow end of the range.
```

## Reading it

The shape to preserve:

- **A guest in the first minute.** A new profile starts with seed money for
  exactly this reason -- rent only comes from housed guests, so a motel that
  starts empty and broke has no income and no way to ever get any. The self-test
  asserts the seed money still covers the cheapest guest.
- **First rating upgrade around fifteen minutes.** Long enough to learn the loop,
  short enough to prove it pays.
- **First renovation around two hours** on these numbers, which lands nearer
  ninety minutes for a real player with quests, dailies and the Celebrity
  Arrival. A prestige loop nobody reaches on day one may as well not exist.
- **Ratings roughly doubling in distance** each time. Two Star at 15 minutes,
  Three at 38, Four at 87, Five at 164.

## What the simulation leaves out

Quests, daily rewards, the playtime ladder, codes, the Celebrity Arrival, and
every gamepass. A real player has all of them, which is why real progression is
faster than this table.

They are excluded on purpose: the table measures the core loop on its own. If the
core loop only works because of its bonuses, the core loop does not work.

Raiding is also excluded, which cuts both ways -- a good raider progresses faster
than this, and somebody having a bad week progresses slower. The floor of three
guests and the ten-minute grace window mean nobody falls far below it.
