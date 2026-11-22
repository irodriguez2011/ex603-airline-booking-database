-- ============================================================
-- TASK 6.2: COMPARE EACH ROW TO ITS NEIGHBORS
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Roles used in this unit:
--   Event table : bookings (booked_at is the timestamp)
--   Producer    : flights
--   Metric      : fare_paid
--
-- Question: Is the platform moving up or down over time, where
-- does it stand against a revenue target, and where does a
-- flight's booking history stop and restart?
-- ============================================================


-- ============================================================
-- 6.2 Part A: Row to row, for one flight.
-- Requirement: LAG() and LEAD() partitioned by producer and
-- ordered by timestamp, a delta column, and the final output
-- filtered to one producer.
-- Question: For each booking on VN202, what did the booking
-- before it and the booking after it pay, and did the fare go
-- up or down?
-- VN202 is the flight with the highest no-show rate (Unit 4).
-- The windows are computed for every flight first, then the
-- outer query keeps VN202, so the neighbors are always that
-- flight's own neighbors.
-- ============================================================

WITH fare_sequence AS (
    SELECT
        f.flight_number,
        b.booking_id,
        b.booked_at,
        b.booking_status,
        b.fare_paid,
        LAG(b.fare_paid)  OVER w AS prev_fare,
        LEAD(b.fare_paid) OVER w AS next_fare
    FROM bookings b
    JOIN flights f
      ON f.flight_id = b.flight_id
    WINDOW w AS (PARTITION BY b.flight_id ORDER BY b.booked_at)
)
SELECT
    flight_number,
    booking_id,
    booked_at,
    booking_status,
    prev_fare,
    fare_paid,
    next_fare,
    fare_paid - prev_fare AS delta
FROM fare_sequence
WHERE flight_number = 'VN202'
ORDER BY booked_at;

