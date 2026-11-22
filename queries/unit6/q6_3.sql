-- ============================================================
-- TASK 6.3: BUILD THE REPORTING PATTERNS
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Roles used in this unit:
--   Event table : bookings
--   Producer    : flights
--   Metric      : fare_paid
--
-- Question: What are each flight's highest-value bookings, and
-- is the platform getting better or worse month by month?
-- ============================================================


-- ============================================================
-- 6.3 Part A: Top three bookings per flight.
-- Requirement: a ranking window function partitioned by
-- producer, a CTE that filters to rank <= 3, and FIRST_VALUE()
-- or LAST_VALUE().
-- Question: For each flight, which three bookings paid the
-- highest fares, and how far is each one below that flight's
-- top fare?
--
-- Ties at third place: RANK() is used, not ROW_NUMBER(). If two
-- bookings on a flight tie for third, both get rank 3 and both
-- are returned, so that flight shows four rows. The list shows
-- what passengers paid at the top of each flight's range, and
-- leaving out one of two identical fares would be an arbitrary
-- choice by booking ID, not by the data. DENSE_RANK() is not
-- used because a tie at first would let it pull in a fourth
-- and fifth distinct fare, which is no longer a "top three".
-- 6.3 Part A2 checks for ties in the current data.
-- ============================================================

WITH ranked AS (
    SELECT
        f.flight_number,
        b.booking_id,
        b.booked_at::date AS booked_on,
        b.fare_paid,
        RANK() OVER (PARTITION BY b.flight_id ORDER BY b.fare_paid DESC)
                          AS fare_rank,
        FIRST_VALUE(b.fare_paid) OVER (PARTITION BY b.flight_id ORDER BY b.fare_paid DESC)
                          AS flight_top_fare,
        LAST_VALUE(b.fare_paid) OVER (PARTITION BY b.flight_id ORDER BY b.fare_paid DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING
                                               AND UNBOUNDED FOLLOWING)
                          AS flight_lowest_fare
    FROM bookings b
    JOIN flights f
      ON f.flight_id = b.flight_id
)
SELECT
    flight_number,
    fare_rank,
    booking_id,
    booked_on,
    fare_paid,
    fare_paid - flight_top_fare AS below_top_fare,
    flight_lowest_fare
FROM ranked
WHERE fare_rank <= 3
ORDER BY flight_number, fare_rank;

-- Finding: 39 rows, exactly three for each of the 13 flights
-- with bookings. The spread inside the top three tells two
-- different stories:
--   VN204's top fare ($70.86) is $48 above its second ($22.77).
--   One outlier booking, not a pattern.
--   VN210's top three are within $0.67 of each other ($35.21,
--   $34.54, $34.41): a consistent high-end price.
-- flight_lowest_fare is $0.00 on every flight except VN210
-- ($4.88), the only flight whose lowest booking was not a
-- cancelled booking refunded to $0. LAST_VALUE needs the
-- full frame here: with the default frame it would return the
-- current row's fare, not the flight's lowest.


-- ============================================================
-- 6.3 Part A2: Are there ties at third place?
-- Question: Does any flight have two bookings tied on the fare
-- at third place, which would make RANK() return a fourth row?
-- ============================================================

WITH ranked AS (
    SELECT
        flight_id,
        fare_paid,
        RANK() OVER (PARTITION BY flight_id ORDER BY fare_paid DESC) AS fare_rank
    FROM bookings
)
SELECT
    flight_id,
    COUNT(*) AS bookings_at_rank_3
FROM ranked
WHERE fare_rank = 3
GROUP BY flight_id
HAVING COUNT(*) > 1;

-- Result: 0 rows. No flight has a tie at third place today, so
-- RANK() and ROW_NUMBER() would return the same 39 rows. The
-- tie rule matters when the data changes, and it is set now so
-- the list does not silently drop a booking later.


-- ============================================================
-- 6.3 Part B: Month over month.
-- Requirement: group events into months with DATE_TRUNC, LAG()
-- over the monthly series, and a percent-change column that
-- avoids division by zero with NULLIF.
-- Question: Is the platform getting better or worse each month,
-- in bookings, revenue, and the share of bookings that fail?
--
-- Missing months: LAG() looks at the previous row, not the
-- previous calendar month. The monthly series is therefore
-- built from GENERATE_SERIES, so every month of 2023 has a row
-- even if it had no bookings, and LEFT JOIN fills in the data.
-- A month with no bookings would show 0, and the next month's
-- LAG would still compare against the right month.
-- ============================================================

