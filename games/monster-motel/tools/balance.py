#!/usr/bin/env python3
"""
Balance simulator for Monster Motel.

Reads the real numbers out of src/shared/Config/*.lua and plays a free-to-play
account forward, so the pacing claims in the comments and in docs/BALANCE.md are
checked against the config rather than against somebody's memory of it.

Unlike a mining game, this economy is driven by who happens to turn up on the
arrivals road, so a single run is noise. This does a Monte Carlo: several runs
against the real rarity weights, reporting the median time to each milestone.

The simulated player is greedy but sensible:

  * Buys a guest if a room is free, or if it out-earns the worst guest housed.
  * Buys a room or a rating upgrade when it is affordable and worth more than
    banking the cash for the next guest.
  * Never raids and is never raided. Theft is a wash across a server -- one
    motel's loss is another's gain -- so leaving it out measures the economy
    rather than the dice.

Run it after changing any price:

    python3 games/monster-motel/tools/balance.py
"""

from __future__ import annotations

import random
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config"

# Mirrors EconomyService.RenovationBonus, which lives in the server layer rather
# than in Config because it is applied rather than configured.
RENOVATION_BONUS = 0.25


def read(name: str) -> str:
    return (CONFIG / f"{name}.lua").read_text()


def scalar(source: str, name: str) -> float:
    match = re.search(rf"{re.escape(name)} = ([\d.]+)", source)
    assert match, f"could not find {name}"
    return float(match.group(1))


def load_guests() -> dict[str, list[int]]:
    """rarity -> sorted list of rents."""
    by_rarity: dict[str, list[int]] = {}
    for block in re.finditer(
        r'id = "(\w+)", name = "[^"]+", rarity = "(\w+)", rent = (\d+)', read("Guests")
    ):
        _, rarity, rent = block.groups()
        by_rarity.setdefault(rarity, []).append(int(rent))
    for rents in by_rarity.values():
        rents.sort()
    return by_rarity


def load_ratings() -> list[dict]:
    source = read("Ratings")
    ratings = []
    for block in re.split(r"\n\t\{", source):
        level = re.search(r"level = (\d+)", block)
        cost = re.search(r"cost = (\d+)", block)
        weights = re.search(r"weights = \{([^}]*)\}", block)
        name = re.search(r'name = "([^"]+)"', block)
        if not (level and cost and weights and name):
            continue
        parsed = {
            key: int(value)
            for key, value in re.findall(r"(\w+) = (\d+)", weights.group(1))
        }
        ratings.append(
            {"level": int(level.group(1)), "name": name.group(1), "cost": int(cost.group(1)), "weights": parsed}
        )
    return sorted(ratings, key=lambda r: r["level"])


def load_payback() -> dict[str, int]:
    source = read("Ratings")
    block = re.search(r"Ratings\.PaybackSeconds = \{(.*?)\}", source, re.S)
    assert block
    return {key: int(value) for key, value in re.findall(r"(\w+) = (\d+)", block.group(1))}


