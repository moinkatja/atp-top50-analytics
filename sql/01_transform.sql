-- Clean tables built from staging (players_raw, matches_raw, rankings_raw)

DROP TABLE IF EXISTS player_match_results;
DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS rankings_weekly;
DROP TABLE IF EXISTS players;

CREATE TABLE players (
    player_id   INTEGER PRIMARY KEY,
    first_name  TEXT,
    last_name   TEXT,
    country     TEXT,
    birth_date  INTEGER,
    hand        TEXT,
    height      REAL
);

INSERT INTO players (player_id, first_name, last_name, country, birth_date, hand, height)
SELECT
    player_id,
    name_first,
    name_last,
    ioc,
    dob,
    hand,
    height
FROM players_raw
WHERE player_id IN (
    SELECT winner_id FROM matches_raw
    UNION SELECT loser_id FROM matches_raw
    UNION SELECT player_id FROM rankings_raw
);

CREATE TABLE matches (
    match_id        TEXT PRIMARY KEY,
    tourney_id      TEXT NOT NULL,
    tourney_name    TEXT,
    surface         TEXT,
    tourney_date    INTEGER NOT NULL,
    match_num       INTEGER NOT NULL,
    winner_id       INTEGER NOT NULL,
    loser_id        INTEGER NOT NULL,
    round           TEXT,
    best_of         INTEGER,
    score           TEXT,
    winner_rank     INTEGER,
    loser_rank      INTEGER
);

INSERT INTO matches (
    match_id, tourney_id, tourney_name, surface, tourney_date, match_num,
    winner_id, loser_id, round, best_of, score, winner_rank, loser_rank
)
SELECT
    tourney_id || '-' || match_num,
    tourney_id,
    tourney_name,
    surface,
    tourney_date,
    match_num,
    winner_id,
    loser_id,
    round,
    best_of,
    score,
    winner_rank,
    loser_rank
FROM matches_raw
WHERE tourney_date >= 20150101
  AND tourney_date <= 20251231;

CREATE TABLE rankings_weekly (
    ranking_date INTEGER NOT NULL,
    player_id    INTEGER NOT NULL,
    rank         INTEGER NOT NULL,
    points       INTEGER,
    PRIMARY KEY (ranking_date, player_id)
);

INSERT INTO rankings_weekly (ranking_date, player_id, rank, points)
SELECT ranking_date, player_id, ranking, ranking_points
FROM rankings_raw
WHERE ranking_date >= 20150101
  AND ranking_date <= 20251231;

-- One row per player per match (for win rate, streaks, rolling metrics)
CREATE TABLE player_match_results (
    match_id     TEXT NOT NULL,
    player_id    INTEGER NOT NULL,
    opponent_id  INTEGER NOT NULL,
    tourney_date INTEGER NOT NULL,
    surface      TEXT,
    is_win       INTEGER NOT NULL CHECK (is_win IN (0, 1)),
    PRIMARY KEY (match_id, player_id)
);

INSERT INTO player_match_results (match_id, player_id, opponent_id, tourney_date, surface, is_win)
SELECT match_id, winner_id, loser_id, tourney_date, surface, 1
FROM matches
UNION ALL
SELECT match_id, loser_id, winner_id, tourney_date, surface, 0
FROM matches;

CREATE INDEX idx_matches_date ON matches(tourney_date);
CREATE INDEX idx_matches_surface ON matches(surface);
CREATE INDEX idx_rankings_player_date ON rankings_weekly(player_id, ranking_date);
CREATE INDEX idx_pmr_player_date ON player_match_results(player_id, tourney_date);
