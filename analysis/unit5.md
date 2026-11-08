# Unit 5 Analysis

Queries: [`queries/unit5/q5_1.sql`](../queries/unit5/q5_1.sql), [`queries/unit5/q5_2.sql`](../queries/unit5/q5_2.sql), and [`queries/unit5/q5_3.sql`](../queries/unit5/q5_3.sql), run against the `ex603_data` database (PostgreSQL 16).

For this unit, the event table is `bookings`, the actor is the passenger, the producer is the flight, the catalog is `airports`, and the junction table is `flight_routes`, which links flights to the airports they serve. The flights identified in Unit 4 are **VN202** (flight 2), **VN203** (flight 3), and **VN211** (flight 11).

## Task 5.1: Connect producers to their data

### What the queries showed

- **Who is behind the bookings (5.1.1).** Joining `bookings`, `passengers`, and `flights` lists all 45 bookings on the three Unit 4 flights, each with its passenger and booking time. The 6 no-shows come from 5 different passengers. Passenger 21 is the only repeat, with a no-show on both VN203 and VN211. No single passenger is driving the problem. The join also shows that most of VN211's cancellations were not the passengers' choice: 2 were flight cancellations and 1 was a failed payment.
- **Shared airport (5.1.2).** Going from `airports` through `flight_routes` to `flights` shows that five flights route through **SIN (Changi Airport)**: VN202, VN203, VN205, VN210, and VN211. SIN is the only airport all three Unit 4 flights have in common. But VN205 and VN210 also fly through SIN and have no no-shows, so the airport is a lead, not an explanation.
- **Self join on seat capacity (5.1.3).** Comparing each flight with other flights of the same aircraft size shows the clearest pattern. VN202 and VN203 are both 320-seat aircraft, as are VN201, VN204, and VN205. Four of those five have no-shows. Together the 320-seat flights have 7 no-shows in 64 bookings (**10.9%**), against 5 in 136 (**3.7%**) for every other flight. VN211 (193 seats) has no same-size peer, which fits its different problem: cancellations rather than no-shows. Activity level doesn't explain the pattern, because VN205 has more bookings than VN202 and no no-shows. The self join also surfaced a data question: **VN203 is marked inactive but has 13 bookings**.

### Which feature could use the three-table join?

The three-table join from 5.1.1 could power a **flight manifest and booking-history screen** for operations staff. For a selected flight, it would list each booking with the passenger's name and ID, when they booked, and how the booking ended: confirmed, cancelled with its reason, or disputed. Staff could see at a glance which passengers didn't show up and whether the same passenger keeps failing to show across flights, as passenger 21 did. None of the three tables can show that alone: `bookings` holds only IDs, `passengers` has no flight information, and `flights` has no booking history.

### Why the junction table matters for Question 2

A flight can stop at several airports, and an airport serves many flights. That many-to-many relationship can't be stored in either table alone. `flight_routes` holds one row per flight and airport pair, so the question "which flights go through SIN?" is a straightforward join: airports → flight_routes → flights.

Without the junction table, the airports would have to be stored on the `flights` table. A fixed set of columns like `airport_1`, `airport_2`, `airport_3` would cap how many stops a flight can have, and every query would need to check each column (`WHERE airport_1 = 'SIN' OR airport_2 = 'SIN' OR ...`). A single text list like `'SGN,SIN,NRT'` would force string matching, which can't use a foreign key or an index and breaks on typos. Either way, a simple question becomes fragile, and the database could no longer guarantee that every airport on a route really exists.

## Task 5.2: Find records that joins may exclude

### What the queries showed

- **Part A.** The LEFT JOIN from `flights` to `bookings` returns all **15** flights, with VN214 and VN215 showing 0 bookings. The same query as an INNER JOIN returns only **13**. Counting distinct `flight_id` values in each result (15 − 13) confirms that the **INNER JOIN excludes 2 flights**. I counted distinct IDs because the joined rows have one row per booking, so counting rows would count a busy flight like VN206 21 times.
- **Part B.** Writing the LEFT JOIN as `bookings RIGHT JOIN flights` returns the same 15 rows. I checked this with EXCEPT in both directions rather than assuming it: 0 rows differ. The FULL OUTER JOIN returns 200 matched rows (13 flights, 200 bookings) plus 2 rows for flights with no bookings, and **no bookings without a flight**.
- **Part C.** NOT EXISTS and EXCEPT both return flights **14 and 15**, and a comparison of the two results finds 0 flights that appear in only one. NOT EXISTS tests each flight row for a matching booking, so it can return any column from `flights`. EXCEPT compares two lists of IDs as sets, so it returns only the shared column (`flight_id`) and removes duplicates.

