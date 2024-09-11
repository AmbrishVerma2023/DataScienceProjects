/*

-----------------------------------------------------------------------------------------------------------------------------------
													    Guidelines
-----------------------------------------------------------------------------------------------------------------------------------

The provided document is a guide for the project. Follow the instructions and take the necessary steps to finish
the project in the SQL file			

-----------------------------------------------------------------------------------------------------------------------------------
                                                         Queries
                                               
-----------------------------------------------------------------------------------------------------------------------------------*/
  
/*-- QUESTIONS RELATED TO CUSTOMERS
     [Q1] What is the distribution of customers across states?*/

/*the distribution is calculated based on grouping the data by state and then counting all the customer IDs for each state*/
SELECT 
    COUNT(customer_id) AS cust_state_distribution, state
FROM
    customer_t
GROUP BY state
ORDER BY cust_state_distribution DESC;

-- ---------------------------------------------------------------------------------------------------------------------------------

/* [Q2] What is the average rating in each quarter?
-- Very Bad is 1, Bad is 2, Okay is 3, Good is 4, Very Good is 5.*/

/*in the below, the text for customer feedback provided is converted into numerics in the ascending order of low to high rating. 
It is then averaged for all the ratings provided in each quarter*/
SELECT 
    AVG(CASE
        WHEN CUSTOMER_FEEDBACK = 'VERY BAD' THEN 1
        WHEN CUSTOMER_FEEDBACK = 'BAD' THEN 2
        WHEN CUSTOMER_FEEDBACK = 'OKAY' THEN 3
        WHEN CUSTOMER_FEEDBACK = 'GOOD' THEN 4
        ELSE 5
    END) AS AVG_CUST_FEEDBACK,
    QUARTER_NUMBER
FROM
    ORDER_T
GROUP BY QUARTER_NUMBER
ORDER BY QUARTER_NUMBER DESC;
-- ---------------------------------------------------------------------------------------------------------------------------------
/* [Q3] Are customers getting more dissatisfied over time? */

WITH FEEDBACK_DATA AS
(SELECT 
/*CONVERT THE TEXT BASED FEEDBACK TO NUMERIC*/
CASE WHEN CUSTOMER_FEEDBACK='VERY BAD' THEN 1
	 WHEN CUSTOMER_FEEDBACK='BAD' THEN 2
     WHEN CUSTOMER_FEEDBACK='OKAY' THEN 3 
     WHEN CUSTOMER_FEEDBACK='GOOD' THEN 4
     ELSE 5 END AS CUST_FEEDBACK, QUARTER_NUMBER, ORDER_ID
FROM ORDER_T), 
QRTR_CNT AS
/*COUNT OF EACH FEEDBACK VALUE WITHIN EACH QUARTER AND FOR EACH FEEDBACK VALUE*/
(SELECT 
    COUNT(CUST_FEEDBACK) FB_CNT, CUST_FEEDBACK, QUARTER_NUMBER
FROM
    FEEDBACK_DATA
GROUP BY QUARTER_NUMBER , CUST_FEEDBACK), 
QRTR_AVG AS
/*AVERAGE OF FEEDBACK, percentage of feedbacks for each feedback value per quarter*/
(SELECT 
    AVG(CUST_FEEDBACK) AVG_FB,
    COUNT(CUST_FEEDBACK) AS TOTAL_FEEDBACKS,
    QUARTER_NUMBER
FROM
    FEEDBACK_DATA
GROUP BY QUARTER_NUMBER)
SELECT DISTINCT
    AVG_FB AS AVERAGE_CUSTOMER_FEEDBACK,
    FB_CNT AS FEEDBACK_COUNT,
    FEEDBACK_DATA.CUST_FEEDBACK AS CUSTOMER_FEEDBACK,
    FEEDBACK_DATA.QUARTER_NUMBER,
    100 * (QRTR_CNT.FB_CNT / QRTR_AVG.TOTAL_FEEDBACKS) AS FEEDBACK_PERCENT
FROM
    FEEDBACK_DATA
JOIN
    QRTR_AVG ON FEEDBACK_DATA.QUARTER_NUMBER = QRTR_AVG.QUARTER_NUMBER
JOIN
    QRTR_CNT ON FEEDBACK_DATA.QUARTER_NUMBER = QRTR_CNT.QUARTER_NUMBER
        AND FEEDBACK_DATA.CUST_FEEDBACK = QRTR_CNT.CUST_FEEDBACK
ORDER BY FEEDBACK_DATA.QUARTER_NUMBER ASC , FEEDBACK_DATA.CUST_FEEDBACK ASC;
  
-- ---------------------------------------------------------------------------------------------------------------------------------
/*[Q4] Which are the top 5 vehicle makers preferred by the customer.
Hint: For each vehicle make what is the count of the customers.*/

SELECT 
    VEHICLE_MAKER, 
    COUNT(ORDER_ID) NUMBER_VEHICLES_ORDERED
    /*count the number of vehicles sold, grouped by the vehicle maker, sort them in descending order and then display the first 5 rows*/
FROM
    PRODUCT_T PROD
JOIN
    ORDER_T ORDERS ON PROD.PRODUCT_ID = ORDERS.PRODUCT_ID
GROUP BY VEHICLE_MAKER
ORDER BY NUMBER_VEHICLES_ORDERED DESC
LIMIT 5;

-- ---------------------------------------------------------------------------------------------------------------------------------
/*[Q5] What is the most preferred vehicle maker in each state?*/

