-- ============================================================
-- TASK 5.2: FIND RECORDS THAT JOINS MAY EXCLUDE
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Relationship examined: flights (producer) and bookings
-- (event). Every booking must point to a flight (foreign key),
-- but a flight does not need to have any bookings.
-- ============================================================


-- ============================================================
-- PART A: COMPARE INNER JOIN AND LEFT JOIN
-- ============================================================

-- ------------------------------------------------------------
-- 5.2A.1: How many bookings does every flight have, including
-- flights with none?
-- Requirement: LEFT JOIN returning all producers.
-- Question: For all 15 flights, how many bookings did each one
-- receive?
-- ------------------------------------------------------------

SELECT
    f.flight_id,
    f.flight_number,
    f.is_active,
    COUNT(b.booking_id) AS total_bookings
FROM flights f
LEFT JOIN bookings b
  ON b.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY total_bookings, f.flight_id;

-- Finding: 15 rows, one per flight. VN214 (flight 14) and
-- VN215 (flight 15) have 0 bookings. COUNT(b.booking_id)
-- returns 0 for them because the LEFT JOIN fills their booking
-- columns with NULL, and COUNT ignores NULLs.


-- ------------------------------------------------------------
-- 5.2A.2: The same question written with INNER JOIN.
-- Requirement: Equivalent INNER JOIN.
-- Question: How many bookings does each flight have, counting
-- only flights that appear in bookings?
-- ------------------------------------------------------------

SELECT
    f.flight_id,
    f.flight_number,
    f.is_active,
    COUNT(b.booking_id) AS total_bookings
FROM flights f
JOIN bookings b
  ON b.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY total_bookings, f.flight_id;

-- Finding: 13 rows. VN214 and VN215 are missing entirely: an
-- INNER JOIN keeps only flights with at least one matching
-- booking, so a flight with no bookings has nothing to match
-- and is dropped instead of being shown with 0.


-- ------------------------------------------------------------
-- 5.2A.3: How many flights does the INNER JOIN exclude?
-- Requirement: Count of producers excluded by the inner join,
-- using unique identifiers.
-- Question: How many distinct flights does each join return,
-- and how many does the INNER JOIN leave out?
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(DISTINCT f.flight_id)
       FROM flights f
       LEFT JOIN bookings b ON b.flight_id = f.flight_id) AS left_join_flights,
    (SELECT COUNT(DISTINCT f.flight_id)
       FROM flights f
       JOIN bookings b ON b.flight_id = f.flight_id)      AS inner_join_flights,
    (SELECT COUNT(DISTINCT f.flight_id)
       FROM flights f
       LEFT JOIN bookings b ON b.flight_id = f.flight_id)
  - (SELECT COUNT(DISTINCT f.flight_id)
       FROM flights f
       JOIN bookings b ON b.flight_id = f.flight_id)      AS flights_excluded;

-- Finding: LEFT JOIN 15 flights, INNER JOIN 13 flights, so the
-- INNER JOIN excludes 2 flights (VN214 and VN215).
-- COUNT(DISTINCT f.flight_id) is used because the joined rows
-- contain one row per booking: counting rows would count
-- VN206 21 times instead of once.


-- ============================================================
-- PART B: EXPLORE RIGHT JOIN AND FULL OUTER JOIN
-- ============================================================

-- ------------------------------------------------------------
-- 5.2B.1: The LEFT JOIN from 5.2A.1 written as a RIGHT JOIN.
-- Requirement: RIGHT JOIN returning the same records.
-- Question: For all 15 flights, how many bookings did each one
-- receive? (Tables listed in the opposite order.)
-- ------------------------------------------------------------

SELECT
    f.flight_id,
    f.flight_number,
    f.is_active,
    COUNT(b.booking_id) AS total_bookings
FROM bookings b
RIGHT JOIN flights f
  ON b.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_number, f.is_active
ORDER BY total_bookings, f.flight_id;

-- Finding: 15 rows, the same as 5.2A.1, with VN214 and VN215
-- at 0 bookings. "bookings RIGHT JOIN flights" keeps every
-- flight, exactly as "flights LEFT JOIN bookings" does.


-- ------------------------------------------------------------
-- 5.2B.2: Do the LEFT JOIN and RIGHT JOIN really return the
-- same rows?
-- Requirement: Verify the results match, not just the counts.
-- Question: Is there any row in one result that is missing
-- from the other?
-- ------------------------------------------------------------

WITH
left_result AS (
    SELECT f.flight_id, f.flight_number, f.is_active,
           COUNT(b.booking_id) AS total_bookings
    FROM flights f
    LEFT JOIN bookings b ON b.flight_id = f.flight_id
    GROUP BY f.flight_id, f.flight_number, f.is_active
),
right_result AS (
    SELECT f.flight_id, f.flight_number, f.is_active,
           COUNT(b.booking_id) AS total_bookings
    FROM bookings b
    RIGHT JOIN flights f ON b.flight_id = f.flight_id
    GROUP BY f.flight_id, f.flight_number, f.is_active
)

