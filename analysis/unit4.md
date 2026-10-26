# Unit 4 Analysis

Queries: [`queries/unit4/q4_1.sql`](../queries/unit4/q4_1.sql) and [`queries/unit4/q4_2.sql`](../queries/unit4/q4_2.sql), run against the `ex603_data` database.

For this unit, the event table is `bookings`, the metric is `fare_paid`, the actor is the passenger, the producer is the flight, and the region is `booking_country`. A **failure** is a booking cancelled because the passenger did not show up (`cancellation_reason = 'Passenger no show'`), the same definition as the Unit 3 finding. All cancellations are reported alongside it as a broader measure.

## Task 4.1: Measure the platform

### What the queries showed

- **Whole platform (4.1.1).** 200 bookings, $3,628.19 in fares, an average fare of $18.14, fares from $0.00 to $70.86, and 30 distinct passengers.
- **The $0.00 minimum (4.1.1b).** A booking should not have a $0.00 fare, so I checked it. All 34 zero fares are cancelled bookings, and every cancelled booking has a zero fare. The fare appears to be zeroed out on cancellation. This isn't corrupt data, but it pulls the average down: without cancelled bookings, the average fare is $21.86, not $18.14.
- **Per flight (4.1.2).** 13 flights have bookings, from 21 (VN206) down to 6 (VN204). Average fares range from $11.94 (VN211) to $23.06 (VN205). The lowest averages belong to the flights with the most cancellations, because each cancellation adds a $0.00 fare.
- **Volume threshold (4.1.3).** I kept only flights with at least 15 bookings. 200 bookings across 13 booked flights is about 15 per flight, so this keeps flights with at least average volume. Below 15 bookings, a single no-show moves a flight's rate by more than 6.7 percentage points, which is larger than the whole platform's 6% no-show rate. Eight flights qualify. Among them, VN202 has an 18.8% no-show rate, about three times the platform rate.
- **Region by status (4.1.4).** Thailand has the most cancellations (11 of 40) and no disputed bookings. Korea has the most disputed bookings (4). Confirmed fares are similar across regions ($18.89 to $24.39).

### Who acts on the per-flight breakdown, and what it hides

The person who would act on the per-flight breakdown is the **flight operations manager** responsible for these routes. They decide whether a flight's no-show problem needs a change, such as stricter check-in reminders, overbooking rules, or a schedule change.

The aggregates hide a lot:

- **An average conceals its distribution.** The $18.14 average fare looks like a typical price, but it mixes 34 refunded bookings at $0.00 with 166 paid bookings averaging $21.86. A flight's average can fall because its fares are low or because many of its passengers cancelled, and the average alone cannot tell you which.
- **A count conceals who is counted.** A GROUP BY over bookings only shows flights that have bookings, so flights 14 and 15 are invisible rather than shown as zero. The counts also don't say whether VN202's three no-shows came from three different passengers or one passenger who keeps failing to show up, and those call for very different fixes. Thailand's missing "disputed" row in 4.1.4 is another absence that is easy to miss.

**What I would need to see next:** the individual no-show bookings for VN202 and VN203 with passenger IDs and booking dates, to see whether the no-shows are spread out or concentrated in a few passengers or dates; the full spread of fares per flight (median and range), not just the average; and the two flights with no bookings, to learn whether they are new, inactive, or a data gap.

## Task 4.2: Build the breakdown leadership asked for

### Part A: Two numbers in one pass

The conditional aggregation answers two questions side by side for each flight:

1. **How many bookings did this flight receive?** (`COUNT(*)`)
2. **How many of those bookings were passenger no-shows?** (`SUM(CASE WHEN cancellation_reason = 'Passenger no show' THEN 1 ELSE 0 END)`)

Both come from one pass over `bookings` with no WHERE clause. A WHERE filter on no-shows would have removed every other booking, and the total would have been lost. The outliers are VN202 (3 of 16, 18.8%) and VN203 (2 of 13, 15.4%). VN204 also shows a high rate (1 of 6, 16.7%), but on too few bookings to trust.

### Part B: Subtotals and a grand total

`GROUP BY ROLLUP (booking_country)` returns one row per region plus one platform row, with no individual booking rows.

- **Subtotal rows:** the five rows labelled `Regional subtotal` (Japan, Korea, Singapore, Thailand, Vietnam).
- **Grand total row:** the last row, labelled `ALL REGIONS` / `Grand total`. ROLLUP leaves its region as NULL; `GROUPING(booking_country) = 1` identifies it, and the query labels it so it can't be mistaken for missing data.

The reader who needs subtotals rather than detail rows is the **regional director**. They manage countries, not individual bookings, and 200 booking rows would bury the five numbers they need. The **grand total** supports a decision the regional rows cannot: whether the platform as a whole has a no-show problem at all. The 6.0% grand total is the benchmark for each region. Thailand (10.0%) and Vietnam (7.9%) are above it, and Japan (2.3%) and Singapore (2.5%) are well below. Without the grand total, a director could not tell whether 7.7% in Korea is high or normal, and leadership could not judge the platform against the 50% the dashboard reported in Unit 3.

### Part C: A two-step pipeline

The pipeline answers: **Among flights with at least 15 bookings, what is a normal no-show rate, cancellation rate, and average fare, so that any single flight can be compared against it?**

Step 1 (the WITH clause) summarizes each flight. Step 2 keeps the high-volume flights and combines their rows into one baseline. The 8 high-volume flights carry 145 of the 200 bookings. Their baseline is a 4.8% no-show rate, a 15.2% cancellation rate, and an $18.76 average fare. VN202's 18.8% no-show rate is almost four times that baseline.

## Reflection

Conditional aggregation computes several answers in one pass. In Part A, the database reads each booking once and, as it goes, adds it to the flight's total and, if it is a no-show, to the no-show count too. The alternative is two separate queries: one counting all bookings per flight, and one with `WHERE cancellation_reason = 'Passenger no show'` counting no-shows per flight. The results then have to be joined back together.

With 200 rows the difference is invisible, but at a million rows it matters for three reasons. First, cost: two queries mean two full scans of a million rows instead of one, which doubles the reading, and the bookings table is the one that grows fastest. Second, consistency: if bookings are being written between the two queries, the total and the no-show count come from slightly different versions of the data, so the rate can be wrong. Third, correctness of the join: the filtered query drops every flight with zero no-shows, so joining the two results needs an outer join and a COALESCE, or flights like VN208 and VN210 silently disappear. That is the same kind of vanishing-rows bug I found with NULLs in Unit 3. One pass with CASE inside the aggregate avoids all three problems: it reads the data once, both numbers describe exactly the same rows, and every flight keeps its row even when its count of failures is zero.
