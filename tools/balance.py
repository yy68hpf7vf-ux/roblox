#!/usr/bin/env python3
"""
Balance simulator for Rift Miner Simulator.

Reads the real numbers out of src/shared/Config/*.lua and plays a free-to-play
account forward, so the pacing claims in the comments and in docs/BALANCE.md are
checked against the config rather than against somebody's memory of it.

The player model is a greedy one: at each decision point, buy whichever available
upgrade (next pick, next backpack, next zone) buys the most crystals-per-second
per crystal spent, wait until it is affordable, buy it, repeat.

Run it after changing any price:

    python3 tools/balance.py
"""

from __future__ import annotations

import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config"

# Mirrors GameConfig.lua. Parsed rather than hardcoded where it matters.
SWING_COOLDOWN = 0.55
BREAK_BONUS_SWINGS = 2
# Round trip to the sell pad and back to the seam. Generous; a real player who
# knows the map does it faster, which makes every number below a little
# pessimistic.
WALK_SECONDS = 9.0


def read(name: str) -> str:
    return (CONFIG / f"{name}.lua").read_text()


def entries(source: str, fields: dict[str, str]) -> list[dict]:
    """Pulls one dict per `id = "..."` block, reading the named numeric fields."""
    blocks = re.split(r'\n\t\t\{|\n\t\{', source)
    out = []
    for block in blocks:
        found = re.search(r'id = "([a-z]+)"', block)
        if not found:
            continue
        row = {"id": found.group(1)}
        ok = True
        for key, pattern in fields.items():
            match = re.search(pattern, block)
            if not match:
                ok = False
                break
            row[key] = float(match.group(1))
        if ok:
            name = re.search(r'name = "([^"]+)"', block)
            row["name"] = name.group(1) if name else row["id"]
            out.append(row)
    return out


def scalar(source: str, name: str) -> float:
    match = re.search(rf"{name} = ([\d.]+)", source)
    assert match, f"could not find {name}"
    return float(match.group(1))


@dataclass
class Zone:
    id: str
    name: str
    ore_value: float
    ore_per_power: float
    node_health: float
    unlock_cost: float
    rebirths: int
    gated: bool


def load():
    tools = entries(read("Tools"), {"price": r"price = (\d+)", "power": r"power = (\d+)",
                                    "rebirths": r"rebirths = (\d+)"})
    packs = entries(read("Backpacks"), {"price": r"price = (\d+)", "capacity": r"capacity = (\d+)",
                                        "rebirths": r"rebirths = (\d+)"})

    zone_source = read("Zones")
    zone_rows = entries(zone_source, {
        "ore_value": r"oreValue = ([\d.]+)",
        "ore_per_power": r"orePerPower = ([\d.]+)",
        "node_health": r"nodeHealth = (\d+)",
        "unlock_cost": r"unlockCost = (\d+)",
        "rebirths": r"rebirths = (\d+)",
    })
    zones = []
    for row in zone_rows:
        block_match = re.search(rf'id = "{row["id"]}".*?nodeColor', zone_source, re.S)
        gated = bool(block_match and re.search(r'gamepass = "', block_match.group(0)))
        zones.append(Zone(row["id"], row["name"], row["ore_value"], row["ore_per_power"],
                          row["node_health"], row["unlock_cost"], int(row["rebirths"]), gated))

    eggs = entries(read("Eggs"), {"price": r"price = (\d+)"})

    rebirth_source = read("Rebirths")
    rebirth = {
        "base": scalar(rebirth_source, "Rebirths.BaseCost"),
        "growth": scalar(rebirth_source, "Rebirths.CostGrowth"),
        "per": scalar(rebirth_source, "Rebirths.MultiplierPerRebirth"),
    }

    return tools, packs, zones, eggs, rebirth


def ore_per_second(zone: Zone, power: float) -> float:
    """Mirrors EconomyService.incomePerSecond, in ore rather than crystals."""
    per_swing = power * zone.ore_per_power
    swings = max(1, math.ceil(zone.node_health / power))
    return per_swing * (swings + BREAK_BONUS_SWINGS) / (swings * SWING_COOLDOWN)


def crystals_per_second(zone: Zone, power: float, capacity: float, mult: float) -> float:
    """Includes the walk back to the sell pad, which the in-game estimate omits."""
    rate = ore_per_second(zone, power)
    mine_time = capacity / rate
    return (capacity * zone.ore_value * mult) / (mine_time + WALK_SECONDS)


def trip_seconds(zone: Zone, power: float, capacity: float) -> float:
    return capacity / ore_per_second(zone, power)


