-- Top-50 players at least once in 2015–2025 (MVP scope for Tableau)

DROP VIEW IF EXISTS v_top50_players;
CREATE VIEW v_top50_players AS
SELECT DISTINCT
    r.player_id,
    p.first_name,
    p.last_name,
    p.country
FROM rankings_weekly r
JOIN players p ON p.player_id = r.player_id
WHERE r.rank <= 50;

DROP VIEW IF EXISTS v_matches_top50;
CREATE VIEW v_matches_top50 AS
SELECT m.*
FROM matches m
WHERE m.winner_id IN (SELECT player_id FROM v_top50_players)
   OR m.loser_id IN (SELECT player_id FROM v_top50_players);

DROP VIEW IF EXISTS v_player_match_results_top50;
CREATE VIEW v_player_match_results_top50 AS
SELECT pmr.*
FROM player_match_results pmr
WHERE pmr.player_id IN (SELECT player_id FROM v_top50_players);

DROP VIEW IF EXISTS v_rankings_top50;
CREATE VIEW v_rankings_top50 AS
SELECT r.*
FROM rankings_weekly r
WHERE r.player_id IN (SELECT player_id FROM v_top50_players);
