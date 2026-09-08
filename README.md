# Rift Miner Simulator

> **This repo holds two complete games.** Rift Miner Simulator is documented below
> and builds from this folder. **[Monster Motel](games/monster-motel/)** — a
> base-building game about renting rooms to monsters and robbing the motel next
> door — builds from `games/monster-motel/`. `tools/check.sh` checks both.

A complete, working Roblox simulator game. Mine crystal seams, fill your backpack,
sell it, buy a better pick, unlock a deeper zone, hatch pets that multiply
everything, then rebirth and do it again faster.

Everything is code and config — the map, the shops, the pets, the economy. There
is no `.rbxl` to hand-edit. Change a number in `src/shared/Config/` and the game
changes.

## What's in it

**Core loop.** Ten zones, twelve picks, ten backpacks. Swing at a node, ore goes
in the pack, walk to the sell pad, buy the next thing. A trip is about 25 seconds
anywhere in the game.

**Pets.** Forty-two pets across eight eggs, each multiplying every sale.
Duplicates group into one row so a 300-pet collection is twelve lines, not three
hundred.

**Rebirth and the Core Shop.** Trade the map for a permanent multiplier and Cores.
Cores buy Refinery (crystal value, 30 levels), Deep Yield (ore per swing, 20
levels) and Kennel (pet slots, 2 levels) — permanently, and only with Cores.
Nothing in the Core Shop is for sale.

**Retention.** Daily login streak with a two-day grace window, a twelve-rung
playtime ladder that ends when it says it does, three daily quests that scale with
your rebirth count, redeemable codes, and global leaderboards on physical signs in
the starting plaza.

**Monetization.** Five gamepasses and five developer products, all optional, all
stating exactly what they do. See [docs/MONETIZATION.md](docs/MONETIZATION.md).

## Getting it running

### 1. Get the code

```bash
git clone https://github.com/yy68hpf7vf-ux/roblox.git
cd roblox
git checkout claude/roblox-simulator-game-1amidi
```

### 2. Install Rojo

Rojo turns this folder into a Roblox place file. Either:

