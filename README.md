# Airline Booking Database

## Project Overview

This repository contains my EX 603 course project: a PostgreSQL relational database for an airline booking system that organizes passengers, flights, bookings, airports, and flight routes.

The project will be developed incrementally across Units 1–6. It will begin with a relational data model and schema, then expand to include SQL queries, multi-table joins, data analysis, written reflections, and a final video presentation.

## Chosen Theme

I selected the **Airline Booking** theme. The database will model the following five roles required by the project:

| Database role | Table | Purpose |
|---|---|---|
| Actor | `passengers` | Stores information about passengers who make bookings. |
| Producer | `flights` | Stores the flights available for passengers to book. |
| Event | `bookings` | Records each booking, including its date and the fare paid. |
| Catalog | `airports` | Stores descriptive information about airports. |
| Junction | `flight_routes` | Connects flights and airports in a many-to-many relationship. |

The main numeric metric for the project is `fare_paid`. As the project develops, the database will support questions such as which flights receive the most bookings, how much revenue flights generate, which passengers book most frequently, and which airports are associated with particular routes.

## Project Status

This project is currently in **Unit 1: setup and planning**. The repository and README have been created, and the Airline Booking theme has been selected. The schema, queries, analysis, screenshots, and presentation will be added in later units.

## Planned Repository Structure

```text
.
├── README.md
├── schema/
│   ├── schema.sql
│   └── erd.png
├── queries/
│   ├── unit3/
│   ├── unit4/
│   ├── unit5/
│   └── unit6/
├── analysis/
└── screenshots/
```

## Technology

- PostgreSQL 14 or later
- A PostgreSQL client DataGrip, or `psql`
- Git and GitHub for version control and project presentation

## How to Run the Project

The database setup instructions will be added after the schema is created in a later unit. Before running future SQL files, users will need PostgreSQL 14 or later and access to a PostgreSQL database.

## Query Catalogue

Queries and the business questions they answer will be documented here as they are completed.

| Unit | Query or topic | Business question | Status |
|---|---|---|---|
| Unit 3 | To be added | To be added | Not started |
| Unit 4 | To be added | To be added | Not started |
| Unit 5 | To be added | To be added | Not started |
| Unit 6 | To be added | To be added | Not started |

## Technical Highlights

Technical highlights will be added as the schema and queries are developed.

## What I Would Do Differently

This reflection will be completed near the end of the project after the database has been designed, implemented, and tested.

## Video Presentation

The final 8–12 minute video presentation will be linked here in Unit 6.

## Academic and Security Note

This repository is an academic project created for EX 603. It must not contain passwords, database connection strings, API keys, or personal data.
