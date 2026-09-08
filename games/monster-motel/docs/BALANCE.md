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
| `Upgrades.List[]` | `Config/Upgrades.lua` | The levelled Cash sinks: rent, arrival rate, speed, defence |

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
     42.5 min   Three Star               +/-   5.1 min
     53.6 min   10 rooms                 +/-   3.8 min
     84.2 min   Four Star                +/-   8.9 min
    110.0 min   renovate for 1 star      +/-  11.4 min
    125.5 min   15 rooms                 +/-  12.0 min
    145.2 min   Five Star                +/-  11.8 min
    171.4 min   renovate for 3 stars     +/-  16.6 min
    254.8 min   Six Star                 +/-  23.8 min
    280.1 min   renovate for 10 stars    +/-  19.9 min
    287.1 min   20 rooms                 +/-  19.7 min
    416.8 min   The Last Motel           +/-  31.4 min

One full run for shape:

      0.0 min   start
     10.0 min   5 rooms
     15.4 min   Two Star
     41.8 min   Three Star
     53.6 min   10 rooms
     85.8 min   Four Star
    109.9 min   renovate for 1 star
    122.8 min   15 rooms
    141.3 min   Five Star
    163.2 min   renovate for 3 stars
    244.3 min   Six Star
    269.4 min   renovate for 10 stars
    276.1 min   20 rooms
    406.6 min   The Last Motel

Summary
  first rating upgrade   15.4 min
  final rating           416.8 min

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
- **First renovation just under two hours** on these numbers, which lands nearer
  seventy-five minutes for a real player with quests, dailies and the Celebrity
  Arrival. A prestige loop nobody reaches on day one may as well not exist.
- **Somewhere to put spare cash at every point.** Room Service and the Neon Sign
  are modelled here because they are real sinks that change the curve -- adding
  them pulled the first renovation in by eighteen minutes and the endgame in by
  four hours. Running Shoes and Night Porter are left out because neither
  changes income.
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
