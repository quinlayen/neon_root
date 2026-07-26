# Neon Root

A cyberpunk, hub-and-jobs text adventure that teaches **real tools**:
Linux shell, Python, Git, and (optionally) SQL — by using them.

> Status: early design / scaffold. See [docs/DESIGN.md](docs/DESIGN.md).

## Fantasy options (pick one spine; jobs can flavor the others)

See the design doc for full details. Short versions:

1. **Street Netrunner** — freelance hacker running wetwork on the grid.
2. **Corp IT Mole** — insider tickets, logs, and "maintenance windows."
3. **Open-Source Resistance** — liberate knowledge from corp silos.

## Planned skills (v1)

- **Shell** — navigate the city filesystem, logs, perms, processes
- **Python** — small scripts that parse data / unlock systems
- **Git** — versioned safehouses, recover deleted intel
- **SQL** (stretch) — one corp DB heist job

## Requirements

**Required**

- macOS or Linux
- bash (including macOS system bash 3.2)

**Optional** (for optional skill jobs; the shell-only path is completable without them)

- `python3` — Python jobs
- `git` — Git jobs
- `sqlite3` — SQL stretch jobs

## Play (not implemented yet)

```bash
# future
./play.sh
```

## Relation to Tuxville

Sibling project to [The Ruins of Tuxville](../tuxville_game): same "filesystem as world"
idea, different theme (cyberpunk), structure (hub + jobs), and skill set (multi-tool).

## License / spirit

Built for learning. Share freely with students and friends.
