USE Olist_DB;

-- QUESTIONS FROM STAKEHOLDERS

--	1) HOW MANY ORDERS IN DATABASE? 
SELECT 
	COUNT(*) 
FROM 
	orders

--	2) HOW MANY INDIVIDUAL CLIENTS IN DATABASE?
SELECT 
	COUNT(DISTINCT customer_unique_id) 
FROM
	customers

-- 3) LOYAL CLIENTS  - list of customers who made more than one purchase
SELECT
	 customer_unique_id
	,COUNT(*) AS purchase_count
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY purchase_count DESC 

-- 4) HOW MANY LOYAL CLIENTS(more than one purchase)

SELECT COUNT(*)
FROM (
	SELECT
		 customer_unique_id
		,COUNT(*) AS purchase_count
	FROM customers
	GROUP BY customer_unique_id
	HAVING COUNT(*) > 1) AS loyal_client

-- 5) How often is the average order value for a second purchase, larger than the first purchase?

-- STEP 5.1 -- create table with clients whom made more than one order
DROP TABLE IF EXISTS #customers_first_and_second_order_values_TEMP
GO
WITH orders_CTE (order_id, customer_unique_id, payment_value, order_purchase_timestamp)
AS (
	SELECT
		 OP.order_id
		,C.customer_unique_id
		,OP.payment_value
		,O.order_purchase_timestamp
	FROM order_payments AS OP
	INNER JOIN 
		orders AS O
		ON OP.order_id = O.order_id
	INNER JOIN 
		customers AS C
		ON c.customer_id = O.customer_id
	WHERE
		C.customer_unique_id IN (
			SELECT
				customer_unique_id
			FROM customers
			GROUP BY customer_unique_id
			HAVING COUNT(*) > 1
		)
),
-- STEP 5.2 -- grouped orders_CTE lowers granularity of orders_CTE to sum of each order
grouped_orders_CTE (order_id, customer_unique_id, order_purchase_timestamp, sum_payment_value)
AS (
	SELECT 
		order_id
		,customer_unique_id
		,order_purchase_timestamp
		,SUM(payment_value)
	FROM orders_CTE
	GROUP BY 
		order_id
		,customer_unique_id
		,order_purchase_timestamp
),
-- STEP 5.3 -- add partition by column witch contaitns value of first order and count orders by customer_unique_id
counted_grouped_orders_CTE (customer_unique_id, order_purchase_timestamp, sum_payment_value, customer_first_purchase_amount, customer_second_purchase_amount,order_rank)
AS (
	SELECT 
		customer_unique_id
		,order_purchase_timestamp
		,sum_payment_value
		,FIRST_VALUE(sum_payment_value) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC) AS customer_first_purchase_value
		,LEAD(sum_payment_value) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC) AS customer_second_purchase_value
		,ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC)
	FROM grouped_orders_CTE
),
-- STEP 5.4 -- create list of 1st and 2nd order value for each customer
customers_first_and_second_order_values_CTE (customer_unique_id, customer_first_purchase_amount, customer_second_purchase_amount)
AS (
	SELECT
		customer_unique_id
		,customer_first_purchase_amount
		,customer_second_purchase_amount
	FROM counted_grouped_orders_CTE
	WHERE order_rank = 1
)
-- STEP 5.5 -- save STEP 5.4 result
SELECT *
INTO #customers_first_and_second_order_values_TEMP
FROM customers_first_and_second_order_values_CTE
GO
-- STEP 5.6 -- how many clients made more than 1 order
WITH more_than_one_order_CTE (id, count_result)
AS (
	SELECT 1, COUNT(*) 
	FROM #customers_first_and_second_order_values_TEMP
),
-- STEP 5.7 -- how many clients made 2nd order larger than 1st one
second_more_expensive_CTE (id, count_result)
AS (
	SELECT 1, COUNT(*) 
	FROM #customers_first_and_second_order_values_TEMP
	WHERE customer_second_purchase_amount > customer_first_purchase_amount
)
-- STEP 5.8 -- result table 
SELECT 
	m.count_result AS more_than_one_purchase_client_count
	,s.count_result AS second_purchase_larger_client_count
	,ROUND(CAST(S.count_result AS FLOAT) / CAST(M.count_result AS FLOAT) * 100, 2) AS perc_how_many_clients_2nd_purchase_larger
