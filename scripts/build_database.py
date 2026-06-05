"""
Load ATP CSV files into SQLite and build analytics tables.

Run from project root:
    python scripts/build_database.py
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pandas as pd

MATCH_YEAR_MIN = 2015
MATCH_YEAR_MAX = 2025
RANKING_DATE_MIN = 20150101
RANKING_DATE_MAX = 20251231


def project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_raw_tables(conn: sqlite3.Connection, raw_dir: Path) -> dict[str, int]:
    counts: dict[str, int] = {}

    players = pd.read_csv(raw_dir / "atp_players.csv", low_memory=False)
    players.to_sql("players_raw", conn, if_exists="replace", index=False)
    counts["players_raw"] = len(players)

    match_files = sorted(raw_dir.glob("atp_matches_*.csv"))
    match_files = [
        f
        for f in match_files
        if f.stem.split("_")[-1].isdigit()
        and MATCH_YEAR_MIN <= int(f.stem.split("_")[-1]) <= MATCH_YEAR_MAX
    ]
    if not match_files:
        raise FileNotFoundError(
            f"No match files for {MATCH_YEAR_MIN}-{MATCH_YEAR_MAX} in {raw_dir}"
        )

    matches = pd.concat([pd.read_csv(f) for f in match_files], ignore_index=True)
    matches.to_sql("matches_raw", conn, if_exists="replace", index=False)
    counts["matches_raw"] = len(matches)

    ranking_files = [raw_dir / "atp_rankings_10s.csv", raw_dir / "atp_rankings_20s.csv"]
    for path in ranking_files:
        if not path.exists():
            raise FileNotFoundError(f"Missing rankings file: {path}")

    rankings = pd.concat([pd.read_csv(f) for f in ranking_files], ignore_index=True)
    rankings = rankings.rename(
        columns={"rank": "ranking", "player": "player_id", "points": "ranking_points"}
    )
    rankings = rankings[
        (rankings["ranking_date"] >= RANKING_DATE_MIN)
        & (rankings["ranking_date"] <= RANKING_DATE_MAX)
    ]
    rankings = rankings.drop_duplicates(
        subset=["ranking_date", "player_id"], keep="last"
    )
    rankings.to_sql("rankings_raw", conn, if_exists="replace", index=False)
    counts["rankings_raw"] = len(rankings)

    return counts


def run_sql_file(conn: sqlite3.Connection, path: Path) -> None:
    conn.executescript(path.read_text(encoding="utf-8"))


def print_summary(conn: sqlite3.Connection) -> None:
    tables = ["players", "matches", "rankings_weekly", "player_match_results"]
    print("\nFinal tables:")
    for name in tables:
        row = conn.execute(f"SELECT COUNT(*) FROM {name}").fetchone()
        print(f"  {name}: {row[0]:,}")

    top50 = conn.execute("SELECT COUNT(*) FROM v_top50_players").fetchone()[0]
    print(f"  v_top50_players: {top50:,}")


def main() -> None:
    root = project_root()
    raw_dir = root / "data" / "raw"
    sql_dir = root / "sql"
    db_path = root / "data" / "atp_tennis.db"
    db_path.parent.mkdir(parents=True, exist_ok=True)

    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    try:
        print("Loading CSV into staging tables...")
        counts = load_raw_tables(conn, raw_dir)
        for table, n in counts.items():
            print(f"  {table}: {n:,}")

        print("\nBuilding analytics tables...")
        run_sql_file(conn, sql_dir / "01_transform.sql")
        run_sql_file(conn, sql_dir / "02_views.sql")
        run_sql_file(conn, sql_dir / "04_analytics_views.sql")
        conn.commit()

        print(f"\nDatabase ready: {db_path}")
        print_summary(conn)
    finally:
        conn.close()

    print("\nExporting Tableau CSVs...")
    import subprocess
    import sys

    subprocess.run(
        [sys.executable, str(root / "scripts" / "export_tableau.py")],
        check=True,
    )


if __name__ == "__main__":
    main()
