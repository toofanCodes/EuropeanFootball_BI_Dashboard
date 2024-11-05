/* 
by league and season calculate the number of total home wins
*/

	SELECT 
		l. name, 
		m.season, 
		COUNT(*) AS Home_team_wins
	FROM soccerDB.Match m
	JOIN
		League l ON l.country_id = m.country_id
	WHERE 
		home_team_goal > away_team_goal
	GROUP BY league_id, season
	ORDER BY league_id, season;

/* 
What if we want home wins and away wins
Conditional Aggregation - performed here
*/

	SELECT 
		l. name, 
		m.season, 
		COUNT(*) AS total_games,
		ROUND(COUNT(CASE WHEN home_team_goal > away_team_goal THEN 1 END)*100/COUNT(*),2) AS home_wins_percentage,
		ROUND(COUNT(CASE WHEN home_team_goal < away_team_goal THEN 1 END)*100/COUNT(*),2) AS away_wins_percentage
	FROM soccerDB.Match m
	JOIN
		League l ON l.country_id = m.country_id
	JOIN
		Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
	GROUP BY league_id, season
	ORDER BY league_id, season;

/* 
BY League by team - home vs away record (win %, and draw%)
Conditional Aggregation - performed here
*/

	SELECT 
		l.name,
		m.season,
		t.team_long_name,
		COUNT(DISTINCT m.match_api_id) AS total_games,
		ROUND(COUNT(CASE WHEN home_team_goal > away_team_goal THEN 1 END)*100/COUNT(*),2) AS home_wins_percentage,
		ROUND(COUNT(CASE WHEN home_team_goal < away_team_goal THEN 1 END)*100/COUNT(*),2) AS away_wins_percentage,
		ROUND(COUNT(CASE WHEN home_team_goal = away_team_goal THEN 1 END)*100/COUNT(*),2) AS draw_percentage
	FROM soccerDB.Match m
	JOIN
		League l ON l.country_id = m.country_id
	JOIN
		Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
	GROUP BY league_id, season, team_api_id
	ORDER BY league_id, season, team_api_id;


/* 
BY League by team - home team wins with goals higher than average home goals for the tournament
nested subqueries, Conditional Aggregation, 
Mathematical Calculations and Formatting, 
NULLIF for Handling Division by Zero, 
multiple JOIN's are used here
*/

	SELECT
		l.name,
		mt.season,
		t.team_long_name,
		COUNT(DISTINCT CASE WHEN mt.home_team_api_id = t.team_api_id THEN mt.match_api_id END) +
		COUNT(DISTINCT CASE WHEN mt.away_team_api_id = t.team_api_id THEN mt.match_api_id END) AS total_games,
		ROUND(COUNT(CASE WHEN (mt.home_team_api_id = t.team_api_id AND mt.home_team_goal > sub.avg_home) THEN 1 END)*100/NULLIF(COUNT(CASE WHEN mt.home_team_api_id = t.team_api_id THEN 1 END),0), 2) AS grt_avgHome_percentage,
		ROUND(COUNT(CASE WHEN (mt.away_team_api_id = t.team_api_id AND mt.away_team_goal > sub.avg_away) THEN 1 END)*100/NULLIF(COUNT(CASE WHEN mt.away_team_api_id = t.team_api_id THEN 1 END),0), 2) AS grt_avgAway_percentage
	FROM 
		soccerDB.Match mt
	JOIN
		League l ON l.country_id = mt.country_id
	JOIN
		Team t ON t.team_api_id IN (mt.home_team_api_id, mt.away_team_api_id)
	JOIN
		(SELECT 
			m.league_id,
			m.season,
			AVG(home_team_goal) AS avg_home,
			AVG(away_team_goal) AS avg_away
		FROM 
			soccerDB.Match m
		GROUP BY 
			m.league_id, m.season) sub ON sub.league_id = mt.league_id AND sub.season = mt.season 
		GROUP BY l.name, mt.season,mt.home_team_api_id
	ORDER BY grt_avgHome_percentage DESC;
		
/*  
let's use a CTE to reduce the complexity of the code in earlier query
*/

