-- USER ANALYSIS

-- (1) Repeat Visitors
-- Task: pull data on how many of the website visitors come back for another session (year 2014)

SELECT
	sum_of_sessions AS repeat_sessions
    ,COUNT(user_id) AS users
FROM(
-- Filter users who made first visit in the in requested period and count their sessions
SELECT
	user_id
    ,MIN(is_repeat_session) AS first_session
    ,SUM(is_repeat_session) AS sum_of_sessions
FROM
	website_sessions
WHERE
	created_at BETWEEN '2014-01-01' AND '2014-11-01'
GROUP BY
	user_id
HAVING first_session = 0
) AS users_sessions
GROUP BY 1
ORDER BY 1
;

-- (2) - Analyze repeat visitors behaviour
-- Task: List the minimum, maximum and average time between the first and second session for customer do come back

-- Step1 - Create temporary table of sessions that had repeat visit in specified period
DROP TABLE sessions_with_repeat_visit;
CREATE TEMPORARY TABLE sessions_with_repeat_visit
SELECT
	first_sessions.website_session_id
    ,first_sessions.user_id
    ,first_sessions.first_session_date
    ,MIN(website_sessions.created_at) AS second_session_date
FROM(
SELECT
	website_session_id
    ,user_id
    ,created_at AS first_session_date
FROM
	website_sessions
WHERE
	created_at BETWEEN '2014-01-01' AND '2014-11-02'
    AND is_repeat_session = 0
) AS first_sessions
LEFT JOIN website_sessions
	ON first_sessions.user_id = website_sessions.user_id
    AND website_sessions.is_repeat_session = 1
    AND website_sessions.website_session_id > first_sessions.website_session_id
GROUP BY
	1,2,3
HAVING second_session_date IS NOT NULL
ORDER BY first_sessions.user_id
;

-- Step 2 - aggregate the data

SELECT
	AVG(DATEDIFF(second_session_date, first_session_date)) AS avg_days_first_to_second_session
    ,MIN(DATEDIFF(second_session_date, first_session_date)) AS min_days_first_to_second_session
    ,MAX(DATEDIFF(second_session_date, first_session_date)) AS max_days_first_to_second_session
FROM
	sessions_with_repeat_visit
;
		
-- (3) Repeat Channel Mix
-- Task: Understand the channels the repeat customers come back through. If they are direct type-in, or paid search. Comapre new vs repeat sessions channels

-- organic-search utm_source and utm_campaign null, but http_referer not null
-- paid_brand 
-- direct_type_in - http_referer IS NULL
-- paid_non_brand - utm_campaign = 'non_brand'
-- paid_social

-- Step1 - Filter new and repeat sessions
DROP TABLE repeat_sessions;
CREATE TEMPORARY TABLE repeat_sessions
SELECT
	website_sessions.website_session_id
    ,website_sessions.is_repeat_session
FROM(
SELECT
	website_session_id
    ,user_id
FROM
	website_sessions
WHERE
	created_at BETWEEN '2014-01-01' AND '2014-11-05'
    AND is_repeat_session = 0
) AS first_sessions
LEFT JOIN website_sessions
	ON first_sessions.user_id = website_sessions.user_id
    AND website_sessions.created_at BETWEEN '2014-01-01' AND '2014-11-05'
ORDER BY first_sessions.user_id
;

-- Step2 - pivot and aggregate sessions
SELECT
	CASE
		WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN 'organic_search'
        WHEN website_sessions.utm_source = 'socialbook' THEN 'paid_social'
        WHEN website_sessions.utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
        WHEN website_sessions.utm_campaign = 'brand' THEN 'paid_brand'
        WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NULL THEN 'direct_type_in'
	END AS channel_group
    ,COUNT(DISTINCT CASE WHEN repeat_sessions.is_repeat_session = 0 THEN repeat_sessions.website_session_id ELSE NULL END) AS new_sessions
    ,COUNT(DISTINCT CASE WHEN repeat_sessions.is_repeat_session = 1 THEN repeat_sessions.website_session_id ELSE NULL END) AS repeat_sessions
FROM 
	repeat_sessions
    LEFT JOIN website_sessions
		ON repeat_sessions.website_session_id = website_sessions.website_session_id
        AND website_sessions.created_at BETWEEN '2014-01-01' AND '2014-11-05'
GROUP BY 1
ORDER BY 3 DESC
;

-- Alternatively
SELECT
	CASE
		WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IN ('https://www.gsearch.com','https://www.bsearch.com') THEN 'organic_search'
        WHEN website_sessions.utm_source = 'socialbook' THEN 'paid_social'
        WHEN website_sessions.utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
        WHEN website_sessions.utm_campaign = 'brand' THEN 'paid_brand'
        WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NULL THEN 'direct_type_in'
	END AS channel_group
	,COUNT(DISTINCT CASE WHEN website_sessions.is_repeat_session = 0 THEN website_sessions.website_session_id ELSE NULL END) AS new_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.is_repeat_session = 1 THEN website_sessions.website_session_id ELSE NULL END) AS repeat_sessions
FROM website_sessions
WHERE created_at BETWEEN '2014-01-01' AND '2014-11-05'
GROUP BY 1
;

-- (4) Top Website Pages - Analyzing New & Repeat Conversion Rates
-- Task: Do a comparison of conversion rates and revenue per session for repeat vs new sessions

SELECT
	website_sessions.is_repeat_session AS is_repeat_session
    ,COUNT(DISTINCT website_sessions.website_session_id) AS sessions
    ,COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS conversion_rate
    ,ROUND(SUM(orders.price_usd) / COUNT(DISTINCT website_sessions.website_session_id), 2) AS revenue_per_session
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.created_at BETWEEN '2014-01-01' AND '2014-11-08'
GROUP BY
	1
;