FROM more_than_one_order_CTE AS M
INNER JOIN second_more_expensive_CTE AS S
	ON M.id = S.id;
-- 	6) What is the average order value by city?

-- STEP 6.1 calculate table, summing orders value
DROP TABLE IF EXISTS #group_by_countries_temp
GO
WITH orders_payment_values_CTE(order_id, order_value)
AS (
	SELECT
		order_id
		,SUM(payment_value)
	FROM order_payments
	GROUP BY order_id
),
-- STEP 6.2 calculate table, summing orders value
group_by_cities_CTE(customer_city, number_of_orders, avarage_order_value, total_order_value)
AS(
	SELECT
		C.customer_city
		,COUNT(*) AS number_of_orders
		,ROUND(AVG(OPV.order_value), 2) AS avarage_order_value
		,SUM(OPV.order_value) AS total_order_value
	FROM orders_payment_values_CTE AS OPV
	INNER JOIN orders AS O
		ON OPV.order_id = O.order_id
	INNER JOIN customers AS C
		ON O.customer_id = C.customer_id
	GROUP BY C.customer_city
)
-- STEP 6.3 create temp table (for further usage)
SELECT * 
INTO #group_by_countries_temp
FROM group_by_cities_CTE
GO
-- STEP 6.4 display result
SELECT * 
FROM #group_by_countries_temp;

--	7) show cities which makeing 80% of income - is paretho true here?

-- STEP 7.1
-- execute question 6 query to create #group_by_countries_temp
-- STEP 7.2 -- add running total column and populate paretho check
SELECT
	*
	,SUM(total_order_value) OVER (ORDER BY total_order_value DESC) AS running_total_order_value
	,( SUM(total_order_value) OVER (ORDER BY total_order_value DESC) ) * 100 / ( SUM(total_order_value) OVER() ) AS perc
	,CASE 
		WHEN ( SUM(total_order_value) OVER (ORDER BY total_order_value DESC) ) * 100 / ( SUM(total_order_value) OVER() ) <= 80
		THEN 1 
		ELSE 0 
	END AS paretho_check_city_customer
INTO #running_total_temp
FROM #group_by_countries_temp
-- show only 80% value cities
SELECT *
FROM #running_total_temp
WHERE paretho_check_city_customer = 1;
-- is 20% of cities makeing 80% of order value
SELECT ROUND(CAST(SUM(paretho_check_city_customer) AS float) * 100 / CAST(COUNT(*) AS float), 2)
FROM #running_total_temp
/*
--	8) What is the average order value by city seller? 
*/
-- STEP 8.1 calculate table, summing orders value
DROP TABLE IF EXISTS #group_by_seller_city_temp
GO
WITH orders_payment_values_CTE(order_id, order_value)
AS (
	SELECT
		order_id
		,SUM(payment_value)
	FROM order_payments
	GROUP BY order_id
),
-- STEP 8.2 calculate table, summing orders value
group_by_seller_city_CTE(seller_city, number_of_orders, avarage_order_value, total_order_value) 
AS(
	SELECT
		S.seller_city
		,COUNT(*) AS number_of_orders
		,ROUND(AVG(OPV.order_value), 2) AS avarage_order_value
		,SUM(OPV.order_value) AS total_order_value
	FROM orders_payment_values_CTE AS OPV
	INNER JOIN 
		orders AS O
		ON OPV.order_id = O.order_id
	INNER JOIN 
		order_items AS OI
		ON O.order_id = OI.order_id
	INNER JOIN 
		sellers AS S
		ON OI.seller_id = S.seller_id
	GROUP BY S.seller_city
)
-- STEP 8.3 create temp table (for further usage)
SELECT * 
INTO #group_by_seller_city_temp
FROM group_by_seller_city_CTE;
-- 8.4.1 display results
SELECT *
FROM #group_by_seller_city_temp
-- 8.4.2 it appears to one mistake value in seller_city column - first value
SELECT DISTINCT seller_city 
FROM sellers
ORDER BY 1 ASC;
-- 8.4.3 set null in incorect field
UPDATE sellers
SET seller_city = null
WHERE seller_city = '04482255';
-- 8.4.4 check for nulls 
SELECT 
	SUM(CASE 
			WHEN seller_city IS NULL
			THEN 1 
			ELSE 0
		END
	)
