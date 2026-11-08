-- ============================================================
-- TASK 5.1: CONNECT PRODUCERS TO THEIR DATA
-- Theme: Airline Booking
-- Database: ex603_data
--
-- Roles used in this unit:
--   Event table : bookings
--   Actor       : passengers
--   Producer    : flights
--   Catalog     : airports
--   Junction    : flight_routes (flights <-> airports)
--
-- Flights identified in Unit 4: VN202 (flight 2), VN203
-- (flight 3), and VN211 (flight 11).
-- ============================================================


-- ============================================================
-- 5.1.1: Who are the passengers behind the bookings on the
-- flights identified in Unit 4?
-- Requirement: Three-table INNER JOIN (passengers, bookings,
-- flights).
-- Question: For every booking on VN202, VN203, and VN211,
-- which passenger made it, on which flight, when, and how did
-- the booking end?
-- ============================================================

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

-- Finding: 45 bookings (VN202 16, VN203 13, VN211 16), each
-- shown with the passenger who made it and when it was booked.
-- The 6 no-shows on these flights come from 5 passengers:
--   VN202: passengers 19, 29, and 1.
--   VN203: passengers 6 and 21.
--   VN211: passenger 21.
-- Passenger 21 no-showed on both VN203 and VN211, the only
-- repeat. Otherwise the no-shows are spread across different
-- passengers, so no single passenger explains the problem.
-- VN211's cancellations are mostly not the passenger's doing:
-- 2 of its 5 are 'Flight cancelled' and 1 is 'Payment failed'.


-- ============================================================
-- 5.1.2: Do the flights identified in Unit 4 share an airport?
-- Requirement: Producer -> junction -> catalog join
-- (flights -> flight_routes -> airports).
-- Question: Which flights fly through Changi Airport (SIN),
-- and how many bookings and no-shows does each have?
-- ============================================================

SELECT
    a.iata_code,
    a.airport_name,
    f.flight_id,
    f.flight_number,
    r.effective_from,
    f.is_active,
    COUNT(b.booking_id) AS total_bookings,
    COUNT(CASE WHEN b.cancellation_reason = 'Passenger no show'
               THEN 1 END) AS no_show_bookings
FROM airports a
JOIN flight_routes r
  ON r.airport_id = a.airport_id
JOIN flights f
  ON f.flight_id = r.flight_id
LEFT JOIN bookings b
  ON b.flight_id = f.flight_id
WHERE a.iata_code = 'SIN'
GROUP BY a.iata_code, a.airport_name, f.flight_id, f.flight_number,
         r.effective_from, f.is_active
ORDER BY no_show_bookings DESC, f.flight_id;

-- Finding: Five flights route through SIN: VN202, VN203,
-- VN205, VN210, and VN211. SIN is the only airport that all
-- three Unit 4 flights share.
-- SIN alone does not explain the no-shows, though: VN205 and
-- VN210 also fly through SIN and have no no-shows at all.
-- The shared airport is a lead worth checking, not a cause.


-- ============================================================
-- 5.1.3: How do the Unit 4 flights compare with flights that
-- use the same size of aircraft?
-- Requirement: Self join on the flights table.
-- Question: For VN202, VN203, and VN211, which other flights
-- have the same seat capacity, and how do their bookings and
-- no-shows compare?
-- ============================================================

WITH flight_activity AS (
    SELECT
        flight_id,
        COUNT(*) AS total_bookings,
        COUNT(CASE WHEN cancellation_reason = 'Passenger no show'
                   THEN 1 END) AS no_show_bookings
    FROM bookings
    GROUP BY flight_id
)

SELECT
    f1.flight_number     AS flagged_flight,
    f1.seat_capacity     AS flagged_capacity,
    f1.is_active         AS flagged_active,
    a1.total_bookings    AS flagged_bookings,
    a1.no_show_bookings  AS flagged_no_shows,
    f2.flight_number     AS peer_flight,
    f2.is_active         AS peer_active,
    a2.total_bookings    AS peer_bookings,
    a2.no_show_bookings  AS peer_no_shows
FROM flights f1
LEFT JOIN flights f2
  ON f2.seat_capacity = f1.seat_capacity
 AND f2.flight_id <> f1.flight_id
LEFT JOIN flight_activity a1
  ON a1.flight_id = f1.flight_id
LEFT JOIN flight_activity a2
  ON a2.flight_id = f2.flight_id
WHERE f1.flight_number IN ('VN202', 'VN203', 'VN211')
ORDER BY f1.flight_id, f2.flight_id;

-- Finding: VN202 and VN203 are both 320-seat aircraft, and
-- they share that size with VN201, VN204, and VN205.
-- Four of those five 320-seat flights have no-shows (VN201 1,
-- VN202 3, VN203 2, VN204 1); only VN205 has none. Together
-- the 320-seat flights have 7 no-shows in 64 bookings (10.9%),
-- against 5 in 136 (3.7%) for every other flight.
-- VN211 (193 seats) has no peer of the same size, so its row
-- shows NULL for the peer columns. Its problem in Unit 4 was
-- cancellations, not no-shows, which fits it not belonging to
-- the 320-seat group.
-- VN203 is also marked inactive (is_active = false) but still
-- has 13 bookings, which needs explaining.
-- Activity level does not explain the pattern: VN205 has more
-- bookings (18) than VN202 (16) and no no-shows.
