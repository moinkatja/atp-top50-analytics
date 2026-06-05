# Tableau setup

Connect each sheet to a **Text file** in `data/exports/`. Refresh after `python scripts/export_tableau.py`.

**Parameter:** `Selected Player` (string list, exact names e.g. `Rafael Nadal`).

| CSV | Chart | Key fields |
|-----|-------|------------|
| `v_ranking_history.csv` | Ranking line | X: `ranking_date`, Y: **MIN(rank)**, reverse axis |
| `v_rolling_form_monthly.csv` | Form | X: `month_date` (month), Y: **AVG(win_rate_pct)** — values are 0–100 |
| `v_win_rate_by_surface.csv` | Surface bars | X: `surface`, Y: **AVG(win_rate)**, filter `surface_rank` ≤ 10 |
| `v_win_rate_leaderboard.csv` | Leaderboard | Y: name, X: `win_rate`, sort desc |
| `v_longest_win_streak.csv` | Streak | Y: `last_name`, X: `longest_win_streak`, sort desc |

**Highlight color** (`best_surface` on all exports except surface chart):

```tableau
IF [player_name] = [Selected Player] THEN [best_surface] ELSE "Other" END
```

Leaderboard / streak: replace `[player_name]` with `[first_name] + " " + [last_name]`.

Colors: Grass green, Clay orange, Hard blue, Other grey.

**Tips:** Use **AVG/MIN**, not SUM, on rank and win rate. Ranking gaps = player outside Top 50.
