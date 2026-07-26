# Neon Root

A cyberpunk, hub-and-jobs text adventure that teaches **real tools**:
Linux shell, Python, Git, and (optionally) SQL — by using them.

You play in a real terminal. The world is a generated directory tree
(`metroplex/`). Progress is filesystem state. Fiction default: **Street Netrunner**.

## Requirements

**Required**

- macOS or Linux
- **bash** (including macOS bash 3.2)

**Optional** (jobs that need them show as **Locked** until installed)

- `python3` — implant_parse
- `git` — git_safehouse, git_stash_drop
- `sqlite3` — payroll_shard (stretch)

The **shell-only** path (tutorial + shell jobs) is completable without optional tools.

## Play

```bash
./play.sh              # continue if possible, else new game
./play.sh --new        # wipe metroplex/, re-seed, rebuild
./play.sh --continue   # resume only (error if no world)
./play.sh --tools      # detect python3/git/sqlite3 and exit
./play.sh --help
```

After launch you are in a game shell with helpers loaded:

| Command | Purpose |
|---------|---------|
| `look` | Room text (`-` file), exits, items |
| `hint` | Local hint if present |
| `jobs` | Job board (open / active / locked / completed) |
| `brief [id]` | Contract objective |
| `accept <id>` | Take a contract (must accept before complete) |
| `complete [id]` | Run the job checker; cash out if done |
| `status` | Progress / CLEARED / tools |
| `inventory` / `take` / `drop` | Global inventory under `.inventory/` |
| `whereami` / `save` | Location + bookmark |
| `exit` | Leave shell (progress stays on disk) |

Typical first run:

```text
look
jobs
accept tutorial_grid
cd jobs/tutorial_grid
look
# write jack_confirm.txt with the uplink code from the room
complete
status
```

## Smoke test

```bash
./scripts/smoke_test.sh
```

Builds a fresh world, exercises tutorial accept/complete, inventory guards,
tool lock/unlock without re-seed, and a few job checkers.

## Honor-system boundary

Neon Root **cannot** confine your shell without an OS sandbox. You can `cd $HOME`
or run anything. The game still:

- Never suggests host-destructive commands or real network attacks
- Completes only via in-tree checkers under `metroplex/jobs/<id>/`
- Uses local git only (`git -c user…`, no `git config --global`)
- Names watcher processes exactly `nr_watcher_<job_id>` for safe `ps`/`kill` teaching

**Do not** use skills learned here against real systems without authorization.

### Author Safety Checklist (for job PRs)

1. No real public hostnames/IPs as attack targets; fiction names only.
2. Room text must not instruct `curl`/`wget`/`ssh`/`sudo` against real systems.
3. Python: stdlib, offline, no required sockets.
4. Git: no `git config --global`; remotes none or path/`file://` under metroplex.
5. Checkers: no `eval` of player content; no network; secrets baked at gen time via `seed_token`.
6. Process hints: exact `nr_watcher_<job_id>` or pid from `ps`; never `kill -9 -1` or broad `pkill`.
7. All puzzle paths under `metroplex/jobs/<id>/`.
8. Use `seed_token` for any secret string players must discover.

## Fantasy spines

See [docs/FANTASY_NOTES.md](docs/FANTASY_NOTES.md) and [docs/DESIGN.md](docs/DESIGN.md).

1. **Street Netrunner** (default) — freelance gridwork
2. **Corp IT Mole** — tickets and maintenance windows
3. **Open-Source Resistance** — liberate knowledge from corp ACLs

## Relation to Tuxville

Sibling project to The Ruins of Tuxville: same “filesystem as world” idea,
different theme (cyberpunk), structure (hub + jobs), and multi-tool skill set.
Code reuse is **patterns only** — not a shared package.

## License / spirit

Built for learning. Share freely with students and friends.
