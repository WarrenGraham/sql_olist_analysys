-- QUESTIONS FROM STAKEHOLDERS
USE Olist_DB;
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

-- 3) LOYAL CLIENTS  - list of customers who had done more than 1 purchase
SELECT
	 customer_unique_id
	,COUNT(*) AS purchase_count
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY purchase_count DESC

-- HOW MANY LOYAL CLIENTS(more than one purchase)

SELECT COUNT(*)
FROM (
	SELECT
		 customer_unique_id
		,COUNT(*) AS purchase_count
	FROM customers
	GROUP BY customer_unique_id
	HAVING COUNT(*) > 1) AS loyal_client

--	How often is the average order value for a second purchase, larger than the first purchase?
WITH orders_CTE (order_id, customer_unique_id, payment_value)
AS (
	SELECT top 1000 
		 OP.order_id
		,C.customer_unique_id
		,OP.payment_value
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
	ORDER BY C.customer_unique_id
)
SELECT top 1000 *
FROM orders_CTE; --zwr�c w tym zapytaniu sumy payment_value per orderid w funkcji klienta unique_id

-- ponizej lista id klient�w kt�rzy zrobili wiecej ni� 1 zam�wienie
SELECT
	customer_unique_id
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
--	What is the average order value by city?

--	What�s the total value of orders that haven�t been delivered?



 