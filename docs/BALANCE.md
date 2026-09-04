# Balance

Everything about the economy comes out of one formula. If you understand this
page you can re-tune the whole game from `src/shared/Config/`.

## The model

```
ore per swing   = tool.power  x  zone.orePerPower  x  yieldUpgrade
crystals earned = ore  x  zone.oreValue  x  sellMultiplier
sell multiplier = rebirth  x  pets  x  Refinery  x  gamepasses  x  boost
trip length     = backpack capacity / ore per second
```

Swing speed is a constant (`GameConfig.SwingCooldown`, 0.55s) and is the same for
every player in the game. Nothing -- no pass, no upgrade, no amount of Robux --
makes one player's clicks worth more per second than another's. Auto Mine swings
at that same rate; it removes the clicking, not the waiting.

`orePerPower` is held at **0.6 in every zone**. Deeper zones pay more because
`oreValue` climbs, never because the rock got stingier. This is what keeps a new
pick feeling like an upgrade everywhere on the map instead of only in the zone it
was priced for.

## The four dials

| Dial | Where | What it moves |
|---|---|---|
| `tool.power` | `Config/Tools.lua` | Ore per second. The main progression axis. |
| `backpack.capacity` | `Config/Backpacks.lua` | Trip length. Target 20-35 seconds. |
| `zone.oreValue` | `Config/Zones.lua` | Crystals per ore. The other progression axis. |
| `zone.nodeHealth` | `Config/Zones.lua` | How often a node breaks. Rhythm only; set to about 5x the pick a player arrives with. |

Prices (`tool.price`, `backpack.price`, `zone.unlockCost`, `egg.price`) set the
*pacing*; the four dials above set the *rates*. Change a rate and you should
re-check the prices, which is what the simulator is for.

## Checking a change

```
tools/check.sh              # everything: parse, requires, config self-test, balance
python3 tools/balance.py    # just this simulation
```

It parses the real config files and plays a free-to-play account forward with a
greedy buying strategy, so the numbers below are checked against the code rather
than remembered. It also charges 9 seconds for every walk to the sell pad, which
the in-game income estimate ignores -- so these figures are the slow end.

## Current output

