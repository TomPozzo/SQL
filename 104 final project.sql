-- In order to secure company's funding, the management need to tell a compelling story to the investors.
-- Extract and analyze the traffic and website performance data to craft a growth story

-- (1) volume growth
-- Pull overall session and order volume, trended by quarter for the life of the business

SELECT
    YEAR(website_sessions.created_at) AS year
    ,QUARTER(website_sessions.created_at) AS quarter
    ,COUNT(DISTINCT website_sessions.website_session_id) AS sessions
    ,COUNT(DISTINCT orders.order_id) AS orders
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.created_at < '2015-01-01' -- limit to end of 2014, because last quarter in 2015 is incomplete
GROUP BY 1,2
ORDER BY 1,2
;

-- (2) efficiency improvements
-- Show session-to-order conversion rate, revenue per order, and revenue per session

SELECT
    YEAR(website_sessions.created_at) AS year
    ,QUARTER(website_sessions.created_at) AS quarter
    ,COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS session_to_order_conversion_rate
    ,SUM(price_usd) / COUNT(DISTINCT orders.order_id) AS revenue_per_order
    ,SUM(price_usd) / COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.created_at < '2015-01-01' -- limit to end of 2014, because last quarter in 2015 is incomplete
GROUP BY 1,2
;

-- (3) show the growth for specific channels
SELECT
    YEAR(orders.created_at) AS year
    ,QUARTER(orders.created_at) AS quarter
    ,COUNT(DISTINCT CASE WHEN channel_group = 'gsearch_nonbrand' THEN orders.order_id ELSE NULL END) AS gsearch__nonbrand_orders
    ,COUNT(DISTINCT CASE WHEN channel_group = 'bsearch_nonbrand' THEN orders.order_id ELSE NULL END) AS bsearch__nonbrand_orders
    ,COUNT(DISTINCT CASE WHEN channel_group = 'paid_social' THEN orders.order_id ELSE NULL END) AS paid_social_orders
    ,COUNT(DISTINCT CASE WHEN channel_group = 'organic_search' THEN orders.order_id ELSE NULL END) AS organic_search_orders
    ,COUNT(DISTINCT CASE WHEN channel_group = 'paid_brand' THEN orders.order_id ELSE NULL END) AS paid_brand_orders
    ,COUNT(DISTINCT CASE WHEN channel_group = 'direct_type_in' THEN orders.order_id ELSE NULL END) AS direct_type_in_orders
FROM
(SELECT
	website_session_id,
	CASE
		WHEN website_sessions.utm_source = 'gsearch' AND website_sessions.utm_campaign = 'nonbrand' THEN 'gsearch_nonbrand'
        WHEN website_sessions.utm_source = 'bsearch' AND website_sessions.utm_campaign = 'nonbrand' THEN 'bsearch_nonbrand'
        WHEN website_sessions.utm_source = 'socialbook' THEN 'paid_social'
        WHEN website_sessions.utm_campaign = 'brand' THEN 'paid_brand'
        WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NULL THEN 'direct_type_in'
        WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NOT NULL THEN 'organic_search'
	END AS channel_group
FROM
	website_sessions) AS sessions_channels
    INNER JOIN orders
		ON sessions_channels.website_session_id = orders.website_session_id
WHERE
	orders.created_at < '2015-01-01' -- limit to end of 2014, because last quarter in 2015 is incomplete
GROUP BY 1,2
;

-- (4) Show the overall session-to-order conversion rate trends for the channels by quarter
SELECT
    YEAR(sessions_channels.created_at) AS year
    ,QUARTER(sessions_channels.created_at) AS quarter
    ,COUNT(DISTINCT CASE WHEN channel_group = 'gsearch_nonbrand' THEN orders.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN channel_group = 'gsearch_nonbrand' THEN sessions_channels.website_session_id ELSE NULL END) AS gsearch_nonbrand_conversion_rate
    ,COUNT(DISTINCT CASE WHEN channel_group = 'bsearch_nonbrand' THEN orders.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN channel_group = 'bsearch_nonbrand' THEN sessions_channels.website_session_id ELSE NULL END) AS bsearch_nonbrand_conversion_rate
    ,COUNT(DISTINCT CASE WHEN channel_group = 'organic_search' THEN orders.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN channel_group = 'organic_search' THEN sessions_channels.website_session_id ELSE NULL END) AS organic_search_conversion_rate
    ,COUNT(DISTINCT CASE WHEN channel_group = 'brand' THEN orders.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN channel_group = 'brand' THEN sessions_channels.website_session_id ELSE NULL END) AS brand_conversion_rate
    ,COUNT(DISTINCT CASE WHEN channel_group = 'direct_type_in' THEN orders.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN channel_group = 'direct_type_in' THEN sessions_channels.website_session_id ELSE NULL END) AS direct_type_in__conversion_rate
