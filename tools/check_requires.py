#!/usr/bin/env python3
"""
Resolves every require() in the project against the Rojo tree in
default.project.json, and reports any that would fail at runtime.

Rojo maps folders to Instances, so `require(script.Parent.Foo)` is only correct if
a sibling file named Foo.lua exists. A typo there compiles fine and fails the
moment the game starts, which is exactly the class of mistake worth catching from
the command line.

Also reports require cycles, which in Luau surface as a confusing
"requested module experienced an error while loading" rather than a stack trace
pointing at the loop.

    python3 tools/check_requires.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Mirrors default.project.json.
ROOTS = {
    "shared": ("ReplicatedStorage", "Shared"),
    "server": ("ServerScriptService", "Server"),
    "client": ("StarterPlayer", "StarterPlayerScripts", "Client"),
}

# Locals that hold a service lookup rather than a script-relative path.
ALIASES = {
    "Shared": ("ReplicatedStorage", "Shared"),
    "Services": ("ServerScriptService", "Server", "Services"),
}


def node_path(file: Path) -> tuple[str, ...]:
    """The Instance path a source file becomes once Rojo has synced it."""
    relative = file.relative_to(SRC)
    side = relative.parts[0]
    base = ROOTS[side]
    rest = relative.parts[1:]

    if rest[-1] in ("init.server.lua", "init.client.lua", "init.lua"):
        return base + tuple(rest[:-1])
    return base + tuple(rest[:-1]) + (rest[-1][: -len(".lua")],)


def build_index() -> dict[tuple[str, ...], Path]:
    return {node_path(f): f for f in SRC.rglob("*.lua")}


def resolve(expr: str, owner: tuple[str, ...], is_init: bool) -> tuple[str, ...] | None:
    """Turns `script.Parent.Foo` into an Instance path, or None if not resolvable."""
    parts = [p.strip() for p in expr.split(".")]
    head = parts[0]

    if head == "script":
        # A non-init module is its own node; `script.Parent` from it means the
        # containing folder. An init script *is* the folder.
        current = list(owner)
    elif head in ALIASES:
        current = list(ALIASES[head])
    else:
        return None

    for part in parts[1:]:
        if part == "Parent":
            if not current:
                return None
            current.pop()
        else:
            current.append(part)

    return tuple(current)


def main() -> int:
    index = build_index()
    edges: dict[Path, list[Path]] = {}
    problems: list[str] = []

    pattern = re.compile(r"require\(([A-Za-z_][A-Za-z0-9_.]*)\)")

    for file in sorted(SRC.rglob("*.lua")):
        owner = node_path(file)
        is_init = file.name.startswith("init.")
        edges[file] = []

        for match in pattern.finditer(file.read_text()):
            expr = match.group(1)
            target = resolve(expr, owner, is_init)

            if target is None:
                problems.append(f"{file.relative_to(ROOT)}: cannot resolve require({expr})")
                continue

            resolved = index.get(target)
            if resolved is None:
                problems.append(
                    f"{file.relative_to(ROOT)}: require({expr}) -> {'.'.join(target)} does not exist"
                )
                continue

            edges[file].append(resolved)

    # Cycle detection over the resolved graph.
    WHITE, GREY, BLACK = 0, 1, 2
    colour: dict[Path, int] = {f: WHITE for f in edges}
    stack: list[Path] = []
    cycles: list[list[Path]] = []

    def visit(node: Path):
        colour[node] = GREY
        stack.append(node)
        for nxt in edges.get(node, []):
            if colour.get(nxt, BLACK) == GREY:
                start = stack.index(nxt)
                cycles.append(stack[start:] + [nxt])
            elif colour.get(nxt, BLACK) == WHITE:
                visit(nxt)
        stack.pop()
        colour[node] = BLACK

    for node in edges:
        if colour[node] == WHITE:
            visit(node)

    for cycle in cycles:
        names = " -> ".join(p.relative_to(ROOT).as_posix() for p in cycle)
        problems.append(f"require cycle: {names}")

    total = sum(len(v) for v in edges.values())
    if problems:
        print(f"{len(problems)} problem(s) across {total} requires:\n")
        for problem in problems:
            print(f"  {problem}")
        return 1

    print(f"All {total} requires resolve. No cycles. ({len(edges)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