-- Finding: 16 rows. The first row has no previous fare and the
-- last has no next fare, so their LAG/LEAD values are NULL. The
-- largest swings are +27.98 into booking 18 ($47.81, the
-- flight's top fare) and -32.59 right after it. Two of the
-- negative deltas (-15.21 and -20.29) are not price changes at
-- all: they are cancelled bookings refunded to $0. VN202 opens the year with 3 cancellations in
-- its first 4 bookings, runs 11 confirmed bookings in a row
-- from April to November, and ends with a no-show in December.


-- ============================================================
-- 6.2 Part B1: Running total against a target, and a moving
-- average.
-- Requirement: SUM(...) OVER (ORDER BY ... ROWS BETWEEN
-- UNBOUNDED PRECEDING AND CURRENT ROW) and AVG(...) OVER (...
-- ROWS BETWEEN n PRECEDING AND CURRENT ROW).
-- Question: Day by day, how much fare revenue has the platform
-- earned this quarter and this year, and how close is it to
-- target?
--
-- Target: $1,000 of fare revenue per quarter ($4,000 for
-- 2023). $1,000 is the best quarter actually reached (Q3 was
-- $1,004.11), so the target asks every quarter to match it.
--
-- Bookings are first grouped to one row per booking day
-- (155 days had bookings). The 7-row moving average therefore
-- covers 7 booking days, not 7 calendar days: days_in_window
-- shows how many calendar days each window really spans.
-- ============================================================

WITH daily AS (
    SELECT
        booked_at::date                         AS booked_on,
        DATE_TRUNC('quarter', booked_at)::date  AS quarter,
        COUNT(*)                                AS bookings,
        SUM(fare_paid)                          AS revenue
    FROM bookings
    GROUP BY booked_at::date, DATE_TRUNC('quarter', booked_at)
)
SELECT
    booked_on,
    bookings,
    revenue,
    SUM(revenue) OVER (PARTITION BY quarter ORDER BY booked_on
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                          AS quarter_to_date,
    ROUND(100 * SUM(revenue) OVER (PARTITION BY quarter ORDER BY booked_on
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 1000, 1)
                                                          AS pct_of_q_target,
    SUM(revenue) OVER (ORDER BY booked_on
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                          AS year_to_date,
    ROUND(AVG(revenue) OVER (ORDER BY booked_on
                       ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2)
                                                          AS moving_avg_7_rows,
    booked_on - LAG(booked_on, 6) OVER (ORDER BY booked_on) + 1
                                                          AS days_in_window
FROM daily
ORDER BY booked_on;

-- Result: 155 rows. The year-to-date total ends at $3,628.19,
-- 90.7% of the $4,000 target. The 7-row window covers 8 to 28
-- calendar days (about 15 on average), so it is roughly a
-- two-week average, not a one-week one.


-- ============================================================
-- 6.2 Part B2: Where each quarter finished against target.
-- Question: How close did each quarter's running total get to
-- the $1,000 target?
-- The running total is computed in a CTE and the outer query
-- keeps the last day of each quarter.
-- ============================================================

WITH daily AS (
    SELECT
        booked_at::date                         AS booked_on,
        DATE_TRUNC('quarter', booked_at)::date  AS quarter,
        SUM(fare_paid)                          AS revenue
    FROM bookings
    GROUP BY booked_at::date, DATE_TRUNC('quarter', booked_at)
),
running AS (
    SELECT
        quarter,
        booked_on,
        SUM(revenue) OVER (PARTITION BY quarter ORDER BY booked_on
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                            AS quarter_to_date,
        ROW_NUMBER() OVER (PARTITION BY quarter ORDER BY booked_on DESC)
                                            AS days_from_end
    FROM daily
)
SELECT
    quarter,
    booked_on                                 AS last_booking_day,
    quarter_to_date                           AS quarter_total,
    1000.00                                   AS quarter_target,
    quarter_to_date - 1000                    AS vs_target,
    ROUND(100 * quarter_to_date / 1000, 1)    AS pct_of_target
FROM running
WHERE days_from_end = 1
ORDER BY quarter;

-- Finding: Q1 $909.78 (91.0%), Q2 $856.99 (85.7%), Q3
-- $1,004.11 (100.4%), Q4 $857.31 (85.7%). Only Q3 reached the
-- target. Q4 fell back to Q2's level.


-- ============================================================
-- 6.2 Part B3: A smoothed failure rate.
-- Requirement: AVG(...) OVER (ORDER BY ... ROWS BETWEEN n
-- PRECEDING AND CURRENT ROW).
-- Question: Over the most recent 30 bookings at each point in
-- the year, what share were cancelled, and what share were
-- passenger no-shows?
-- CASE turns each outcome into 1 or 0. A plain comparison like
-- (cancellation_reason = 'Passenger no show') returns NULL for
-- confirmed bookings, and AVG would silently skip them: the
-- same NULL trap found in Unit 3.
-- The first 29 bookings do not have a full window and are
-- removed in the outer query.
-- ============================================================

WITH outcomes AS (
    SELECT
        booking_id,
        booked_at,
        CASE WHEN booking_status = 'cancelled' THEN 1 ELSE 0 END             AS is_cancelled,
        CASE WHEN cancellation_reason = 'Passenger no show' THEN 1 ELSE 0 END AS is_no_show
    FROM bookings
),
rolling AS (
    SELECT
        booking_id,
        booked_at,
        ROW_NUMBER() OVER (ORDER BY booked_at)                           AS booking_seq,
        ROUND(100 * AVG(is_cancelled) OVER last_30, 1)                   AS cancel_rate_last_30,
        ROUND(100 * AVG(is_no_show)   OVER last_30, 1)                   AS no_show_rate_last_30
    FROM outcomes
    WINDOW last_30 AS (ORDER BY booked_at ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
)
SELECT
    DATE_TRUNC('month', booked_at)::date                                  AS month,
    MIN(cancel_rate_last_30)                                              AS lowest_cancel_rate,
    MAX(cancel_rate_last_30)                                              AS highest_cancel_rate,
    (ARRAY_AGG(cancel_rate_last_30  ORDER BY booked_at DESC))[1]          AS cancel_rate_at_month_end,
    (ARRAY_AGG(no_show_rate_last_30 ORDER BY booked_at DESC))[1]          AS no_show_rate_at_month_end
FROM rolling
WHERE booking_seq >= 30
GROUP BY DATE_TRUNC('month', booked_at)
ORDER BY month;

-- Finding: the rolling cancellation rate sat between 20% and
-- 30% through February and March. From October onward it never
-- rose above 16.7%. The rolling no-show rate stays between 0%
-- and 10% (0 to 3 of the last 30 bookings) all year. No-shows
-- are too rare for a 30-booking window to show a clear trend.


-- ============================================================
-- 6.2 Part B4: ROWS vs. RANGE on tied ORDER BY values.
-- Question: When several bookings fall on the same day, does a
-- running total by day treat them one at a time or together?
-- 2023-01-08 has three bookings.
-- ============================================================

SELECT
    booked_at::date AS booked_on,
    booking_id,
    fare_paid,
    SUM(fare_paid) OVER (ORDER BY booked_at::date
                         ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_rows,
    SUM(fare_paid) OVER (ORDER BY booked_at::date
                         RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_range
FROM bookings
WHERE booked_at < '2023-01-11'
ORDER BY booked_at, booking_id;

-- Finding: ROWS adds one row at a time, so the three
-- 2023-01-08 bookings get three different running totals, in
-- an order PostgreSQL picks because they tie on the date.
-- RANGE treats every row with the same date as one peer group,
-- so all three show the same total, $131.62, the total at the
-- end of that day.


-- ============================================================
-- 6.2 Part C: Where the series stops.
-- Requirement: LAG() comparing adjacent rows, a CTE that
-- computes the gap, and a WHERE in the outer query that keeps
-- only the gaps.
-- Question: Which flights went 60 days or more without a
-- single booking, and when did they start again?
-- 60 days is about three times the typical gap between a
-- flight's bookings (16 to 36 days on average, depending on
-- the flight).
-- ============================================================

WITH booking_sequence AS (
    SELECT
        f.flight_number,
        b.booking_id,
        b.booked_at,
        LAG(b.booked_at) OVER (PARTITION BY b.flight_id ORDER BY b.booked_at)
                             AS prev_booked_at
    FROM bookings b
    JOIN flights f
      ON f.flight_id = b.flight_id
),
gaps AS (
    SELECT
        flight_number,
        prev_booked_at::date                  AS last_booking_before_gap,
        booked_at::date                       AS first_booking_after_gap,
        booked_at::date - prev_booked_at::date AS gap_days
    FROM booking_sequence
    WHERE prev_booked_at IS NOT NULL
)
SELECT *
FROM gaps
WHERE gap_days >= 60
ORDER BY gap_days DESC;

-- Finding: 11 gaps of 60 days or more. The longest is VN209:
-- no bookings for 113 days, from 2023-01-05 to 2023-04-28.
-- After that it booked steadily (13 more bookings through
-- December). VN212 (107 days, March to June) and VN205 (93
-- days, February to May) show the same spring pause.


-- ============================================================
-- 6.2 Part C2: Did the platform lose VN209, or did VN209 stop?
-- Question: While VN209 had no bookings, was the platform still
-- recording bookings for other flights, and is anything missing
-- from VN209's own booking IDs?
-- ============================================================

SELECT
    (SELECT COUNT(*)
       FROM bookings
      WHERE booked_at > '2023-01-05 14:18'
        AND booked_at < '2023-04-28 04:16')     AS other_bookings_during_gap,
    (SELECT COUNT(DISTINCT flight_id)
       FROM bookings
      WHERE booked_at > '2023-01-05 14:18'
        AND booked_at < '2023-04-28 04:16')     AS flights_booked_during_gap,
    MIN(booking_id)                              AS vn209_first_id,
    MAX(booking_id)                              AS vn209_last_id,
    COUNT(*)                                     AS vn209_bookings,
    MAX(booking_id) - MIN(booking_id) + 1        AS ids_in_range
FROM bookings
WHERE flight_id = 9;

-- Finding: during VN209's 113-day gap the platform recorded 61
-- bookings on 11 other flights, so booking capture was working.
-- VN209's booking IDs run 124 to 137: 14 bookings, 14 IDs, none
-- missing. If rows had been deleted or lost there would be a
-- hole in the IDs. The evidence points to a real stop in
-- bookings for VN209, not a data-quality loss. VN209 is also
-- one of the two flights marked inactive (is_active = false),
-- which fits a flight that was taken off sale for a while.
