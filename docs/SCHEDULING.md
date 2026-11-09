# Scheduling policy

This is an SM-2-inspired four-rating scheduler, not a claim of canonical SM-2 or FSRS.
SM-2 is transparent and deterministic without fitted parameters. FSRS can be considered
later after collecting sufficient local review history; review events are retained for that purpose.

| State | Again | Hard | Good | Easy |
| --- | --- | --- | --- | --- |
| New / first learning step | 1 min, step 0 | 6 min, same step | 10 min, step 1 | graduate, 4 days |
| Second learning step | 1 min, reset step | 10 min, same step | graduate, 1 day | graduate, 4 days |
| Review | 1 min, relearn | interval × 1.2 | interval × ease | interval × increased ease × 1.3 |
| Relearning | 1 min, reset step | same delays as learning | 10 min, then retained interval | max(4 days, retained interval) |

Review Hard lowers ease by 0.15; Again lowers it by 0.2; Easy raises it by 0.15.
Ease stays in [1.3, 3.5]. Initial ease is 2.5. Review intervals round to whole days,
increase by at least one day for successful reviews, and cap at 36,500 days.
A review lapse retains half the previous interval (minimum one day) after relearning.
Repeated failures during learning count as misses, not additional review lapses.
Eight lifetime Again ratings flag a leech; no card is automatically suspended.
Mature means review state with an interval of at least 21 days; relearning is still learning.

Due time is measured from the answer timestamp. A day interval is 86,400 elapsed seconds;
it does not promise the same wall-clock time across daylight-saving changes. Streaks and
daily budgets use an injected calendar (user-local by default), not rolling 24-hour windows.

Queue priority: due short learning/relearning steps, due review cards, then new cards.
Only already-due non-new cards enter the queue. Short steps ignore daily caps so forgotten
cards can return soon. Recompute the queue after every answer and when the next due time
arrives; the Phase 2 session UI will own that timer. New cards and review cards consume
separate daily budgets. Review budgets count distinct cards reviewed today; repeated
learning attempts do not consume extra review slots.

Track weights apply separately within reviews and new cards, with oldest due first within
each track and stable UUID tie-breaking. If one track runs out, the other fills the queue.
An exact zero weight disables that track for new/review selection but still permits its active
short steps. Weight balance is per queue; long-term adaptive balancing is not implemented.
No randomness, network calls, or wall-clock reads occur inside the scheduler.

Retention = non-Again review attempts / all review attempts, excluding initial learning.
Streaks count consecutive local study days; yesterday's streak survives until today's first
study, and a missed full day breaks it. Time spent is stored in review events for later charts.
