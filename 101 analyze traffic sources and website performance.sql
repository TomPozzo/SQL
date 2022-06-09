-- (1) Monthly Trend for Gsearch Sessions and Orders
-- Background: UTM source 'gsearch' seems to be the bigest driver of the business.
-- Task: Pull monthly trends for gsearch sessions and orders to show the growth
SELECT
	YEAR(website_sessions.created_at) AS year
	,MONTH(website_sessions.created_at) AS month
	,COUNT(DISTINCT website_sessions.website_session_id) AS sessions
    ,COUNT(DISTINCT order_id) AS orders
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.utm_source = 'gsearch'
    AND website_sessions.created_at < '2012-11-27'
    -- AND website_sessions.created_at > '2012-03-27'
GROUP BY
	YEAR(website_sessions.created_at)
    ,MONTH(website_sessions.created_at)
;

-- (2) Monthly Trend gsearch Sessions and Orders Split by Campaigns
-- Task: As above but separating brand and nonbrand campaigns
SELECT
	YEAR(website_sessions.created_at) AS year
    ,MONTH(website_sessions.created_at) AS month
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_campaign = 'brand'THEN orders.order_id ELSE NULL END) AS brand_orders
	,COUNT(DISTINCT CASE WHEN website_sessions.utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS nonbrand_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_campaign = 'nonbrand'THEN orders.order_id ELSE NULL END) AS nonbrand_orders
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.utm_source = 'gsearch'
    AND website_sessions.created_at < '2012-11-27'
    -- AND website_sessions.created_at > '2012-03-27'
GROUP BY
	MONTH(website_sessions.created_at)
;

-- (3) Traffic sources analysis
-- Task: For gsearch nonbrand - see monthly sessions by device type
SELECT
	YEAR(website_sessions.created_at) AS year
	,MONTH(website_sessions.created_at) AS month
    ,COUNT(DISTINCT CASE WHEN website_sessions.device_type = 'mobile' THEN website_sessions.website_session_id ELSE NULL END) AS mobile_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.device_type = 'mobile'THEN orders.order_id ELSE NULL END) AS mobile_orders
	,COUNT(DISTINCT CASE WHEN website_sessions.device_type = 'desktop' THEN website_sessions.website_session_id ELSE NULL END) AS desktop_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.device_type = 'desktop'THEN orders.order_id ELSE NULL END) AS desktop_orders
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.utm_source = 'gsearch'
    AND website_sessions.created_at < '2012-11-27'
    -- AND website_sessions.created_at > '2012-03-27'
GROUP BY
	1,2
;

-- (4) Analyze traffic channels
SELECT
	YEAR(website_sessions.created_at) AS year
    ,MONTH(website_sessions.created_at) AS month
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_source = 'gsearch' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_source = 'gsearch'THEN orders.order_id ELSE NULL END) AS gsearch_orders
	,COUNT(DISTINCT CASE WHEN website_sessions.utm_source = 'bsearch' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_source = 'bsearch' THEN orders.order_id ELSE NULL END) AS bsearch_orders
	,COUNT(DISTINCT CASE WHEN website_sessions.utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) AS organic_sessions
    ,COUNT(DISTINCT CASE WHEN website_sessions.utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END) AS direct_type_in_sessions
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.created_at < '2012-11-27'
    -- AND website_sessions.created_at > '2012-03-27'
GROUP BY
	1,2
;

-- (5)  Conversion rate per month
SELECT
	MONTH(website_sessions.created_at) AS month
	,COUNT(DISTINCT order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS session_order_ratio
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.utm_source = 'gsearch'
    AND website_sessions.created_at < '2012-11-27'
    -- AND website_sessions.created_at > '2012-03-27'
GROUP BY
	MONTH(website_sessions.created_at);
    
-- (6) Estimate the revenue impact of the new landing page by analyzing the conversion rate
-- Step1 - Indetified the earliest pageview_id of the new landing page /lander-1
SELECT MIN(website_pageview_id) FROM website_pageviews WHERE pageview_url = '/lander-1';

-- Step2 - Identify first pageview per session
DROP TABLE first_pageviews;
CREATE TEMPORARY TABLE first_pageviews
SELECT
	website_pageviews.website_session_id,
    MIN(website_pageview_id) AS first_pageview
FROM website_sessions
	INNER JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE
	website_pageviews.website_pageview_id >= 23504
    AND website_pageviews.created_at < '2012-07-28'
    AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand"
	AND website_pageviews.pageview_url IN ('/home', '/lander-1')
GROUP BY
	website_session_id
;

-- Step3 - Add the landing page to allow split by current / test landing page
CREATE TEMPORARY TABLE first_pageviews_landing
SELECT
	first_pageviews.website_session_id,
	website_pageviews.pageview_url AS landing_page
FROM
	first_pageviews
	LEFT JOIN website_pageviews
		ON first_pageviews.first_pageview = website_pageviews.website_pageview_id
;

-- Step4 - Add orders
CREATE TEMPORARY TABLE first_pageviews_landing_orders
SELECT
	first_pageviews_landing.website_session_id
	,first_pageviews_landing.landing_page
    ,orders.order_id AS order_id
FROM
	first_pageviews_landing
    LEFT JOIN orders
     ON first_pageviews_landing.website_session_id = orders.website_session_id
;
  
-- Step5 - Find the diffrence between conversion rates for current / test landing page
SELECT
	landing_page
    ,COUNT(DISTINCT website_session_id) AS sessions
    ,COUNT(DISTINCT order_id) AS orders
    ,COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) AS conv_rate