FROM
(SELECT
	website_session_id,
    created_at,
	CASE
		WHEN website_sessions.utm_source = 'gsearch' AND website_sessions.utm_campaign = 'nonbrand' THEN 'gsearch_nonbrand'
        WHEN website_sessions.utm_source = 'bsearch' AND website_sessions.utm_campaign = 'nonbrand' THEN 'bsearch_nonbrand'
        WHEN website_sessions.utm_campaign = 'brand' THEN 'brand'
		WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NULL THEN 'direct_type_in'
        WHEN website_sessions.utm_source IS NULL AND website_sessions.http_referer IS NOT NULL THEN 'organic_search'
	END AS channel_group
FROM
	website_sessions
WHERE
	created_at < '2015-01-01') AS sessions_channels
    LEFT JOIN orders
		ON sessions_channels.website_session_id = orders.website_session_id
GROUP BY 1,2
;

-- (5) Monthly trending for revenue and margin by product, along with total sales and revenue

SELECT
	YEAR(created_at) AS year
    ,MONTH(created_at) AS month
    ,SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS revenue_product1
    ,SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS revenue_product2
    ,SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS revenue_product3
    ,SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS revenue_product4
    ,SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS margin_product1
    ,SUM(CASE WHEN product_id = 2 THEN price_usd - cogs_usd ELSE NULL END) AS margin_product2
    ,SUM(CASE WHEN product_id = 3 THEN price_usd - cogs_usd ELSE NULL END) AS margin_product3
    ,SUM(CASE WHEN product_id = 4 THEN price_usd - cogs_usd ELSE NULL END) AS margin_product4
    ,SUM(price_usd) AS total_revenue
    ,SUM(price_usd - cogs_usd) AS total_margin
FROM
	order_items
GROUP BY
	1,2
;

-- (6) Impact of introducing new products. Pull monthly session to the products page, shopw the % of the session clicking though another page along with conversion from /products to orders

-- Step1 - Create a temporary table to list sessions, which reached /products page and flag the clickthrough
CREATE TEMPORARY TABLE sessions_products_clickthrough
SELECT
	sessions_products.created_at
    ,sessions_products.website_session_id
    ,CASE WHEN MIN(website_pageviews.website_pageview_id) IS NOT NULL THEN 1 ELSE 0 END AS clickthrough
FROM(
SELECT
	created_at
	,website_session_id
    ,website_pageview_id
FROM
	website_pageviews
WHERE
	pageview_url = '/products') AS sessions_products
    LEFT JOIN website_pageviews
		ON sessions_products.website_session_id = website_pageviews.website_session_id
        AND sessions_products.website_pageview_id < website_pageviews.website_pageview_id
GROUP BY 1, 2
;

-- Step2 - Calculate conversion rate from products to order by month
SELECT
	YEAR(sessions_products_clickthrough.created_at) AS year
    ,MONTH(sessions_products_clickthrough.created_at) AS month
    ,COUNT(DISTINCT sessions_products_clickthrough.website_session_id) AS sessions_products
    ,COUNT(DISTINCT CASE WHEN sessions_products_clickthrough.clickthrough = 1 THEN sessions_products_clickthrough.website_session_id ELSE NULL END) /
		COUNT(DISTINCT sessions_products_clickthrough.website_session_id) AS clickthrough_rate
	,COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT sessions_products_clickthrough.website_session_id) AS products_orders_conversion_rate
FROM
	sessions_products_clickthrough
    LEFT JOIN orders
		ON sessions_products_clickthrough.website_session_id = orders.website_session_id
GROUP BY 1,2
;

-- (7) Product 4 was made available as a primary product on the 5th Dec 2014. Previously it was available only as a cross-sell item). Pull sales data since them to show how well each product cross-sells from one another
SELECT
	primary_orders.primary_product_id
    ,COUNT(DISTINCT primary_orders.order_id) AS total_orders
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id IS NULL THEN primary_orders.order_id ELSE NULL END) AS cross_sell_orders_product_none
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 1 THEN primary_orders.order_id ELSE NULL END) AS cross_sell_orders_product_1
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 2 THEN primary_orders.order_id ELSE NULL END) AS cross_sell_orders_product_2
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 3 THEN primary_orders.order_id ELSE NULL END) AS cross_sell_orders_product_3
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 4 THEN primary_orders.order_id ELSE NULL END) AS cross_sell_orders_product_4
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id IS NULL THEN primary_orders.order_id ELSE NULL END) / COUNT(DISTINCT primary_orders.order_id) AS cross_sell_pct_product_none
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 1 THEN primary_orders.order_id ELSE NULL END) / COUNT(DISTINCT primary_orders.order_id) AS cross_sell_pct_product_1
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 2 THEN primary_orders.order_id ELSE NULL END) / COUNT(DISTINCT primary_orders.order_id) AS cross_sell_pct_product_2
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 3 THEN primary_orders.order_id ELSE NULL END) / COUNT(DISTINCT primary_orders.order_id) AS cross_sell_pct_product_3
    ,COUNT(DISTINCT CASE WHEN primary_orders.cross_sell_product_id = 4 THEN primary_orders.order_id ELSE NULL END) / COUNT(DISTINCT primary_orders.order_id) AS cross_sell_pct_product_4
FROM(
SELECT
	orders.order_id
	,orders.primary_product_id
    ,order_items.product_id AS cross_sell_product_id
FROM
	orders
    LEFT JOIN order_items
		ON orders.order_id = order_items.order_id
        AND order_items.is_primary_item = 0
WHERE
	orders.created_at > '2014-12-05') AS primary_orders
GROUP BY 1
;