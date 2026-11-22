**To:** Leadership Team
**Subject:** Failures Are Falling, Revenue Is Not: What to Do Next Quarter

Four weeks ago the dashboard said half of all bookings failed. The real passenger no-show rate was 6% (Unit 3). The question now is whether the platform is getting better or worse, and what to do about it. The short answer: **the failure problem improved over 2023, but bookings and revenue did not grow, and the improvement is too small to call finished.** Every figure below comes from a query in this repository; the query is named in brackets.

**1. Failures went down over the year.**

- **No-shows fell every quarter:** 7.5% in Q1, 6.3% in Q2, 5.9% in Q3, and **4.2% in Q4** [`q6_3.sql`, Part B3]. Q4 is below the 4.8% benchmark set in Unit 4.
- **Cancellations dropped after the first quarter and stayed down:** 22.6% in Q1, then 14.6%, 15.7% and 14.6% [`q6_3.sql`, Part B3]. The second half of the year cancelled 15.2% of bookings against 18.8% in the first [`q6_3.sql`, Part B].
- **The smoothed rate agrees.** Over the latest 30 bookings, the cancellation rate was 20–30% in February and March and **never higher than 16.7% from October on** [`q6_2.sql`, Part B3].
- **Bookings that did not end confirmed** (cancelled or disputed) were lowest in Q4: 16.7%, down from 24.5% in Q1 [`q6_3.sql`, Part B3]. Disputes rose to 5 in Q3 and fell back to 1 in Q4.

**A caution:** the platform has about 50 bookings a quarter. The fall in no-shows from Q1 to Q4 is 4 bookings to 2. The direction is consistent in every quarter, which is encouraging, but one year of data at this size can't prove the change is permanent. It needs to hold for another quarter before we treat it as fixed.

**2. Revenue and volume did not improve.**

- **Bookings were flat:** 53, 48, 51 and 48 per quarter [`q6_3.sql`, Part B3].
- **Revenue missed a $1,000-per-quarter target in three of four quarters:** 91.0%, 85.7%, **100.4%** and 85.7%. The year closed at $3,628.19, 90.7% of $4,000 [`q6_2.sql`, Parts B1 and B2]. Q3 reached the target only on its last booking day, and Q4 fell back to Q2's level.
- **Month-to-month swings are mostly volume.** March's 70% revenue drop came from bookings halving to 11 and the cancellation rate rising to 27.3% in the same month [`q6_3.sql`, Part B].

**3. Some flights were missing from the market for months.**

**VN209** went **113 days without a booking**, from January 5 to April 28, while the platform recorded 61 bookings on 11 other flights during that time. None of its booking records are missing, so this was a real stop, not lost data [`q6_2.sql`, Parts C and C2]. VN209 is also marked inactive, yet it took 13 bookings after the gap. VN212 (107 days) and VN205 (93 days) had similar spring gaps [`q6_2.sql`, Part C]. VN214 and VN215 never received a booking at all (Unit 5).

**What the team should do next quarter**

1. **Keep the no-show work on the 320-seat flights going, and measure it.** These flights still carry most of the no-show problem (Unit 5). Run the 24-hour check-in reminders on VN202 and VN203 first. **Goal for next quarter: no-show rate at or below 4.8% and cancellation rate at or below 15%**, checked with the quarterly query [`q6_3.sql`, Part B3]. If Q1 2024 holds at Q4 2023's level, the improvement is real.
2. **Put the flights that stopped selling back on sale, or retire them.** Ask scheduling to confirm whether VN209 was off sale from January to April, and why VN203 and VN209 are marked inactive while still taking bookings. Settle VN214 and VN215 within the first month. Each week a flight sits unsold is booking volume the platform cannot recover, and flat volume is now the bigger problem than failures.
3. **Track revenue pace weekly, not at quarter end.** Use the running total against the $1,000 quarterly target [`q6_2.sql`, Part B1]. If a quarter is below 50% of target at its halfway point, review which flights are not selling that week instead of discovering the miss after the quarter closes.
4. **Replace the dashboard's failure number with this monthly report** [`q6_3.sql`, Part B]: bookings, revenue, cancellation rate and the change from last month, with the month list built so that a missing month cannot skew the comparison. Flag a month for review when its cancellation rate rises by more than 10 points while bookings stay steady.

**Bottom line:** the problem that froze the payout four weeks ago is smaller than reported and shrinking. The team's next quarter should go to holding that improvement and getting the platform's idle and part-time flights selling again.
