/*
Title: Project 2 Chicago 311 Queries
Date: December 2023
By: Sean Xu
*/

-- This query returns the total number of unique tickets from the 3 tables (2018, 2019, and 2020).
-- There are a total of 2.8M unique rows in this dataset.

SELECT count(distinct request_id) AS n_tickets
FROM ( SELECT request_id
      FROM public.chicago_311_2020
       UNION 
       -- combining the 3 tables together into one.
      SELECT request_id
      FROM public.chicago_311_2019
       UNION
      SELECT request_id
      FROM public.chicago_311_2018
     ) AS temp;

-- This query returns unique values in relevant fields including category, agency, community area, and status.
-- There are 96 categories, 13 agencies, 77 communities, and 3 statuses.

SELECT distinct category
FROM public.chicago_311_2019
ORDER BY 1 ASC;

SELECT distinct responsibleagency
FROM public.chicago_311_2019
ORDER BY 1 ASC;

SELECT distinct community_area
FROM public.chicago_311_2019
ORDER BY 1 ASC;

SELECT distinct status
FROM public.chicago_311_2019;

-- This query returns the earliest and the latest created dates of tickets.
-- The first ticket and the last ticket were created on 1 July 2018 and 22 April 2020. 
-- We shouldn't aggregate by year as the data for 2018 and 2020 are not completed (not the whole year).

SELECT 
  min(date)AS earliest_date
  , max(date) AS latest_date
FROM (SELECT cast(created_date AS date) AS date
      -- convert from timestamp to date for simplicity. 
      FROM public.chicago_311_2020
       UNION
      SELECT cast(created_date AS date) AS date
      FROM public.chicago_311_2019
       UNION
      SELECT cast(created_date AS date) AS date
      FROM public.chicago_311_2018
     ) AS temp;

-- These queries identify duplicate rows in each data table. 
-- There is no duplicate found in the 3 tables.

SELECT 
   request_id
   , category
   , count(*)
FROM public.chicago_311_2020
GROUP BY 1, 2 
   -- By grouping data on id and category columns, duplicate rows would have 2 or more counts.
HAVING count(*) > 1;

SELECT 
   request_id
   , category
   , count(*)
FROM public.chicago_311_2019
GROUP BY 1, 2
HAVING count(*) > 1;

SELECT 
   request_id
   , category
   , count(*)
FROM public.chicago_311_2018
GROUP BY 1, 2
HAVING count(*) > 1;

-- This query returns the highest and the lowest time to close the ticket in the datasets.
-- The maximum is 1 years 9 months and the minimum is -12 hours. 
-- There are some wrong inputs which created date is after closed date, causing negative results.
-- We need to exclude negative ones with WHERE clause in any close time related queries.

SELECT 
  min(closed_date - created_date) AS min_close_time
  , max(closed_date - created_date) AS max_close_time
FROM (SELECT request_id, closed_date, created_date
       FROM public.chicago_311_2020
       UNION
       SELECT request_id, closed_date, created_date
       FROM public.chicago_311_2019
       UNION
       SELECT request_id, closed_date, created_date
       FROM public.chicago_311_2018
     ) AS temp
WHERE closed_date is not null;

---- Deep dive into Department of Streets and Sanitation or DSS.

-- This query returns the total ticket counts by responsible agency.
-- DSS ranks 2nd with 750k tickets, behind only 311 City Services ifself.

SELECT
  responsibleagency
  , count(distinct request_id) as n_tickets
FROM (SELECT
        responsibleagency 
        , request_id
      FROM public.chicago_311_2020
       UNION
      SELECT
        responsibleagency
        , request_id
      FROM public.chicago_311_2019 
       UNION
      SELECT
        responsibleagency
        , request_id
      FROM public.chicago_311_2018
     ) AS temp
GROUP BY 1
ORDER BY 2 DESC;

-- This query returns the average time to close by agency.
-- DSS ranks 7th with an average of 23 days to close a ticket.

SELECT
  responsibleagency
  , extract('day' from avg(closed_date - created_date)) AS avg_days_to_close
  -- We can find average close time with AVG() and '-' and then extract days out of the result. 
FROM (SELECT request_id, responsibleagency, closed_date, created_date
      FROM public.chicago_311_2020
        UNION
      SELECT request_id, responsibleagency, closed_date, created_date
      FROM public.chicago_311_2019
       UNION
      SELECT request_id, responsibleagency, closed_date, created_date
      FROM public.chicago_311_2018
     ) AS temp
WHERE closed_date is not null
    -- Exclude rows with null in closed date column. 
    AND closed_date > created_date
    -- Exclude rows which created date is after closed date.
