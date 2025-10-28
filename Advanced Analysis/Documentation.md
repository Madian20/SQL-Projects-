# 📊 Sales & Customer Insights — SQL Project

## 🧩 Overview
A set of T-SQL queries analyzing business performance from sales, products, categories, and customers — all using data from the `gold` schema.

---

## ⚙️ Tech Stack
- **DB:** SQL Server  
- **Language:** T-SQL  
- **Main Tables:** `fact_sales`, `dim_products`, `dim_customers`

---

## 📈 Sales Analysis
- Track **total sales**, **unique customers**, and **quantities** by month/year.  
- Calculate **running totals** and **moving averages** to monitor growth trends.

---

## 🧾 Product & Category Insights
- Compare each product’s yearly sales vs. its average and last year.  
- Identify **top categories** by their contribution to total sales.  
- Segment products by **cost range** to understand price distribution.

---

## 👥 Customer Segmentation
Classifies customers based on behavior:
- **VIP:** >12 months active & >\$5000 spent  
- **Regular:** >12 months active & ≤\$5000 spent  
- **New:** <12 months active  

---

## 📊 Customer Report View
Creates `gold.customer_report` with key KPIs:
- Orders, sales, quantity, age group, recency, avg order value & monthly spend.  

**Run the report:**
```sql
SELECT * FROM gold.customer_report;