**What a FULL OUTER JOIN can reveal.** A LEFT JOIN from `flights` finds flights with no bookings, and a RIGHT JOIN in the same direction finds the same thing. Neither one checks the other side. A FULL OUTER JOIN keeps unmatched rows from both tables in one result, so it would also expose bookings that point to a flight that doesn't exist. Here it found none, because the foreign key `fk_bookings_prod` makes that impossible. On data without that constraint, such as an import or a copy of another system's data, the FULL OUTER JOIN would catch both kinds of gaps at once.

### Which flights did the INNER JOIN exclude?

**Flight 14 (VN214)** and **flight 15 (VN215)**.

### What it means when a flight has no bookings

In this data, it means no passenger booked VN214 or VN215 at any point during the booking period (January to December 2023). Both are still marked **active** (`is_active = true`), so they aren't flights the airline already retired.

Possible explanations:

- **They can't be booked yet.** Neither flight has any row in `flight_routes`, so it has no airports attached. A flight with no route may not appear in search results at all.
- **They are new, seasonal, or planned flights** that haven't opened for sale.
- **Low demand on the route**, so they were listed but nobody chose them.
- **A data problem.** Bookings may have been recorded under a different flight ID, or the `is_active` flag may be out of date. VN203 shows the flag can be wrong in the other direction: it is marked inactive but has 13 bookings.

### How an inner-join report gives an incomplete picture

A report built on an INNER JOIN only describes flights that already have bookings. VN214 and VN215 wouldn't appear at all: not as zeros, but as if they didn't exist. Leadership would see 13 flights and assume that is the whole schedule. Platform averages, such as bookings per flight, would also look healthier than they are: 200 ÷ 13 = 15.4 instead of 200 ÷ 15 = 13.3. And the problem the report most needs to show, flights the airline runs that nobody books, is exactly the one it hides.

### Why leadership would want to find flights that were never active

An active flight with no bookings is pure cost: an aircraft, crew, and an airport slot that earn nothing. VN214 alone is a 303-seat aircraft, one of the largest in the fleet. These flights are also invisible to every report built so far in this project, including the Unit 4 no-show analysis, so no one would think to ask about them unless someone went looking.

### What leadership could do

Start by checking with the scheduling team whether VN214 and VN215 were ever open for sale, and why they have no routes. If they were never set up properly, fix the setup and put them on sale. If they were set up but nobody booked them, decide whether to market them, move the aircraft to a busier route, or deactivate them so they stop showing as active capacity.

### What the data shows vs. what needs investigating

| The data shows | Needs further investigation |
|---|---|
| VN214 and VN215 have 0 bookings in 2023. | Whether they were ever on sale. |
| Both are marked `is_active = true`. | Whether that flag is accurate. VN203 suggests the flag isn't always reliable. |
| Neither has any route in `flight_routes`. | Whether the missing route is *why* they have no bookings. VN213 also has no route but still has 11 bookings, so a missing route doesn't block bookings on its own. |
| VN214 has 303 seats; VN215 has 132. | What these aircraft are actually doing, and what they cost while unbooked. |

## Task 5.3: Understand join performance and execution plans

### Part A: CROSS JOIN

`airports` has **5** rows and `flights` has **15**. Their CROSS JOIN returns **75** rows, exactly 5 × 15. Every airport is paired with every flight, whether or not the flight goes there: only 25 of those pairings are real routes in `flight_routes`.

**When a Cartesian product is useful on this platform.** It's useful for building a complete grid before counting. In Unit 4, grouping bookings by country and status returned 14 rows, because Thailand had no disputed bookings and GROUP BY only returns combinations that exist. Query 5.3A.2 CROSS JOINs the 5 countries with the 3 statuses to build all 15 combinations first, then LEFT JOINs bookings onto them. Thailand / disputed now shows as **0** instead of being missing. A regional dashboard needs that, so a reader can tell "none happened" apart from "not reported". The same idea would apply to a flight × month calendar, so that months with no bookings still show up.

**When it signals an error.** Joining `bookings` and `flights` with no join condition (5.3A.3) returns 200 × 15 = **3,000** rows instead of 200. Every booking gets paired with every flight, so any total built on it would be 15 times too large. A row count that equals the product of the two table sizes is the giveaway that an ON clause is missing or wrong.