FROM
	first_pageviews_landing_orders
GROUP BY
	1
;

--
  
  
-- (7) Same as before but including full conversion funnel time period 19-Jun - 28 Jul

-- Step1 - Create a temporary table per session with a flag for pages reached
DROP TABLE session_level_pageview_made_it;
CREATE TEMPORARY TABLE session_level_pageview_made_it
SELECT
	website_session_id
    ,MAX(homepage) AS homepage_ok
    ,MAX(lander_1) AS custom_lander_ok
    ,MAX(products_page) AS products_page_ok
    ,MAX(mrfuzzy_page) AS mrfuzzy_ok
    ,MAX(cart_page) AS cart_ok
    ,MAX(shipping_page) AS shipping_ok
    ,MAX(billing_page) AS billing_ok
    ,MAX(thankyou_page) AS thankyou_ok
FROM(
SELECT
	website_sessions.website_session_id
    ,website_pageviews.website_pageview_id
    ,CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END AS homepage
    ,CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END AS lander_1
    ,CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS products_page
    ,CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page
    ,CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page
    ,CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page
    ,CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page
    ,CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
	AND website_sessions.utm_campaign = 'nonbrand'
    AND website_sessions.created_at < '2012-07-28'
    AND website_sessions.created_at > '2012-06-19'
ORDER BY
	website_sessions.website_session_id
    ,website_pageviews.created_at
) AS page_level

GROUP BY
	website_session_id
;

-- Step2 - Aggregate the data by landing page and calculate the conversion rate for each tep of the funnel
SELECT
	CASE
		WHEN homepage_ok = 1 THEN "seen_homepage"
        WHEN custom_lander_ok = 1 THEN "seen_lander1"
        ELSE "error"
	END AS landing_page
	,COUNT(DISTINCT website_session_id) AS sessions
	,SUM(products_page_ok) / COUNT(DISTINCT website_session_id) AS to_products_cvr
	,SUM(mrfuzzy_ok) / SUM(products_page_ok) AS to_mrfuzzy_cvr
	,SUM(cart_ok) / SUM(mrfuzzy_ok) AS to_cart_cvr
	,SUM(shipping_ok) / SUM(cart_ok) AS to_shipping_cvr
	,SUM(billing_ok) / SUM(shipping_ok) AS to_billing_cvr
	,SUM(thankyou_ok) / SUM(billing_ok) AS to_thankyou_cvr
FROM session_level_pageview_made_it
GROUP BY 1
;

-- (8) Quantify the impact of the billing test. Analyze the lift generated from the test (10th Sep - 10th Nov), in terms of revenue per billing page session
SELECT
	billing_version
    ,COUNT(DISTINCT website_session_id) AS sessions
    ,ROUND(SUM(price_usd) / COUNT(DISTINCT website_session_id), 2) AS revenue_per_billing_page_seen
FROM(
SELECT
	website_pageviews.website_session_id
    ,website_pageviews.pageview_url AS billing_version
    ,orders.order_id
    ,orders.price_usd
FROM website_pageviews
	LEFT JOIN orders
		ON orders.website_session_id = website_pageviews.website_session_id
WHERE
	website_pageviews.created_at > '2012-09-10'
    AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing', '/billing-2')
) AS billing_pageviews
GROUP BY 1
;
        
SELECT
	COUNT(website_session_id) AS billing_sessions_last_month
FROM website_pageviews
WHERE pageview_url IN ('/billing', '/billing-2')
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27'
;
-- 1193 sessions
-- 31.34 - 22.83 = 8.48 per billing session
-- 10116.64 - value of billing test in the past month