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
3. **Spend it.** Rooms hold more guests, rating attracts better ones, a lock slows
   thieves down, a bigger safe holds more rent. Then keep spending it: **Running
   Shoes** make you faster, **Room Service** raises every guest's rent, a **Neon
   Sign** brings guests in more often, and a **Night Porter** tells you the moment
   somebody starts on your door.
4. **Lights Out.** Ninety seconds where every door in town can be broken. Raid
   somebody, or stay home and guard yours.
5. **Renovate** for a permanent multiplier and Stars. You keep every guest.

## What's in it

**45 guests across 8 rarities**, from the Sock Gremlin to Guest Zero. Four
Celebrities that never appear in a shop — they only arrive in the square, in front
of everybody — and three Signature guests sold for Robux that are strong, stealable,
and still beaten by the best free ones.

**A real raid**, with a break timer on the door, a carried guest you can see on the
thief's back, and a chase that ends when the owner catches up. A guest in transit
belongs to nobody's save until it lands, so it can never be duplicated or lost.

**A day/night cycle** the whole server shares. Five minute days, ninety second
nights, and a clock on the HUD that everything else keys off. At Lights Out the
whole town switches over at once — every lamp, window and neon sign comes on and
the fog closes to 620 studs, so you cannot read a distant motel sign and have to
commit to a direction.

**A town, not a testbed.** A ring road with dashed lines and street lamps, twelve
two-storey motels with walkways, stairs, lit windows and a **VACANCY / NO VACANCY**
board readable from across the square, and a central plaza with a stage, benches
and a fountain of light where the celebrity lands.

**The Celebrity Arrival** every ten minutes: a guest worth more than anything the
road will ever offer, dropped in public with a countdown. Anyone can tag the
carrier and make them drop it, which turns the walk home into the best ninety
seconds in the game.

**Somewhere to put the money.** Four step purchases and four levelled upgrades, so
collecting rent still has a point once the obvious things are bought. Running Shoes
are Cash-only and capped, and they deliberately do not apply while you are carrying
a guest — see [docs/FAIRNESS.md](docs/FAIRNESS.md).

**An objective chip** that gives a new player exactly one thing to do next, from
"check in your first guest" through to "renovate once", then gets out of the way
for good. The game is not self-explanatory without it.

**A motel that visibly gets better.** Every star changes the walls, the roof and
the material, and each one hangs something new off the building: planters at Two
Star, an awning at Three, a pool with loungers at Four, roof neon at Five, a
searchlight at Six, and a gold arch at Seven. It is the strongest motivator the
genre has, and it is free — you can see what somebody else's money bought them from
across the square, which is the whole reason anybody buys it.

**An index of all 45 guests**, showing which you have ever owned. Discovery is
permanent: renovating does not clear it and neither does losing one to a thief. An
undiscovered row still shows its rarity and its rent, so it doubles as the price
list a player reads before deciding whether the next star is worth it.

**Feedback on the thing you do most.** Cash flies off you when you collect, a guest
pops when it checks in, a new rarity bursts, and the screen goes red the instant
somebody lifts a guest off your desk — the alarm that makes the chase window worth
having. A ticker in the bottom-right reports the rest of the server: big thefts,
renovations, rare finds. It is deliberately picky about what it reports, so the
town feels inhabited rather than noisy.

**Retention** — daily streak with a two-day grace window, a playtime ladder that
ends when it says it does, three daily quests that reward defending as often as
raiding, codes, and global leaderboards on signs in the square.

**Monetization** — nine gamepasses and five products, all optional, none of which
touch raiding. Three of the passes are Signature guests: permanent, strong, and
still out-earned by the best Mythic. See [docs/FAIRNESS.md](docs/FAIRNESS.md).

**The bits every published game needs** — a loading screen from ReplicatedFirst
that hides the default one and teaches the loop while it waits, the VIP chat tag
the store actually promises, sky and atmosphere, and a rescue for anyone who walks
off the edge of the world (a teleport home, not a death, so a thief mid-carry does
not lose their raid to a misstep).

## Running it

