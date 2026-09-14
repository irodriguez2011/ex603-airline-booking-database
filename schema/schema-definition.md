# Relation Schemas

## Overview

The Airline Booking database consists of five relations:

1. passengers
2. airports
3. flights
4. flight_routes
5. bookings

Each relation is described below with its attributes, domains, primary key, and foreign keys.

---

# 1. passengers

## Relation Schema

```
passengers(
    passenger_id,
    first_name,
    last_name,
    email,
    phone_number,
    date_of_birth
)
```

## Attributes and Domains

| Attribute     | Domain       |
| ------------- | ------------ |
| passenger_id  | SERIAL       |
| first_name    | VARCHAR(50)  |
| last_name     | VARCHAR(50)  |
| email         | VARCHAR(255) |
| phone_number  | VARCHAR(20)  |
| date_of_birth | DATE         |

## Primary Key

```
PK(passenger_id)
```

---

# 2. airports

## Relation Schema

```
airports(
    airport_code,
    airport_name,
    city,
    country
)
```

## Attributes and Domains

| Attribute    | Domain       |
| ------------ | ------------ |
| airport_code | CHAR(3)      |
| airport_name | VARCHAR(100) |
| city         | VARCHAR(100) |
| country      | VARCHAR(100) |

## Primary Key

```
PK(airport_code)
```

---

# 3. flights

## Relation Schema

```
flights(
    flight_id,
    flight_number,
    departure_time,
    arrival_time,
    aircraft_type,
    base_fare
)
```

## Attributes and Domains

| Attribute      | Domain        |
| -------------- | ------------- |
| flight_id      | SERIAL        |
| flight_number  | VARCHAR(10)   |
| departure_time | TIMESTAMP     |
| arrival_time   | TIMESTAMP     |
| aircraft_type  | VARCHAR(50)   |
| base_fare      | DECIMAL(10,2) |

## Primary Key

```
PK(flight_id)
```

---

# 4. flight_routes

## Relation Schema

```
flight_routes(
    flight_id,
    stop_sequence,
    airport_code,
    stop_type,
    scheduled_time
)
```

## Attributes and Domains

| Attribute      | Domain      |
| -------------- | ----------- |
| flight_id      | INTEGER     |
| stop_sequence  | INTEGER     |
| airport_code   | CHAR(3)     |
| stop_type      | VARCHAR(20) |
| scheduled_time | TIMESTAMP   |

## Primary Key

```
PK(flight_id, stop_sequence)
```

## Foreign Keys

```
FK(flight_id)
    → flights(flight_id)

FK(airport_code)
    → airports(airport_code)
```

---

# 5. bookings

## Relation Schema

```
bookings(
    booking_id,
    passenger_id,
    flight_id,
    booking_date,
    fare_paid,
    seat_number
)
```

## Attributes and Domains

| Attribute    | Domain        |
| ------------ | ------------- |
| booking_id   | SERIAL        |
| passenger_id | INTEGER       |
| flight_id    | INTEGER       |
| booking_date | TIMESTAMP     |
| fare_paid    | DECIMAL(10,2) |
| seat_number  | VARCHAR(10)   |

## Primary Key

```
PK(booking_id)
```

## Foreign Keys

```
FK(passenger_id)
    → passengers(passenger_id)

FK(flight_id)
    → flights(flight_id)
```

---

# Relationship Summary

| Parent Relation | Child Relation | Cardinality |
| ---------------- | --------------- | ----------- |
| passengers       | bookings        | 1 : M       |
| flights          | bookings        | 1 : M       |
| flights          | flight_routes   | 1 : M       |
| airports         | flight_routes   | 1 : M       |

---

# Relational Model

```
passengers(
    passenger_id PK,
    first_name,
    last_name,
    email,
    phone_number,
    date_of_birth
)

airports(
    airport_code PK,
    airport_name,
    city,
    country
)

flights(
    flight_id PK,
    flight_number,
    departure_time,
    arrival_time,
    aircraft_type,
    base_fare
)

flight_routes(
    flight_id FK,
    stop_sequence,
    airport_code FK,
    stop_type,
    scheduled_time,
    PK(flight_id, stop_sequence)
)

bookings(
    booking_id PK,
    passenger_id FK,
    flight_id FK,
    booking_date,
    fare_paid,
    seat_number
)
```