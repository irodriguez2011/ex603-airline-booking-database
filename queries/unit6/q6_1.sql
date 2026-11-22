-- ============================================================
-- TASK 6.1: COMPUTE ACROSS A WINDOW WITHOUT COLLAPSING
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Roles used in this unit:
--   Event table : bookings
--   Producer    : flights
--   Metric      : fare_paid
--
-- Question: Is a booking's fare unusual for its own flight, and
-- how should flights be ranked and banded on a leaderboard when
-- some of them have the same number of bookings?
-- ============================================================


-- ============================================================
-- 6.1.1a: Each booking next to its own flight's average fare.
-- Requirement: AVG(...) OVER (PARTITION BY ...).
-- Question: For every booking, what did the passenger pay, what
-- does that flight's average booking pay, and how far from the
-- average is this booking?
-- ============================================================

SELECT
    f.flight_number,
    b.booking_id,
    b.booked_at::date                                        AS booked_on,
    b.booking_status,
    b.fare_paid,
    ROUND(AVG(b.fare_paid) OVER (PARTITION BY b.flight_id), 2)
                                                             AS flight_avg_fare,
    ROUND(b.fare_paid - AVG(b.fare_paid) OVER (PARTITION BY b.flight_id), 2)
                                                             AS diff_from_avg,
    ROUND(b.fare_paid / NULLIF(AVG(b.fare_paid) OVER (PARTITION BY b.flight_id), 0), 2)
                                                             AS times_flight_avg
FROM bookings b
JOIN flights f
  ON f.flight_id = b.flight_id
ORDER BY f.flight_number, b.booked_at;

-- Result: 200 rows, one per booking. Each row keeps its own
-- fare and gains its flight's average beside it. Every
-- cancelled booking shows $0.00 and a negative difference,
-- because cancelled fares are refunded to $0 (Unit 4).


-- ============================================================
-- 6.1.1b: The most unusual bookings for their own flight.
-- Requirement: window result filtered in an outer query (a
-- window function cannot be used in WHERE).
-- Question: Which bookings paid the most relative to what their
-- own flight usually earns?
-- ============================================================

WITH fare_vs_flight AS (
    SELECT
        f.flight_number,
        b.booking_id,
        b.booked_at::date                                    AS booked_on,
        b.fare_paid,
        ROUND(AVG(b.fare_paid) OVER (PARTITION BY b.flight_id), 2)
                                                             AS flight_avg_fare,
        ROUND(b.fare_paid / NULLIF(AVG(b.fare_paid) OVER (PARTITION BY b.flight_id), 0), 2)
                                                             AS times_flight_avg
    FROM bookings b
    JOIN flights f
      ON f.flight_id = b.flight_id
)
SELECT *
FROM fare_vs_flight
WHERE times_flight_avg >= 2
ORDER BY times_flight_avg DESC;

-- Finding: 15 bookings paid at least twice their flight's
-- average. The extreme case is booking 43 on VN204: $70.86
-- against a flight average of $19.49 (3.64x). VN204 has only 6
-- bookings, so this single fare is about 60% of the flight's
-- revenue. Second is booking 164 on VN211: $34.79 is an
-- ordinary fare on most flights, but it is 2.91x VN211's
-- average, because VN211's five cancellations pull its average
-- down to $11.94. Only the per-flight comparison shows that.


-- ============================================================
-- 6.1.1c: The GROUP BY version of the same average.
-- Requirement: GROUP BY, for comparison with 6.1.1a.
-- Question: What is each flight's average fare when the
-- bookings are collapsed into one row per flight?
-- ============================================================

SELECT
    f.flight_number,
    COUNT(*)                    AS bookings,
    ROUND(AVG(b.fare_paid), 2)  AS flight_avg_fare
FROM bookings b
JOIN flights f
  ON f.flight_id = b.flight_id
GROUP BY f.flight_number
ORDER BY f.flight_number;

-- Result: 13 rows, one per flight with bookings. The averages
-- match 6.1.1a, but booking_id, fare_paid, status and date are
-- gone, so it is no longer possible to say which booking is
-- above or below its flight's average.


-- ============================================================
-- 6.1.1d: Row counts, window version vs. GROUP BY version.
-- Question: How many rows does each version return?
-- ============================================================

SELECT
    (SELECT COUNT(*)
       FROM (SELECT AVG(fare_paid) OVER (PARTITION BY flight_id)
               FROM bookings) w)                 AS window_rows,
    (SELECT COUNT(*)
       FROM (SELECT flight_id, AVG(fare_paid)
               FROM bookings
              GROUP BY flight_id) g)             AS group_by_rows;

