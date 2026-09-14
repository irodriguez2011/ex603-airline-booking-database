# Integrity Constraints

## Overview

This document specifies the constraints enforced at the database level for the Airline Booking database. It covers NOT NULL, UNIQUE, and CHECK constraints, followed by every foreign key with its justified ON DELETE behavior.

---

# NOT NULL Constraints

| Table | Column | Required? | Reason |
|---|---|---|---|
| passengers | first_name, last_name, email | NOT NULL | A passenger record is meaningless without a name and a way to contact them. |
| passengers | phone_number, date_of_birth | nullable | Optional at signup; not required to make a booking. |
| airports | airport_name, city, country | NOT NULL | An airport row must be identifiable to be useful in a route. |
| flights | flight_number, departure_time, arrival_time, base_fare | NOT NULL | A flight can't be scheduled or priced without these. |
| flights | aircraft_type | nullable | May be unassigned during early scheduling. |
| flight_routes | airport_code, stop_type, scheduled_time | NOT NULL | A route stop is incomplete without knowing where, what kind of stop, and when. |
| bookings | flight_id, booking_date, fare_paid | NOT NULL | A booking must always tie to a real flight, date, and amount paid. |
| bookings | passenger_id | nullable | Exception — see the ON DELETE SET NULL justification below. |
| bookings | seat_number | nullable | May be assigned after booking, not at the time of purchase. |

---

# UNIQUE Constraints

| Table | Column | Reason |
|---|---|---|
| passengers | email | Prevents the same person from creating duplicate accounts, and keeps email usable as a lookup key. |

---

# CHECK Constraints

| Table | Constraint | Reason |
|---|---|---|
| flights | `CHECK (arrival_time > departure_time)` | A flight physically cannot arrive before it departs. Catching this at the database level stops bad data from ever being written, regardless of which application or script inserts it. |
| flights | `CHECK (base_fare >= 0)` | A fare can't be negative. |
| bookings | `CHECK (fare_paid >= 0)` | Same logic — a paid amount can't be negative. |
| flight_routes | `CHECK (stop_sequence >= 1)` | Stop order starts at 1 (the first stop), not 0 or a negative number. |

---

# Foreign Key Constraints and ON DELETE Justification

## 1. bookings.passenger_id → passengers.passenger_id

```
FK(passenger_id) REFERENCES passengers(passenger_id)
ON DELETE SET NULL
```

**Justification:** The platform needs to support account-deletion requests without destroying financial and booking history. `SET NULL` lets a passenger's record be removed while the `bookings` rows tied to them stay intact — `fare_paid`, `flight_id`, and `booking_date` are preserved, so revenue totals and per-flight booking counts are unaffected. The booking simply can no longer be traced to a specific person. This requires `bookings.passenger_id` to allow `NULL`, which is why it's listed as nullable above.

## 2. bookings.flight_id → flights.flight_id

```
FK(flight_id) REFERENCES flights(flight_id)
ON DELETE RESTRICT
```

**Justification:** A flight with existing bookings has revenue and passenger-count history attached to it. Deleting the flight would silently erase that record. If a flight is cancelled, that should be represented as a status change on the `flights` row, not a deletion — so `RESTRICT` blocks the delete and forces that distinction to be made deliberately.

## 3. flight_routes.flight_id → flights.flight_id

```
FK(flight_id) REFERENCES flights(flight_id)
ON DELETE CASCADE
```

**Justification:** A `flight_routes` row has no meaning independent of its flight — it exists only to describe a stop that flight makes. If a flight is ever removed (for example, a duplicate or erroneous entry), its route stops should go with it automatically rather than being left behind as orphaned data.

## 4. flight_routes.airport_code → airports.airport_code

```
FK(airport_code) REFERENCES airports(airport_code)
ON DELETE RESTRICT
```

**Justification:** Airports are reference/catalog data, not transactional data — they're expected to be stable and rarely change. `RESTRICT` prevents an airport from being deleted while active routes still depend on it, which would otherwise silently break every flight that passes through it.

---

# Summary

| Foreign Key | ON DELETE | Short Reason |
|---|---|---|
| bookings.passenger_id → passengers.passenger_id | SET NULL | Preserve revenue/booking history while still honoring account deletion |
| bookings.flight_id → flights.flight_id | RESTRICT | Preserve booking and revenue history tied to a flight |
| flight_routes.flight_id → flights.flight_id | CASCADE | Route stops have no meaning without their flight |
| flight_routes.airport_code → airports.airport_code | RESTRICT | Protect catalog data from deletion while still in use |