WITH VEHICLE_COUNT AS
(SELECT 
DISTINCT 
	PROD.VEHICLE_MAKER AS VEHICLE_MAKER, 
    CUST.STATE AS STATE, 
    COUNT(ORDER_ID) OVER (PARTITION BY STATE, VEHICLE_MAKER) AS CNT
/*THE CTE: VEHICLE_COUNT GIVES A COUNT OF VEHICLES ORDERED WITHIN EACH STATE AND FOR EACH VEHICLE MAKER*/
FROM CUSTOMER_T CUST 
JOIN ORDER_T ORDERS ON CUST.CUSTOMER_ID=ORDERS.CUSTOMER_ID 
JOIN PRODUCT_T PROD ON PROD.PRODUCT_ID=ORDERS.PRODUCT_ID)
SELECT X.STATE, 
GROUP_CONCAT(VEHICLE_MAKER) AS VEHICLE_MAKERS_OF_CHOICE 
/*IN THE FIELD LIST, THE GROUP_CONCAT FUNCTION LISTS ALL THE VEHICLE MAKERS WITHIN EACH STATE WHO HAVE THE MOST NUMBER OF VEHICLES ORDERED*/
FROM
(SELECT 
	VEHICLE_MAKER, 
    STATE, 
    RANK() OVER (PARTITION BY STATE ORDER BY CNT DESC) RNK
/*THE RANK FUNCTION RANKS THE COUNT OF VEHICLES ORDERED PER STATE AND VEHICLE MAKE IN THE DESCENDING ORDER*/    
    FROM VEHICLE_COUNT) X 
WHERE X.RNK=1 
GROUP BY STATE 
ORDER BY STATE;

-- ---------------------------------------------------------------------------------------------------------------------------------
/*QUESTIONS RELATED TO REVENUE and ORDERS 
-- [Q6] What is the trend of number of orders by quarters?*/

SELECT 
    COUNT(ORDER_ID) NUMBER_VEHICLES_ORDERED, QUARTER_NUMBER
FROM
    ORDER_T
GROUP BY QUARTER_NUMBER
ORDER BY QUARTER_NUMBER;

-- ---------------------------------------------------------------------------------------------------------------------------------
/* [Q7] What is the quarter over quarter % change in revenue? 
Hint: Quarter over Quarter percentage change in revenue means what is the change in revenue from the subsequent quarter to the previous quarter in percentage.
      To calculate you need to use the common table expression to find out the sum of revenue for each quarter.
      Then use that CTE along with the LAG function to calculate the QoQ percentage change in revenue.
*/
      
WITH QRTR_RVNUE_DTLS AS 
(SELECT 
	QRTR_REVENUE.QUARTER_NUMBER, 
	QRTR_REVENUE.SM AS QRTR_REVENUE, 
	LAG(QRTR_REVENUE.SM, 1) OVER (ORDER BY QRTR_REVENUE.QUARTER_NUMBER) PREV_QRTR_REVENUE 
FROM
	(SELECT 
		DISTINCT 
			QUARTER_NUMBER, 
			SUM(VEHICLE_PRICE) SM
	FROM ORDER_T ORDERS 
	GROUP BY QUARTER_NUMBER) QRTR_REVENUE)
/*within the cte, qrtr_revenue calculates the total of revenue in each quarter. QRTR_RVNUE_DTLS displays the total revenue for previous quarter for each row(quarter)*/
SELECT 
    QUARTER_NUMBER,
    QRTR_REVENUE,
    PREV_QRTR_REVENUE,
    (QRTR_REVENUE - PREV_QRTR_REVENUE) AS REVENUE_INCREASE_PER_QRTR,
    ((QRTR_REVENUE - PREV_QRTR_REVENUE) / PREV_QRTR_REVENUE) * 100 AS REVENUE_INCREASE_PERCENT
FROM
    QRTR_RVNUE_DTLS
ORDER BY QUARTER_NUMBER DESC;      

-- ---------------------------------------------------------------------------------------------------------------------------------
/* [Q8] What is the trend of revenue and orders by quarters?
Hint: Find out the sum of revenue and count the number of orders for each quarter.*/

SELECT 
    COUNT(order_ID) TOTAL_ORDERS,
    SUM(VEHICLE_PRICE) TOTAL_REVENUE,
    QUARTER_NUMBER
FROM
    ORDER_T
GROUP BY QUARTER_NUMBER
ORDER BY QUARTER_NUMBER DESC;

-- ---------------------------------------------------------------------------------------------------------------------------------
/* QUESTIONS RELATED TO SHIPPING 
    [Q9] What is the average discount offered for different types of credit cards?
Hint: Find out the average of discount for each credit card type.*/

SELECT 
    AVG(DISCOUNT) DISCOUNT_AVERAGE, 
    CREDIT_CARD_TYPE
/*discount values(in orders table) averaged per credit card type(in customer table)*/    
FROM
    ORDER_T ORDERS
JOIN
    CUSTOMER_T CUST ON ORDERS.CUSTOMER_ID = CUST.CUSTOMER_ID
GROUP BY CREDIT_CARD_TYPE 
ORDER BY DISCOUNT_AVERAGE DESC;

-- ---------------------------------------------------------------------------------------------------------------------------------

/* [Q10] What is the average time taken to ship the placed orders for each quarters?
	Hint: Use the dateiff function to find the difference between the ship date and the order date.
*/
SELECT 
    AVG(DATEDIFF(SHIP_DATE, ORDER_DATE)) ORDER_PROCESS_DURATION, 
    /*DIFFERENCE BETWEEN SHIP_DATE AND ORDER_DATE GIVES ORDER_PROCESS_DURATION. THE NUMBER OF DAYS THUS OBTAINED IS THEN AVERAGED PER QUARTER */
    QUARTER_NUMBER
FROM
    ORDER_T GROUP BY QUARTER_NUMBER ORDER BY QUARTER_NUMBER DESC;

-- --------------------------------------------------------Done----------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------------------------------------------------



