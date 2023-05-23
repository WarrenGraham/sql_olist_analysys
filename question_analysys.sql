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
FROM customers_first_and_second_order_values_CTE;