def simulate(tools, packs, zones, rebirth, max_rebirths=4, verbose=True):
    owned_tool, owned_pack, owned_zone = 0, 0, 0
    crystals = 0.0
    seconds = 0.0
    rebirths = 0
    log = []

    playable = [z for z in zones if not z.gated]

    def mult() -> float:
        return 1 + rebirth["per"] * rebirths

    def rate() -> float:
        return crystals_per_second(playable[owned_zone], tools[owned_tool]["power"],
                                   packs[owned_pack]["capacity"], mult())

    def note(label: str):
        log.append((seconds, label, rate()))
        if verbose:
            print(f"  {seconds/60:7.1f} min   {label:<34} {rate():>16,.0f} c/s")

    note("start")

    guard = 0
    while rebirths <= max_rebirths and guard < 400:
        guard += 1
        current = rate()
        candidates = []

        if owned_tool + 1 < len(tools):
            nxt = tools[owned_tool + 1]
            if rebirths >= nxt["rebirths"]:
                gain = crystals_per_second(playable[owned_zone], nxt["power"],
                                           packs[owned_pack]["capacity"], mult()) - current
                candidates.append((gain / nxt["price"], nxt["price"], "tool", nxt))

        if owned_pack + 1 < len(packs):
            nxt = packs[owned_pack + 1]
            if rebirths >= nxt["rebirths"]:
                gain = crystals_per_second(playable[owned_zone], tools[owned_tool]["power"],
                                           nxt["capacity"], mult()) - current
                candidates.append((gain / nxt["price"], nxt["price"], "pack", nxt))

        if owned_zone + 1 < len(playable):
            nxt = playable[owned_zone + 1]
            if rebirths >= nxt.rebirths:
                gain = crystals_per_second(nxt, tools[owned_tool]["power"],
                                           packs[owned_pack]["capacity"], mult()) - current
                candidates.append((gain / max(1, nxt.unlock_cost), nxt.unlock_cost, "zone", nxt))

        rebirth_cost = rebirth["base"] * (rebirth["growth"] ** rebirths)
        best = max(candidates, key=lambda c: c[0]) if candidates else None

        # Rebirth when there is nothing left to buy at this rebirth count (the
        # rebirth-gated content is the only thing above them), or when a rebirth
        # is comfortably cheaper than the next upgrade worth having.
        if best is None or rebirth_cost * 2 <= best[1]:
            seconds += max(0, (rebirth_cost - crystals) / rate())
            crystals = 0.0
            rebirths += 1
            owned_tool = owned_pack = owned_zone = 0
            note(f"REBIRTH {rebirths} (x{mult():.0f})")
            continue

        _, cost, kind, item = best
        seconds += max(0, (cost - crystals) / rate())
        crystals = 0.0

        if kind == "tool":
            owned_tool += 1
            note(f"pick: {item['name']}")
        elif kind == "pack":
            owned_pack += 1
            note(f"pack: {item['name']}")
        else:
            owned_zone += 1
            note(f"ZONE: {item.name}")

    return log


def main() -> int:
    tools, packs, zones, eggs, rebirth = load()

    print(f"Loaded {len(tools)} picks, {len(packs)} backpacks, {len(zones)} zones, {len(eggs)} eggs.\n")

    print("Trip length at the expected loadout for each zone")
    print("  (how long a backpack takes to fill; the design target is 20-35s)\n")
    playable = [z for z in zones if not z.gated]
    for index, zone in enumerate(playable):
        power = tools[min(index, len(tools) - 1)]["power"]
        capacity = packs[min(index, len(packs) - 1)]["capacity"]
        seconds = trip_seconds(zone, power, capacity)
        flag = "" if 20 <= seconds <= 35 else "   <-- outside target"
        print(f"  {zone.name:<18} {seconds:6.1f}s{flag}")

    print("\nFree-to-play progression (no pets, no Robux, no quests or dailies)\n")
    log = simulate(tools, packs, zones, rebirth)

    zone_times = [(t, label) for t, label, _ in log if label.startswith("ZONE")]
    rebirth_times = [(t, label) for t, label, _ in log if label.startswith("REBIRTH")]

    print("\nSummary")
    if zone_times:
        print(f"  second zone at        {zone_times[0][0]/60:.1f} min")
        print(f"  all base zones open   {zone_times[-1][0]/60:.1f} min")
        gaps = [zone_times[i][0] - zone_times[i - 1][0] for i in range(1, len(zone_times))]
        if gaps:
            print(f"  gap between zones     {min(gaps)/60:.1f} - {max(gaps)/60:.1f} min")
    if rebirth_times:
        print(f"  first rebirth at      {rebirth_times[0][0]/60:.1f} min")
    print("\nEverything above ignores pets, quests, daily rewards and codes, all of")
    print("which a real player has. Treat these as the slow end of the range.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