-- Result: window_rows = 200, group_by_rows = 13. The window
-- keeps all 200 bookings; GROUP BY collapses them to 13 flights
-- and loses the individual bookings.


-- ============================================================
-- 6.1.2: Rank flights three ways.
-- Requirement: ROW_NUMBER(), RANK() and DENSE_RANK() side by
-- side, with at least one tie in the output.
-- Question: If leadership publishes a flight leaderboard by
-- number of bookings, where does each flight land under each
-- ranking method?
-- LEFT JOIN keeps VN214 and VN215, which have no bookings
-- (found in Unit 5), so the board shows every flight.
-- ============================================================

WITH flight_bookings AS (
    SELECT
        f.flight_number,
        COUNT(b.booking_id) AS bookings
    FROM flights f
    LEFT JOIN bookings b
      ON b.flight_id = f.flight_id
    GROUP BY f.flight_number
)
SELECT
    flight_number,
    bookings,
    ROW_NUMBER() OVER (ORDER BY bookings DESC, flight_number) AS row_number,
    RANK()       OVER (ORDER BY bookings DESC)                AS rank,
    DENSE_RANK() OVER (ORDER BY bookings DESC)                AS dense_rank
FROM flight_bookings
ORDER BY bookings DESC, flight_number;

-- Finding: four ties. VN205 and VN207 (18 bookings), VN202 and
-- VN211 (16), VN201 and VN213 (11), and VN214 and VN215 (0).
--   ROW_NUMBER gives every flight a different position. VN205
--   is 4th and VN207 is 5th only because '205' sorts before
--   '207'; the data does not separate them.
--   RANK gives both 4th, then skips to 6th, so positions still
--   match "how many flights are ahead of you".
--   DENSE_RANK gives both 4th, then continues at 5th. By the
--   bottom of the board it shows 11 positions for 15 flights:
--   VN214 and VN215 are 14th by RANK but 11th by DENSE_RANK.


-- ============================================================
-- 6.1.3: Sort flights into four bands.
-- Requirement: NTILE(4) by number of bookings.
-- Question: If flights are split into four equal-sized bands
-- by bookings, which band does each fall into, and what happens
-- to tied flights at a band boundary?
-- ============================================================

WITH flight_bookings AS (
    SELECT
        f.flight_number,
        COUNT(b.booking_id) AS bookings
    FROM flights f
    LEFT JOIN bookings b
      ON b.flight_id = f.flight_id
    GROUP BY f.flight_number
)
SELECT
    flight_number,
    bookings,
    NTILE(4)     OVER (ORDER BY bookings DESC, flight_number) AS band,
    RANK()       OVER (ORDER BY bookings DESC)                AS rank
FROM flight_bookings
ORDER BY bookings DESC, flight_number;

-- Finding: 15 flights do not divide by 4, so NTILE makes bands
-- of 4, 4, 4 and 3. VN205 and VN207 both have 18 bookings, but
-- VN205 lands in band 1 (the top band) and VN207 in band 2.
-- NTILE fills each band to a fixed size and cuts wherever the
-- count runs out, even between two identical values. The order
-- inside the tie is decided only by the flight_number
-- tiebreaker, so a reporting label like "top-quartile flight"
-- would be given to one and not the other for no real reason.


-- ============================================================
-- 6.1.3b: Which tied booking counts are split across bands?
-- Question: Does any group of flights with the same number of
-- bookings end up in more than one band?
-- ============================================================

WITH banded AS (
    SELECT
        f.flight_number,
        COUNT(b.booking_id)                                        AS bookings,
        NTILE(4) OVER (ORDER BY COUNT(b.booking_id) DESC, f.flight_number) AS band
    FROM flights f
    LEFT JOIN bookings b
      ON b.flight_id = f.flight_id
    GROUP BY f.flight_number
)
SELECT
    bookings,
    STRING_AGG(flight_number || ' (band ' || band || ')', ', ' ORDER BY flight_number)
                         AS flights,
    COUNT(DISTINCT band) AS bands_used
FROM banded
GROUP BY bookings
HAVING COUNT(*) > 1
ORDER BY bookings DESC;

-- Result: of the four tied pairs, only the 18-booking pair
-- (VN205, VN207) is split across a boundary. The others happen
-- to fall inside one band.
