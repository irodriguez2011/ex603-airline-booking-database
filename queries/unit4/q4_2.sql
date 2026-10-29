-- ============================================================
-- TASK 4.2: BUILD THE BREAKDOWN LEADERSHIP ASKED FOR
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Failure definition: a booking whose cancellation_reason is
-- 'Passenger no show', the same definition used in the Unit 3
-- finding (12 of 200 bookings, 6%). All cancellations are
-- shown alongside as a broader measure.
-- ============================================================


-- ============================================================
-- PART A: TWO NUMBERS IN ONE PASS
-- Requirement: CASE inside an aggregate, no WHERE clause.
-- Question: For each flight, how many bookings did it receive,
-- and how many of those were passenger no-shows?
-- ============================================================

SELECT
    b.flight_id,
    f.flight_number,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
             THEN 1 ELSE 0 END) AS no_show_bookings,
    SUM(CASE WHEN b.booking_status = 'cancelled'
             THEN 1 ELSE 0 END) AS cancelled_bookings,
    ROUND(
        100.0 * SUM(CASE WHEN b.cancellation_reason = 'Passenger no show'
                         THEN 1 ELSE 0 END)
        / COUNT(*), 1
    ) AS no_show_rate_pct
FROM bookings b
JOIN flights f
  ON f.flight_id = b.flight_id
GROUP BY b.flight_id, f.flight_number
ORDER BY no_show_rate_pct DESC, total_bookings DESC;

-- Finding: One pass over the 200 bookings returns both totals
-- for each of the 13 booked flights.
-- Outliers:
--   VN202 (flight 2): 3 no-shows in 16 bookings, 18.8%, the
--     highest rate among flights with 15+ bookings.
--   VN203 (flight 3): 2 no-shows in 13 bookings, 15.4%, plus
--     2 disputed bookings.
--   VN204 (flight 4): 1 no-show in 6 bookings, 16.7%, but too
--     few bookings for the rate to be meaningful.
-- VN211 (flight 11) has only 1 no-show but the most
-- cancellations (5 of 16), so it is an outlier on the broader
-- cancellation measure.


-- ============================================================
-- PART B: SUBTOTALS AND A GRAND TOTAL
-- Requirement: GROUP BY ROLLUP.
-- Question: For each booking country, and for the platform as
-- a whole, how many bookings, no-shows, and cancellations were
-- there, and how much fare was paid?
-- ============================================================

SELECT
    CASE WHEN GROUPING(booking_country) = 1
         THEN 'ALL REGIONS'
         ELSE booking_country
    END AS booking_country,
    CASE WHEN GROUPING(booking_country) = 1
         THEN 'Grand total'
         ELSE 'Regional subtotal'
    END AS row_type,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN cancellation_reason = 'Passenger no show'
             THEN 1 ELSE 0 END) AS no_show_bookings,
    SUM(CASE WHEN booking_status = 'cancelled'
             THEN 1 ELSE 0 END) AS cancelled_bookings,
    ROUND(
        100.0 * SUM(CASE WHEN cancellation_reason = 'Passenger no show'
                         THEN 1 ELSE 0 END)
        / COUNT(*), 1
    ) AS no_show_rate_pct,
    SUM(fare_paid) AS total_fare_paid
FROM bookings
GROUP BY ROLLUP (booking_country)
ORDER BY GROUPING(booking_country), booking_country;

-- Finding: ROLLUP (booking_country) returns no detail rows,
-- only one row per region plus one platform row.
-- Rows 1-5 (row_type = 'Regional subtotal') are the subtotals:
--   Japan     43 bookings, 1 no-show  (2.3%), $691.00
--   Korea     39 bookings, 3 no-shows (7.7%), $780.43
--   Singapore 40 bookings, 1 no-show  (2.5%), $835.77
--   Thailand  40 bookings, 4 no-shows (10.0%), $707.31
--   Vietnam   38 bookings, 3 no-shows (7.9%), $613.68
-- Row 6 (booking_country = 'ALL REGIONS', row_type =
-- 'Grand total') is the grand total: 200 bookings,
-- 12 no-shows (6.0%), 34 cancellations, $3,628.19.
-- GROUPING(booking_country) = 1 marks the grand total row,
-- where ROLLUP would otherwise show a NULL region.


-- ============================================================
-- PART C: A TWO-STEP PIPELINE
-- Requirement: WITH clause producing an intermediate
-- aggregate, then a second aggregation on it.
-- Question: Among flights with at least 15 bookings, what is
-- the typical no-show rate, cancellation rate, and average
-- fare that any single flight can be compared against?
-- ============================================================

WITH flight_summary AS (
    -- Step 1: one row per flight
    SELECT
        flight_id,
        COUNT(*) AS total_bookings,
        SUM(CASE WHEN cancellation_reason = 'Passenger no show'
                 THEN 1 ELSE 0 END) AS no_show_bookings,
        SUM(CASE WHEN booking_status = 'cancelled'
                 THEN 1 ELSE 0 END) AS cancelled_bookings,
        AVG(fare_paid) AS average_fare_paid
    FROM bookings
    GROUP BY flight_id
)

-- Step 2: aggregate the per-flight rows into a baseline
SELECT
    COUNT(*)            AS high_volume_flights,
    SUM(total_bookings) AS high_volume_bookings,
    ROUND(100.0 * SUM(no_show_bookings) / SUM(total_bookings), 1)
                        AS baseline_no_show_rate_pct,
    ROUND(100.0 * SUM(cancelled_bookings) / SUM(total_bookings), 1)
                        AS baseline_cancellation_rate_pct,
    ROUND(AVG(average_fare_paid), 2)
                        AS baseline_average_fare_paid,
    ROUND(MAX(100.0 * no_show_bookings / total_bookings), 1)
                        AS worst_no_show_rate_pct
FROM flight_summary
WHERE total_bookings >= 15;

-- Finding: The 8 high-volume flights account for 145 of the
-- 200 bookings. Their baseline is a 4.8% no-show rate, a 15.2%
-- cancellation rate, and an average fare of $18.76 per flight.
-- The worst high-volume flight (VN202) has an 18.8% no-show
-- rate, almost four times the baseline.
