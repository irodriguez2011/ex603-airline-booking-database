-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: Airline Booking
-- Author: Isamar Rodriguez
-- Target: PostgreSQL 14+
-- =================================================================
-- Creation order (a table is created only after everything it references):
--   1. passengers     -> references nothing
--   2. airports       -> references nothing
--   3. flights        -> references nothing
--   4. flight_routes  -> references flights, airports
--   5. bookings       -> references passengers, flights, and itself
--
-- Convention: every TIMESTAMP column stores UTC. Airports sit in
-- different time zones, so local times would make arrival-vs-departure
-- comparisons and durations meaningless.
-- =================================================================

-- Reset. Reverse creation order, so no dependency blocks a drop.
DROP TABLE IF EXISTS bookings      CASCADE;
DROP TABLE IF EXISTS flight_routes CASCADE;
DROP TABLE IF EXISTS flights       CASCADE;
DROP TABLE IF EXISTS airports      CASCADE;
DROP TABLE IF EXISTS passengers    CASCADE;


-- ----------------------------------------------------------------
-- 1. passengers (actor) — first, because it references nothing.
-- ----------------------------------------------------------------
CREATE TABLE passengers (
    passenger_id   INTEGER GENERATED ALWAYS AS IDENTITY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(254) NOT NULL,  -- 254 = longest valid address (RFC 5321)
    phone_number   VARCHAR(20),            -- E.164 max is 15 digits, plus '+' and spacing
    date_of_birth  DATE,
    CONSTRAINT pk_passengers PRIMARY KEY (passenger_id),
    CONSTRAINT uq_passengers_email UNIQUE (email),
    CONSTRAINT chk_passengers_email_format
        CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);


-- ----------------------------------------------------------------
-- 2. airports (catalog) — references nothing. Uses the IATA code as
--    a natural key, so it has no identity column.
-- ----------------------------------------------------------------
CREATE TABLE airports (
    airport_code  CHAR(3)      NOT NULL,
    airport_name  VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    country       VARCHAR(60)  NOT NULL,
    CONSTRAINT pk_airports PRIMARY KEY (airport_code),
    CONSTRAINT chk_airports_code_format
        CHECK (airport_code ~ '^[A-Z]{3}$')
);


-- ----------------------------------------------------------------
-- 3. flights (producer) — references nothing. Must exist before
--    flight_routes and bookings, which both point at it.
-- ----------------------------------------------------------------
CREATE TABLE flights (
    flight_id       INTEGER GENERATED ALWAYS AS IDENTITY,
    flight_number   VARCHAR(7)    NOT NULL,   -- e.g. 'AA1234': 2-char airline + up to 4 digits + suffix
    departure_time  TIMESTAMP     NOT NULL,   -- UTC
    arrival_time    TIMESTAMP     NOT NULL,   -- UTC
    aircraft_type   VARCHAR(50),
    base_fare       NUMERIC(10,2) NOT NULL,
    flight_status   VARCHAR(10)   NOT NULL DEFAULT 'scheduled',
    -- Derived value, stored: always consistent with the two times above.
    duration_min    INTEGER GENERATED ALWAYS AS
        ((EXTRACT(EPOCH FROM (arrival_time - departure_time)) / 60)::INTEGER) STORED,
    CONSTRAINT pk_flights PRIMARY KEY (flight_id),
    CONSTRAINT uq_flights_number_departure UNIQUE (flight_number, departure_time),
    CONSTRAINT chk_flights_arrival_after_departure
        CHECK (arrival_time > departure_time),
    CONSTRAINT chk_flights_base_fare_nonneg
        CHECK (base_fare >= 0),
    CONSTRAINT chk_flights_status
        CHECK (flight_status IN ('scheduled', 'delayed', 'cancelled', 'completed'))
);


-- ----------------------------------------------------------------
-- 4. flight_routes (junction) — resolves the M:N between flights and
--    airports. Created after both parents. The key is (flight_id,
--    stop_sequence), not (flight_id, airport_code): a row is "the nth
--    stop of this flight", and order matters.
-- ----------------------------------------------------------------
CREATE TABLE flight_routes (
    flight_id       INTEGER     NOT NULL,
    stop_sequence   INTEGER     NOT NULL,
    airport_code    CHAR(3)     NOT NULL,
    stop_type       VARCHAR(11) NOT NULL,
    scheduled_time  TIMESTAMP   NOT NULL,     -- UTC
    CONSTRAINT pk_flight_routes PRIMARY KEY (flight_id, stop_sequence),
    CONSTRAINT fk_flight_routes_flight
        FOREIGN KEY (flight_id) REFERENCES flights (flight_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_flight_routes_airport
        FOREIGN KEY (airport_code) REFERENCES airports (airport_code)
        ON DELETE RESTRICT,
    CONSTRAINT chk_flight_routes_stop_sequence_positive
        CHECK (stop_sequence >= 1),
    CONSTRAINT chk_flight_routes_stop_type
        CHECK (stop_type IN ('origin', 'layover', 'destination'))
);


-- ----------------------------------------------------------------
-- 5. bookings (event) — last, because it references passengers,
--    flights, and itself. rebooked_from is the recursive FK: when a
--    passenger changes flights, the new booking points at the one it
--    replaced.
-- ----------------------------------------------------------------
CREATE TABLE bookings (
    booking_id     INTEGER GENERATED ALWAYS AS IDENTITY,
    passenger_id   INTEGER,                   -- nullable: see fk_bookings_passenger
    flight_id      INTEGER       NOT NULL,
    booking_date   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fare_paid      NUMERIC(10,2) NOT NULL,
    seat_number    VARCHAR(4),                -- e.g. '12C'; assigned later, so nullable
    rebooked_from  INTEGER,
    CONSTRAINT pk_bookings PRIMARY KEY (booking_id),
    CONSTRAINT fk_bookings_passenger
        FOREIGN KEY (passenger_id) REFERENCES passengers (passenger_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_bookings_flight
        FOREIGN KEY (flight_id) REFERENCES flights (flight_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_bookings_rebooked_from
        FOREIGN KEY (rebooked_from) REFERENCES bookings (booking_id)
        ON DELETE SET NULL,
    CONSTRAINT uq_bookings_flight_seat UNIQUE (flight_id, seat_number),
    CONSTRAINT uq_bookings_rebooked_from UNIQUE (rebooked_from),
    CONSTRAINT chk_bookings_fare_paid_nonneg
        CHECK (fare_paid >= 0),
    CONSTRAINT chk_bookings_seat_format
        CHECK (seat_number ~ '^[0-9]{1,3}[A-K]$'),
    CONSTRAINT chk_bookings_no_self_rebook
        CHECK (rebooked_from IS DISTINCT FROM booking_id)
);