GROUP BY 1
ORDER BY 2 DESC;

-- [DSS] This query returns DSS’s total ticket counts for each category.
-- Top 5 are Graffiti Removal, Weed Removal, Garbage Cart, Rodent/Rat, and Tree Trim. 

SELECT
  responsibleagency
  , category
  , count(distinct request_id) AS ticket_count
FROM (
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2020
     WHERE responsibleagency = 'Streets and Sanitation')
     -- Filter for only 1 targeted agency which is DSS. 
      UNION
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2019
     WHERE responsibleagency = 'Streets and Sanitation')
      UNION
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2018
     WHERE responsibleagency = 'Streets and Sanitation')
     ) AS temp
GROUP BY 1, 2
ORDER BY 3 DESC;

-- [DSS] This query returns DSS’s average time to close for each category.
-- Top 5 are Tree Planting, Tree Trim, Tree Removal, Garbage Cart, and Abandoned Vehicle.

SELECT
  responsibleagency
  , category
  , extract('day' from AVG(closed_date - created_date)) AS avg_days_to_close
FROM (  
      (SELECT 
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation')
        UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation')
         UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation')
      ) AS temptable
WHERE closed_date is not null
     AND closed_date > created_date
GROUP BY 1, 2
ORDER BY 3 DESC;

-- [DSS] These subqueries and main query returns the categories that rank top 10 by both ticket volume and close time.
-- We can INNER JOIN top 10 categories by volume and top 10 categories by close time together to get categories that appear in both lists.
-- There are 5 categories that appear in both lists out of 23 categories.

WITH top_cats_volume 
AS (SELECT category, count(distinct request_id) AS ticket_count
  -- This is our first subquery for top 10 categories by ticket count.
FROM (
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2020
     WHERE responsibleagency = 'Streets and Sanitation')
      UNION
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2019
     WHERE responsibleagency = 'Streets and Sanitation')
      UNION
    (SELECT request_id, responsibleagency, category
     FROM public.chicago_311_2018
     WHERE responsibleagency = 'Streets and Sanitation')
     ) AS temp
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10)

