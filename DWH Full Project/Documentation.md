# 🧠 Project Overview
**Project Name:** Data Warehouse Setup Script  
**Objective:** To create a database named `DataWarehouse` in a safe and organized way.  
The script checks if the database already exists before creating it to avoid duplication or errors.

---

## ⚙️ How It Works
1. The script starts by using the default `master` database.  
2. It checks if a database named `DataWarehouse` already exists.  
3. If it doesn’t exist, the script creates it and prints:  
   `✅ Database "DataWarehouse" has been created.`  
4. If it already exists, it prints:  
   `ℹ️ Database "DataWarehouse" already exists.`  
5. After the database is set up, additional stored procedures can be executed to load data into different layers (bronze and silver).

---

## 🧩 Tools & Technologies
- Microsoft SQL Server  
- T-SQL (Transact-SQL)

---

## 🧾 Notes
- This script is designed to initialize the database environment for Data Warehouse projects.  
- It’s safe to run multiple times without creating duplicate databases.  
- Run the script with administrator privileges for proper execution.  
- To execute the **Bronze** and **Silver** layers after creating the database, switch to the `DataWarehouse` database and run:  
  ```sql
  EXEC bronze.load_bronze;
  EXEC silver.load_silver;
