#создали базу данных
CREATE DATABASE project;

#заменили пустые значение на NULL
UPDATE customers SET Gender = NULL WHERE Gender = '';
UPDATE customers SET Age = NULL WHERE Age = '';

#поменяли тип Age с текстового на INT NULL. почему NULL, потому что там есть пустые значение.
ALTER TABLE Customers MODIFY Age INT NULL;

SELECT * FROM customers;


CREATE TABLE Transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));


LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions.csv.txt"
INTO TABLE Transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SHOW VARIABLES LIKE 'secure_file_priv';

SELECT * FROM Transactions LIMIT 10;


#1.	список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
#средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;информацию в разрезе месяцев:

WITH monthly_activity AS (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY ID_client, month
),
active_clients AS (
    SELECT ID_client
    FROM monthly_activity
    GROUP BY ID_client
    HAVING COUNT(month) = 12
)

SELECT 
    t.ID_client,
    AVG(t.Sum_payment) AS avg_check,
    SUM(t.Sum_payment) / 12 AS avg_monthly_spend,
    COUNT(*) AS total_operations
FROM Transactions t
JOIN active_clients ac 
    ON t.ID_client = ac.ID_client
WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'
GROUP BY t.ID_client;


#2.a)средняя сумма чека в месяц;
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    AVG(Sum_payment) AS avg_check
FROM Transactions
WHERE date_new >= '2015-06-01'
  AND date_new < '2016-06-01'
GROUP BY month
ORDER BY month;

#2.b)среднее количество операций в месяц;
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(*) AS operations
FROM Transactions
WHERE date_new >= '2015-06-01'
  AND date_new < '2016-06-01'
GROUP BY month
ORDER BY month;

#2.c)среднее количество клиентов, которые совершали операции;
SELECT 
    DATE_FORMAT(date_new, '%Y-%m') AS month,
    COUNT(DISTINCT ID_client) AS clients
FROM Transactions
WHERE date_new >= '2015-06-01'
  AND date_new < '2016-06-01'
GROUP BY month
ORDER BY month;

#2.d)долю от общего количества операций за год и долю в месяц от общей суммы операций;
WITH monthly AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(*) AS operations,
        SUM(Sum_payment) AS total_sum
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
    GROUP BY month
),
year_total AS (
    SELECT 
        COUNT(*) AS total_operations,
        SUM(Sum_payment) AS total_sum
    FROM Transactions
    WHERE date_new >= '2015-06-01'
      AND date_new < '2016-06-01'
)

SELECT 
    m.month,
    m.operations,
    m.total_sum,
    
    m.operations / y.total_operations AS operations_share,
    m.total_sum / y.total_sum AS sum_share

FROM monthly m
JOIN year_total y;

#2.e)вывести % соотношение M/F/NA в каждом месяце с их долей затрат;
DESCRIBE customers;

ALTER TABLE customers  
CHANGE COLUMN `п»їId_client` ID_client INT;

SHOW CREATE TABLE customers;

SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    c.Gender,

    COUNT(*) AS operations,
    SUM(t.Sum_payment) AS total_sum,

    COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS ratio_count,

    SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) AS ratio_sum

FROM Transactions t
JOIN customers c 
    ON t.ID_client = c.ID_client

WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'

GROUP BY month, c.Gender
ORDER BY month;

#3.	возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной 
#информации, с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.

#1.Возрастные группы (за весь период)
SELECT 
    CASE 
        WHEN c.Age IS NULL THEN 'NA'
        ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
    END AS age_group,

    COUNT(*) AS operations,
    SUM(t.Sum_payment) AS total_sum

FROM Transactions t
LEFT JOIN customers c 
    ON t.ID_client = c.ID_client

WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'

GROUP BY age_group
ORDER BY age_group;



#2.Добавляем квартал + средние
SELECT 
    CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,

    CASE 
        WHEN c.Age IS NULL THEN 'NA'
        ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
    END AS age_group,

    COUNT(*) AS operations,
    AVG(t.Sum_payment) AS avg_check,
    SUM(t.Sum_payment) AS total_sum

FROM Transactions t
LEFT JOIN customers c 
    ON t.ID_client = c.ID_client

WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'

GROUP BY quarter, age_group
ORDER BY quarter, age_group;



#3.Добавляем % для оценки
SELECT 
    CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter,

    CASE 
        WHEN c.Age IS NULL THEN 'NA'
        ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', FLOOR(c.Age / 10) * 10 + 9)
    END AS age_group,

    COUNT(*) AS operations,

    COUNT(*) / SUM(COUNT(*)) OVER (
        PARTITION BY CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new))
    ) AS operations_ratio,

    SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (
        PARTITION BY CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new))
    ) AS sum_ratio

FROM Transactions t
LEFT JOIN customers c 
    ON t.ID_client = c.ID_client

WHERE t.date_new >= '2015-06-01'
  AND t.date_new < '2016-06-01'

GROUP BY quarter, age_group
ORDER BY quarter, age_group;