# Unit 6 Analysis

Queries: [`queries/unit6/q6_1.sql`](../queries/unit6/q6_1.sql), [`queries/unit6/q6_2.sql`](../queries/unit6/q6_2.sql), and [`queries/unit6/q6_3.sql`](../queries/unit6/q6_3.sql), run against the `ex603_data` database (PostgreSQL 16). Screenshots are in [`screenshots/unit6/`](../screenshots/unit6/).

For this unit, the event table is `bookings` (timestamp `booked_at`), the producer is the flight, and the metric is `fare_paid`. Cancelled bookings are refunded to $0.00, so a $0 fare always means a cancellation, never a free ticket (Unit 4).

## Task 6.1: Compute across a window without collapsing

### What the queries showed

- **Each booking next to its flight's average (6.1.1a).** `AVG(fare_paid) OVER (PARTITION BY flight_id)` returns all **200** bookings. Each row keeps its own fare and also carries its flight's average, how far it is from that average, and the ratio between the two.
- **The GROUP BY version (6.1.1c, 6.1.1d).** The same average with `GROUP BY` returns **13** rows, one per flight with bookings. The averages are identical, but booking ID, fare, date and status are gone. A row-count check confirms 200 against 13.
- **Unusual bookings (6.1.1b).** Filtering the window result in an outer query finds **15 bookings that paid at least twice their own flight's average**. The most extreme is booking 43 on VN204: **$70.86 against a flight average of $19.49 (3.64×)**. VN204 has only 6 bookings, so that one fare is about 60% of the flight's revenue. Second is booking 164 on VN211. Its $34.79 fare would be ordinary on most flights, but it is 2.91× VN211's average, because VN211's five cancellations pull the average down to $11.94.
- **Three rankings (6.1.2).** Ranking flights by bookings produces four ties: VN205/VN207 (18), VN202/VN211 (16), VN201/VN213 (11), and VN214/VN215 (0). `ROW_NUMBER` puts VN205 4th and VN207 5th only because of the flight-number tiebreaker. `RANK` makes both 4th and skips to 6th. `DENSE_RANK` makes both 4th and continues at 5th, so by the bottom of the board VN214 and VN215 are 14th by `RANK` but 11th by `DENSE_RANK`.
- **Four bands (6.1.3).** `NTILE(4)` splits 15 flights into bands of 4, 4, 4 and 3. **VN205 and VN207 both have 18 bookings, but VN205 is in band 1 and VN207 is in band 2.** NTILE fills each band to a fixed size and cuts wherever the count runs out, even between two equal values. The other three tied pairs happen to land inside one band (6.1.3b).

### A question that needs each row next to its group's average

**"Is this booking's fare unusually high or low for the flight it was on?"**

A revenue analyst asks this to spot pricing mistakes, data-entry errors or fare-rule exceptions. Answering it needs two values on the same row: the booking's own fare and its flight's average. The GROUP BY version produces only the second. It can say that VN204 averages $19.49, but it cannot say that booking 43 paid $70.86, because the booking rows were collapsed to make the average. Getting both back would mean joining the grouped result to `bookings` again. The window function does it in one pass and keeps every booking.

A flat platform-wide threshold doesn't work either. $34.79 is normal on VN205 (average $23.06) but nearly triple the average on VN211, and only a per-flight comparison shows the difference.

### Which ranking function a platform feature should use

**Feature: a "Most booked flights" panel on the booking site's home page, showing the top five flights.**

It should use **`RANK()`**.

- **`ROW_NUMBER()`** would put VN205 above VN207 although both have 18 bookings. The difference comes from the flight number sorting first, not from customer demand. On a public list that is a small false claim, and if the panel shows only the top four, VN207 vanishes for no real reason.
- **`DENSE_RANK()`** treats ties fairly but compresses the positions. A flight shown as "#6" would really have seven flights ahead of it. It also lets a "top five" grow: DENSE_RANK ≤ 5 returns six flights here (VN206, VN208, VN210, VN205, VN207, VN212), and more as further ties appear.
- **`RANK()`** gives VN205 and VN207 the same position, and the next flight shows as 6th, so a flight's position always equals one plus the number of flights ahead of it. The panel shows "top 5 by RANK", which returns five flights today, and an extra flight only when there is a real tie at 5th.

The fair-treatment question is who gets shown to customers. A flight left off a home-page panel loses visibility and bookings, so the rule for ties should come from the data, not from how flight numbers happen to sort.

## Task 6.2: Compare each row to its neighbors

### What the queries showed