### Part B: Reading the execution plan

The three-table join from 5.1.1 (bookings + passengers + flights for VN202, VN203, and VN211) produced this plan (`EXPLAIN ANALYZE`, abbreviated):

```
Sort  (rows=5 estimated, 45 actual)
  -> Nested Loop
       -> Nested Loop
            -> Seq Scan on bookings b                (200 rows)
            -> Memoize  (cache key: b.flight_id; 187 hits, 13 misses)
                 -> Index Scan using flights_pkey on flights f
                      Filter: flight_number IN ('VN202','VN203','VN211')
       -> Index Scan using passengers_pkey on passengers p   (loops=45)
Execution Time: under 1 ms
```

**Which join algorithms did PostgreSQL choose?** Two **Nested Loop** joins: one between bookings and flights, then one with passengers. A **Memoize** node caches flight lookups, and a **Sort** produces the final order. No Hash Join or Merge Join is used.

**What in the plan explains those choices?**

- **Table sizes.** `bookings` has only 200 rows on 3 disk pages, so the cheapest way to read it is a **Seq Scan** of the whole table. An index wouldn't save anything at this size, and there is no index on `bookings.flight_id` or `bookings.passenger_id` anyway.
- **Primary-key indexes on the other side.** For each booking, PostgreSQL finds its flight with `flights_pkey` and its passenger with `passengers_pkey`. A Nested Loop is the natural fit when every lookup on the inner side is a cheap index hit returning one row.
- **Repeated lookups.** The 200 bookings point to only 13 different flights, so **Memoize** looks up each flight once (13 misses) and reuses the answer 187 times.
- **A low row estimate.** The planner expected the filtered join to return **5** rows; it really returned **45**. Query 5.3B.3 shows why: `bookings` has statistics (auto-analyzed), but `flights` and `passengers` have **never been analyzed**, so the planner had to guess how many flights match `flight_number IN (...)`. With an estimate that small, a Nested Loop looks cheapest. Building a hash table only pays off when many rows are expected.

**Why it's useful to understand the join algorithm.** The plan shows what the database actually does, not what the query seems to say. Here it shows that PostgreSQL reads all 200 bookings to find the 45 it needs, and that its estimate was off by 9×. Neither is visible from the query text. Knowing the algorithm explains why a query that's fast today could slow down, which index would help, and whether a bad estimate is steering the planner to the wrong strategy.

**What could change the algorithm, and which part would slow down first?** The **Seq Scan on bookings** is the part most likely to become inefficient. It reads every booking on the platform even though the query wants only three flights. At 200 rows that's instant; at millions of rows it means reading the whole table every time. As the tables grow:

- With many more bookings and accurate statistics, PostgreSQL would likely switch to a **Hash Join**: build a hash table of the 3 matching flights and stream the bookings past it once, instead of looping.
- An **index on `bookings(flight_id)`** would let it start from the 3 filtered flights and fetch only their bookings: a Nested Loop again, but driven from the small side.
- If both inputs arrived already sorted on the join key, for example both read through indexes on the key, a **Merge Join** could become the cheapest.
- Running `ANALYZE` on `flights` and `passengers` would fix the 5-vs-45 estimate. At this size it probably wouldn't change the plan, but on a large table a bad estimate like this one can make the planner pick a Nested Loop where a Hash Join would be far faster.

## Reflection

What would make PostgreSQL choose a different join algorithm for my three-table join? The deciding factor is how many rows the planner *thinks* each step will produce. Today it chose Nested Loops because every table is tiny, both lookups (flights and passengers) can use a primary-key index, and it expected only 5 matching rows.

**Table size** is the first lever. If bookings grew to millions of rows, scanning the whole table and looking up a flight for every row would get expensive, and a **Hash Join** would become cheaper: build a small hash table of the three flights, then pass over the bookings once. **Indexes** are the second. An index on `bookings.flight_id` would let PostgreSQL start from the three flights and fetch only their bookings, avoiding the full scan entirely. Inputs already sorted on the join key could make a **Merge Join** the best option. The **number of matching records** is the third. If the filter matched most flights instead of three, the per-row lookups of a Nested Loop would add up, and a Hash Join would win.

All of this depends on accurate **statistics**. My plan estimated 5 rows but returned 45, because `flights` and `passengers` had never been analyzed. On a small table that mistake costs nothing. On a large one, it can lead the planner to a Nested Loop that runs millions of lookups. Keeping statistics current matters as much as adding indexes.
