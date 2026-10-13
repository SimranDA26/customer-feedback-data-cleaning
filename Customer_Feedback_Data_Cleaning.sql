
-- PROJECT: CUSTOMER FEEDBACK DATA CLEANING

CREATE DATABASE IF NOT EXISTS Customer_Feedback_Project;
USE Customer_Feedback_Project;

DROP TABLE IF EXISTS customer_feedback_stage;

CREATE TABLE customer_feedback_stage
LIKE customer_feedback_raw;

INSERT INTO customer_feedback_stage
SELECT *
FROM customer_feedback_raw;

SELECT COUNT(*) AS raw_records
FROM customer_feedback_raw;

SELECT COUNT(*) AS stage_records
FROM customer_feedback_stage;

-- INITIAL DATA PROFILING


SELECT * FROM customer_feedback_stage;

DESCRIBE customer_feedback_stage;

-- Missing values
SELECT
    SUM(customer_name IS NULL OR TRIM(customer_name) = '')
        AS missing_names,
    SUM(email IS NULL OR TRIM(email) = '')
        AS missing_emails,
    SUM(mobile_number IS NULL OR TRIM(mobile_number) = '')
        AS missing_mobile,
    SUM(feedback_date IS NULL OR TRIM(feedback_date) = '')
        AS missing_dates
FROM customer_feedback_stage;

-- Duplicate feedback IDs
SELECT feedback_id, COUNT(*) AS record_count
FROM customer_feedback_stage
GROUP BY feedback_id
HAVING COUNT(*) > 1;

-- Repeated customer names (not automatically duplicates)
SELECT customer_name, COUNT(*) AS record_count
FROM customer_feedback_stage
GROUP BY customer_name
HAVING COUNT(*) > 1;

-- Review distinct category values
SELECT DISTINCT gender FROM customer_feedback_stage;
SELECT DISTINCT city FROM customer_feedback_stage;
SELECT DISTINCT channel FROM customer_feedback_stage;
SELECT DISTINCT issue_type FROM customer_feedback_stage;
SELECT DISTINCT resolution_status FROM customer_feedback_stage;

-- TEXT CLEANING

UPDATE customer_feedback_stage
SET customer_name =
    REGEXP_REPLACE(TRIM(customer_name), '[[:space:]]+', ' ');

UPDATE customer_feedback_stage
SET email = LOWER(TRIM(email));

UPDATE customer_feedback_stage
SET gender =
    CASE
        WHEN LOWER(TRIM(gender)) IN ('male', 'm') THEN 'Male'
        WHEN LOWER(TRIM(gender)) IN ('female', 'f') THEN 'Female'
        ELSE NULL
    END;
    
UPDATE customer_feedback_stage
SET satisfaction = NULL
WHERE LOWER(TRIM(satisfaction)) IN ('unknown', '');

select * from customer_feedback_stage;

UPDATE customer_feedback_stage
SET agent_name = NULL
WHERE LOWER(TRIM(agent_name)) IN ('unknown', '');

UPDATE customer_feedback_stage
SET city =
    CASE
        WHEN LOWER(TRIM(city)) = 'delhi' THEN 'Delhi'
        WHEN LOWER(TRIM(city)) IN ('gurgaon', 'gurugram')
            THEN 'Gurugram'
        WHEN LOWER(TRIM(city)) = 'mumbai' THEN 'Mumbai'
        WHEN LOWER(TRIM(city)) = 'noida' THEN 'Noida'
        ELSE NULLIF(TRIM(city), '')
    END;

UPDATE customer_feedback_stage
SET channel =
    CASE
        WHEN LOWER(TRIM(channel))
            IN ('website chat', 'webchat', 'web chat')
            THEN 'Website Chat'
        WHEN LOWER(TRIM(channel)) = 'email' THEN 'Email'
        WHEN LOWER(TRIM(channel))
            IN ('phone', 'phone call') THEN 'Phone'
        ELSE NULLIF(TRIM(channel), '')
    END;

UPDATE customer_feedback_stage
SET issue_type =
    CASE
        WHEN LOWER(TRIM(issue_type)) = 'delivery'
            THEN 'Delivery'
        WHEN LOWER(TRIM(issue_type)) = 'billing'
            THEN 'Billing'
        WHEN LOWER(TRIM(issue_type)) = 'product quality'
            THEN 'Product Quality'
        WHEN LOWER(TRIM(issue_type)) = 'customer service'
            THEN 'Customer Service'
        ELSE NULLIF(TRIM(issue_type), '')
    END;

