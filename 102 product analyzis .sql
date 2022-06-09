-- 106. PRODUCT ANALYSIS
-- Analyzing product sales to understand how each product contributes to the business, and how launches impact the overall portfolio

-- (1) Product-Level Sales - Sales Trends
-- Background: The company is about to launch a new product
-- Task: Pull monthly trends to date for number of sales, total revenue, and total margin generated

SELECT
	YEAR(created_at) AS year
    ,MONTH(created_at) AS month
    ,COUNT(order_id) AS number_of_sales
    ,ROUND(SUM(price_usd), 0) AS total_revenue
    ,ROUND(SUM(price_usd - cogs_usd), 0) AS total_margin
FROM
	orders
WHERE
	created_at < "2013-01-04" -- The request date
GROUP BY
	1, 2
ORDER BY
	1, 2
;

-- (2) Impact of New Product Launch
-- Background: The company launched a second product on January 6th
-- Task: Analyze mothly order volume, overall conversion rates, revenue per session, and a breakdown of sales by product since 1st April 2012

SELECT
	YEAR(website_sessions.created_at) AS year
    ,MONTH(website_sessions.created_at) AS month
    ,COUNT(DISTINCT orders.order_id) AS orders
    ,COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate
    ,ROUND(SUM(orders.price_usd) / COUNT(DISTINCT website_sessions.website_session_id), 2) AS revenue_per_session
    ,COUNT(CASE WHEN primary_product_id = 1 THEN order_id ELSE NULL END) AS product_one_orders
    ,COUNT(CASE WHEN primary_product_id = 2 THEN order_id ELSE NULL END) AS product_two_orders
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id    
WHERE
	website_sessions.created_at > '2012-04-01'
    AND website_sessions.created_at < '2013-04-01' -- Reduced to 1st April to avoid reporting partial month
GROUP BY
	1,2
;

-- (3) Product Level Website Analysis
-- Help with User Pathing to Understand Cutomer Website Behaviour
-- Background: New product was launched. Understand the user path and conversion funnel by looking at sessions which hit the 'products' page and see when they went next

-- Step1 - Create temporary table with filtered website sessions which led to 'products' page and further pageview funnel
CREATE TEMPORARY TABLE products_next_page
SELECT
	website_session_id,
    MAX(products) AS products_made_it,
    MAX(mr_fuzzy) AS mr_fuzzy_made_it,
    MAX(love_bear) AS love_bear_made_it
FROM(
SELECT
	website_session_id,
    CASE WHEN pageview_url = "/products" THEN 1 ELSE 0 END AS products,
    CASE WHEN pageview_url = "/the-original-mr-fuzzy" THEN 1 ELSE 0 END AS mr_fuzzy,
    CASE WHEN pageview_url = "/the-forever-love-bear" THEN 1 ELSE 0 END AS love_bear
FROM
	website_pageviews
WHERE
	created_at BETWEEN "2012-10-06" AND "2013-04-06") AS temp_pageviews
GROUP BY
	1
HAVING
	products_made_it = 1
;

-- Step2 - Aggregate sessions by pre / post product2 launch period per product
SELECT
	CASE WHEN website_sessions.created_at < "2013-01-06" THEN "A. Pre_Product_2" ELSE "B. Post_Product_2" END AS period,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN products_next_page.mr_fuzzy_made_it = 1 OR products_next_page.love_bear_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) AS sessions_moved_next_page,
    COUNT(DISTINCT CASE WHEN products_next_page.mr_fuzzy_made_it = 1 OR products_next_page.love_bear_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) / 
		COUNT(DISTINCT website_sessions.website_session_id) AS pct_sessions_next_page,
	COUNT(DISTINCT CASE WHEN products_next_page.mr_fuzzy_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) AS to_product1,
    COUNT(DISTINCT CASE WHEN products_next_page.mr_fuzzy_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) / 
		COUNT(DISTINCT website_sessions.website_session_id) AS pct_to_product1,
	COUNT(DISTINCT CASE WHEN products_next_page.love_bear_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) AS to_product2,
    COUNT(DISTINCT CASE WHEN products_next_page.love_bear_made_it = 1 THEN products_next_page.website_session_id ELSE NULL END) / 
		COUNT(DISTINCT website_sessions.website_session_id) AS pct_to_product2
