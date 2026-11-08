-- ============================================================
-- TASK 5.3: UNDERSTAND JOIN PERFORMANCE AND EXECUTION PLANS
-- Theme: Airline Booking
-- Database: ex603_data (PostgreSQL 16)
-- ============================================================


-- ============================================================
-- PART A: EXPLORE CROSS JOIN
-- ============================================================

-- ------------------------------------------------------------
-- 5.3A.1: How many rows does a CROSS JOIN of airports and
-- flights produce?
-- Requirement: CROSS JOIN between two small tables, with both
-- source counts and the result count.
-- Question: How many rows are in airports and in flights, and
-- does their CROSS JOIN return exactly their product?
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM airports)                AS airport_rows,
    (SELECT COUNT(*) FROM flights)                 AS flight_rows,
    (SELECT COUNT(*) FROM airports)
  * (SELECT COUNT(*) FROM flights)                 AS expected_product,
    (SELECT COUNT(*)
       FROM airports
       CROSS JOIN flights)                         AS cross_join_rows,
    (SELECT COUNT(*) FROM flight_routes)           AS actual_routes;

-- Finding: 5 airports x 15 flights = 75, and the CROSS JOIN
-- returns 75 rows. It pairs every airport with every flight,
-- whether or not the flight goes there. Only 25 of those 75
-- pairings are real routes (flight_routes), so 50 of the
-- CROSS JOIN rows describe routes that do not exist.


-- ------------------------------------------------------------
-- 5.3A.2: When is a Cartesian product useful?
-- Requirement: CROSS JOIN used on purpose.
-- Question: For every booking country and every booking
-- status, including combinations with no bookings, how many
-- bookings are there?
-- ------------------------------------------------------------

WITH
countries AS (SELECT DISTINCT booking_country FROM bookings),
statuses  AS (SELECT DISTINCT booking_status  FROM bookings)

SELECT
    c.booking_country,
    s.booking_status,
    COUNT(b.booking_id) AS total_bookings
FROM countries c
CROSS JOIN statuses s
LEFT JOIN bookings b
  ON b.booking_country = c.booking_country
 AND b.booking_status  = s.booking_status
GROUP BY c.booking_country, s.booking_status
ORDER BY c.booking_country, s.booking_status;

-- Finding: 5 countries x 3 statuses = 15 rows. Thailand /
-- disputed now appears with 0 bookings. In Unit 4's GROUP BY
-- (q4_1.sql, 4.1.4) that row was simply missing, because
-- GROUP BY only returns combinations that exist. The CROSS JOIN
-- builds the complete grid first, so a regional report can show
-- a true zero instead of a gap.


-- ------------------------------------------------------------
-- 5.3A.3: What does an accidental Cartesian product look like?
-- Requirement: CROSS JOIN as a query error.
-- Question: How many rows come back if bookings and flights
-- are joined with no join condition?
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM bookings)               AS booking_rows,
    (SELECT COUNT(*) FROM flights)                AS flight_rows,
    (SELECT COUNT(*)
       FROM bookings, flights)                    AS rows_without_on,
    (SELECT COUNT(*)
       FROM bookings b
       JOIN flights f ON f.flight_id = b.flight_id) AS rows_with_on;

-- Finding: Without a join condition, 200 bookings x 15 flights
-- = 3,000 rows, each booking paired with every flight. With
-- the ON condition, the result is the correct 200 rows, one
-- per booking. A total that is suddenly 15 times too large is
-- the usual sign of a missing or wrong join condition.


-- ============================================================
-- PART B: EXAMINE A QUERY EXECUTION PLAN
-- ============================================================

-- ------------------------------------------------------------
-- 5.3B.1: How does PostgreSQL plan the three-table join from
-- 5.1.1?
-- Requirement: EXPLAIN.
-- Question: Which join algorithms and access paths does the
-- planner choose for passengers + bookings + flights?
-- ------------------------------------------------------------

EXPLAIN
SELECT
    f.flight_number,
    p.passenger_id,
    p.passenger_name,
    b.booking_id,
    b.booked_at,
    b.booking_status,
    b.cancellation_reason
FROM bookings b
JOIN passengers p
  ON p.passenger_id = b.passenger_id
JOIN flights f
  ON f.flight_id = b.flight_id
WHERE f.flight_number IN ('VN202', 'VN203', 'VN211')
ORDER BY f.flight_number, b.booked_at;

-- Finding: Two Nested Loop joins, then a Sort.
--   Inner loop: Seq Scan on bookings (all 200 rows), and for
--     each booking an Index Scan on flights_pkey to find its
--     flight. A Memoize node caches each flight lookup.
--   Outer loop: for each remaining booking, an Index Scan on
--     passengers_pkey to find the passenger.
-- No Hash Join or Merge Join is used. The planner estimates
-- only 5 rows will come out of the joins.


-- ------------------------------------------------------------
-- 5.3B.2: What actually happens when the plan runs?
-- Requirement: EXPLAIN ANALYZE (safe here: read-only SELECT).
-- Question: How many rows does each step really produce, and
-- how long does the query take?
-- ------------------------------------------------------------

EXPLAIN ANALYZE
SELECT
    f.flight_number,
    p.passenger_id,
    p.passenger_name,
    b.booking_id,
    b.booked_at,
    b.booking_status,
    b.cancellation_reason
FROM bookings b
JOIN passengers p
  ON p.passenger_id = b.passenger_id
JOIN flights f
  ON f.flight_id = b.flight_id
WHERE f.flight_number IN ('VN202', 'VN203', 'VN211')
ORDER BY f.flight_number, b.booked_at;

-- Finding: Same plan. The joins really return 45 rows, not the
-- estimated 5. Memoize had 187 hits and 13 misses: it looked up
-- only the 13 distinct flights and reused the answer for the
-- other 187 bookings. The passenger index was used 45 times
-- (loops=45). Total execution time is well under 1 ms.


-- ------------------------------------------------------------
-- 5.3B.3: Why was the row estimate wrong?
-- Requirement: Supporting evidence for reading the plan.
-- Question: How many rows does each table hold, and has
-- PostgreSQL collected statistics on it?
-- ------------------------------------------------------------

SELECT
    relname AS table_name,
    n_live_tup AS live_rows,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE relname IN ('bookings', 'flights', 'passengers')
ORDER BY relname;

-- Finding: bookings (200 rows) has been analyzed
-- automatically, but flights (15) and passengers (30) have
-- never been analyzed. Without statistics on flight_number,
-- the planner guessed how many flights match the IN list,
-- which is why it expected 5 rows instead of 45.