SELECT 'LEFT minus RIGHT' AS comparison, *
FROM (SELECT * FROM left_result
      EXCEPT
      SELECT * FROM right_result) AS diff_lr

UNION ALL

SELECT 'RIGHT minus LEFT' AS comparison, *
FROM (SELECT * FROM right_result
      EXCEPT
      SELECT * FROM left_result) AS diff_rl;

-- Finding: 0 rows. No row exists in one result without the
-- other, so the LEFT JOIN and RIGHT JOIN return identical
-- results, including the same booking counts.


-- ------------------------------------------------------------
-- 5.2B.3: What does a FULL OUTER JOIN show about flights and
-- bookings?
-- Requirement: FULL OUTER JOIN including matched and unmatched
-- records from both tables.
-- Question: How many joined rows are matched, how many are
-- flights with no booking, and how many are bookings with no
-- flight?
-- ------------------------------------------------------------

SELECT
    CASE
        WHEN f.flight_id IS NULL  THEN 'Booking with no flight'
        WHEN b.booking_id IS NULL THEN 'Flight with no bookings'
        ELSE 'Matched'
    END                          AS match_status,
    COUNT(*)                     AS joined_rows,
    COUNT(DISTINCT f.flight_id)  AS distinct_flights,
    COUNT(DISTINCT b.booking_id) AS distinct_bookings,
    STRING_AGG(DISTINCT f.flight_number, ', ') AS flights
FROM flights f
FULL OUTER JOIN bookings b
  ON b.flight_id = f.flight_id
GROUP BY match_status
ORDER BY match_status;

-- Finding: Two kinds of rows appear.
--   Matched: 200 rows, 13 flights, 200 bookings.
--   Flight with no bookings: 2 rows (VN214 and VN215).
-- No 'Booking with no flight' row appears: every booking points
-- to a real flight, which the foreign key fk_bookings_prod
-- guarantees. A FULL OUTER JOIN checks both directions in one
-- query; a LEFT or RIGHT JOIN checks only one side.


-- ============================================================
-- PART C: FIND FLIGHTS WITH NO BOOKINGS, TWO WAYS
-- ============================================================

-- ------------------------------------------------------------
-- 5.2C.1: Which flights have never been booked? (NOT EXISTS)
-- Requirement: NOT EXISTS.
-- Question: Which flights have no booking at all, and what do
-- we know about them?
-- ------------------------------------------------------------

SELECT
    f.flight_id,
    f.flight_number,
    f.origin_country,
    f.seat_capacity,
    f.is_active,
    f.first_scheduled_on
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.flight_id = f.flight_id
)
ORDER BY f.flight_id;

-- Finding: 2 flights: VN214 (flight 14, Vietnam, 303 seats)
-- and VN215 (flight 15, Thailand, 132 seats). Both are marked
-- active (is_active = true), yet neither has a single booking.


-- ------------------------------------------------------------
-- 5.2C.2: Which flights have never been booked? (EXCEPT)
-- Requirement: EXCEPT.
-- Question: Which flight IDs exist in flights but never appear
-- in bookings?
-- ------------------------------------------------------------

SELECT flight_id
FROM flights
EXCEPT
SELECT flight_id
FROM bookings
ORDER BY flight_id;

-- Finding: The same 2 flights: flight_id 14 and 15.


-- ------------------------------------------------------------
-- 5.2C.3: Do NOT EXISTS and EXCEPT find the same flights?
-- Requirement: Compare the two results.
-- Question: Is any flight found by one approach but not the
-- other?
-- ------------------------------------------------------------

WITH
not_exists_result AS (
    SELECT f.flight_id
    FROM flights f
    WHERE NOT EXISTS (
        SELECT 1 FROM bookings b WHERE b.flight_id = f.flight_id
    )
),
except_result AS (
    SELECT flight_id FROM flights
    EXCEPT
    SELECT flight_id FROM bookings
)

SELECT
    (SELECT COUNT(*) FROM not_exists_result) AS not_exists_flights,
    (SELECT COUNT(*) FROM except_result)     AS except_flights,
    (SELECT COUNT(*) FROM (
        (SELECT * FROM not_exists_result EXCEPT SELECT * FROM except_result)
        UNION ALL
        (SELECT * FROM except_result EXCEPT SELECT * FROM not_exists_result)
    ) AS diff)                               AS flights_in_only_one;

-- Finding: Both approaches find 2 flights, and 0 flights
-- appear in only one result, so they identify the same flights
-- (14 and 15).
-- NOT EXISTS checks each flight row for a matching booking and
-- can return any column from flights. EXCEPT compares two lists
-- of IDs as sets, so it returns only the columns both lists
-- share (flight_id) and removes duplicates.
