-- =============================================================================
-- ATP Top-50 Analytics 2015-2025 — dashboard queries
-- Database: data/atp_tennis.db
-- All queries use Top-50 views (player reached rank <= 50 at least once)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Best players by surface — RANK()
-- Tableau: bar chart; filter surface_rank <= 10
-- Threshold: minimum 20 matches per surface (adjust in HAVING)
-- -----------------------------------------------------------------------------
WITH surface_stats AS (
    SELECT
        pmr.player_id,
        p.first_name,
        p.last_name,
        p.country,
        pmr.surface,
        SUM(pmr.is_win) AS wins,
        COUNT(*)        AS matches,
        ROUND(1.0 * SUM(pmr.is_win) / COUNT(*), 4) AS win_rate
    FROM v_player_match_results_top50 pmr
    JOIN players p ON p.player_id = pmr.player_id
    WHERE pmr.surface IS NOT NULL
      AND pmr.surface != ''
    GROUP BY pmr.player_id, p.first_name, p.last_name, p.country, pmr.surface
    HAVING COUNT(*) >= 20
)
SELECT
    player_id,
    first_name,
    last_name,
    country,
    surface,
    wins,
    matches,
    win_rate,
    RANK() OVER (
        PARTITION BY surface
        ORDER BY win_rate DESC, matches DESC
    ) AS surface_rank
FROM surface_stats
ORDER BY surface, surface_rank;


-- -----------------------------------------------------------------------------
-- 2) Player ranking over time — LAG()
-- Tableau: line chart — ranking_date (X), rank (Y, reverse axis)
-- Filter by player_name or player_id
-- rank_change > 0 means moved up (lower rank number is better)
-- -----------------------------------------------------------------------------
SELECT
    r.ranking_date,
    r.player_id,
    p.first_name || ' ' || p.last_name AS player_name,
    p.country,
    r.rank,
    r.points,
    LAG(r.rank) OVER (
        PARTITION BY r.player_id
        ORDER BY r.ranking_date
    ) AS prev_rank,
    LAG(r.points) OVER (
        PARTITION BY r.player_id
        ORDER BY r.ranking_date
    ) AS prev_points,
    LAG(r.rank) OVER (
        PARTITION BY r.player_id
        ORDER BY r.ranking_date
    ) - r.rank AS rank_change,
    r.rank - LAG(r.rank) OVER (
        PARTITION BY r.player_id
        ORDER BY r.ranking_date
    ) AS rank_delta_raw
FROM v_rankings_top50 r
JOIN players p ON p.player_id = r.player_id
ORDER BY r.player_id, r.ranking_date;


-- -----------------------------------------------------------------------------
-- 3) Win rate leaderboard — CTE
-- Tableau: horizontal bar, sort by win_rate
-- Threshold: minimum 50 matches in period (adjust in HAVING)
-- -----------------------------------------------------------------------------
WITH player_totals AS (
    SELECT
        player_id,
        SUM(is_win) AS wins,
        COUNT(*)    AS matches
    FROM v_player_match_results_top50
    GROUP BY player_id
    HAVING COUNT(*) >= 50
)
SELECT
    pt.player_id,
    p.first_name,
    p.last_name,
    p.country,
    pt.wins,
    pt.matches,
    pt.matches - pt.wins AS losses,
    ROUND(1.0 * pt.wins / pt.matches, 4) AS win_rate
FROM player_totals pt
JOIN players p ON p.player_id = pt.player_id
ORDER BY win_rate DESC, matches DESC;


-- -----------------------------------------------------------------------------
-- 4) Longest winning streak — window functions (gaps & islands)
-- Tableau: top-N bar chart or table
-- -----------------------------------------------------------------------------
WITH ordered AS (
    SELECT
        player_id,
        tourney_date,
        match_id,
        is_win,
        ROW_NUMBER() OVER (
            PARTITION BY player_id
            ORDER BY tourney_date, match_id
        ) AS rn_all,
        ROW_NUMBER() OVER (
            PARTITION BY player_id, is_win
            ORDER BY tourney_date, match_id
        ) AS rn_by_result
    FROM v_player_match_results_top50
),
win_islands AS (
    SELECT
        player_id,
        tourney_date,
        match_id,
        rn_all - rn_by_result AS island_id
    FROM ordered
    WHERE is_win = 1
),
streak_lengths AS (
    SELECT
        player_id,
        island_id,
        COUNT(*) AS streak_len,
        MIN(tourney_date) AS streak_start,
        MAX(tourney_date) AS streak_end
    FROM win_islands
    GROUP BY player_id, island_id
)
SELECT
    sl.player_id,
    p.first_name,
    p.last_name,
    p.country,
    MAX(sl.streak_len) AS longest_win_streak
FROM streak_lengths sl
JOIN players p ON p.player_id = sl.player_id
GROUP BY sl.player_id, p.first_name, p.last_name, p.country
ORDER BY longest_win_streak DESC;


-- -----------------------------------------------------------------------------
-- 5) Rolling 20-match win rate
-- Tableau: line chart — tourney_date vs rolling_win_rate_20
-- Filter window_matches >= 20 to hide partial window warmup
-- -----------------------------------------------------------------------------
SELECT
    pmr.player_id,
    p.first_name || ' ' || p.last_name AS player_name,
    pmr.tourney_date,
    pmr.match_id,
    pmr.surface,
    pmr.is_win,
    COUNT(*) OVER (
        PARTITION BY pmr.player_id
        ORDER BY pmr.tourney_date, pmr.match_id
        ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ) AS window_matches,
    ROUND(
        AVG(pmr.is_win) OVER (
            PARTITION BY pmr.player_id
            ORDER BY pmr.tourney_date, pmr.match_id
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ),
        4
    ) AS rolling_win_rate_20
FROM v_player_match_results_top50 pmr
JOIN players p ON p.player_id = pmr.player_id
ORDER BY pmr.player_id, pmr.tourney_date, pmr.match_id;
