"""
Export CSV files for Tableau (one file per dashboard chart).

Run after build_database.py:
    python scripts/export_tableau.py
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

BEST_SURFACE_CTE = """
best_surface AS (
    SELECT first_name || ' ' || last_name AS player_name, surface AS best_surface
    FROM (
        SELECT
            first_name,
            last_name,
            surface,
            ROW_NUMBER() OVER (
                PARTITION BY first_name, last_name
                ORDER BY win_rate DESC, matches DESC
            ) AS rn
        FROM v_win_rate_by_surface
    )
    WHERE rn = 1
)
"""

EXPORTS = [
    ("v_win_rate_by_surface.csv", "SELECT * FROM v_win_rate_by_surface"),
    (
        "v_ranking_history.csv",
        f"""
        WITH {BEST_SURFACE_CTE}
        SELECT r.*, b.best_surface
        FROM v_ranking_history r
        LEFT JOIN best_surface b ON b.player_name = r.player_name
        """,
    ),
    (
        "v_win_rate_leaderboard.csv",
        f"""
        WITH {BEST_SURFACE_CTE}
        SELECT w.*, b.best_surface
        FROM v_win_rate_leaderboard w
        LEFT JOIN best_surface b
          ON b.player_name = w.first_name || ' ' || w.last_name
        """,
    ),
    (
        "v_longest_win_streak.csv",
        f"""
        WITH {BEST_SURFACE_CTE}
        SELECT s.*, b.best_surface
        FROM v_longest_win_streak s
        LEFT JOIN best_surface b
          ON b.player_name = s.first_name || ' ' || s.last_name
        """,
    ),
    (
        "v_rolling_form_monthly.csv",
        f"""
        WITH {BEST_SURFACE_CTE}
        SELECT
            f.player_name,
            substr(cast(tourney_date as text), 1, 4) || '-' ||
            substr(cast(tourney_date as text), 5, 2) || '-01' AS month_date,
            CAST(ROUND(AVG(rolling_win_rate_20) * 100, 1) AS REAL) AS win_rate_pct,
            b.best_surface
        FROM v_rolling_win_rate_20 f
        LEFT JOIN best_surface b ON b.player_name = f.player_name
        WHERE f.window_matches >= 20
        GROUP BY f.player_name, substr(cast(tourney_date as text), 1, 6), b.best_surface
        ORDER BY f.player_name, month_date
        """,
    ),
]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    db_path = root / "data" / "atp_tennis.db"
    out_dir = root / "data" / "exports"
    out_dir.mkdir(parents=True, exist_ok=True)

    if not db_path.exists():
        raise FileNotFoundError(f"Run build_database.py first. Missing: {db_path}")

    conn = sqlite3.connect(db_path)
    try:
        for filename, query in EXPORTS:
            out_path = out_dir / filename
            rows = conn.execute(query).fetchall()
            cols = [d[0] for d in conn.execute(query).description]
            import csv

            with out_path.open("w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(cols)
                writer.writerows(rows)
            print(f"  {filename}: {len(rows):,} rows")
    finally:
        conn.close()

    print(f"\nExports written to: {out_dir}")


if __name__ == "__main__":
    main()