FROM sellers;
-- 8.5 is paretho true for running totals? 
-- you need to execute 8.3 first
SELECT
	*
	,SUM(total_order_value) OVER (ORDER BY total_order_value DESC) AS running_total_order_value
	,( SUM(total_order_value) OVER (ORDER BY total_order_value DESC) ) * 100 / ( SUM(total_order_value) OVER() ) AS perc
	,CASE 
		WHEN ( SUM(total_order_value) OVER (ORDER BY total_order_value DESC) ) * 100 / ( SUM(total_order_value) OVER() ) <= 80
		THEN 1
		ELSE 0
	END AS paretho_check_city_seller
INTO #seller_cities_paretho_check_temp
FROM #group_by_seller_city_temp
ORDER BY perc;
-- is 20% of sellers group by headquater city makeing 80% of order value
SELECT ROUND(CAST(SUM(paretho_check_city_seller) AS float) * 100 / CAST(COUNT(*) AS float), 2)
FROM #seller_cities_paretho_check_temp;
--	9)	How much % of orders was made in hometown
-- STEP 9.1 calculate table, summing orders value
WITH orders_payment_values_CTE(order_id, order_value)
AS (
	SELECT
		order_id
		,SUM(payment_value)
	FROM order_payments
	GROUP BY order_id
),
-- STEP 9.2 calculate table, summing orders value and hometown check
hometown_purchases_city_CTE(seller_city, customer_city, number_of_orders, avarage_order_value, total_order_value)  
AS(
	SELECT
		S.seller_city
		,C.customer_city
		,COUNT(*) AS number_of_orders
		,ROUND(AVG(OPV.order_value), 2) AS avarage_order_value
		,SUM(OPV.order_value) AS total_order_value
	FROM orders_payment_values_CTE AS OPV
	INNER JOIN 
		orders AS O
		ON OPV.order_id = O.order_id
	INNER JOIN 
		order_items AS OI
		ON O.order_id = OI.order_id
	INNER JOIN 
		sellers AS S
		ON OI.seller_id = S.seller_id
	INNER JOIN
		customers AS C 
		ON C.customer_id = O.customer_id
	WHERE S.seller_city = C.customer_city
	GROUP BY
		S.seller_city
		,C.customer_city
),
all_purchases_city_group_by_CTE(seller_city, number_of_orders, avarage_order_value, total_order_value)  
AS(
	SELECT
		S.seller_city
		,COUNT(*) AS number_of_orders
		,ROUND(AVG(OPV.order_value), 2) AS avarage_order_value
		,SUM(OPV.order_value) AS total_order_value
	FROM orders_payment_values_CTE AS OPV
	INNER JOIN 
		orders AS O
		ON OPV.order_id = O.order_id
	INNER JOIN 
		order_items AS OI
		ON O.order_id = OI.order_id
	INNER JOIN 
		sellers AS S
		ON OI.seller_id = S.seller_id
	GROUP BY
		S.seller_city
)
-- results and percentage of local trades
SELECT 
	 _hometown.seller_city AS city
	,_hometown.number_of_orders AS HOMETOWN_orders_count
	,_all.number_of_orders AS ALL_orders_count
	,_hometown.avarage_order_value AS HOMETOWN_avg_order_value
	,_all.avarage_order_value AS ALL_avg_order_value
	,_hometown.total_order_value AS HOMETOWN_total_order_value
	,_all.total_order_value AS ALL_total_order_value
	,ROUND(CAST(_hometown.number_of_orders as float) * 100 / CAST(_all.number_of_orders as float), 2) AS perc_hometown_orders
	,ROUND(CAST(_hometown.total_order_value as float) * 100 / CAST(_all.total_order_value as float), 2) AS perc_hometown_order_value
FROM all_purchases_city_group_by_CTE AS _all
INNER JOIN hometown_purchases_city_CTE AS _hometown
	ON _hometown.seller_city = _all.seller_city
ORDER BY perc_hometown_order_value DESC
/*
--	10) What’s the total value of orders that haven’t been delivered?
*/