WITH months AS (
    SELECT GENERATE_SERIES(DATE '2023-01-01', DATE '2023-12-01', INTERVAL '1 month')::date
               AS month
),
monthly AS (
    SELECT
        DATE_TRUNC('month', booked_at)::date                              AS month,
        COUNT(*)                                                          AS bookings,
        SUM(fare_paid)                                                    AS revenue,
        COUNT(*) FILTER (WHERE booking_status = 'cancelled')              AS cancelled,
        COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show') AS no_shows
    FROM bookings
    GROUP BY DATE_TRUNC('month', booked_at)
),
series AS (
    SELECT
        m.month,
        COALESCE(x.bookings, 0)  AS bookings,
        COALESCE(x.revenue, 0)   AS revenue,
        COALESCE(x.cancelled, 0) AS cancelled,
        COALESCE(x.no_shows, 0)  AS no_shows
    FROM months m
    LEFT JOIN monthly x
      ON x.month = m.month
)
SELECT
    month,
    bookings,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                                    AS prev_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
              / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1)         AS revenue_pct_change,
    cancelled,
    ROUND(100.0 * cancelled / NULLIF(bookings, 0), 1)                     AS cancel_rate,
    ROUND(100.0 * cancelled / NULLIF(bookings, 0), 1)
      - ROUND(100.0 * LAG(cancelled) OVER (ORDER BY month)
              / NULLIF(LAG(bookings) OVER (ORDER BY month), 0), 1)        AS cancel_rate_change_pts,
    no_shows
FROM series
ORDER BY month;

-- Finding: 12 months. Revenue swings hard month to month:
-- +41.5% in February, -70.0% in March, +91.0% in April. Those
-- swings come from small monthly volumes (11 to 21 bookings),
-- not from a change in the platform. The cancellation rate is
-- more useful: 23.8%, 19.0% and 27.3% in January to March,
-- then 0% in April, and it never goes above 25% again. The
-- second half of the year is lower than the first: 15 of 99
-- bookings cancelled (15.2%) against 19 of 101 (18.8%).


-- ============================================================
-- 6.3 Part B2: Check for missing months.
-- Question: Does every calendar month between the first and
-- last booking have at least one booking, so that LAG on the
-- raw monthly data would compare each month with the month
-- that really came before it?
-- ============================================================

WITH monthly AS (
    SELECT DISTINCT DATE_TRUNC('month', booked_at)::date AS month
    FROM bookings
),
with_prev AS (
    SELECT
        month,
        LAG(month) OVER (ORDER BY month) AS prev_month
    FROM monthly
)
SELECT
    month,
    prev_month,
    (month - prev_month)                 AS days_since_prev_row,
    month <> (prev_month + INTERVAL '1 month')::date AS month_skipped
FROM with_prev
WHERE prev_month IS NOT NULL
  AND month <> (prev_month + INTERVAL '1 month')::date;

-- Result: 0 rows. Every month from January to December 2023
-- has bookings, so no month is skipped and LAG compares each
-- month with the one before it. The GENERATE_SERIES in Part B
-- is kept anyway, so the query stays correct when a month is
-- empty.


-- ============================================================
-- 6.3 Part B3 (supports the Task 6.4 memo): Quarter over
-- quarter failure rates.
-- Question: Measured by quarter, which smooths out the small
-- monthly counts, are no-shows, cancellations and disputes
-- going up or down?
-- ============================================================

WITH quarterly AS (
    SELECT
        DATE_TRUNC('quarter', booked_at)::date                            AS quarter,
        COUNT(*)                                                          AS bookings,
        COUNT(*) FILTER (WHERE cancellation_reason = 'Passenger no show') AS no_shows,
        COUNT(*) FILTER (WHERE booking_status = 'cancelled')              AS cancelled,
        COUNT(*) FILTER (WHERE booking_status = 'disputed')               AS disputed,
        COUNT(*) FILTER (WHERE booking_status <> 'confirmed')             AS not_confirmed
    FROM bookings
    GROUP BY DATE_TRUNC('quarter', booked_at)
)
SELECT
    quarter,
    bookings,
    no_shows,
    ROUND(100.0 * no_shows      / bookings, 1) AS no_show_rate,
    cancelled,
    ROUND(100.0 * cancelled     / bookings, 1) AS cancel_rate,
    disputed,
    ROUND(100.0 * not_confirmed / bookings, 1) AS not_confirmed_rate,
    ROUND(100.0 * not_confirmed / bookings, 1)
      - ROUND(100.0 * LAG(not_confirmed) OVER (ORDER BY quarter)
              / NULLIF(LAG(bookings) OVER (ORDER BY quarter), 0), 1)
                                               AS not_confirmed_change_pts
FROM quarterly
ORDER BY quarter;

-- Finding: no-show rate 7.5%, 6.3%, 5.9%, 4.2%: down every
-- quarter. Cancellation rate 22.6% in Q1, then 14.6%, 15.7%,
-- 14.6%: one step down after Q1, then flat. Disputes rose to 5
-- in Q3 (9.8%) and fell back to 1 in Q4. The share of bookings
-- that did not end confirmed was lowest in Q4 (16.7%).
