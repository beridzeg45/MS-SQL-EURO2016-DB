-- CREATE VIEW TO SEE MATCH DETALS(HOME TEAM,AWAY TEAM, GOALS SCORED BY EACH, RESULT, DATE PLAYED ON,AVENUE PLAYED ON,AUDIENCE ATTENDEED)
DROP VIEW IF EXISTS VIEW_MATCHES_INFO;
GO
CREATE VIEW VIEW_MATCHES_INFO AS
WITH T1 AS
(
SELECT MD1.match_no,MD1.team_id AS TEAM1_ID, MD2.team_id AS TEAM2_ID, MD1.win_lose AS WIN_LOSE1,MD2.win_lose AS WIN_LOSE2,MD1.goal_score AS [TEAM1_GAOLS],MD2.goal_score AS [TEAM2_GAOLS]
FROM match_details MD1
JOIN match_details MD2 ON MD1.match_no=MD2.match_no
WHERE ((MD1.win_lose='W' AND MD2.win_lose='L') OR (MD1.win_lose='L' AND MD2.win_lose='W') OR (MD1.win_lose='D' AND MD2.win_lose='D')) AND MD1.team_id>MD2.team_id
)
,T2 AS
(
SELECT match_no,TEAM1_ID,SC1.country_name AS [TEAM1],TEAM2_ID,SC2.country_name AS [TEAM2],WIN_LOSE1 AS[TEAM1_RESULT],WIN_LOSE2 AS[TEAM2_RESULT],TEAM1_GAOLS,TEAM2_GAOLS
FROM T1
JOIN [Soccer Country] SC1 ON T1.TEAM1_ID=SC1.country_id
JOIN [Soccer Country] SC2 ON T1.TEAM2_ID=SC2.country_id
)
,T3 AS
(
SELECT T2.match_no,CAST(play_date AS DATE) AS [PLAY_DATE],venue_id,audence,TEAM1_ID,TEAM1,TEAM1_GAOLS,TEAM1_RESULT,TEAM2_ID,TEAM2,TEAM2_GAOLS,TEAM2_RESULT
FROM T2
JOIN match_MAST MM ON T2.match_no=MM.match_no)
SELECT ROW_NUMBER() OVER(ORDER BY MATCH_NO) AS ID,T3.*
FROM T3;
GO


--MOST REPRESENTED CLUBS ON EURO 2016
SELECT TOP 10 playing_club, COUNT(player_id) AS [NUMBER OF PLAYERS]
FROM player_mast
GROUP BY playing_club
ORDER BY [NUMBER OF PLAYERS] DESC;

--NUMBER OF MATCHES BY VENUE
WITH T1 AS
(
SELECT venue_id,COUNT(match_no) AS [COUNT OF MATCHES]
FROM match_mast
GROUP BY venue_id
)
SELECT T1.venue_id,venue_name,aud_capacity,[COUNT OF MATCHES]
FROM T1
JOIN soccer_venue SV ON T1.venue_id=SV.venue_id
ORDER BY [COUNT OF MATCHES] DESC;

--LIST PLAYERS, WHO SCORED THE MOST GOALS, AVG GOAL TIME AND OTHER RELEVANT INFORMATION
WITH T1 AS
(
SELECT player_id,COUNT(goal_id) AS [NUMBER OF GOALS], AVG(goal_time) AS [AVG GOAL TIME]
FROM goal_details GD
GROUP BY player_id
)
SELECT T1.player_id,player_name,country_name,posi_to_play,CAST(dt_of_bir AS DATE) AS [DATE OF BIRTH],[NUMBER OF GOALS],ROUND([AVG GOAL TIME],2) AS [AVG GOAL TIME(MIN)]
FROM T1
JOIN player_mast PM ON T1.player_id=PM.player_id
JOIN [Soccer Country] SC ON PM.team_id=SC.country_id
ORDER BY [NUMBER OF GOALS] DESC;

--NUMBER OF GOALS SCORED BY COUNTRY
SELECT country_name, COUNT(goal_id) AS [NUMBER OF GOALS]
FROM goal_details GD
JOIN [Soccer Country] SC ON GD.team_id=SC.country_id
GROUP BY country_name
ORDER BY [NUMBER OF GOALS] DESC;

--AVG TEAM AGE BY COUNTRY
SELECT country_name,ROUND(AVG(age),2)AS [AVG AGE]
FROM player_mast PM
JOIN [Soccer Country] SC ON PM.team_id=SC.country_id
GROUP BY country_name
ORDER BY [AVG AGE];