- Download the binary for your OS from
  [the Rojo releases page](https://github.com/rojo-rbx/rojo/releases) and put it
  on your PATH, or
- Install [Rokit](https://github.com/rojo-rbx/rokit) (or Aftman) and run
  `rokit install` here — `aftman.toml` already pins the versions.

Check it worked: `rojo --version` should print 7.x.

### 3. Build and open

```bash
rojo build -o game.rbxl
```

Double-click `game.rbxl`. Studio opens with the whole game in it. Press **Play**
and you can mine immediately — the islands, shops and pads are all generated on
the first server tick.

If you would rather edit code and see it sync live, install the **Rojo** plugin
from the Studio marketplace, run `rojo serve` in this folder, and hit Connect in
the plugin instead.

### 4. Turn on saving

Straight out of the build, the HUD will tell you your progress is **not being
saved**. That is correct and expected, not a bug — Roblox DataStores need two
things, and a fresh local file has neither:

1. **The place must be published.** In Studio: **File → Publish to Roblox As…**,
   create a new experience. A local `.rbxl` has no place id, so DataStore calls
   fail no matter what else you set.
2. **API access must be on.** **File → Game Settings → Security → Enable Studio
   Access to API Services.**

Do both, restart the playtest, and the warning goes away. Until then every player
gets a working in-memory profile so you can still test everything else.

### 5. Test it like a real server

The game is multiplayer — shared nodes, leaderboards, pets you can see on other
players. In Studio: **Test → Clients and Servers → 2 players → Start**. That is
the only way to catch anything server-authoritative.

### 6. Turn on the store (optional)

Nothing is for sale until you say so. On the
[Creator Dashboard](https://create.roblox.com), create the passes and developer
products, then paste each id into `src/shared/Config/Monetization.lua` where it
currently says `assetId = 0`.

Anything left at `0` is hidden from the Store window rather than opening a prompt
that cannot resolve, and the server logs one warning at startup listing what is
still unconfigured. See [docs/MONETIZATION.md](docs/MONETIZATION.md).

## Layout

```
src/shared/          Config, schema, remotes, formatting — used by both sides
  Config/            Every tunable number in the game
  Util/              Format, Signal, TableUtil
  Net.lua            Remote definitions
  Schema.lua         Profile shape and migrations
src/server/
  Services/          One responsibility each; see below
  World/             Builds all ten islands at runtime
src/client/
  Ui/                Theme, widgets, HUD, six windows
  Controllers/       Input, pick and pet rendering
tools/
  check.sh           Runs everything below
  check_requires.py  Resolves every require against the Rojo tree
  selftest.py        Bundles the shared layer and runs it outside Roblox
  selftest.luau      The assertions it runs
  balance.py         Simulates progression against the real config
```

### How the server is arranged

`DataService` owns profiles: load, save, autosave, shutdown flush, and a session
lock so two servers can never write over each other.

`EconomyService` is the only place that answers "how much is this worth". Every
multiplier in the game is assembled in one function, so the HUD, a sale, and a
quest reward can never disagree about your rate.

`MiningService` owns node health and every ore award. The client asks to swing at
a node and never says what it got; the server checks the cooldown, the distance,
the zone you are standing in and whether you have access to it, then does the
arithmetic itself.

`StateService` turns a profile into the payload the client renders and pushes it
when something changes, coalesced on Heartbeat — a sale that touches five fields
sends one packet.

`ActionService` is the single entry point the client can call. Everything arrives
as a named action, gets rate limited, and is re-validated against the server's own
config.

The rest — `PetService`, `RebirthService`, `QuestService`, `RewardService`,
`ShopService`, `PadService`, `CodeService`, `MonetizationService`, `PassService`,
`LeaderboardService`, `LoadoutService` — do what they are named after.
`Remote.lua` exists so gameplay services can message a client without requiring
`StateService`, which has to require them.

Cosmetics (the pick in your hand, the pets trailing behind you) are drawn by each
client from attributes the server sets, not built as server instances. That is the
difference between a server that holds thirty players and one that holds eight.

## Checking a change

```bash
tools/check.sh [path/to/luau]
```

Four things per game, none of which need Studio open:

1. **Parse** — every source file compiles as Luau.
2. **Requires** — all 192 `require()` calls resolve against the Rojo tree, and
   there are no cycles. A typo in a require path compiles fine and fails the
   instant the game starts, so it is worth catching from a terminal.
3. **Config self-test** — 750 assertions over the shared layer: no duplicate ids,
   price and power curves that only go up, egg pools that reference pets that
   exist, odds that sum to 100% *and* match what `Eggs.roll` actually produces
   over 60,000 rolls, a Core Shop the game mints enough Cores to finish, and
   round-trip tests for `Format`, `Signal`, `TableUtil` and `Schema.sanitise`.
4. **Balance** — the progression simulation below still runs.

The Luau interpreter is optional (steps 1 and 3 skip without it); grab it from
[the Luau releases page](https://github.com/luau-lang/luau/releases).

## Tuning it

Read [docs/BALANCE.md](docs/BALANCE.md). The whole economy is four dials and one
formula, and `tools/balance.py` will tell you what your change did:

```bash
python3 tools/balance.py
```

It parses the real config and plays a free-to-play account forward. Current shape:
first upgrade at 2 minutes, second zone at 7, first rebirth at 49, and each run
through the map shorter than the last.

## A note on the design

The brief for this was "make people spend money and play for a long time". That is
a reasonable thing to want from a game, and this build is genuinely built for it:
the progression curve, the prestige loop, the daily hooks and the store are all
real and all tuned.

What it deliberately does not do is get there through the manipulative patterns
common in this genre — no Robux loot boxes, no hidden odds, no countdown timers,
no offers that appear when you run out of currency, no walls priced so that paying
is the sensible way through. Roblox's audience is mostly children, those patterns
get games moderated, and they trade a good month for a bad year.

The honest versions of all of those things are in here instead, and they are the
versions that keep working. `docs/MONETIZATION.md` lists what was left out, so
nobody adds it back by accident.