FROM
	website_sessions
    INNER JOIN products_next_page
		ON website_sessions.website_session_id = products_next_page.website_session_id
WHERE
	website_sessions.created_at BETWEEN "2012-10-06" AND "2013-04-06"
GROUP BY 1
;


-- (4) Product Conversion Funnels
-- Background: New product was launched on the 6th January
-- Task: Analyze the conversion funnels for two products

-- Step1 - Create temporary table to filter website sessions for the period and create the funnels
CREATE TEMPORARY TABLE sessions_pageviews
SELECT
	website_session_id,
    MAX(mr_fuzzy) AS to_mrfuzzy,
    MAX(love_bear) AS to_lovebear,
    MAX(cart) AS to_cart,
    MAX(shipping) AS to_shipping,
    MAX(billing) AS to_billing,
    MAX(thankyou) AS to_thankyou
FROM(
SELECT
	website_session_id,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mr_fuzzy,
    CASE WHEN pageview_url = '/the-forever-love-bear' THEN 1 ELSE 0 END AS love_bear,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou    
FROM
	website_pageviews
WHERE
	created_at BETWEEN "2013-01-06" AND "2013-04-10") AS temp_pageviews
GROUP BY 1
;

-- Step2 - Aggregate per product to create conversion funnels
SELECT
    CASE
		WHEN to_mrfuzzy = 1 AND to_lovebear = 1 THEN "both"
        WHEN to_mrfuzzy = 1 AND to_lovebear = 0 THEN "product1"
        WHEN to_mrfuzzy = 0 AND to_lovebear = 1 THEN "product2"
        ELSE "none"
	END AS product_seen,
    ROUND(SUM(to_cart) / COUNT(DISTINCT website_session_id), 3) AS product_page_click_rate
    ,ROUND(SUM(to_shipping) / SUM(to_cart), 3) AS cart_click_rate
    ,ROUND(SUM(to_billing) / SUM(to_shipping), 3) AS shipping_click_rate
    ,ROUND(SUM(to_thankyou) / SUM(to_billing), 3) AS billing_click_rate
FROM sessions_pageviews
GROUP BY 1
HAVING product_seen <> "none"
;

-- (5) Cross Selling Performance
-- Background: On the 25th September an option was added on the 'cart' page to add a second product
-- Task: Understand impact of adding cross selling functionality. Compare the month before vs the month after the change

-- Step1 -- Filter sessions that reached cart page during the requested period
DROP TABLE sessions_cart;
CREATE TEMPORARY TABLE sessions_cart
SELECT
	website_session_id
    ,website_pageview_id -- for cart
    ,CASE WHEN created_at < "2013-09-25" THEN "Pre_Cross_Sell" ELSE "Post_Cross_Sell" END AS time_period
FROM
	website_pageviews
WHERE
	created_at BETWEEN "2013-08-25" AND "2013-10-25"
    AND pageview_url = "/cart"
;

-- Step2 - Add next pageviews for cart clickthroughs
CREATE TEMPORARY TABLE sessions_cart_clicktrough
SELECT
	sessions_cart.website_session_id
    ,sessions_cart.time_period
    ,MAX(website_pageviews.pageview_url) AS last_pageview
FROM
	sessions_cart
    LEFT JOIN website_pageviews
		ON sessions_cart.website_session_id = website_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > sessions_cart.website_pageview_id
GROUP BY 1,2
;