- **Part A, VN202 row to row.** `LAG` and `LEAD` partitioned by flight and ordered by `booked_at` show each VN202 booking with the fare before and after it. The largest swings are **+$27.98** into booking 18 ($47.81, VN202's top fare) and **−$32.59** right after it. Two negative deltas, −$15.21 and −$20.29, are not price changes: they are cancelled bookings refunded to $0. The sequence shows VN202's year: 3 cancellations in its first 4 bookings, then **11 confirmed bookings in a row from April to November**, then a no-show in December.
- **Part B, running total and moving average.** With bookings grouped to one row per booking day (155 days), the running total reaches **$3,628.19 for 2023, 90.7% of a $4,000 target**. Against $1,000 per quarter, the quarters finished at **91.0%, 85.7%, 100.4% and 85.7%** (B2). Only Q3 reached the target, and Q3 crossed it on its last booking day (2023-09-25). The 7-row moving average covers **8 to 28 calendar days** (about 15 on average), because many days have no bookings.
- **Part B, smoothed failure rate (B3).** Over the most recent 30 bookings, the cancellation rate was **20–30% in February and March** and **never above 16.7% from October on**. The rolling no-show rate stays between 0% and 10% all year (0 to 3 of the last 30 bookings).
- **ROWS vs. RANGE (B4).** On 2023-01-08 three bookings share the same date. With `ROWS`, the running total adds them one at a time, so they get three different totals in an order PostgreSQL picks for itself. With `RANGE`, all rows with the same date are peers and all three show $131.62, the total at the end of that day.
- **Part C, gaps.** `LAG(booked_at)` in a CTE, filtered in the outer query, finds **11 gaps of 60 days or more**. The longest is **VN209: 113 days without a booking, from 2023-01-05 to 2023-04-28**. VN212 (107 days) and VN205 (93 days) show a similar pause in spring.

**ROWS vs. RANGE in one sentence or two.** `ROWS` counts physical rows, so rows that tie on the ORDER BY value are added one by one, in an order that isn't guaranteed. `RANGE` works on values, so every row tied on the ORDER BY value is included at once and gets the same result.

### What a large delta tells someone, and what to do about it

On this platform a large delta between consecutive bookings on the same flight means one of two things, and the booking status tells them apart:

1. **A drop to $0** is a cancellation, not a price change. VN202's −$20.29 in December is a no-show. A run of these deltas on one flight is an early warning. VN202 opened the year with three in four bookings, the pattern that later made it the highest no-show flight on the platform (Unit 4). **Action:** when a flight has two or more refund drops among its last five bookings, the operations team reviews that flight's cancellation reasons that week, not at quarter end.
2. **A large jump in a confirmed fare** (VN202's +$27.98 into a $47.81 booking) is a pricing event: a late booking, a fare-class upgrade, or a pricing error. **Action:** revenue management checks the booking's `fare_multiplier` and fare rule. If the price was legitimate, it shows what passengers will pay. If it was an error, it is a refund or dispute risk.

### Why a running total answers what a plain SUM cannot

A plain `SUM(fare_paid)` returns one number, $3,628.19. That says where the year ended, not how it got there. The running total keeps every day, so it shows **when** the platform fell behind. Q2 and Q4 both finished at 85.7%. Q3 reached its target only on its last booking day, so it was behind the target until the very end of the quarter. Leadership can only act on a shortfall while the quarter is still open, and the running total is what shows the pace on any given day. A plain SUM shows the shortfall only after the quarter has closed.

### Why I picked my moving-average window sizes

- **Daily revenue, 7 rows.** Most booking days have a single booking, so daily revenue swings between $0 (one cancelled booking) and $83.60. A 7-row window averages about seven bookings across roughly two weeks (8 to 28 calendar days), enough to dampen one-booking days and short enough to show changes within a quarter. A 3-row window would still react to every cancellation. A 30-row window would cover about two months and would hide the Q3 rise until the quarter was almost over.
- **Failure rate, 30 bookings.** Cancellations are about 17% of bookings, so a 30-booking window holds about five of them. With a 10-booking window a single cancellation moves the rate by 10 points, and the line jumps between 0% and 30% at random. Thirty bookings is about two months of activity, which keeps a real shift visible within one quarter.

Neither window tells a full story about no-shows. At a 6% rate, a 30-booking window holds only about two, which is why the rolling no-show rate moves only between 0% and 10%. A trend that small needs quarterly totals (6.3 Part B3), not a moving window.

### What the VN209 gap means

**My conclusion: a real stop in VN209's bookings, not a data-quality problem.** It is also not simply a side effect of how events were recorded. The evidence (6.2 Part C2):

- **The platform kept recording.** During VN209's 113 days of silence, **61 bookings were recorded on 11 other flights**. If booking capture had failed, every flight would show the gap at the same time.
- **No VN209 rows are missing.** VN209's booking IDs run from 124 to 137: 14 IDs and 14 bookings, with no holes. Lost or deleted rows would leave missing IDs.
- **The flight is flagged.** VN209 is one of the two flights marked `is_active = false`, yet it took 13 bookings after the gap. A flight that was taken off sale for a while and later reopened, without its status being updated, would look like this.

What I can't tell from this data is **why** it stopped. The database has no schedule or sales-channel history, so a suspended route, a seasonal pause and a flight that was hidden from search would all look the same. The right response is to ask the scheduling team whether VN209 was off sale from January to April, and to correct its status. If it was on sale and nobody booked it, that is a demand question for the route team. The spring gaps on VN212, VN205 and VN211 also fall in March, the platform's weakest month (11 bookings), so some of this may be seasonal.

## Task 6.3: Build the reporting patterns

### What the queries showed

- **Top three per flight (Part A).** `RANK()` partitioned by flight, filtered to rank ≤ 3 in a CTE, returns **39 rows: three for each of the 13 flights with bookings**. `FIRST_VALUE` gives each flight's top fare, so each row shows how far it sits below the top. `LAST_VALUE` with a full `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` frame gives each flight's lowest fare. That is $0.00 everywhere except VN210 ($4.88), the only flight whose lowest booking was not a refund. The spread inside the top three is the useful part. **VN204's top fare is $48 above its second**, a single outlier. **VN210's top three sit within $0.67 of each other**, a consistent high-end price.
- **Ties at third (A2).** No flight currently has a tie at third place, so `RANK` and `ROW_NUMBER` return the same 39 rows today. I chose `RANK` so that a future tie returns both bookings rather than dropping one by booking ID.
- **Month over month (Part B).** Built on a `GENERATE_SERIES` of all twelve months, with `LAG` and `NULLIF`: revenue swings hard from month to month (**+41.5%** in February, **−70.0%** in March, **+91.0%** in April). The cancellation rate is steadier: 23.8%, 19.0% and 27.3% in January to March, **0% in April**, and never above 25% after that. The second half of the year cancelled 15.2% of bookings against 18.8% in the first.
- **Missing months (B2).** `LAG` on the month itself finds no skipped months. Every month of 2023 has bookings. The `GENERATE_SERIES` stays in Part B anyway, so the comparison remains correct if a month is ever empty.

### The feature top-N would power, and why three

**Feature: a "Top fares" panel on each flight's page in the revenue management dashboard.** It shows the three highest fares paid on that flight, the date of each, and how far each is below the top fare.

Revenue managers use it to see what passengers on a given flight are willing to pay at the high end, before they adjust fare classes.

- **One is too few.** One fare can't separate a real price ceiling from an outlier. VN204's top fare is $70.86, but its next is $22.77. Pricing VN204 off that one booking would set its fares about three times too high.
- **Ten is too many.** VN204 has only 6 bookings in total, and VN201 and VN213 have 11 each. A top ten would list nearly every booking on those flights, including the $0 refunds, and stop being a "top" list at all.
- **Three is enough to see a pattern.** If the three are close together (VN210, within $0.67), the high price is consistent and the flight can likely support a higher fare class. If the first is far above the other two (VN204, VN202), it is an exception to investigate, not a price to copy.

### What a large month-over-month change means, and what to do

A large month-over-month change on this platform usually comes from **volume, not behavior**. March's −70% revenue came from bookings halving (21 to 11) **and** the cancellation rate rising to 27.3% in the same month. April's +91% came from the same 11 bookings with no cancellations. With 11 to 21 bookings a month, one or two bookings move revenue by 10–20%.

So the rule I would give the team has two steps:

1. **Check the bookings column first.** If bookings fell, it is a demand or sales problem: check whether flights were taken off sale (as VN209 was, 6.2 Part C) before discounting fares.
2. **If bookings held steady but the cancellation rate jumped by more than 10 points, treat it as an operations problem.** Break the month down by flight and cancellation reason, using the Unit 5 joins, to find whether it is passenger no-shows (reminders), airline cancellations (operations) or failed payments (payments team).

A single month above the line is a reason to look, not to act. Two months in a row above 25% cancellations, which did not happen in 2023, would justify changing how the affected flights are run.

## Reflection

A question that is natural on this platform but awkward with GROUP BY is: **"For each flight, has each booking turned out better or worse than the one before it, and when did the flight's run of good bookings start and end?"**

Window functions answer that directly. `LAG(fare_paid) OVER (PARTITION BY flight_id ORDER BY booked_at)` places each booking beside the one before it on the same flight, so VN202's three early cancellations, its eleven confirmed bookings in a row from April to November, and its December no-show all appear in one result. The partition keeps each flight's sequence separate, and the ORDER BY gives "before" a meaning.

GROUP BY can't express "the previous row" at all. It collapses each flight to one row, so it can count VN202's cancellations (4) but not tell whether they came together or were spread out. That is exactly the difference between a flight that had a bad January and one that fails all year. Getting the same answer without window functions would mean joining `bookings` to itself on "the latest earlier booking on the same flight", which needs a correlated subquery for every row. That is harder to read, easy to get wrong when two bookings share a timestamp, and slower as the table grows.

The running total and the rolling cancellation rate work the same way: they keep the rows and add context from their neighbors. That turns "how many?" into "is it getting better?", the question leadership actually asked.
