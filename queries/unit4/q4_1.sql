-- ============================================================
-- TASK 4.1: MEASURE THE PLATFORM
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Roles used in this unit:
--   Event table : bookings
--   Metric      : fare_paid
--   Actor       : passenger_id (passengers)
--   Producer    : flight_id (flights)
--   Region      : booking_country
-- ============================================================


-- ============================================================
-- 4.1.1: What does the platform look like as a whole?
-- Requirement: COUNT, SUM, AVG, MIN, MAX, COUNT(DISTINCT).
-- Question: Across every booking, how many bookings are there,
-- how much fare was paid in total, what is the average,
-- lowest, and highest fare, and how many different
-- passengers made those bookings?
-- ============================================================

SELECT
    COUNT(*)                      AS total_bookings,
    SUM(fare_paid)                AS total_fare_paid,
    ROUND(AVG(fare_paid), 2)      AS average_fare_paid,
    MIN(fare_paid)                AS lowest_fare_paid,
    MAX(fare_paid)                AS highest_fare_paid,
    COUNT(DISTINCT passenger_id)  AS distinct_passengers
FROM bookings;

-- Finding: 200 bookings, $3,628.19 in total fares, an average
-- fare of $18.14, a lowest fare of $0.00, a highest fare of
-- $70.86, and 30 distinct passengers.
-- A $0.00 fare should not exist for a paid booking, so the
-- minimum needs investigating (see 4.1.1b).


-- ------------------------------------------------------------
-- 4.1.1b: Which bookings have a $0.00 fare?
-- Requirement: Follow-up data-quality check on 4.1.1.
-- Question: Are the zero fares spread across every booking
-- status, or do they belong to one kind of booking?
-- ------------------------------------------------------------

SELECT
    booking_status,
    COUNT(*)                                  AS total_bookings,
    COUNT(CASE WHEN fare_paid = 0 THEN 1 END) AS zero_fare_bookings,
    ROUND(AVG(fare_paid), 2)                  AS average_fare_paid
FROM bookings
GROUP BY booking_status
ORDER BY booking_status;

-- Finding: All 34 zero fares are cancelled bookings, and every
-- cancelled booking has a zero fare. The fare appears to be
-- zeroed out when a booking is cancelled (a refund), so the
-- $0.00 rows are not bad data, but they pull the platform
-- average down. Excluding cancelled bookings, the average
-- fare is $21.86 rather than $18.14.


-- ============================================================
-- 4.1.2: How busy is each flight, and what does it earn
-- per booking?
-- Requirement: GROUP BY, ORDER BY on an aggregate.
-- Question: For each flight, how many bookings did it receive
-- and what was its average fare, from the busiest flight
-- to the quietest?
-- ============================================================

SELECT
    b.flight_id,
    f.flight_number,
    COUNT(*)                  AS total_bookings,
    ROUND(AVG(b.fare_paid), 2) AS average_fare_paid
FROM bookings b
JOIN flights f
  ON f.flight_id = b.flight_id
GROUP BY b.flight_id, f.flight_number
ORDER BY total_bookings DESC, b.flight_id;

-- Finding: 13 flights have bookings. Volume ranges from 21
-- bookings (VN206, flight 6) down to 6 bookings (VN204,
-- flight 4). Average fares range from $11.94 (VN211) to
-- $23.06 (VN205).
-- Flights 14 and 15 do not appear at all: they have no
-- bookings, so a GROUP BY over bookings cannot show them.
-- Low averages partly reflect cancellations: VN211 has the
-- lowest average and also the most cancelled ($0.00) bookings.


-- ============================================================
-- 4.1.3: Which flights have enough bookings for their rates
-- to mean anything?
-- Requirement: HAVING.
-- Question: Which flights have at least 15 bookings, and what
-- are their booking count, average fare, and no-show rate?
-- ============================================================

SELECT
    b.flight_id,
    f.flight_number,
    COUNT(*)                   AS total_bookings,
    ROUND(AVG(b.fare_paid), 2) AS average_fare_paid,
    ROUND(
        100.0 * COUNT(CASE WHEN b.cancellation_reason = 'Passenger no show' THEN 1 END)
        / COUNT(*), 1
    )                          AS no_show_rate_pct
FROM bookings b
JOIN flights f
  ON f.flight_id = b.flight_id
GROUP BY b.flight_id, f.flight_number
HAVING COUNT(*) >= 15
ORDER BY total_bookings DESC, b.flight_id;

-- Finding: 8 of the 13 booked flights meet the threshold:
-- flights 6, 8, 10, 5, 7, 12, 2, and 11.
-- Why 15: 200 bookings across 13 booked flights is an average
-- of about 15 per flight, so the threshold keeps flights with
-- at least average volume. Below 15, a single no-show moves a
-- flight's rate by more than 6.7 percentage points, which is
-- larger than the platform's whole no-show rate of 6%.
-- Flight 4 (VN204, 6 bookings) is the clearest case: one
-- no-show already gives it a 16.7% rate.
-- Among the qualifying flights, VN202 (flight 2) stands out
-- with an 18.8% no-show rate (3 of 16), about three times the
-- platform rate. Three flights (8, 10, 5) have no no-shows.


-- ============================================================
-- 4.1.4: How do bookings and fares vary by region and status?
-- Requirement: GROUP BY two dimensions.
-- Question: For each booking country, how many bookings ended
-- in each status, and what were the total, average, lowest,
-- and highest fares for each combination?
-- ============================================================

SELECT
    booking_country,
    booking_status,
    COUNT(*)                 AS total_bookings,
    SUM(fare_paid)           AS total_fare_paid,
    ROUND(AVG(fare_paid), 2) AS average_fare_paid,
    MIN(fare_paid)           AS lowest_fare_paid,
    MAX(fare_paid)           AS highest_fare_paid
FROM bookings
GROUP BY booking_country, booking_status
ORDER BY booking_country, booking_status;

-- Finding: 14 rows, one for each region and status combination
-- that exists. Thailand has the most cancellations (11 of 40
-- bookings) and no disputed bookings, so it has no "disputed"
-- row at all. Korea has the most disputed bookings (4).
-- Average confirmed fares are similar across regions, from
-- $18.89 (Japan) to $24.39 (Thailand).