There is no `.rbxl` in this repo on purpose -- the whole game, town included, is
built from these files at runtime, so the source is the game. You turn it into a
place file with [Rojo](https://rojo.space).

**Install Rojo** (once):

```bash
# macOS / Linux, with Homebrew:
brew install rojo
# or download the binary for your OS from github.com/rojo-rbx/rojo/releases
# and put it somewhere on your PATH. Windows also has an installer there.
```

**Build the place:**

```bash
cd games/monster-motel
rojo build -o MonsterMotel.rbxl
```

Double-click `MonsterMotel.rbxl` to open it in Studio, and press Play.

If you would rather have Studio update live as you edit these files, install the
**Rojo plugin** from the Studio toolbox, run `rojo serve` in this folder, and hit
Connect in the plugin. That is the better setup while you are changing things; the
`build` above is the better one for just looking at it.

Once it opens:

1. **Publish the place** (File → Publish to Roblox As…) and **enable API
   Services** (File → Game Settings → Security). DataStores need both; a local
   file has no place id, so saving fails without publishing no matter what else
   you set. Until then the HUD says plainly that nothing is being saved.
2. **Test with two players** (Test → Clients and Servers → 2 players). Raiding,
   the leaderboards and the celebrity scramble are invisible in single-player.
3. **Fill in the store ids** in `src/shared/Config/Monetization.lua` when you are
   ready to sell. Anything left at `0` stays hidden.

The town has 12 plots, so set MaxPlayers to 12 or raise `WorldBuilder.PlotCount`.

**Workspace opens empty, and that is correct.** There is no map to look at in edit
mode because there is no map until the server runs -- `WorldBuilder` builds the
road, all twelve motels and the square when you press Play. If you want to inspect
the geometry, press Play and switch to the Server view.

**Instance streaming is deliberately off.** Motels sit on a ring 640 studs across
and the game asks you to read a VACANCY board from the far side of it, spot a
thief leaving somebody else's motel, and see the celebrity land in the square from
your own front desk. Streaming decides what a client can see by distance, which is
exactly the decision this game needs to make for itself. The town is a few hundred
parts, far below the scale streaming exists for, so it costs nothing to send all of
it. Turning it back on will make distant motels and the celebrity pop in and out.

## Checking a change

```bash
tools/check.sh                                          # from the repo root, both games
python3 tools/check_requires.py games/monster-motel     # require graph
python3 tools/selftest.py <luau> games/monster-motel    # 1,129 config assertions
python3 games/monster-motel/tools/balance.py            # progression simulation
```

The self-test is worth knowing about. Beyond the usual curve and id checks it
asserts two things specific to this game:

- **No paid item can touch a raid.** It walks every gamepass and product against a
  forbidden-field list and the names of the raid constants. A future "+2 carry
  speed" pass fails at the terminal instead of shipping. It also checks the
  Cash upgrades: there may be at most one movement upgrade, it must cap under
  double the base speed, and nothing may be named for carry speed.
- **Every objective must be incomplete on a fresh profile.** Otherwise the chip
  would fire the whole tutorial on the first frame and hand out every reward.
- **A maxed door is still a door.** The worst-case break time has to fit inside
  half a night, or a fully upgraded motel would be unraidable.
- **The best guests are not for sale.** Best Signature < best Mythic < best
  Celebrity, every Signature has exactly one pass selling it, and no rating can
  roll one onto the arrivals road.

It also caught a real bug during development: a new profile started with no cash
and no guests, which meant no rent, which meant no way to ever buy a guest. New
motels now start with seed money, and there is an assertion that keeps it covering
the cheapest guest on the road.

## Layout

```
src/shared/Config/     Every tunable number
src/server/Services/   One responsibility each
  TheftService         The raid. Read the header comment first.
  MovementService      The only code that writes WalkSpeed, which is the point
  PlotService          Motels, and keeping them in sync with saves
  NightService         The clock everything keys off
  EventService         The Celebrity Arrival
  ObjectiveService     The one-at-a-time tutorial chip
  SignatureService     Robux guests, and giving them back after a bad night
  AmbienceService      Sky, fog, and switching the whole town on at Lights Out
  SafetyService        Nobody falls out of the world
  FeedService          What the rest of the server is up to, filtered hard
src/replicatedfirst/   The loading screen
src/server/World/      Builds the town at runtime
src/client/            HUD, seven windows, the raid and feedback controllers
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