UPDATE customer_feedback_stage
SET resolution_status =
    CASE
        WHEN LOWER(TRIM(resolution_status)) = 'resolved'
            THEN 'Resolved'
        WHEN LOWER(TRIM(resolution_status)) = 'pending'
            THEN 'Pending'
        WHEN LOWER(TRIM(resolution_status)) = 'open'
            THEN 'Open'
        ELSE NULLIF(TRIM(resolution_status), '')
    END;

-- 5. NUMERICAL CLEANING
-- Example business rules: age 0-100, rating 1-5,
-- response time 0-168 hours.
-- Confirm these rules for real business data.


UPDATE customer_feedback_stage
SET age = NULL
WHERE TRIM(age) = ''
   OR age NOT REGEXP '^[0-9]+$'
   OR CAST(age AS UNSIGNED) NOT BETWEEN 0 AND 100;

UPDATE customer_feedback_stage
SET rating = NULL
WHERE TRIM(rating) = ''
   OR rating NOT REGEXP '^[0-9]+$'
   OR CAST(rating AS UNSIGNED) NOT BETWEEN 1 AND 5;

UPDATE customer_feedback_stage
SET response_time_hours = NULL
WHERE TRIM(response_time_hours) = ''
   OR response_time_hours NOT REGEXP '^[0-9]+$'
   OR CAST(response_time_hours AS UNSIGNED) > 168;

-- Remove currency symbols, commas and spaces

UPDATE customer_feedback_stage
SET order_value =
    REPLACE(
        REPLACE(
            REPLACE(TRIM(order_value), '₹', ''),
            ',', ''
        ),
        ' ',
        ''
    );

UPDATE customer_feedback_stage
SET order_value = NULL
WHERE TRIM(order_value) = ''
   OR order_value NOT REGEXP '^[0-9]+([.][0-9]+)?$';

-- Normalize mobile numbers
UPDATE customer_feedback_stage
SET mobile_number =
    REPLACE(
        REPLACE(TRIM(mobile_number), ' ', ''),
        '-', ''
    );

UPDATE customer_feedback_stage
SET mobile_number = NULL
WHERE mobile_number IS NOT NULL
  AND mobile_number NOT REGEXP '^[6-9][0-9]{9}$';

-- Validate email format
UPDATE customer_feedback_stage
SET email = NULL
WHERE email IS NOT NULL
  AND email NOT REGEXP
      '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$';

 -- DATE STANDARDIZATION
-- Supported formats:
-- DD-MM-YYYY, DD/MM/YYYY, YYYY-MM-DD, YYYY/MM/DD
-- Impossible dates are rejected using month-day limits.

UPDATE customer_feedback_stage
SET feedback_date =
    CASE
        WHEN feedback_date REGEXP
             '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
         AND CAST(SUBSTRING(feedback_date, 4, 2)
                  AS UNSIGNED) BETWEEN 1 AND 12
         AND CAST(SUBSTRING(feedback_date, 1, 2)
                  AS UNSIGNED) BETWEEN 1 AND
             DAY(LAST_DAY(CONCAT(
                 SUBSTRING(feedback_date, 7, 4), '-',
                 SUBSTRING(feedback_date, 4, 2), '-01'
             )))
        THEN DATE_FORMAT(
                 STR_TO_DATE(feedback_date, '%d-%m-%Y'),
                 '%Y-%m-%d'
             )

        WHEN feedback_date REGEXP
             '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
         AND CAST(SUBSTRING(feedback_date, 4, 2)
                  AS UNSIGNED) BETWEEN 1 AND 12
         AND CAST(SUBSTRING(feedback_date, 1, 2)
                  AS UNSIGNED) BETWEEN 1 AND
             DAY(LAST_DAY(CONCAT(
                 SUBSTRING(feedback_date, 7, 4), '-',
                 SUBSTRING(feedback_date, 4, 2), '-01'
             )))
        THEN DATE_FORMAT(
                 STR_TO_DATE(feedback_date, '%d/%m/%Y'),
                 '%Y-%m-%d'
             )

        WHEN feedback_date REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
         AND CAST(SUBSTRING(feedback_date, 6, 2)
                  AS UNSIGNED) BETWEEN 1 AND 12
         AND CAST(SUBSTRING(feedback_date, 9, 2)
                  AS UNSIGNED) BETWEEN 1 AND
             DAY(LAST_DAY(CONCAT(
                 SUBSTRING(feedback_date, 1, 4), '-',
                 SUBSTRING(feedback_date, 6, 2), '-01'
             )))
        THEN DATE_FORMAT(
                 STR_TO_DATE(feedback_date, '%Y-%m-%d'),
                 '%Y-%m-%d'
             )

        WHEN feedback_date REGEXP
             '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
         AND CAST(SUBSTRING(feedback_date, 6, 2)
                  AS UNSIGNED) BETWEEN 1 AND 12
         AND CAST(SUBSTRING(feedback_date, 9, 2)
                  AS UNSIGNED) BETWEEN 1 AND
             DAY(LAST_DAY(CONCAT(
                 SUBSTRING(feedback_date, 1, 4), '-',
                 SUBSTRING(feedback_date, 6, 2), '-01'
             )))
        THEN DATE_FORMAT(
                 STR_TO_DATE(feedback_date, '%Y/%m/%d'),
                 '%Y-%m-%d'
             )

        ELSE NULL
    END;


