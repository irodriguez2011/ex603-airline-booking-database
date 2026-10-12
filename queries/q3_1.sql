-- Exploration 1: What tables are available in the airline booking database?
-- Purpose: Identify the tables that contain the data needed for the audit.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';

-- Exploration 2: What columns are available in the flight_services table?
-- Purpose: Understand the structure of flight services and determine
-- whether it contains information about active or highly rated flights.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'flight_services'
ORDER BY ordinal_position;

-- Exploration 3: What columns are available in the flights table?
-- Purpose: Identify which flight attributes can be used to filter
-- and sort flights.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'flights'
ORDER BY ordinal_position;

-- Exploration 4: What does the actual flight data look like?
-- Purpose: Preview five flight records to understand the values
-- stored in each column.
SELECT *
FROM flights
LIMIT 5;

-- ============================================================
-- TASK 3.1: ESTABLISH WHAT THE DATA CONTAINS
-- Theme: Airline Booking
-- Database: ex603_data
-- ============================================================

-- ============================================================
-- 3.1a: Which active flights have the largest seat capacities?
-- Requirement: SELECT, WHERE, ORDER BY, LIMIT.
-- Purpose: Identify the ten active flights with the
-- largest passenger capacities.
-- ============================================================

SELECT
    flight_id,
    flight_number,
    seat_capacity
FROM flights
WHERE is_active = TRUE
  AND seat_capacity >= 180
ORDER BY seat_capacity DESC, flight_id
LIMIT 10;

-- Finding: This query returns the ten active flights
-- with the largest seating capacities.
-- Note: Seat capacity is used as an illustrative measure.
-- The airline-specific filter from the appendix
-- still needs to be verified.


-- ============================================================
-- 3.1b: What are all the possible booking statuses?
-- Requirement: SELECT DISTINCT.
-- Purpose: Identify every unique booking status and determine
-- whether unexpected statuses exist.
-- ============================================================

SELECT DISTINCT
    booking_status
FROM bookings
ORDER BY booking_status;

-- Finding: The bookings table contains three distinct statuses:
-- cancelled, confirmed, and disputed.
-- The disputed status is important because it represents
-- an additional category that could affect how booking
-- failure rates are calculated.


-- ============================================================
-- 3.1c: Which bookings have fares between $100 and $500?
-- Requirement: WHERE, BETWEEN.
-- Purpose: Filter booking events using a numeric range.
-- ============================================================

SELECT
    booking_id,
    passenger_id,
    fare_paid
FROM bookings
WHERE fare_paid BETWEEN 100 AND 500
ORDER BY fare_paid DESC;

-- Finding: This query identifies bookings with fares
-- between $100 and $500, inclusive.
-- Number of matching bookings: 0.
-- No booking has a fare in this range. Fares in the bookings
-- table range from $0.00 to $70.86, so $100 to $500 is above
-- every recorded fare.


-- ============================================================
-- 3.1d: Which bookings match selected booking statuses?
-- Requirement: WHERE, IN.
-- Purpose: Filter booking events using an explicit list.
-- ============================================================

SELECT
    booking_id,
    passenger_id,
    booking_status
FROM bookings
WHERE booking_status IN ('confirmed', 'cancelled');

-- Finding: This query returns bookings with either a confirmed
-- or cancelled status. The disputed bookings are excluded.


-- ============================================================
-- 3.1e: Which flight numbers begin with VN?
-- Requirement: LIKE.
-- Purpose: Find flights matching a specific text pattern.
-- ============================================================

SELECT
    flight_id,
    flight_number,
    origin_country
FROM flights
WHERE flight_number LIKE 'VN%';

-- Finding: This query identifies flights whose flight
-- numbers begin with VN.


-- ============================================================
-- 3.1f: Which bookings have missing cancellation reasons?
-- Requirement: IS NULL, COALESCE.
-- Purpose: Identify missing cancellation reasons and
-- replace NULL with a readable label.
-- ============================================================

SELECT
    booking_id,
    booking_status,
    CASE
        WHEN cancellation_reason IS NOT NULL THEN cancellation_reason
        ELSE 'No reason provided'
        END AS cancellation_reason_label
FROM bookings
WHERE cancellation_reason IS NULL;

-- Finding: The query identified 166 bookings with a NULL
-- cancellation_reason. These missing values are displayed
-- as 'No reason provided'.



-- ============================================================
-- 3.1g: How can flights be categorized by seating capacity?
-- Requirement: Computed columns, CASE.
-- Purpose: Make flight information easier for a
-- nontechnical audience to understand.
-- ============================================================

SELECT
    flight_id,
    flight_number,
    seat_capacity,

    CASE
        WHEN seat_capacity < 100
            THEN 'Small Capacity'
        WHEN seat_capacity BETWEEN 100 AND 250
            THEN 'Medium Capacity'
        ELSE 'Large Capacity'
    END AS capacity_category,

    seat_capacity * 0.80 AS estimated_80_percent_occupancy

FROM flights
ORDER BY seat_capacity DESC;

-- Finding: This query categorizes flights as small,
-- medium, or large based on passenger capacity.
-- It also calculates 80% of each flight's total
-- seating capacity as a hypothetical occupancy measure.

