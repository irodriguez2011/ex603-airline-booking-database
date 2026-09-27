# Unit 2 Analysis — From ERD to DDL

The complete schema is in [`schema/schema.sql`](../schema/schema.sql). It runs top to bottom on an empty PostgreSQL 14+ database, and it runs a second time without manual cleanup because it opens with a reset block that drops the tables in reverse creation order.

## Creation Order

| # | Table | References | Why it sits here |
|---|---|---|---|
| 1 | `passengers` | — | No outgoing foreign keys. |
| 2 | `airports` | — | No outgoing foreign keys. |
| 3 | `flights` | — | No outgoing foreign keys, but both remaining tables point at it. |
| 4 | `flight_routes` | `flights`, `airports` | Both parents now exist. |
| 5 | `bookings` | `passengers`, `flights`, `bookings` | Last, because it depends on two parents; its self-reference needs nothing that isn't created in the same statement. |

## Foreign Key Constraints

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `bookings.passenger_id → passengers.passenger_id` | SET NULL | Honors account deletion while keeping the booking and its `fare_paid` in the revenue history. |
| `bookings.flight_id → flights.flight_id` | RESTRICT | A flight with bookings carries revenue and seat history, so it must be cancelled via `flight_status`, not deleted. |
| `bookings.rebooked_from → bookings.booking_id` | SET NULL | Purging an old, replaced booking must never destroy or block the live booking that replaced it. |
| `flight_routes.flight_id → flights.flight_id` | CASCADE | A route stop has no meaning without its flight. |
| `flight_routes.airport_code → airports.airport_code` | RESTRICT | Airports are catalog data that active routes depend on. |

### What each choice governs

**Passenger deletion — `bookings.passenger_id`, SET NULL.** The real event is a customer closing their account and asking for their personal data to be removed. When that `passengers` row is deleted, every booking they made stays in place with `passenger_id` set to `NULL`: the flight, the date, the seat, and the fare survive. The people affected are the airline's finance and analytics teams, whose revenue-per-flight and load-factor figures stay correct, and the passenger, whose identifying record is actually gone. Under `CASCADE`, closing one account would silently delete real, paid-for bookings and reduce reported revenue for past flights. Under `RESTRICT`, the deletion would be refused for as long as any booking existed, which for a regular traveller means forever, so the platform could never honor the request. The cost of my choice is that anonymized bookings can no longer be traced to a person, which is why `bookings.passenger_id` is the one nullable foreign key in the schema.

**Flight deletion — `bookings.flight_id`, RESTRICT.** The real event is an operations user trying to remove a flight, most likely because it was cancelled. On this platform a cancellation is recorded by setting `flights.flight_status = 'cancelled'`, not by deleting the row. `RESTRICT` makes that distinction enforceable: a flight with bookings cannot be deleted, so the passengers who need refunds or rebooking, and the reports that count cancelled flights, still have a row to point at. Under `CASCADE`, deleting the flight would erase every booking on it, leaving passengers who paid with no record of their ticket. Under `SET NULL`, the column is `NOT NULL`, and even if it weren't, a booking with no flight is meaningless. A flight with **no** bookings (a duplicate or a data-entry mistake) can still be deleted.

**Booking purge — `bookings.rebooked_from`, SET NULL.** This is the recursive foreign key. The real event is a passenger changing flights: the airline issues a new booking whose `rebooked_from` points at the booking it replaced, which creates a change history. If the old booking is later deleted (for example, in a data-retention purge), the new booking is a valid, paid ticket and must survive, so its link simply becomes `NULL`. Under `CASCADE`, purging an old booking would delete the passenger's current ticket. Under `RESTRICT`, no replaced booking could ever be purged. I placed this key on `bookings` rather than on `passengers` (as a referral link) because rebooking is an event the airline actually handles every day and it relates booking to booking. `uq_bookings_rebooked_from` also ensures a booking can be replaced only once, so the history is a single chain rather than a tree.

**Flight deletion — `flight_routes.flight_id`, CASCADE.** The event is the same flight deletion as above, but from the route's side. Because of the RESTRICT on `bookings`, this cascade only ever runs for a flight nobody booked, such as a duplicate entry. Its stops (origin, layovers, destination) describe nothing once the flight is gone, so they are removed with it. Under `RESTRICT`, anyone cleaning up a mistaken flight would first have to delete each of its stops by hand. Under `SET NULL`, `flight_id` is part of the primary key and cannot be null.

**Airport deletion — `flight_routes.airport_code`, RESTRICT.** The event is someone removing an airport from the catalog, perhaps because it closed. `RESTRICT` blocks the delete while any flight still stops there. The affected parties are passengers and schedulers, whose itineraries would otherwise lose a stop. Under `CASCADE`, deleting one airport would silently remove a stop from the middle of every multi-leg flight through it, turning JFK → ORD → LAX into JFK → LAX with no error.

