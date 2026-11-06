# Combinatorial Optimization & Parallel Simulation Engine (MATLAB)

## At a glance

- 231 ways to split 20 people across 3 jobs (stars and bars).
- 231^24, about 5.34 × 10^56, strategies if the split changes every month; 231^4 = 2.85 billion with 6-month blocks.
- Exhaustive recursive search on a MATLAB parallel pool (`parpool` and `parfor`), about 8 hours.
- Result: $4,184,692.80, the optimum over all 2.85 billion six-month-block strategies, 15.5% above the $3,623,944 heuristic baseline.

I built this in 2024 for a case study and found it again in my archives in November 2026. It was the first optimization problem I solved by brute force on a parallel pool, and the answer it found is not the one I would have picked by hand. I am publishing it so that my quantitative work is visible in one place, and I plan to replicate it in Python next. The case study used a fictional software company called SaaSafras.

## The problem

A 20-person team has three jobs to staff: Support, New Business and Account Management. The split can change every month. The goal is the highest cumulative revenue over 24 months.

The case study fixes the numbers:

- 1,000 customers at the start, and 25 new customers a month arrive on their own.
- Baseline churn is 10% a month, and each Support member cuts it by 15% of its current level.
- Each New Business member brings in 5 new customers a month.
- Each Account Manager can manage 25 customers, and a managed customer pays $100 \times 1.20^{\min(m,\,6)}$ in calendar month $m$.
- Every other customer pays the baseline of $100 a month.

## The model, one month at a time

With $s$, $n$ and $a$ the Support, New Business and Account Management headcounts, $B_m$ the customer base after month $m$, and $R_m$ cumulative revenue:

$$\chi = 0.10 \times 0.85^{\,s}$$

$$B_m = B_{m-1} - \left\lfloor \chi \, B_{m-1} \right\rfloor + 25 + 5n$$

$$M_m = \min\left(B_m,\; 25a\right)$$

$$R_m = R_{m-1} + 100\,M_m\,1.20^{\min(m,\,6)} + 100\left(B_m - M_m\right)$$

with $B_0 = 1{,}000$ and $R_0 = 0$.

In plain words:

- Support lowers churn.
- New Business grows the base.
- Account Management earns more from the customers it can reach.

None of these effects is linear, so there is no clean formula for the best split.

## Why brute force, and why it is possible

The number of ways to place $n$ identical people into $k$ distinct jobs is the stars-and-bars count $\binom{n+k-1}{k-1}$. With $n = 20$ and $k = 3$:

$$\binom{20 + 3 - 1}{3 - 1} = \binom{22}{2} = \frac{22 \times 21}{2 \times 1} = 231$$

So there are 231 possible splits at any decision point. If the split can change every month, there are 24 decision points and

$$231^{24} \approx 5.34 \times 10^{56}$$

strategies, which no computer can enumerate.

Exhaustive search is not needed for the monthly problem. The only state carried from one month to the next is the customer count, an integer that cannot exceed $1{,}000 + 24 \times 125 = 4{,}000$, so dynamic programming over month and customer count solves the full monthly problem exactly in about $24 \times 4{,}000 \times 231 \approx 22$ million evaluations. I used brute force because it was the method I knew in 2024. The Python replication will solve the monthly problem by dynamic programming and report the gap.

Holding the split constant for six months at a time leaves four decision points, so

$$231^{4} = 2{,}847{,}396{,}321$$

strategies, about 2.85 billion. That is large, but a modern laptop can get through it in a working day.

## How the search runs

`SaaSafras_Six_Code.m` opens a MATLAB parallel pool and hands each possible first six-month split to a worker with `parfor`. Each worker then walks through every split for months 7 to 12, 13 to 18 and 19 to 24 in a recursive loop, simulates all 24 months for each full strategy, and keeps the best one. The pool collects the winners and keeps the best overall. Nothing is pruned, which is the point of brute force.

The run took about eight hours.

## Result

The heuristic baseline in `SaaS_Model_False.m`, a plan chosen by judgment rather than by search, earns $3,623,944. The best six-month-block strategy earns $4,184,692.80, a 15.5% lift.

| Months | Support | New Business | Account Mgmt | Cumulative revenue | Customers | What the plan is doing |
|---|---|---|---|---|---|---|
| 1-6 | 8 | 12 | 0 | 717,000.00 | 1,327 | Grow the base and keep churn low |
| 7-12 | 10 | 10 | 0 | 1,613,200.00 | 1,609 | Keep growing, protect the base |
| 13-18 | 8 | 0 | 12 | 2,899,577.12 | 1,507 | Stop selling, collect the full multiplier |
| 19-24 | 2 | 0 | 18 | 4,184,692.80 | 1,089 | Harvest, and let the base shrink |

The best plan is not the obvious one. It runs with zero Account Managers for a full year to grow the base, then stops selling entirely and moves almost everyone into Account Management, and it accepts a shrinking customer base at the end. The multiplier explains it: $1.20^{\min(m,\,6)}$ depends on the calendar month, not on how long a customer has been managed, so a customer first managed in month 13 pays the full 2.99 times at once, and starting Account Management late costs nothing. The heuristic baseline, which balanced the three jobs the way most people would, was 15% worse.

Month-by-month numbers are in `results/Monthly_Strategy.csv`.

## A known issue

The version that produced the report used `ind2sub`, which counts from 1, directly as a headcount. That skipped the 41 first-block splits with zero Support or zero New Business, so the eight-hour run covered $190 \times 231^{3} \approx 2.34$ billion of the 2.85 billion strategies. The bug turned up in a review of the code in November 2026.

A full re-run, done during the November 2026 review, confirmed that the strategy above is the optimum over all 2.85 billion six-month-block strategies, and that the best strategy in the skipped region reaches only $3,865,141.60. The script in this repository has the one-line fix, with a comment where it sits. The Python replication will carry this check as its own test.

## Files

- `SaaS_Model_False.m`: the heuristic baseline.
- `SaaSafras_Six_Code.m`: the parallel exhaustive search, plus the result tables and plots.
- `results/Best_Strategy.csv`: the block table for the best strategy, a converted copy of `Best_Strategy.xlsx`.
- `results/Monthly_Strategy.csv`: the monthly table for the best strategy, a converted copy of `Monthly_Strategy.xlsx`.
- `SaaSafras_Case_Study_Maximizing_Revenue.pdf`: the original 2024 write-up.

## Running it

You need MATLAB with the Parallel Computing Toolbox. Run `SaaS_Model_False.m` for the baseline and `SaaSafras_Six_Code.m` for the search. The search writes `Best_Strategy.xlsx` and `Monthly_Strategy.xlsx` to the working directory and plots revenue and customer base by month.
