drop table if exists League_Team;
	
-- temp table league - teams	
CREATE TABLE League_Team AS
SELECT 
    DISTINCT m.league_id,
    L.name,
    m.home_team_api_id AS team_id,
    t.team_long_name
FROM soccerDB.Match m
JOIN Team t ON t.team_api_id = m.home_team_api_id
JOIN League L ON L.country_id = m.country_id;


select * from League_Team;

-- League Stats
SELECT
    lt.league_id,
    lt.name,
    ROUND(AVG(ta.buildUpPlaySpeed), 2) AS avg_buildUpPlaySpeed,
    ROUND(AVG(ta.buildUpPlayDribbling), 2) AS avg_buildUpPlayDribbling,
    ROUND(AVG(ta.buildUpPlayPassing), 2) AS avg_buildUpPlayPassing,
    ROUND(AVG(ta.chanceCreationPassing), 2) AS avg_chanceCreationPassing,
    ROUND(AVG(ta.chanceCreationCrossing), 2) AS avg_chanceCreationCrossing,
    ROUND(AVG(ta.chanceCreationShooting), 2) AS avg_chanceCreationShooting,
    ROUND(AVG(ta.defencePressure), 2) AS avg_defencePressure,
    ROUND(AVG(ta.defenceAggression), 2) AS avg_defenceAggression,
    ROUND(AVG(ta.defenceTeamWidth), 2) AS avg_defenceTeamWidth
FROM 
    Team_Attributes ta 
JOIN
	Team tm ON tm.team_api_id = ta.team_api_id
JOIN 
    League_Team lt ON lt.team_id = ta.team_api_id 
GROUP BY 
    lt.league_id;


-- Team Stats
SELECT 
	ta.team_api_id,
	lt.league_id,
    lt.name,
    team_long_name,
	ROUND(AVG(ta.buildUpPlaySpeed), 2) AS avg_buildUpPlaySpeed,
    ROUND(AVG(ta.buildUpPlayDribbling), 2) AS avg_buildUpPlayDribbling,
    ROUND(AVG(ta.buildUpPlayPassing), 2) AS avg_buildUpPlayPassing,
    ROUND(AVG(ta.chanceCreationPassing), 2) AS avg_chanceCreationPassing,
    ROUND(AVG(ta.chanceCreationCrossing), 2) AS avg_chanceCreationCrossing,
    ROUND(AVG(ta.chanceCreationShooting), 2) AS avg_chanceCreationShooting,
    ROUND(AVG(ta.defencePressure), 2) AS avg_defencePressure,
    ROUND(AVG(ta.defenceAggression), 2) AS avg_defenceAggression,
    ROUND(AVG(ta.defenceTeamWidth), 2) AS avg_defenceTeamWidth
FROM 	
	Team_Attributes ta 
JOIN League_Team lt on lt.team_id = ta.team_api_id 
GROUP BY lt.league_id, team_api_id;


-- home and away team goals
SELECT 
    h.league_id,
    h.season,
    h.home_team_api_id AS team_api_id,
    h.team_long_name,
    h.avg_home_goals_team,
    h.avg_home_goals_league,
    a.avg_away_goals_team,
    a.avg_away_goals_league
FROM 
    ( -- Subquery for home goals
        SELECT 
            m.league_id,
            m.home_team_api_id,
            m.season,
            t.team_long_name, 
            ROUND(AVG(m.home_team_goal), 2) AS avg_home_goals_team,
            ROUND(AVG(m.home_team_goal) OVER (PARTITION BY m.league_id, m.season), 2) AS avg_home_goals_league
        FROM 
            soccerDB.Match m
        LEFT JOIN 
            Team t ON m.home_team_api_id = t.team_api_id
        GROUP BY 
            m.league_id, m.season, m.home_team_api_id
    ) h
JOIN 
    ( -- Subquery for away goals
        SELECT 
            m.league_id,
            m.away_team_api_id,
            m.season,
            t.team_long_name, 
            ROUND(AVG(m.away_team_goal), 2) AS avg_away_goals_team,
            ROUND(AVG(m.away_team_goal) OVER (PARTITION BY m.league_id, m.season), 2) AS avg_away_goals_league
        FROM 
            soccerDB.Match m
        LEFT JOIN 
            Team t ON m.away_team_api_id = t.team_api_id
        GROUP BY 
            m.league_id, m.season, m.away_team_api_id
    ) a 
ON 
    h.league_id = a.league_id 
    AND h.season = a.season
    AND h.home_team_api_id = a.away_team_api_id;

-- top 5 players
WITH PlayerAverages AS (
    SELECT 
        m.league_id,
        CASE 
            WHEN pa.player_api_id IN (m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, 
                                      m.home_player_5, m.home_player_6, m.home_player_7, m.home_player_8, 
                                      m.home_player_9, m.home_player_10, m.home_player_11) 
            THEN m.home_team_api_id
            ELSE m.away_team_api_id
        END AS team_id,
        pa.player_api_id,
        ROUND(MAX(pa.overall_rating), 2) AS max_rating
    FROM Player_Attributes pa 
    JOIN soccerDB.Match m ON pa.player_api_id IN (m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, 
                                           m.home_player_5, m.home_player_6, m.home_player_7, m.home_player_8, 
                                           m.home_player_9, m.home_player_10, m.home_player_11, m.away_player_1, 
                                           m.away_player_2, m.away_player_3, m.away_player_4, m.away_player_5, 
                                           m.away_player_6, m.away_player_7, m.away_player_8, m.away_player_9, 
                                           m.away_player_10, m.away_player_11)
    GROUP BY m.league_id, team_id, pa.player_api_id
)

, Top5Players AS (
    SELECT 
        league_id,
        team_id,
        player_api_id,
        max_rating,
        RANK() OVER (PARTITION BY league_id, team_id ORDER BY max_rating DESC) AS ranking
    FROM PlayerAverages
)

SELECT 
    t5.league_id,
    t5.team_id,
    t5.player_api_id,
    pl.player_name,
    t5.max_rating,
    ROUND(MAX(pa.finishing), 2) AS max_finishing,
    ROUND(MAX(pa.acceleration), 2) AS max_acceleration,
    ROUND(MAX(pa.interceptions), 2) AS max_interceptions,
    ROUND(MAX(pa.marking), 2) AS max_marking,
    ROUND(MAX(pa.positioning), 2) AS max_positioning
FROM Top5Players t5
JOIN Player_Attributes pa ON t5.player_api_id = pa.player_api_id
JOIN Player pl ON t5.player_api_id = pl.player_api_id
WHERE t5.ranking <= 5
GROUP BY t5.league_id, t5.team_id, t5.player_api_id
ORDER BY t5.team_id, pl.player_name;

