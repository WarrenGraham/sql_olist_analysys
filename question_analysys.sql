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

WITH orders_CTE (order_id, customer_unique_id, payment_value,order_purchase_timestamp)
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
)
-- this is query for selection earliest purchase for each customer
SELECT 
	 order_id
	,customer_unique_id
	,sum_payment_value
	,FIRST_VALUE(sum_payment_value) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC) AS customer_first_purchase_amount
	,order_purchase_timestamp
FROM grouped_orders_CTE
WHERE customer_unique_id ='9a736b248f67d166d2fbb006bcb877c3'
ORDER BY order_purchase_timestamp


/* test 1 (go investigate ''top'' client, why 31 payments? maybe this is number of installments)
should i group in grouped_orders_CTE or should i consider this data in other way? check for dbo.order_payments*/

/*
WITH orders_CTE (order_id, customer_unique_id, payment_value,order_purchase_timestamp)
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
)


SELECT 
	 order_id
	,customer_unique_id
	,payment_value
	,FIRST_VALUE(payment_value) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp DESC) AS top_purchase_of_customer
	,order_purchase_timestamp
FROM orders_CTE
WHERE customer_unique_id ='9a736b248f67d166d2fbb006bcb877c3'
ORDER BY order_purchase_timestamp
*/



--9a736b248f67d166d2fbb006bcb877c3 TOP KLIENT

--	What is the average order value by city?

--	What's the total value of orders that haven't been delivered?



 