# Airline Booking Database

A PostgreSQL database that models an airline's booking system — passengers, flights, bookings, airports, and the routes connecting them.

## Project Overview

This repository contains my EX 603 course project: a PostgreSQL relational database for an airline booking system that organizes passengers, flights, bookings, airports, and flight routes.

The project will be developed incrementally across Units 1–6. It will begin with a relational data model and schema, then expand to include SQL queries, multi-table joins, data analysis, written reflections, and a final video presentation.

## Chosen Theme

I selected the **Airline Booking** theme. The database will model the following five roles required by the project:

| Database role | Table           | Purpose                                                       |
| -------------- | --------------- | -------------------------------------------------------------- |
| Actor          | `passengers`    | Stores information about passengers who make bookings.         |
| Producer       | `flights`       | Stores the flights available for passengers to book.           |
| Event          | `bookings`      | Records each booking, including its date and the fare paid.    |
| Catalog        | `airports`      | Stores descriptive information about airports.                 |
| Junction       | `flight_routes` | Connects flights and airports in a many-to-many relationship.  |

The main numeric metric for the project is `fare_paid`. As the project develops, the database will support questions such as which flights receive the most bookings, how much revenue flights generate, which passengers book most frequently, and which airports are associated with particular routes.

## Domain

The Airline Booking database models the core operations of an airline's booking platform: passengers, the flights they can book, the bookings themselves, the airports those flights touch, and the routes connecting flights to airports. It's designed to reflect how a real airline reservation system behaves — flights can include layovers across multiple airports, passengers accumulate a history of bookings over time, and every booking carries a fare that contributes to the platform's revenue.

The database needs to answer a consistent set of business questions as the project develops: which flights receive the most bookings, how much revenue each flight generates, which passengers book most frequently, and which airports are associated with which routes. These questions shaped several of the schema's design decisions — for example, routing every flight-to-airport relationship through a dedicated `flight_routes` table, rather than storing departure and arrival airports directly on `flights`, makes it possible to model flights with more than one stop and to answer airport-level questions without a separate structure for layovers.

The full entity-relationship diagram below shows how the five relations connect.

![Airline Booking ERD](schema/erd.png)

## Schema

The full DDL is in [`schema/schema.sql`](schema/schema.sql); the reasoning behind each constraint is in [`analysis/unit2.md`](analysis/unit2.md).

| # | Table | Role | Key | References |
|---|---|---|---|---|
| 1 | `passengers` | Actor | `passenger_id` (identity) | — |
| 2 | `airports` | Catalog | `airport_code` (natural IATA code) | — |
| 3 | `flights` | Producer | `flight_id` (identity) | — |
| 4 | `flight_routes` | Junction | `(flight_id, stop_sequence)` composite | `flights`, `airports` |
| 5 | `bookings` | Event | `booking_id` (identity) | `passengers`, `flights`, `bookings` |

Design decisions worth noticing:

- **Recursive foreign key on `bookings.rebooked_from`.** When a passenger changes flights, the new booking points at the one it replaced, forming a change history.
- **Composite key on the junction.** `flight_routes` is keyed by `(flight_id, stop_sequence)`, not by the two foreign keys, because the order of stops is what the table records.
- **Deletes preserve history.** Deleting a passenger anonymizes their bookings (`SET NULL`) rather than erasing revenue; flights with bookings and airports with routes cannot be deleted (`RESTRICT`); a cancelled flight is recorded with `flight_status`.
- **All timestamps are UTC**, which keeps the `arrival_time > departure_time` check valid across time zones and lets `duration_min` be a stored generated column.
- **Every constraint is named** (`pk_`, `fk_`, `uq_`, `chk_`), so errors point directly at the rule that was broken.

## Project Status

This project has completed **Unit 2: implementation**. Unit 1 produced the relation schemas, ERD, integrity constraints, and written analysis. Unit 2 translated them into a working PostgreSQL schema (`schema/schema.sql`), updated the ERD where implementation changed the design, and documented every foreign key and CHECK decision in `analysis/unit2.md`. Queries and further analysis will be added in later units.

## Planned Repository Structure

```
.
├── README.md
├── schema/
│   ├── schema.sql
│   ├── schema-definition.md
│   ├── constraints.md
│   ├── erd.png
│   └── erd.mmd
├── queries/
│   ├── unit3/
│   ├── unit4/
│   ├── unit5/
│   └── unit6/
├── analysis/
│   ├── unit1.md
│   └── unit2.md
└── screenshots/
```

## Technology

- PostgreSQL 14 or later
- A PostgreSQL client DataGrip, or `psql`
- Git and GitHub for version control and project presentation

## How to Run the Project

Requires PostgreSQL 14 or later. Create an empty database, then run the schema script from the repository root:

```bash
createdb airline_booking
psql -d airline_booking -v ON_ERROR_STOP=1 -f schema/schema.sql
psql -d airline_booking -c '\dt'
```

The script starts with a reset block, so it can be re-run at any time without manual cleanup.

## Query Catalogue

Queries and the business questions they answer will be documented here as they are completed.

| Unit   | Query or topic | Business question | Status      |
| ------ | --------------- | ------------------ | ------------ |
| Unit 3 | To be added     | To be added         | Not started |
| Unit 4 | To be added     | To be added         | Not started |
| Unit 5 | To be added     | To be added         | Not started |
| Unit 6 | To be added     | To be added         | Not started |

## Technical Highlights

Technical highlights will be added as the schema and queries are developed.

## What I Would Do Differently

This reflection will be completed near the end of the project after the database has been designed, implemented, and tested.

## Video Presentation

The final 8–12 minute video presentation will be linked here in Unit 6.

## Academic and Security Note

This repository is an academic project created for EX 603. It must not contain passwords, database connection strings, API keys, or personal data.