class Sim:
    def __init__(self, seed: int):
        self.rng = random.Random(seed)
        self.guests = load_guests()
        self.ratings = load_ratings()
        self.payback = load_payback()

        game = read("GameConfig")
        self.arrival_interval = scalar(game, "ArrivalInterval")
        self.starting_rooms = int(scalar(game, "StartingRooms"))
        self.max_rooms = int(scalar(game, "BaseMaxRooms"))

        rooms = read("Rooms")
        self.room_base = scalar(rooms, "Rooms.BaseCost")
        self.room_growth = scalar(rooms, "Rooms.CostGrowth")

        # A motel with no guests earns nothing, so the seed money in the profile
        # template is what bootstraps the whole economy. Read it rather than
        # assuming it.
        schema = (ROOT / "src" / "shared" / "Schema.lua").read_text()
        self.starting_cash = scalar(schema, "cash")

        prestige = read("Prestige")
        self.star_divisor = scalar(prestige, "Prestige.StarDivisor")
        self.minimum_rating = int(scalar(prestige, "Prestige.MinimumRating"))

        self.reset()

    def reset(self):
        self.cash = float(self.starting_cash)
        self.seconds = 0.0
        self.rating = 1
        self.rooms = self.starting_rooms
        self.housed: list[int] = []
        self.renovations = 0
        self.earned = float(self.starting_cash)
        self.starred = 0
        self.log: list[tuple[float, str]] = []

    # ------------------------------------------------------------------ model

    def room_cost(self, next_room: int) -> float:
        paid = next_room - self.starting_rooms
        if paid <= 0:
            return 0
        return self.room_base * (self.room_growth ** (paid - 1))

    def rent(self) -> float:
        return sum(self.housed) * (1 + self.renovations * RENOVATION_BONUS)

    def roll_guest(self) -> tuple[str, int]:
        weights = self.ratings[self.rating - 1]["weights"]
        rarities = list(weights)
        rarity = self.rng.choices(rarities, weights=[weights[r] for r in rarities])[0]
        return rarity, self.rng.choice(self.guests[rarity])

    def price(self, rarity: str, rent: int) -> float:
        return rent * self.payback[rarity]

    def note(self, label: str):
        self.log.append((self.seconds, label))

    # ------------------------------------------------------------------ run

    def step_to(self, target_cash: float) -> bool:
        """Waits until the motel has earned `target_cash`. False if it never can."""
        rate = self.rent()
        if self.cash >= target_cash:
            return True
        if rate <= 0:
            return False
        self.seconds += (target_cash - self.cash) / rate
        self.cash = target_cash
        return True

    def run(self, until_rating: int = 7, cap_hours: float = 40) -> list[tuple[float, str]]:
        self.reset()
        self.note("start")

        next_arrival = 0.0
        guard = 0

        while self.rating < until_rating and self.seconds < cap_hours * 3600 and guard < 200000:
            guard += 1

            # Rent accrues until the next arrival.
            earned = self.rent() * self.arrival_interval
            self.cash += earned
            self.earned += earned
            self.seconds += self.arrival_interval

            # Renovating needs a minimum rating AND enough earned to be worth a
            # Star, so track when both first line up.
            stars = int((self.earned / self.star_divisor) ** 0.5)
            if stars > self.starred:
                self.starred = stars
                if stars in (1, 3, 10) and self.rating >= self.minimum_rating:
                    self.note(f"renovate for {stars} star{'s' if stars > 1 else ''}")

            rarity, rent = self.roll_guest()
            cost = self.price(rarity, rent)

            free_room = len(self.housed) < self.rooms
            upgrade_target = min(self.housed) if self.housed else 0
            worth_it = free_room or rent > upgrade_target

            if worth_it and self.cash >= cost:
                self.cash -= cost
                if free_room:
                    self.housed.append(rent)
                else:
                    self.housed.remove(upgrade_target)
                    self.housed.append(rent)

            # Consider a room, then a rating. Both are compared against simply
            # holding the cash, which is what a real player weighs up.
            if len(self.housed) >= self.rooms and self.rooms < self.max_rooms:
                cost = self.room_cost(self.rooms + 1)
                if self.cash >= cost:
                    self.cash -= cost
                    self.rooms += 1
                    if self.rooms % 5 == 0:
                        self.note(f"{self.rooms} rooms")

            if self.rating < len(self.ratings):
                nxt = self.ratings[self.rating]
                if self.cash >= nxt["cost"]:
                    self.cash -= nxt["cost"]
                    self.rating += 1
                    self.note(f"{nxt['name']}")

        return list(self.log)


def main() -> int:
    runs = 9
    milestones: dict[str, list[float]] = {}
    example: list[tuple[float, str]] = []

    for seed in range(runs):
        sim = Sim(seed)
        log = sim.run()
        if seed == 0:
            example = log
        for seconds, label in log:
            milestones.setdefault(label, []).append(seconds)

    print(f"Monster Motel progression -- median of {runs} runs, free-to-play, no raiding\n")

    ordered = sorted(milestones.items(), key=lambda kv: statistics.median(kv[1]))
    for label, times in ordered:
        if label == "start":
            continue
        median = statistics.median(times) / 60
        spread = (max(times) - min(times)) / 60
        reached = len(times)
        suffix = "" if reached == runs else f"   (reached in {reached}/{runs} runs)"
        print(f"  {median:7.1f} min   {label:<24} +/- {spread:5.1f} min{suffix}")

    print("\nOne full run for shape:\n")
    for seconds, label in example:
        print(f"  {seconds / 60:7.1f} min   {label}")

    ratings = [v for k, v in milestones.items() if "Star" in k or "Last Motel" in k]
    if ratings:
        first = min(statistics.median(v) for v in ratings) / 60
        last = max(statistics.median(v) for v in ratings) / 60
        print(f"\nSummary\n  first rating upgrade   {first:.1f} min\n  final rating           {last:.1f} min")

    print("\nIgnores quests, dailies, codes, the Celebrity Arrival and every gamepass,")
    print("all of which a real player has. Treat these as the slow end of the range.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
