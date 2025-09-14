-- Create a temporary result set (CTE) for ratings
WITH ratings AS (
    SELECT 
        course_id,
        COUNT(student_id) AS number_of_ratings,   -- Count how many students rated the course
        ROUND(AVG(course_rating), 2) AS average_rating  -- Average rating (rounded to 2 decimals)
    FROM
        365_course_ratings
    GROUP BY course_id
),

-- Create a temporary result set (CTE) for minutes watched
minutes AS (
    SELECT 
        course_id,
        ROUND(SUM(minutes_watched), 2) AS total_minutes_watched,  -- Total minutes watched for the course
        ROUND(AVG(minutes_watched), 2) AS average_minutes         -- Average minutes watched per student
    FROM
        365_student_learning
    GROUP BY course_id
)

-- Final query: combine course info with ratings and minutes data
SELECT 
    c.course_id,                 -- Unique identifier for the course
    c.course_title,              -- Title of the course
    m.total_minutes_watched,     -- From "minutes" CTE: total time spent
    m.average_minutes,           -- From "minutes" CTE: average time per student
    r.number_of_ratings,         -- From "ratings" CTE: how many students rated
    r.average_rating             -- From "ratings" CTE: average rating score
FROM
    365_course_info c
    JOIN minutes m ON c.course_id = m.course_id
    JOIN ratings r ON c.course_id = r.course_id;

-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------
-- To avoid conflicts if the view was already created
DROP VIEW IF EXISTS purchases_info;

-- Create a reusable view called "purchases_info"
CREATE VIEW purchases_info AS
    SELECT 
        DISTINCT purchase_id,            -- Ensure each purchase_id appears only once
        student_id,                      -- The student who made the purchase
        purchase_type,                   -- Type of subscription purchased (Annual, Quarterly, Monthly)
        date_purchased AS date_start,    -- Start date of the subscription

        -- Calculate subscription end date depending on type:
        CASE
            WHEN purchase_type = 'Annual' THEN date_purchased + INTERVAL 1 YEAR
            WHEN purchase_type = 'Quarterly' THEN date_purchased + INTERVAL 3 MONTH
            WHEN purchase_type = 'Monthly' THEN date_purchased + INTERVAL 1 MONTH
        END AS date_end

    FROM
        365_student_purchases;           -- Source table containing raw purchase info

-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------

-- Avoiding conflicts if the view was already created
DROP VIEW IF EXISTS full_student_info;

-- Create a new view called "full_student_info"
CREATE VIEW full_student_info AS
WITH daily_minutes AS (
    -- Aggregate minutes watched per student per day
    SELECT 
        student_id,
        date_watched,
        SUM(minutes_watched) AS minutes_watched
    FROM
        365_student_learning
    GROUP BY student_id, date_watched
)

-- Main SELECT to define the view
SELECT 
    DISTINCT si.student_id,             -- Ensure unique student IDs in output
    si.student_country,                 -- Student’s country (from info table)
    si.date_registered,                 -- Date when the student registered
    dm.date_watched,                    -- Date when student watched something (NULL if no activity)
    dm.minutes_watched,                 -- Total minutes watched that day

    -- Onboarding is 1 if student has any record in learning table, else 0
    CASE
        WHEN si.student_id IN (
            SELECT student_id
            FROM 365_student_learning
        ) THEN 1
        ELSE 0
    END AS onboarded,

    -- Paid is 1 if date_watched is within the subscription start & end range, else 0
    CASE
        WHEN dm.date_watched >= pi.date_start
             AND dm.date_watched <= pi.date_end
        THEN 1
        ELSE 0
    END AS 'paid'

FROM
    365_student_info si
    LEFT JOIN daily_minutes dm ON si.student_id = dm.student_id   -- Join learning activity
    LEFT JOIN purchases_info pi ON si.student_id = pi.student_id  -- Join subscription info
ORDER BY si.student_id, dm.date_watched;  -- Sort by student then by activity date


-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------


-- Top 5 countries by total purchases
SELECT 
    si.student_country, 
    count(sp.purchase_id) as "Total Purchases"   -- Count how many purchases per country
FROM 365_student_info si 
JOIN 365_student_purchases sp USING(student_id)  -- Join student info with purchases on student_id
WHERE si.student_country IS NOT NULL             -- Exclude null countries
GROUP BY si.student_country
ORDER BY count(sp.purchase_id) DESC              -- Sort countries by purchase count (descending)
LIMIT 5;                                         -- Show only top 5 countries


-- Top 5 countries by total minutes watched
SELECT 
    student_country, 
    round(sum(coalesce(minutes_watched, 0)), 2) as "Total Minutes Watched"  -- Sum of watch minutes, rounded
FROM full_student_info
WHERE student_country IS NOT NULL                -- Exclude null countries
GROUP BY student_country
ORDER BY sum(minutes_watched) DESC               -- Sort by total watch time (descending)
LIMIT 5;                                         -- Show only top 5 countries


-- Top months by number of student purchases
SELECT 
    date_format(date_purchased, '%M') as "Month of Purchase",  -- Extract month name (Jan, Feb, etc.)
    count(student_id) as "Number of Students"                  -- Count purchases by students
FROM 365_student_purchases
GROUP BY date_format(date_purchased, '%M')                     -- Group by month name
-- ⚠️ If data spans multiple years, add YEAR(date_purchased) to avoid merging across years
ORDER BY count(student_id) DESC                                -- Sort by number of students (descending)
LIMIT 4;                                                       -- Show only top 4 months












