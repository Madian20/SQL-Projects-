-- the analysis of sales performance over time
SELECT 
  YEAR(order_date) [Order Year]
 ,MONTH(order_date) [Order Month]
 ,SUM(sales_amount) [Total Sales]
 ,COUNT(DISTINCT customer_key) [Total Customers]
 ,SUM(quantity) [Total Quantity]
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date),MONTH(order_date) ASC;

--calculate the total sles per month and the running total sales over time
SELECT
  [Order Date]
 ,[Total Sales]
 -- window function 
 ,SUM([Total Sales]) OVER (PARTITION BY [Order Date] ORDER BY [Order Date]) AS [Running Total Sales]
 -- moving average
 ,AVG([Average Price]) OVER (ORDER BY [Order Date]) AS [Moving Average Price]
FROM(
    SELECT 
     DATETRUNC(year, order_date) [Order Date]
    ,SUM(sales_amount) [Total Sales]
    ,AVG(price) [Average Price]
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
)t;

--the analysis of the yearly performance of products by comparing each product's sales to both its average sales performance and the previous years sales
WITH Yearly_Product_Sales AS (
 SELECT
   YEAR(f.order_date) AS [Order Year]
  ,p.product_name
  ,SUM(f.sales_amount) AS [Current Sales]
 FROM gold.fact_sales f
 LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
 WHERE f.order_date IS NOT NULL
 GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
  [Order Year]
 ,product_name
 ,[Current Sales]
 ,AVG([Current Sales]) OVER (PARTITION BY product_name) AS [Average Sales]
 ,[Current Sales]-AVG([Current Sales]) OVER (PARTITION BY product_name) AS [Diff_AVG]
 ,CASE 
       WHEN [Current Sales]-AVG([Current Sales]) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
       WHEN [Current Sales]-AVG([Current Sales]) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
  ELSE 'AVG' 
  END AS [AVG Change]
 ,LAG([Current Sales]) OVER (PARTITION BY product_name ORDER BY [Order Year]) AS [Previous Year Sales]
 ,([Current Sales]-LAG([Current Sales]) OVER (PARTITION BY product_name ORDER BY [Order Year])) AS [Diff_PY]
 ,CASE
       WHEN ([Current Sales]-LAG([Current Sales]) OVER (PARTITION BY product_name ORDER BY [Order Year])) > 0 THEN 'Increase'
       WHEN ([Current Sales]-LAG([Current Sales]) OVER (PARTITION BY product_name ORDER BY [Order Year])) < 0 THEN 'Decrease'
  ELSE 'No Change' 
  END AS [PY Change]
FROM Yearly_Product_Sales
ORDER BY product_name, [Order Year] ASC;

--the categories that contributed the most to overall sales
WITH Category_Sales AS (
  SELECT
    p.category [Category]
   ,SUM(f.sales_amount) AS [Total Sales]
  FROM gold.fact_sales f
  LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
  GROUP BY p.category
)

SELECT
  Category
 ,[Total Sales]
 ,SUM([Total Sales]) OVER () AS [Overall Sales]
 ,CONCAT(ROUND((CAST([Total Sales]AS float) / SUM([Total Sales]) OVER ()) * 100,2),'%') AS [Sales Contribution Percentage]
from Category_Sales
ORDER BY [Total Sales] DESC;

--segment products into cost range and count how many products fall into each segment
with Product_Cost_Segments AS (
  SELECT
    product_key
   ,product_name
   ,cost
   ,CASE 
     WHEN cost < 100 THEN 'Below $100'
     WHEN cost BETWEEN 100 AND 500 THEN '$100 - $500'
     WHEN cost BETWEEN 500 AND 1000 THEN '$500 - $1000'
    ELSE 'Above $1000'
    END AS [Cost Range]
  FROM gold.dim_products
)

SELECT
  [Cost Range]
 ,COUNT(product_key) AS [Number of Products]
FROM Product_Cost_Segments
GROUP BY [Cost Range]
ORDER BY [Number of Products] DESC;

/*group customers into 3 segments based on their spending behavior:
 - vip : at least 12 months of history and spending more than $5000.
 - regular : at least 12 months of history but spending $5000 or less.
 - new : less than 12 months of history.
*/
WITH CUSTOMER_SPENDING AS(
SELECT 
  c.customer_key as [Customer Key]
 ,SUM(f.sales_amount) AS [Total Spending]
 ,MIN(f.order_date) AS [First Purchase Date]
 ,MAX(f.order_date) AS [Last Purchase Date]
 ,DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS [Months Active]
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
 [Customer Segment]
,COUNT([Customer Key]) AS [Number of Customers]
FROM(
    SELECT 
    [Customer Key]
    ,CASE 
        WHEN [Months Active] >= 12 AND [Total Spending] > 5000 THEN 'VIP'
        WHEN [Months Active] >= 12 AND [Total Spending] <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS [Customer Segment]
    FROM CUSTOMER_SPENDING
)t
GROUP BY [Customer Segment]
ORDER BY [Number of Customers] DESC;

/*
===========================================================
Customer Report
===========================================================

Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend

===========================================================
*/
CREATE OR ALTER VIEW gold.customer_report AS
--1) base query: retrieve core columns from tables
WITH [Base Query] AS (
SELECT
   f.order_number AS [Order Number]
  ,f.product_key AS [Product Key]
  ,f.order_date AS [Order Date]
  ,f.sales_amount AS [Sales Amount]
  ,f.quantity AS [Quantity]
  ,c.customer_key AS [Customer Key]
  ,c.customer_number AS [Customer Number]
  ,CONCAT(c.first_name,' ',c.last_name) AS [Customer Full Name]
  ,DATEDIFF(year, c.birthdate, GETDATE()) AS [Customer Age]
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
WHERE f.order_date IS NOT NULL
)
--2) customer aggregates: summarize key metrics at the customer level
, [Customer Aggregates] AS (
SELECT 
  [Customer Key]
 ,[Customer Number]
 ,[Customer Full Name]
 ,[Customer Age]
 ,COUNT(DISTINCT [Order Number]) AS [Total Orders]
 ,SUM([Sales Amount]) AS [Total Sales]
 ,SUM([Quantity]) AS [Total Quantity Purchased]
 ,COUNT(DISTINCT [Product Key]) AS [Total Products Purchased]
 ,MAX([Order Date]) AS [Last Order Date]
 ,DATEDIFF(month, MIN([Order Date]), MAX([Order Date])) AS [Months Active]
FROM [Base Query]
GROUP BY 
  [Customer Key]
 ,[Customer Number]
 ,[Customer Full Name]
 ,[Customer Age]
)