-- MOST FREQUENT SUBSTITUTIONS ON EURO 2016
WITH T1 AS
(
SELECT PIO1.ID AS ID1,PIO1.match_no AS MATCH_NO1,PIO1.player_id AS PLAYER_ID1,PIO1.in_out AS IN_OUT1,
PIO2.ID AS ID2,PIO2.match_no AS MATCH_NO2,PIO2.player_id AS PLAYER_ID2,PIO2.in_out AS IN_OUT2
FROM player_in_out PIO1
JOIN player_in_out PIO2 ON PIO1.match_no=PIO2.match_no AND PIO1.time_in_out=PIO2.time_in_out
WHERE PIO1.in_out<>PIO2.in_out AND PIO1.player_id>PIO2.player_id
)
,T2 AS
(
SELECT PLAYER_ID1,PLAYER_ID2,COUNT(ID1) AS [COUNT]
FROM T1
GROUP BY PLAYER_ID1,PLAYER_ID2
)
SELECT country_name,PM1.player_name AS PLAYER_1, PM2.player_name AS PLAYER_2, [COUNT]
FROM T2
JOIN player_mast PM1 ON T2.PLAYER_ID1=PM1.player_id
JOIN [Soccer Country] SC ON PM1.team_id=SC.country_id
JOIN player_mast PM2 ON T2.PLAYER_ID2=PM2.player_id
ORDER BY [COUNT] DESC;

--PLAYERS WHO SCORED GOALS AFTER SUBSTITUTION
WITH T1 AS
(
SELECT PIO.match_no, PIO.team_id,PIO.player_id,time_in_out,goal_time
FROM player_in_out PIO,goal_details GD
WHERE IN_OUT='I' AND PIO.match_no=GD.match_no AND PIO.player_id=GD.player_id
)
SELECT T1.match_no,country_name AS [TEAM],player_name,time_in_out AS [SUBSTITUTION TIME],goal_time,
IIF(country_name=TEAM1,TEAM2,TEAM1) AS [OPPONENT TEAM]
FROM T1
JOIN [Soccer Country] SC ON T1.team_id=SC.country_id
JOIN player_mast PM ON T1.player_id=PM.player_id
JOIN VIEW_MATCHES_INFO VMI ON T1.match_no=VMI.match_no;

--WHICH TEAM'S MATCHES HAD HIGHEST AVG VENUE FILL RATE ON EURO 2016
WITH T1 AS
(
SELECT match_no,TEAM1,TEAM2,VMI.venue_id,venue_name,audence,aud_capacity,CAST(audence AS FLOAT)/aud_capacity AS [VENUE FILL PERCENTAGE]
FROM VIEW_MATCHES_INFO VMI
JOIN soccer_venue SV ON VMI.venue_id=SV.venue_id
)
,T2 AS
(
SELECT match_no,TEAM1,TEAM2,venue_id,venue_name,audence,aud_capacity,[VENUE FILL PERCENTAGE]
FROM T1
UNION ALL
SELECT match_no,TEAM2,TEAM1,venue_id,venue_name,audence,aud_capacity,[VENUE FILL PERCENTAGE]
FROM T1
)SELECT TEAM1,FORMAT(AVG([VENUE FILL PERCENTAGE]),'P2') AS [AVG VENUE FILL PERCENTAGE]
FROM T2
GROUP BY TEAM1
ORDER BY [AVG VENUE FILL PERCENTAGE] DESC;

--TEAMS WITH THE MOST BOOKINGS PER MATCH
WITH T1 AS
(
SELECT team_id,COUNT(ID) AS [TOTAL BOOKINGS]
FROM player_booked PB
GROUP BY team_id
)
,T2 AS
(
SELECT team_id, COUNT(DISTINCT match_no) AS [TOTAL MATCHES]
FROM match_details
GROUP BY team_id
)
SELECT T1.team_id,country_name AS [TEAM],[TOTAL BOOKINGS],[TOTAL MATCHES],ROUND(CAST([TOTAL BOOKINGS] AS FLOAT)/[TOTAL MATCHES],2) AS [AVG BOOKING PER MATCH]
FROM T1
JOIN T2 ON T1.team_id=T2.team_id
JOIN [Soccer Country] SC ON T1.team_id=SC.country_id
ORDER BY [AVG BOOKING PER MATCH] DESC;

--PLAYERS WITH MOST BOOKINGS
SELECT player_name,COUNT(PB.ID) AS [TOTAL BOOKINGS]
FROM player_booked PB
JOIN player_mast PM ON PB.player_id=PM.player_id
GROUP BY player_name
ORDER BY [TOTAL BOOKINGS] DESC;

