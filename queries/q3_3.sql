
-- ============================================================
-- TASK 3.3: HAND THE TEAM A CORRECTED QUERY
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Question: Which passengers have at least one disputed booking?
-- ============================================================


-- ------------------------------------------------------------
-- 3.3.1: Find passengers involved in disputed bookings using IN.
-- Requirement: Subquery using IN.
-- Purpose: Identify passengers whose IDs appear in bookings
-- with a disputed status.
-- ------------------------------------------------------------

SELECT
    passenger_id,
    passenger_name
FROM passengers
WHERE passenger_id IN (
    SELECT passenger_id
    FROM bookings
    WHERE booking_status = 'disputed'
)
ORDER BY passenger_id;

-- Finding: The IN subquery returned 7 passengers who
-- have at least one disputed booking.
-- The inner query identifies passenger IDs associated
-- with disputed bookings, while the outer query
-- retrieves their names from the passengers table.


-- ------------------------------------------------------------
-- 3.3.2: Find passengers involved in disputed bookings using WITH.
-- Requirement: Common Table Expression (CTE).
-- Purpose: Identify disputed passengers in a temporary
-- result set before retrieving passenger information.
-- ------------------------------------------------------------

WITH disputed_passengers AS (
    SELECT passenger_id
    FROM bookings
    WHERE booking_status = 'disputed'
)

SELECT
    passenger_id,
    passenger_name
FROM passengers
WHERE passenger_id IN (
    SELECT passenger_id
    FROM disputed_passengers
)
ORDER BY passenger_id;

-- Finding: The CTE returned the same 7 passengers as 3.3A.
-- The WITH clause creates a named result set containing
-- passenger IDs associated with disputed bookings.
-- The main query then retrieves the matching passengers.


-- ------------------------------------------------------------
-- 3.3.3: Find passengers involved in disputed bookings using EXISTS.
-- Requirement: Third distinct approach using EXISTS.
-- Purpose: Check whether each passenger has at least
-- one booking with a disputed status.
-- ------------------------------------------------------------

SELECT
    p.passenger_id,
    p.passenger_name
FROM passengers p
WHERE EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.passenger_id = p.passenger_id
      AND b.booking_status = 'disputed'
)
ORDER BY p.passenger_id;

-- Finding: The EXISTS query returned the same 7 passengers
-- as 3.3.1 and 3.3.2.
-- EXISTS checks whether each passenger has at least
-- one disputed booking without needing to retrieve
-- every matching booking.


-- ------------------------------------------------------------
-- 3.3.4: Verify that all three queries return identical results.
-- Requirement: Compare actual rows, not just row counts.
-- Purpose: Use EXCEPT to identify differences between results.
-- ------------------------------------------------------------

WITH
query_a AS (
    SELECT passenger_id, passenger_name
    FROM passengers
    WHERE passenger_id IN (
        SELECT passenger_id
        FROM bookings
        WHERE booking_status = 'disputed'
    )
),

query_b AS (
    WITH disputed_passengers AS (
        SELECT passenger_id
        FROM bookings
        WHERE booking_status = 'disputed'
    )
    SELECT passenger_id, passenger_name
    FROM passengers
    WHERE passenger_id IN (
        SELECT passenger_id
        FROM disputed_passengers
    )
),

query_c AS (
    SELECT p.passenger_id, p.passenger_name
    FROM passengers p
    WHERE EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.passenger_id = p.passenger_id
          AND b.booking_status = 'disputed'
    )
)

SELECT 'A minus B' AS comparison, *
FROM (
    SELECT * FROM query_a
    EXCEPT
    SELECT * FROM query_b
) AS diff_ab

UNION ALL

SELECT 'B minus A' AS comparison, *
FROM (
    SELECT * FROM query_b
    EXCEPT
    SELECT * FROM query_a
) AS diff_ba

UNION ALL

SELECT 'A minus C' AS comparison, *
FROM (
    SELECT * FROM query_a
    EXCEPT
    SELECT * FROM query_c
) AS diff_ac

UNION ALL

SELECT 'C minus A' AS comparison, *
FROM (
    SELECT * FROM query_c
    EXCEPT
    SELECT * FROM query_a
) AS diff_ca;

-- Finding: The EXCEPT comparison returned 0 rows,
-- indicating no differences between the three result sets.
-- All three approaches returned the same 7 passengers:
-- IDs 1, 3, 5, 9, 16, 24, and 25.
-- This confirms that the IN subquery, CTE, and EXISTS
-- approaches produce identical results for this dataset.


-- ============================================================
-- 3.3.5: Under what condition could query equivalence break?
-- ============================================================

-- Duplicate disputed bookings could cause different results
-- if a regular JOIN were used instead of EXISTS.
-- A passenger with multiple disputed bookings could appear
-- multiple times in a JOIN result, while IN and EXISTS
-- return each matching passenger only once.
--
-- Our three current queries remain equivalent because
-- they use membership checks rather than a regular JOIN.

-- Exploration: How are booking statuses related to cancellation reasons?
-- Purpose: Identify how many bookings belong to each combination
-- of booking status and cancellation reason.

SELECT
    booking_status,
    cancellation_reason,
    COUNT(*) AS total_bookings
FROM bookings
GROUP BY booking_status, cancellation_reason
ORDER BY booking_status, cancellation_reason;