```
Loaded 12 picks, 10 backpacks, 10 zones, 8 eggs.

Trip length at the expected loadout for each zone
  (how long a backpack takes to fill; the design target is 20-35s)

  Green Hollow         22.9s
  Amber Cavern         21.8s
  Frostline            22.9s
  Emberdeep            22.9s
  Stormvault           22.6s
  Voidshelf            22.7s
  Nova Reach           23.4s
  Rift Core            22.9s
  The Singularity      23.4s

Free-to-play progression (no pets, no Robux, no quests or dailies)

      0.0 min   start                                             1 c/s
      2.3 min   pick: Copper Pick                                 2 c/s
      7.4 min   ZONE: Amber Cavern                                8 c/s
      7.9 min   pack: Miner's Pack                               13 c/s
     13.0 min   pick: Iron Pick                                  27 c/s
     14.6 min   pack: Reinforced Pack                            45 c/s
     19.0 min   ZONE: Frostline                                 132 c/s
     24.1 min   pick: Steel Pick                                272 c/s
     25.6 min   pack: Hover Crate                               419 c/s
     30.4 min   ZONE: Emberdeep                               1,316 c/s
     35.5 min   pick: Crystal Pick                            2,831 c/s
     36.9 min   pack: Hauler Rig                              4,591 c/s
     41.7 min   ZONE: Stormvault                             15,623 c/s
     46.8 min   pick: Obsidian Pick                          33,366 c/s
     48.3 min   pack: Cargo Container                        54,321 c/s
     49.2 min   REBIRTH 1 (x2)                                    2 c/s
     50.3 min   pick: Copper Pick                                 5 c/s
     52.9 min   ZONE: Amber Cavern                               17 c/s
     53.2 min   pack: Miner's Pack                               26 c/s
     55.7 min   pick: Iron Pick                                  54 c/s
     56.5 min   pack: Reinforced Pack                            89 c/s
     58.7 min   ZONE: Frostline                                 263 c/s
     61.3 min   pick: Steel Pick                                545 c/s
     62.0 min   pack: Hover Crate                               839 c/s
     64.4 min   ZONE: Emberdeep                               2,632 c/s
     66.9 min   pick: Crystal Pick                            5,663 c/s
     67.7 min   pack: Hauler Rig                              9,181 c/s
     70.0 min   ZONE: Stormvault                             31,247 c/s
     72.6 min   pick: Obsidian Pick                          66,732 c/s
     73.3 min   pack: Cargo Container                       108,643 c/s
     75.6 min   ZONE: Voidshelf                             393,711 c/s
     76.3 min   REBIRTH 2 (x3)                                    3 c/s
     77.0 min   pick: Copper Pick                                 7 c/s
     78.8 min   ZONE: Amber Cavern                               25 c/s
     78.9 min   pack: Miner's Pack                               39 c/s
     80.6 min   pick: Iron Pick                                  81 c/s
     81.1 min   pack: Reinforced Pack                           134 c/s
     82.6 min   ZONE: Frostline                                 395 c/s
     84.3 min   pick: Steel Pick                                817 c/s
     84.8 min   pack: Hover Crate                             1,258 c/s
     86.4 min   ZONE: Emberdeep                               3,948 c/s
     88.1 min   pick: Crystal Pick                            8,494 c/s
     88.6 min   pack: Hauler Rig                             13,772 c/s
     90.2 min   ZONE: Stormvault                             46,870 c/s
     91.9 min   pick: Obsidian Pick                         100,098 c/s
     92.4 min   pack: Cargo Container                       162,964 c/s
     93.9 min   ZONE: Voidshelf                             590,566 c/s
     95.6 min   pick: Prism Pick                          1,275,673 c/s
     96.1 min   pack: Pocket Vault                        2,128,578 c/s
     96.7 min   REBIRTH 3 (x4)                                    4 c/s
     97.3 min   pick: Copper Pick                                10 c/s
     98.5 min   ZONE: Amber Cavern                               34 c/s
     98.7 min   pack: Miner's Pack                               52 c/s
     99.9 min   pick: Iron Pick                                 109 c/s
    100.3 min   pack: Reinforced Pack                           179 c/s
    101.4 min   ZONE: Frostline                                 526 c/s
    102.7 min   pick: Steel Pick                              1,090 c/s
    103.1 min   pack: Hover Crate                             1,677 c/s
    104.3 min   ZONE: Emberdeep                               5,264 c/s
    105.6 min   pick: Crystal Pick                           11,326 c/s
    105.9 min   pack: Hauler Rig                             18,362 c/s
    107.1 min   ZONE: Stormvault                             62,494 c/s
    108.4 min   pick: Obsidian Pick                         133,463 c/s
    108.8 min   pack: Cargo Container                       217,286 c/s
    109.9 min   ZONE: Voidshelf                             787,421 c/s
    111.2 min   pick: Prism Pick                          1,700,898 c/s
    111.6 min   pack: Pocket Vault                        2,838,104 c/s
    112.7 min   ZONE: Nova Reach                         10,190,106 c/s
    113.3 min   REBIRTH 4 (x5)                                    5 c/s
    113.8 min   pick: Copper Pick                                12 c/s
    114.8 min   ZONE: Amber Cavern                               42 c/s
    114.9 min   pack: Miner's Pack                               65 c/s
    115.9 min   pick: Iron Pick                                 136 c/s
    116.3 min   pack: Reinforced Pack                           224 c/s
    117.1 min   ZONE: Frostline                                 658 c/s
    118.2 min   pick: Steel Pick                              1,362 c/s
    118.5 min   pack: Hover Crate                             2,097 c/s
    119.4 min   ZONE: Emberdeep                               6,580 c/s
    120.4 min   pick: Crystal Pick                           14,157 c/s
    120.7 min   pack: Hauler Rig                             22,953 c/s
    121.7 min   ZONE: Stormvault                             78,117 c/s
    122.7 min   pick: Obsidian Pick                         166,829 c/s
    123.0 min   pack: Cargo Container                       271,607 c/s
    123.9 min   ZONE: Voidshelf                             984,276 c/s
    124.9 min   pick: Prism Pick                          2,126,122 c/s
    125.2 min   pack: Pocket Vault                        3,547,630 c/s
    126.2 min   ZONE: Nova Reach                         12,737,633 c/s
    127.2 min   pick: Void Pick                          28,005,658 c/s
    127.5 min   pack: Rift Vault                         46,123,128 c/s
    128.2 min   REBIRTH 5 (x6)                                    7 c/s

Summary
  second zone at        7.4 min
  all base zones open   126.2 min
  gap between zones     2.1 - 11.6 min
  first rebirth at      49.2 min

Everything above ignores pets, quests, daily rewards and codes, all of
which a real player has. Treat these as the slow end of the range.
```

## Reading it

The shape to preserve:

- **First upgrade inside three minutes.** A new player must buy something before
  they decide whether this game is worth their evening.
- **Second zone under ten minutes.** The first zone teaches the loop; the second
  proves the loop pays.
- **About eleven minutes per zone on the first run**, including the pick and the
  backpack bought along the way.
- **First rebirth under an hour**, with five zones seen before anything is taken
  away.
- **Each run through the map is shorter than the last**: roughly 49, 27, 20 and
  16 minutes across the first four rebirths. This gap is the entire reason a
  rebirth feels good rather than punishing, and it comes from keeping pets and
  Core Shop upgrades through the reset.

If a change makes run two *longer* than run one, the rebirth reward is too small
or the reset is too harsh -- fix it before shipping.

## The Core budget

Cores are the one currency with a hard supply: a rebirth mints `rebirths + 1` of
them and nothing else produces any. Across thirty rebirths the game has minted 465.

Core Shop costs are therefore **linear** — level L costs `baseCost + costStep * L`
— rather than the geometric curve the rest of the economy uses. A 1.28x curve over
fifty levels would ask for millions of Cores that do not exist, and rounding a slow
geometric curve to whole Cores makes consecutive levels cost the same, which reads
as a bug to anyone counting.

Maxing the whole Core Shop currently costs **940 Cores, about 43 rebirths**. The
self-test asserts this stays under 100 rebirths, so a change that quietly makes the
prestige track unreachable fails at the terminal instead of in production.

## What the simulation leaves out

Pets, quests, daily rewards, playtime rewards and codes. A real player has all of
them, which is why real progression is faster than this table. They are deliberately
excluded so the table measures the core loop on its own; if the core loop only
works because of its bonuses, the core loop does not work.