WITH leagueSeasonAverages AS (
	SELECT 
			m.league_id,
			m.season,
			AVG(home_team_goal) AS avg_home,
			AVG(away_team_goal) AS avg_away
		FROM 
			soccerDB.Match m
		GROUP BY 
			m.league_id, m.season
),
teamGameStats AS (
	SELECT
		l.name AS league_name,
		mt.season,
		t.team_long_name,
		COUNT(DISTINCT CASE WHEN mt.home_team_api_id = t.team_api_id THEN mt.match_api_id END) +
		COUNT(DISTINCT CASE WHEN mt.away_team_api_id = t.team_api_id THEN mt.match_api_id END) AS total_games,
		ROUND(COUNT(CASE WHEN (mt.home_team_api_id = t.team_api_id AND mt.home_team_goal > ls.avg_home) THEN 1 END)*100/NULLIF(COUNT(CASE WHEN mt.home_team_api_id = t.team_api_id THEN 1 END),0), 2) AS grt_avgHome_percentage,
		ROUND(COUNT(CASE WHEN (mt.away_team_api_id = t.team_api_id AND mt.away_team_goal > ls.avg_away) THEN 1 END)*100/NULLIF(COUNT(CASE WHEN mt.away_team_api_id = t.team_api_id THEN 1 END),0), 2) AS grt_avgAway_percentage
	FROM 
		soccerDB.Match mt
	JOIN
		League l ON l.country_id = mt.country_id
	JOIN
		Team t ON t.team_api_id IN (mt.home_team_api_id, mt.away_team_api_id)
	JOIN leagueSeasonAverages ls ON ls.league_id = mt.league_id AND ls.season = mt.season
    GROUP BY l.name, mt.season, t.team_long_name
)
SELECT 
	league_name,
    mt.season,
    t.team_long_name,
    total_games,
    grt_avgHome_percentage,
    grt_avgAway_percentage
FROM teamGameStats;

/*
Rank teams by their home goal performance by season, by league - using ROW_NUMBER() Window function
*/

WITH AvgGoals AS (
    SELECT 
        m.league_id,
        m.season,
        AVG(m.home_team_goal) AS avg_home,
        AVG(m.away_team_goal) AS avg_away
    FROM 
        soccerDB.Match m
    GROUP BY 
        m.league_id, m.season
)
SELECT
    l.name AS league_name,
    mt.season,
    t.team_long_name,
    
    -- Total games played by team (home + away)
    COUNT(DISTINCT CASE WHEN mt.home_team_api_id = t.team_api_id THEN mt.match_api_id END) +
    COUNT(DISTINCT CASE WHEN mt.away_team_api_id = t.team_api_id THEN mt.match_api_id END) AS total_games,
    
    -- Percentage of games where home goals exceed league average
    ROUND(COUNT(CASE WHEN (mt.home_team_api_id = t.team_api_id AND mt.home_team_goal > sub.avg_home) 
                     THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN mt.home_team_api_id = t.team_api_id THEN 1 END), 0), 2) AS grt_avgHome_percentage,
    
    -- Percentage of games where away goals exceed league average
    ROUND(COUNT(CASE WHEN (mt.away_team_api_id = t.team_api_id AND mt.away_team_goal > sub.avg_away) 
                     THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN mt.away_team_api_id = t.team_api_id THEN 1 END), 0), 2) AS grt_avgAway_percentage,

    -- Row number based on grt_avgHome_percentage within each league and season
    ROW_NUMBER() OVER (PARTITION BY l.name, mt.season ORDER BY ROUND(COUNT(CASE WHEN (mt.home_team_api_id = t.team_api_id AND mt.home_team_goal > sub.avg_home) 
                     THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN mt.home_team_api_id = t.team_api_id THEN 1 END), 0), 2) DESC) AS rank_by_home_perf
FROM 
    soccerDB.Match mt
JOIN
    League l ON l.country_id = mt.country_id
JOIN
    Team t ON t.team_api_id IN (mt.home_team_api_id, mt.away_team_api_id)
JOIN
    AvgGoals sub ON sub.league_id = mt.league_id AND sub.season = mt.season
GROUP BY 
    l.name, mt.season, t.team_long_name
ORDER BY 
    league_name, mt.season, rank_by_home_perf;