--PLAYING POSITIONS WITH THE MOST BOOKINGS
WITH T1 AS
(
SELECT posi_to_play,COUNT(PB.ID) AS [TOTAL BOOKINGS]
FROM player_booked PB
JOIN player_mast PM ON PB.player_id=PM.player_id
GROUP BY posi_to_play
)
SELECT posi_to_play,[TOTAL BOOKINGS],FORMAT(CAST([TOTAL BOOKINGS] AS FLOAT)/(SELECT SUM([TOTAL BOOKINGS]) FROM T1),'P2') AS [PERCENTAGE],
FORMAT(CAST(SUM([TOTAL BOOKINGS]) OVER(ORDER BY [TOTAL BOOKINGS] DESC) AS FLOAT)/(SELECT SUM([TOTAL BOOKINGS]) FROM T1),'P2') AS [CUMULATIVE PCT]
FROM T1
ORDER BY [TOTAL BOOKINGS] DESC;


--MATCH TIME PERIODS WITH THE MOST BOOKINGS
WITH T1 AS
(
SELECT PB.*,
CASE
WHEN booking_time BETWEEN 0 AND 15 THEN '0-15'
WHEN booking_time BETWEEN 15 AND 30 THEN '15-30'
WHEN booking_time BETWEEN 30 AND 45 THEN '30-45'
WHEN booking_time BETWEEN 45 AND 60 THEN '45-60'
WHEN booking_time BETWEEN 60 AND 75 THEN '60-75'
WHEN booking_time BETWEEN 75 AND 199 THEN '75+'
ELSE NULL
END AS [TIME PERIOD]
FROM player_booked PB
)
SELECT [TIME PERIOD],COUNT(ID) AS [TOTAL BOOKINGS], FORMAT(CAST(COUNT(ID) AS FLOAT)/(SELECT COUNT(ID) FROM T1),'P2') AS [PERCENTAGE]
FROM T1
GROUP BY [TIME PERIOD];

--MATCHES WITH MOST MOST BOOKINGS
WITH T1 AS
(
SELECT match_no,COUNT(ID) AS [TOTAL BOOKINGS]
FROM player_booked PB
GROUP BY match_no
)
SELECT T1.match_no,TEAM1,TEAM2, [TOTAL BOOKINGS]
FROM T1
JOIN VIEW_MATCHES_INFO VMI ON T1.match_no=VMI.match_no
ORDER BY [TOTAL BOOKINGS] DESC;

WITH T1 AS
(
SELECT player_id,SUM(goal_time) AS [TOTAL TIME],COUNT(goal_id) AS [TOTAL GOALS],CAST(SUM(goal_time) AS FLOAT)/COUNT(goal_id) AS [AVG TIME]
--PLAYERS WHO NEEDED THE LEAST TIME TO SCORE GOAL,HAVING THEY SCORED MORE THAN 1 GOAL
FROM goal_details GD
GROUP BY player_id
)
SELECT T1.player_id,player_name,country_name,[TOTAL TIME],[TOTAL GOALS],[AVG TIME]
FROM T1,player_mast PM,[Soccer Country] SC
WHERE [TOTAL GOALS]>1 AND T1.player_id=PM.player_id AND PM.team_id=SC.country_id
ORDER BY [AVG TIME];

--WHO ARE THE PLAYERS WHO SCORED AND MISSED PENALTY IN IN PENALTY SHOOTOUTS DURING THE TOURNAMENT
WITH T1 AS
(
SELECT player_id,COUNT(kick_id) AS [TOTAL SCORED]
FROM penalty_shootout PS
WHERE score_goal='Y'
GROUP BY player_id
)
,T2 AS
(
SELECT player_id,COUNT(kick_id) AS [TOTAL MISSED]
FROM penalty_shootout PS
WHERE score_goal='N'
GROUP BY player_id
)
SELECT DISTINCT PS.player_id,player_name,[TOTAL SCORED],[TOTAL MISSED]
FROM penalty_shootout PS
JOIN T1 ON PS.player_id=T1.player_id
JOIN T2 ON PS.player_id=T2.player_id
JOIN player_mast PM ON PS.player_id=PM.player_id
WHERE [TOTAL SCORED] IS NOT NULL AND [TOTAL MISSED] IS NOT NULL;

--REFEREES WITH HIGHEST NUMBER OF BOOKINGS
WITH T1 AS
(
SELECT referee_id,COUNT(PB.ID) AS [TOTAL BOOKINGS], COUNT(DISTINCT PB.match_no) AS [TOTAL MATCHES]
FROM player_booked PB
JOIN match_mast MM ON PB.match_no=MM.match_no
GROUP BY referee_id
)
SELECT T1.referee_id,referee_name,country_name,[TOTAL BOOKINGS],[TOTAL MATCHES],ROUND(CAST([TOTAL BOOKINGS] AS FLOAT)/[TOTAL MATCHES],2) AS [AVG BOOKING PER MATCH]
FROM T1
JOIN referee_mast RM ON T1.referee_id=RM.referee_id
JOIN [Soccer Country] SC ON RM.country_id=SC.country_id
ORDER BY [AVG BOOKING PER MATCH] DESC;