-- DUPLICATE AUDIT
-- Flag duplicates; do not delete based on name alone.


SELECT feedback_id, COUNT(*) AS record_count
FROM customer_feedback_stage
GROUP BY feedback_id
HAVING COUNT(*) > 1;

SELECT
    customer_name,
    email,
    feedback_date,
    COUNT(*) AS record_count
FROM customer_feedback_stage
GROUP BY customer_name, email, feedback_date
HAVING COUNT(*) > 1;

SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY customer_name, email, feedback_date
           ORDER BY feedback_id
       ) AS duplicate_rank
FROM customer_feedback_stage;

-- CREATE FINAL TABLE WITH APPROPRIATE DATA TYPES

DROP TABLE IF EXISTS customer_feedback_cleaned;

CREATE TABLE customer_feedback_cleaned (
    feedback_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    customer_name VARCHAR(100),
    age TINYINT UNSIGNED,
    gender VARCHAR(10),
    city VARCHAR(50),
    email VARCHAR(150),
    mobile_number VARCHAR(10),
    feedback_date DATE,
    rating TINYINT UNSIGNED,
    satisfaction VARCHAR(50),
    channel VARCHAR(50),
    issue_type VARCHAR(80),
    resolution_status VARCHAR(50),
    response_time_hours INT UNSIGNED,
    order_value DECIMAL(12,2),
    comments VARCHAR(255),
    agent_name VARCHAR(100)
);

-- Insert only if feedback IDs are unique.
-- Duplicate IDs must be resolved through an explicit rule first.
INSERT INTO customer_feedback_cleaned
SELECT
    feedback_id,
    customer_id,
    NULLIF(TRIM(customer_name), ''),
    CAST(age AS UNSIGNED),
    gender,
    city,
    email,
    mobile_number,
    STR_TO_DATE(feedback_date, '%Y-%m-%d'),
    CAST(rating AS UNSIGNED),
    satisfaction,
    channel,
    issue_type,
    resolution_status,
    CAST(response_time_hours AS UNSIGNED),
    CAST(order_value AS DECIMAL(12,2)),
    comments,
    agent_name
FROM customer_feedback_stage
WHERE feedback_id IS NOT NULL
  AND feedback_id <> ''
  AND feedback_id IN (
      SELECT feedback_id
      FROM customer_feedback_stage
      GROUP BY feedback_id
      HAVING COUNT(*) = 1
  );


-- ============================================================
-- FINAL DATA QUALITY VALIDATION
-- ============================================================

-- Compare record counts
SELECT 'Raw' AS table_name, COUNT(*) AS total_records
FROM customer_feedback_raw

UNION ALL

SELECT 'Stage', COUNT(*)
FROM customer_feedback_stage

UNION ALL

SELECT 'Cleaned', COUNT(*)
FROM customer_feedback_cleaned;

-- Confirm data types
DESCRIBE customer_feedback_cleaned;

-- Check missing critical fields
SELECT
    SUM(feedback_id IS NULL) AS missing_feedback_id,
    SUM(customer_name IS NULL) AS missing_customer_name,
    SUM(feedback_date IS NULL) AS missing_feedback_date,
    SUM(rating IS NULL) AS missing_rating
FROM customer_feedback_cleaned;

-- Date range for time-based analysis
SELECT
    MIN(feedback_date) AS earliest_feedback_date,
    MAX(feedback_date) AS latest_feedback_date
FROM customer_feedback_cleaned;

-- Rating distribution
SELECT rating, COUNT(*) AS total_feedback
FROM customer_feedback_cleaned
GROUP BY rating
ORDER BY rating;

-- Channel distribution
SELECT channel, COUNT(*) AS total_feedback
FROM customer_feedback_cleaned
GROUP BY channel
ORDER BY total_feedback DESC;

-- Monthly feedback volume
SELECT
    DATE_FORMAT(feedback_date, '%Y-%m') AS feedback_month,
    COUNT(*) AS total_feedback
FROM customer_feedback_cleaned
WHERE feedback_date IS NOT NULL
GROUP BY DATE_FORMAT(feedback_date, '%Y-%m')
ORDER BY feedback_month;

-- Final sample
SELECT *
FROM customer_feedback_cleaned
ORDER BY feedback_id;

