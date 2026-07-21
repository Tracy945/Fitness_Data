/* =====================================
   DATA TRANSFORMATION
===================================== */

-- 1. Convert date/time columns from text format to appropriate DATE/TIMESTAMP data types
--    to enable accurate filtering, aggregation, and time-based analysis.

ALTER TABLE may_data."dailyActivity" 
ALTER COLUMN "ActivityDate" TYPE DATE
USING to_date("ActivityDate", 'MM/DD/YYYY')

ALTER TABLE may_data."weightLog" 
ALTER COLUMN "Date" TYPE TIMESTAMP 
USING to_timestamp("Date", 'MM/DD/YYYY HH12:MI:SS AM');

-- 2. Aggregate minute-level sleep records into daily-level summaries.
--    Sleep data from March and April is recorded by minute. 
--    This transformation calculates total minutes asleep and total time in bed per user per day.

CREATE TABLE april_data."dailySleep" AS
SELECT "Id", DATE("date") AS "SleepDay", 
	SUM(CASE WHEN "value" = 1 THEN 1 ELSE 0 END) AS "TotalMinutesAsleep", 
	COUNT("value") AS "TotalTimeInBed"
FROM april_data."minuteSleep"
GROUP BY "Id", DATE("date")
ORDER BY "Id", DATE("date")

-- 3. Combine activity data & sleep data from April to May into consolidated tables. 
--    Store the merged datasets in the public schema for further analysis.

CREATE TABLE public."all-dailySleep" AS
SELECT *
FROM april_data."dailySleep"
UNION ALL  
SELECT "Id", "SleepDay", "TotalMinutesAsleep", "TotalTimeInBed" 
FROM may_data."dailySleep"
ORDER BY "Id", "SleepDay"

CREATE TABLE public."all-dailyActivity" AS
SELECT *
FROM april_data."dailyActivity" 
UNION ALL  
SELECT * 
FROM may_data."dailyActivity"
ORDER BY "id", "ActivityDate"

-- 4. Join daily activity and sleep data by user ID and date. 
--    Sleep records are shifted by one day to align overnight sleep data 
--    with the corresponding daytime activity records.

CREATE TABLE public."all-dailyA&S" AS
SELECT *
FROM public."all-dailyActivity" AS a
INNER JOIN
(
    SELECT 
        "Id", 
        "SleepDay", 
        "TotalMinutesAsleep", 
        "TotalTimeInBed", 
        "SleepDay" - INTERVAL '1 day' AS "beforeday"
    FROM public."all-dailySleep"
) AS s
ON a."id" = s."Id"           
AND a."ActivityDate" = s."beforeday";