## CHECK Constraints

| Constraint | Invalid state it makes unstorable | How that state could otherwise arise |
|---|---|---|
| `chk_flights_arrival_after_departure` | A flight arriving at or before its departure. | Swapped columns in an import script, or local times entered instead of UTC. A westbound flight such as Tokyo 17:00 → Los Angeles 10:00 local looks like it arrives before it leaves. This check is also why the schema stores all times in UTC. |
| `chk_flights_base_fare_nonneg` | A negative base fare. | A discount applied twice, or a sign error when a pricing tool writes an adjustment. |
| `chk_flights_status` | A status outside `scheduled / delayed / cancelled / completed`. | Free-text entry: `'Cancelled'`, `'canceled'`, and `'CXL'` would each be counted as a different state, and a query for `= 'cancelled'` would miss them. |
| `chk_airports_code_format` | An airport code that isn't three uppercase letters. | Typing `jfk` or the four-letter ICAO code `KJFK`. The lowercase version would then fail to match `JFK` in joins. |
| `chk_flight_routes_stop_sequence_positive` | A stop numbered 0 or negative. | Code that counts from 0 while the rest of the platform counts from 1, which would make "first stop" queries (`stop_sequence = 1`) return the second stop. |
| `chk_flight_routes_stop_type` | A stop type outside `origin / layover / destination`. | Inconsistent spelling (`'stopover'`, `'Layover'`), which would break queries that find where a flight starts or ends. |
| `chk_bookings_fare_paid_nonneg` | A negative amount paid. | Recording a refund as a negative booking instead of as its own transaction, which would silently reduce revenue totals. |
| `chk_bookings_seat_format` | A seat that isn't 1–3 digits followed by a row letter A–K (e.g. `12C`). | Free-text input such as `'window'` or `'12 c'`. That would also defeat `uq_bookings_flight_seat`, because `'12C'` and `'12 c'` would be treated as different seats. |
| `chk_bookings_no_self_rebook` | A booking listed as rebooked from itself. | A bug that copies `booking_id` into `rebooked_from`. That creates a one-row loop, so any query walking the rebooking chain would never terminate. `IS DISTINCT FROM` is used so the ordinary case (`rebooked_from` is `NULL`) passes. |
| `chk_passengers_email_format` | An email without the basic `name@domain.tld` shape. | A typo at signup or a phone number entered in the email field. That leaves the passenger unreachable for booking confirmations, and the value still occupies the `UNIQUE` slot. |

## Derived Value: `flights.duration_min`

I chose to **store** flight duration as `GENERATED ALWAYS AS (...) STORED` rather than compute it at query time. Duration is needed often (average duration per route, delay analysis), and a generated column cannot fall out of step with `departure_time` and `arrival_time`, because PostgreSQL recalculates it on every write and rejects any attempt to set it directly. This depends on the UTC convention: if the two timestamps were local times in different time zones, the subtraction would produce a wrong duration.

## Changes from the Unit 1 Design

Implementation forced or prompted the following changes. The ERD (`schema/erd.png`, source `schema/erd.mmd`) has been updated to match.

1. **Added `bookings.rebooked_from` (recursive FK).** The Unit 1 design had no self-referencing relationship. Rebooking is the natural one in this domain.
2. **Added `flights.flight_status`.** Unit 1 argued that a cancelled flight "should be represented as a status change on the `flights` row", but there was no column for it. Without one, the RESTRICT on `bookings.flight_id` would leave no way to record a cancellation.
3. **Added `flights.duration_min`** as a stored generated column (see above).
4. **Passenger → booking cardinality changed from exactly one to zero-or-one.** Unit 1 already made `bookings.passenger_id` nullable for SET NULL, but the ERD still drew the relationship as mandatory. The diagram now matches the constraint.
5. **Types mapped to PostgreSQL:** `SERIAL` → `INTEGER GENERATED ALWAYS AS IDENTITY`, `DECIMAL` → `NUMERIC(10,2)`. Some lengths were narrowed to real limits: `email` 254, `flight_number` 7, `seat_number` 4, `stop_type` 11, `country` 60.
6. **New constraints:** `uq_flights_number_departure` (the same flight number can't depart twice at the same time), `uq_bookings_flight_seat` (no seat sold twice on one flight), `uq_bookings_rebooked_from`, and the format/list CHECKs in the table above.
7. **Junction key.** `flight_routes` resolves the M:N between flights and airports, but unlike the textbook junction its primary key is `(flight_id, stop_sequence)` rather than the pair of foreign keys. A row means "the nth stop of this flight", and the order of stops is the information the table exists to hold.
