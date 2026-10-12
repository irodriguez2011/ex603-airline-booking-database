-- ============================================================
-- TASK 3.2: FIND THE BUG
-- Theme: Airline Booking
-- Database: ex603_data
-- ============================================================


-- ============================================================
-- PART A: THE ROWS THAT VANISHED
-- Demonstrate how SQL's NULL handling can silently omit rows.
-- ============================================================

-- Exploration: What cancellation reasons exist in the database?

SELECT DISTINCT cancellation_reason
FROM bookings
ORDER BY cancellation_reason;


-- ============================================================
-- TASK 3.2A: THE ROWS THAT VANISHED
-- ============================================================


-- 3.2A.1: How many bookings have a cancellation reason
-- different from 'Passenger no show'?
-- Purpose: Demonstrate how inequality excludes NULL values.

SELECT COUNT(*) AS filtered_bookings
FROM bookings
WHERE cancellation_reason != 'Passenger no show';

-- Finding: The query returned 22 bookings with a
-- cancellation reason other than 'Passenger no show'.
-- It excluded 166 bookings with NULL cancellation reasons.


-- ============================================================

-- 3.2A.2: How many bookings have missing cancellation reasons?
-- Purpose: Count the NULL records excluded by the original query.

SELECT COUNT(*) AS missing_reason_count
FROM bookings
WHERE cancellation_reason IS NULL;

-- Finding: 166 bookings have NULL cancellation reasons.
-- These records were excluded by the original query.


-- ============================================================

-- 3.2A.3: How many bookings have the exact cancellation
-- reason 'Passenger no show'?
-- Purpose: Count records intentionally excluded by the filter.

SELECT COUNT(*) AS matching_reason_count
FROM bookings
WHERE cancellation_reason = 'Passenger no show';

-- Finding: 12 bookings have 'Passenger no show' as their
-- cancellation reason. These records were intentionally
-- excluded by the original inequality filter.


-- ============================================================

-- 3.2A.4: How many bookings exist in total?
-- Purpose: Compare all counts with the total population.

SELECT COUNT(*) AS total_bookings
FROM bookings;

-- Finding: The bookings table contains 200 total records.
-- Of these, 22 have a cancellation reason other than
-- 'Passenger no show', 166 have NULL cancellation reasons,
-- and 12 have 'Passenger no show' as their cancellation reason.
-- All three categories add up to the total of 200 bookings.


-- ============================================================

-- 3.2A.5: How can we fix the query to include NULL reasons?
-- Purpose: Repair the original query using IS NULL.

SELECT COUNT(*) AS corrected_bookings
FROM bookings
WHERE cancellation_reason != 'Passenger no show'
   OR cancellation_reason IS NULL;

-- Finding: The corrected query returned 188 bookings,
-- compared to only 22 bookings in the original query.
-- Adding OR cancellation_reason IS NULL recovered 166
-- records that were previously excluded.
-- The remaining 12 bookings were excluded because their
-- cancellation reason was 'Passenger no show'.

-- ============================================================
-- END OF PART A
-- ============================================================


-- ============================================================
-- TASK 3.2B: THE ALIAS THAT DID NOT EXIST YET
-- ============================================================

 -- Exploration: What is the range of fares in our bookings?

SELECT
    MIN(fare_paid) AS lowest_fare,
    MAX(fare_paid) AS highest_fare
FROM bookings;


-- ------------------------------------------------------------
-- 3.2B.1: Can a calculated column alias be used in WHERE?
-- Purpose: Demonstrate why an alias defined in SELECT
-- cannot be referenced in WHERE at the same query level.
-- ------------------------------------------------------------

-- SELECT
--     booking_id,
--     fare_paid,
--     fare_paid * 0.10 AS service_fee
-- FROM bookings
-- WHERE service_fee > 5;

-- Finding: PostgreSQL returned the following error:
-- [42703] ERROR: column "service_fee" does not exist
--   Position: 95
--
-- Explanation: The WHERE clause cannot reference service_fee
-- because the alias is defined in SELECT at the same query level.
-- WHERE is logically evaluated before SELECT.


-- ------------------------------------------------------------
-- 3.2B.2: How can we fix the alias error by repeating
-- the calculation directly in WHERE?
-- Purpose: Filter bookings by their calculated service fee
-- without referencing the alias in WHERE.
-- ------------------------------------------------------------

SELECT
    booking_id,
    fare_paid,
    fare_paid * 0.10 AS service_fee
FROM bookings
WHERE fare_paid * 0.10 > 5;

-- Finding: The corrected query returned 3 bookings with
-- calculated service fees greater than $5.
-- Repeating the calculation directly in WHERE resolved
-- the alias error and successfully filtered the results.


-- ------------------------------------------------------------
-- 3.2B.3: How can we fix the alias error using a subquery?
-- Purpose: Calculate the service fee in an inner query
-- so the outer query can filter using its alias.
-- ------------------------------------------------------------

SELECT
    booking_id,
    fare_paid,
    service_fee
FROM (
    SELECT
        booking_id,
        fare_paid,
        fare_paid * 0.10 AS service_fee
    FROM bookings
) AS booking_fees
WHERE service_fee > 5;

-- Finding: The subquery returned 3 bookings with calculated
-- service fees greater than $5, matching the results of 3.2B.2.
-- By calculating service_fee in the inner query, the outer
-- query can reference the alias in its WHERE clause.
-- Both corrected approaches returned the same booking IDs:
-- 43, 78, and 104.