, top_cats_closetime
AS (SELECT category, extract('day' from AVG(closed_date - created_date)) AS avg_days_to_close
  -- This is our second subquery for top 10 categories by ticket count.
FROM (  
      (SELECT 
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation')
        UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation')
         UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation')
      ) AS temptable
WHERE closed_date is not null
     AND closed_date > created_date
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10)

SELECT top_cats_volume.category
   -- this is the main query to INNER JOIN both lists.
FROM top_cats_volume
JOIN top_cats_closetime
ON top_cats_volume.category = top_cats_closetime.category
   -- the common value in both tables is category.
   
-- [DSS] This query returns DSS’s overall average close time without Tree Planting, Tree Trim, and Tree Removal tickets.
-- At this point we want to focus on the 3 categories as they have both high volume and close time.
-- The overall average drops from 25 days to just 8 days.

SELECT
  responsibleagency
  , extract('day' from AVG(closed_date - created_date)) AS avg_days_to_close
FROM (  
      (SELECT 
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation')
        UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation')
         UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation')
      ) AS temp
WHERE closed_date is not null
     AND closed_date > created_date
     AND category not in ('Tree Trim Request', 'Tree Planting Request', 'Tree Removal Request')
     -- Exclude rows within these 3 categories.
GROUP BY 1;

-- [DSS] This query returns the average close time for Tree Planting, Tree Trim, and Tree Removal tickets.
-- Average close time for the 3 cateogories is 125 days

SELECT
  responsibleagency
  , extract('day' from AVG(closed_date - created_date)) AS avg_days_to_close
FROM (  
      (SELECT 
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation')
        UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation')
         UNION
       (SELECT
          request_id
          , responsibleagency
          , category
          , closed_date
          , created_date
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation')
      ) AS temp
WHERE closed_date is not null
     AND closed_date > created_date
     AND category in ('Tree Trim Request', 'Tree Planting Request', 'Tree Removal Request')
     -- Only include rows in these 3 cateogories.
GROUP BY 1;

-- [DSS] Thie query returns the number of tickets by community area broken down by the 3 focused categories.
-- The table will be used to build a pivot table in excel for visualization.

SELECT
  community_area
  , category
  , count(request_id) AS n_tickets
FROM (  
      (SELECT request_id, community_area, category
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
        UNION
       (SELECT request_id, community_area, category
        FROM public.chicago_311_2019
        WHERE responsibleagency = 'Streets and Sanitation'
             AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
        UNION
       (SELECT request_id, community_area, category
        FROM public.chicago_311_2018
        WHERE responsibleagency = 'Streets and Sanitation'
             AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
      ) AS temp
WHERE community_area is not null
GROUP BY 1, 2
ORDER BY 1, 2;

-- [DSS] Time to close by community area breakdown by the 3 focused categories
-- This table will be used to build a pivot table in excel for visualization.

SELECT
  community_area
  , category
  , extract('day' from avg(closed_date - created_date)) avg_days_to_close
FROM (  
      (SELECT request_id, community_area, category, created_date, closed_date
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
        UNION
      (SELECT request_id, community_area, category, created_date, closed_date
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
        UNION
      (SELECT request_id, community_area, category, created_date, closed_date
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request'))
      ) AS temp
WHERE community_area is not null
      AND closed_date > created_date
GROUP BY 1, 2
ORDER BY 1, 2;

-- [DSS] This query shows tbe distribution of close time for the 3 focused categories based on predefined bins.

---- Distribution of close time for Tree Trim Request.
SELECT
  CASE WHEN (days_to_close) < 14  THEN 'Group A: Within 1 week'
       WHEN (days_to_close) between 14 and 29 THEN 'Group B: 1-4 weeks'
       WHEN (days_to_close) between 30 and 59 THEN 'Group C: 1-2 months'
       WHEN (days_to_close) between 60 and 89 THEN 'Group D: 2-3 months'
       WHEN (days_to_close) >= 90 THEN 'Group E: More than 3 months'
       END AS distribution
       -- Categorize data into 5 groups based on days range.
  , count(request_id)
FROM (  
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
      ) AS temp
WHERE category = 'Tree Trim Request'
    -- Filter for only data in Tree Trim Request category
GROUP BY 1
ORDER BY 1;

---- Distribution of close time for Tree Removal Request.
SELECT
  CASE WHEN (days_to_close) < 14  THEN 'Group A: Within 1 week'
       WHEN (days_to_close) between 14 and 29 THEN 'Group B: 1-4 weeks'
       WHEN (days_to_close) between 30 and 59 THEN 'Group C: 1-2 months'
       WHEN (days_to_close) between 60 and 89 THEN 'Group D: 2-3 months'
       WHEN (days_to_close) >= 90 THEN 'Group E: More than 3 months'
       END AS distribution
  , count(request_id)
FROM (  
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
      ) AS temp
WHERE category = 'Tree Removal Request'
GROUP BY 1
ORDER BY 1;

---- Distribution of close time for Garbage Cart Maintenance.
SELECT
  CASE WHEN (days_to_close) < 14  THEN 'Group A: Within 1 week'
       WHEN (days_to_close) between 14 and 29 THEN 'Group B: 1-4 weeks'
       WHEN (days_to_close) between 30 and 59 THEN 'Group C: 1-2 months'
       WHEN (days_to_close) between 60 and 89 THEN 'Group D: 2-3 months'
       WHEN (days_to_close) >= 90 THEN 'Group E: More than 3 months'
       END AS distribution
  , count(request_id)
FROM (  
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2020
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2019
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
        UNION
      (SELECT 
           request_id
           , category
           , extract('day' from closed_date - created_date) as days_to_close
       FROM public.chicago_311_2018
       WHERE responsibleagency = 'Streets and Sanitation'
          AND category in ('Tree Trim Request', 'Garbage Cart Maintenance', 'Tree Removal Request')
          AND extract('day' from closed_date - created_date) >= 0)
      ) AS temp
WHERE category = 'Garbage’ Cart Maintenance'
GROUP BY 1
ORDER BY 1;

-- These queries allow for cross checking with NYC data by comparing average close time of similar categories.
-- Around 20-60 days for tree removal related and 1-3 days for garbage cart related.

SELECT 
  distinct category
  , avg(age(closed_date, created_date))
FROM public.nyc_311_2019
GROUP BY 1
HAVING category IN ('Tree Alive - in Poor Condition', 
                    'Dead Branches in Tree', 'Tree Trunk Split'
                    'Tree Leaning/Uprooted', 'Entire Tree Has Fallen Down')
      -- Include a few categories that are mostly related to DSS's tree trim and tree removal services.
ORDER BY 2 DESC

SELECT 
  distinct category
  , avg(age(closed_date, created_date))
FROM public.nyc_311_2019
GROUP BY 1
HAVING category ILIKE '%litter basket%'
     -- Include only litter basket related data.
ORDER BY 2 DESC;

-- End of the note.