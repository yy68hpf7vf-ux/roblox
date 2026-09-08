# Monster Motel

> Vacancy. Sort of.

A complete Roblox game about running a roadside motel for monsters, and robbing
the one next door.

Guests check in, pay rent every second, and live in rooms you buy. At Lights Out
every door in town unlocks and anyone can break into your motel and carry one of
your guests home to theirs. Every ten minutes a Celebrity lands in the town square
and whoever walks them home keeps them.

Everything is code and config — the map, the guests, the odds, the economy. There
is no `.rbxl` to hand-edit.

## The loop

1. **Buy a guest** off the Arrivals Road. Each one pays rent per second.
2. **Rent piles up in your safe.** Walk onto your front desk to bank it.
3. **Spend it** on rooms (more guests), rating (better guests), a lock (a slower
   door), and a bigger safe.
4. **Lights Out.** Ninety seconds where every door in town can be broken. Raid
   somebody, or stay home and guard yours.
5. **Renovate** for a permanent multiplier and Stars. You keep every guest.

## What's in it

**42 guests across 7 rarities**, from the Sock Gremlin to Guest Zero. Four
Celebrities that never appear in a shop — they only arrive in the square, in front
of everybody.

**A real raid**, with a break timer on the door, a carried guest you can see on the
thief's back, and a chase that ends when the owner catches up. A guest in transit
belongs to nobody's save until it lands, so it can never be duplicated or lost.

**A day/night cycle** the whole server shares. Five minute days, ninety second
nights, and a clock on the HUD that everything else keys off.

**The Celebrity Arrival** every ten minutes: a guest worth more than anything the
road will ever offer, dropped in public with a countdown. Anyone can tag the
carrier and make them drop it, which turns the walk home into the best ninety
seconds in the game.

**Retention** — daily streak with a two-day grace window, a playtime ladder that
ends when it says it does, three daily quests that reward defending as often as
raiding, codes, and global leaderboards on signs in the square.

**Monetization** — six gamepasses and five products, all optional, none of which
touch raiding. See [docs/FAIRNESS.md](docs/FAIRNESS.md).

## Running it

```bash
cd games/monster-motel
rojo build -o motel.rbxl
```

Open `motel.rbxl` in Studio and press Play. Then:

1. **Publish the place** (File → Publish to Roblox As…) and **enable API
   Services** (File → Game Settings → Security). DataStores need both; a local
   file has no place id, so saving fails without publishing no matter what else
   you set. Until then the HUD says plainly that nothing is being saved.
2. **Test with two players** (Test → Clients and Servers → 2 players). Raiding,
   the leaderboards and the celebrity scramble are invisible in single-player.
3. **Fill in the store ids** in `src/shared/Config/Monetization.lua` when you are
   ready to sell. Anything left at `0` stays hidden.

The town has 12 plots, so set MaxPlayers to 12 or raise `WorldBuilder.PlotCount`.

## Checking a change

```bash
tools/check.sh                                          # from the repo root, both games
python3 tools/check_requires.py games/monster-motel     # require graph
python3 tools/selftest.py <luau> games/monster-motel    # 876 config assertions
python3 games/monster-motel/tools/balance.py            # progression simulation
```

The self-test is worth knowing about. Beyond the usual curve and id checks it
asserts two things specific to this game:

- **No paid item can touch a raid.** It walks every gamepass and product against a
  forbidden-field list and the names of the raid constants. A future "+2 carry
  speed" pass fails at the terminal instead of shipping.
- **A maxed door is still a door.** The worst-case break time has to fit inside
  half a night, or a fully upgraded motel would be unraidable.

It also caught a real bug during development: a new profile started with no cash
and no guests, which meant no rent, which meant no way to ever buy a guest. New
motels now start with seed money, and there is an assertion that keeps it covering
the cheapest guest on the road.

## Layout

```
src/shared/Config/     Every tunable number
src/server/Services/   One responsibility each
  TheftService         The raid. Read the header comment first.
  PlotService          Motels, and keeping them in sync with saves
  NightService         The clock everything keys off
  EventService         The Celebrity Arrival
src/server/World/      Builds the town at runtime
src/client/            HUD, six windows, the raid controller
tools/                 Self-test assertions and the balance simulation
docs/FAIRNESS.md       Why nothing sold affects a raid, and how that is enforced
docs/BALANCE.md        The economy in one formula, and how to re-tune it
```

## A note on the design

This is built to the shape of the "steal a ___" games, which is a well-worn genre —
passive-income units on a base, plus PvP theft. The mechanics are the genre's; the
motel, the guests, the celebrity event and the code are not lifted from any
particular game.

The one place it deliberately parts company with the genre is the store. Raiding
games usually end up selling an edge in the raid, and they usually die about six
weeks later, because the players who lose every chase leave and take the audience
the payers were performing for with them. This one sells speed of your own
progress instead — a lot of it — and enforces the line with a test.