SELECT 
  [Customer Key]
 ,[Customer Number]
 ,[Customer Full Name]
 ,CASE 
        WHEN [Customer Age] < 20 THEN 'Under 20'
        WHEN [Customer Age] BETWEEN 20 AND 29 THEN '20-29'
        WHEN [Customer Age] BETWEEN 30 AND 39 THEN '30-39'
        WHEN [Customer Age] BETWEEN 40 AND 49 THEN '40-49'
        WHEN [Customer Age] BETWEEN 50 AND 59 THEN '50-59'
  ELSE '60 and over'
    END AS [Age Group]
 ,CASE 
        WHEN [Months Active] >= 12 AND [Total Sales] > 5000 THEN 'VIP'
        WHEN [Months Active] >= 12 AND [Total Sales] <= 5000 THEN 'Regular'
        ELSE 'New'
  END AS [Customer Segment]
 ,[Last Order Date]
 ,DATEDIFF(month, [Last Order Date], GETDATE()) AS Recency
 ,[Total Orders]
 ,[Total Sales]
 ,[Total Quantity Purchased]
 ,[Total Products Purchased]
 --compute average order value
 ,CASE 
   WHEN [Total Orders] = 0 THEN 0
   ELSE ROUND(CAST([Total Sales] AS FLOAT) / [Total Orders],2)
   END AS [Average Order Value]
--compute average monthly spend
 ,CASE 
   WHEN [Months Active] = 0 THEN [Total Sales]
   ELSE ROUND(CAST([Total Sales] AS FLOAT) / [Months Active],2)
  END AS [Average Monthly Spend]
FROM [Customer Aggregates]

SELECT * FROM gold.customer_report;