-- Step3 - Aggregate the date by pre/post period 
SELECT
	sessions_cart_clicktrough.time_period AS period
    ,COUNT(DISTINCT sessions_cart_clicktrough.website_session_id) AS cart_sessions
    ,ROUND(COUNT(sessions_cart_clicktrough.last_pageview), 3) AS clickthroughs
    ,ROUND(COUNT(sessions_cart_clicktrough.last_pageview) / COUNT(DISTINCT sessions_cart_clicktrough.website_session_id), 3) AS cart_clickthrough_ratio
    ,ROUND(AVG(orders.items_purchased), 3) AS products_per_order
    ,ROUND(AVG(orders.price_usd), 3) AS average_order_value
    ,ROUND(AVG(orders.price_usd) / COUNT(DISTINCT sessions_cart_clicktrough.website_session_id), 3) AS revenue_per_cart_session
FROM
	sessions_cart_clicktrough
    LEFT JOIN orders
		ON sessions_cart_clicktrough.website_session_id = orders.website_session_id
GROUP BY 1
ORDER BY 1 DESC
;

-- (6) Recent Product Launch - Portfolio Expansion Analysis
-- Background: A 3rd product was launched
-- Task: Analyze the impact of the launch

SELECT
	CASE
		WHEN website_sessions.created_at < "2013-12-12" THEN "A. Pre_Cross_Sell"
        WHEN website_sessions.created_at >= "2013-12-12" THEN "B. Post_Cross_Sell"
        ELSE "Ups"
	END AS time_period
    ,ROUND(COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id), 3) AS conv_rate
    ,ROUND(AVG(orders.price_usd), 3) AS average_order_value
    ,ROUND(AVG(orders.items_purchased), 3) AS products_per_order
    ,ROUND(SUM(orders.price_usd) / COUNT(DISTINCT website_sessions.website_session_id), 3) AS revenue_per_session
FROM
	website_sessions
    LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE
	website_sessions.created_at BETWEEN "2013-11-12" AND "2014-01-12"
GROUP BY 1
;

-- (7) Product refund analysis / Quality Issues & Refunds
-- Background: One of the products had quality issues in the past (corrected in Sep 2014). A new supplier was intriduced on the 16th Sep 2014
-- Task: Analyze monthly product refund rates, by product and confirm the qulity issues are fixed now

SELECT
	YEAR(order_items.created_at) AS year
    ,MONTH(order_items.created_at) AS month
    -- Product 1
    ,COUNT(CASE WHEN order_items.product_id = 1 THEN order_items.order_id ELSE NULL END) AS p1_orders
    ,ROUND(COUNT(CASE WHEN order_items.product_id = 1 THEN order_item_refunds.order_item_refund_id ELSE NULL END) /
		COUNT(CASE WHEN order_items.product_id = 1 THEN order_items.order_id ELSE NULL END), 3) AS product1_refund_rate
	-- Product 2
    ,COUNT(CASE WHEN order_items.product_id = 2 THEN order_items.order_id ELSE NULL END) AS p2_orders
	,ROUND(COUNT(CASE WHEN order_items.product_id = 2 THEN order_item_refunds.order_item_refund_id ELSE NULL END) /
		COUNT(CASE WHEN order_items.product_id = 2 THEN order_items.order_id ELSE NULL END), 3) AS product2_refund_rate
	-- Product 3
    ,COUNT(CASE WHEN order_items.product_id = 3 THEN order_items.order_id ELSE NULL END) AS p3_orders
	,ROUND(COUNT(CASE WHEN order_items.product_id = 3 THEN order_item_refunds.order_item_refund_id ELSE NULL END) /
		COUNT(CASE WHEN order_items.product_id = 3 THEN order_items.order_id ELSE NULL END), 3) AS product3_refund_rate
	-- Product 4
    ,COUNT(CASE WHEN order_items.product_id = 4 THEN order_items.order_id ELSE NULL END) AS p4_orders
	,ROUND(COUNT(CASE WHEN order_items.product_id = 4 THEN order_item_refunds.order_item_refund_id ELSE NULL END) /
		COUNT(CASE WHEN order_items.product_id = 4 THEN order_items.order_id ELSE NULL END), 3) AS product4_refund_rate
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
WHERE order_items.created_at < "2014-10-15" -- the date of the request
GROUP BY
	1,2
;