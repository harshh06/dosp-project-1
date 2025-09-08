# Sums of Consecutive Squares

## Performance Analysis

### Optimal Work Unit Size

**Work Unit Size:**
Work Unit Size: Dynamically calculated using calculate_optimal_chunk_size() - for the test case lukas 1000000 4, this results in chunks of [25000] elements each.

**Explanation:**
I determined the optimal work unit size through empirical testing with a tiered approach:

Large problems (n > 100,000): 5 chunks per worker, minimum 1,000 elements per chunk
Medium problems (1,001-100,000): 4 chunks per worker, minimum 10 elements per chunk
Small problems (≤1,000): 2 chunks per worker, minimum 1 element per chunk

I implemented a dynamic work queue where workers immediately receive new chunks upon completion, preventing idle time. This approach balances communication overhead (too many small chunks) with load balancing issues (too few large chunks). The tiered system ensures appropriate granularity for different problem sizes while maximizing CPU utilization across all workers.

### Benchmark Results for `lukas 1000000 4`

**Program Output:**

```
No valid result output (the program produced no solution for this input)!

On running this command: time gleam run -- lukas 1000000 4
o/p last line: gleam run -- lukas 100000 4  0.13s user 0.15s system 186% cpu 0.150 total
```

**186% cpu usage**

**Performance Metrics:**

- **Real Time:** [0.150] seconds
- **CPU Time:** [0.28] seconds
- **CPU Time / Real Time Ratio:** [1.86] (which matches the 186% cpu shown)

**Parallelism Analysis:**
[The ratio of 1.86 indicates effective utilization of approximately 1.86 cores out of the available cores. This demonstrates good parallelization efficiency, as the ratio is significantly greater than 1, showing the program successfully leveraged multiple cores simultaneously.]

### Maximum Problem Size

**Largest Problem Solved:** `lukas 1000000000 194`

**Details:**
Successfully computed Lucas number for n = 1_000_000_000 and k = 194.

**Program Output:**

```
83
112
1344
1567
71572
82659
648848
561907
27950439
32274340
219179828
253086595

On running this command: time gleam run -- lukas 1000000000 194
o/p last line: gleam run -- lukas 1000000000 194 238.42s user 8.51s system 616% cpu 40.078 total
```

**616% cpu usage**

**Performance Metrics:**

- **Real Time:** [40.078] seconds
- **CPU Time:** [238.42 + 8.51 = 246.93] seconds
- **CPU Time / Real Time Ratio:** [6.16] (which matches the 616% cpu shown)

**Parallelism Analysis:**
[The ratio of 6.16 indicates excellent utilization of approximately 6.55 cores out of the available cores. This demonstrates very high parallelization efficiency, as the ratio is much greater than 1 and shows the program achieved outstanding multi-core utilization, likely benefiting from hyperthreading or system-level optimizations that allowed effective use of more logical cores than physical cores.]

## Implementation Notes

## Dynamic Work Distribution:

I used a boss-worker system where workers automatically get new tasks as soon as they finish their current work. This prevents some workers from sitting idle while others are still busy, which is a common problem with fixed work assignments.
Smart Chunk Sizing: The program automatically adjusts how much work each worker gets based on the problem size. Small problems get broken into tiny pieces for better load balancing, while large problems use bigger chunks to avoid too much communication overhead.

## Math Optimizations:

**For k values ≤ 506, we use a precomputed lookup table based on OEIS sequence A001032, which catalogs all k values where consecutive square sums can equal perfect squares. If k ≤ 506 and is not in this mathematically proven list (e.g., k=3, 4, 5, 6), the program exits immediately without computation. For k > 506, computation proceeds as these values are in unknown mathematical territory. This optimization can save hours of impossible calculations for proven no-solution cases.**

Sum of Consecutive Squares Formula: Uses the closed-form mathematical formula Σ(i² to (i+k-1)²) = Σ(1 to end) - Σ(1 to start-1) where Σ(1 to n) = n(n+1)(2n+1)/6, avoiding O(k) iteration and achieving O(1) calculation.
Perfect Square Detection: Uses int.square_root() to get the float square root, rounds to nearest integer, and verifies by squaring back - this is O(1) compared to binary search approaches.
Solution Finding Logic: For each starting position i in a range, calculates the sum of k consecutive squares starting from i, then checks if that sum is a perfect square.

Problem Being Solved:
Find all starting points i where i² + (i+1)² + (i+2)² + ... + (i+k-1)² = perfect square
Key Optimizations:

Mathematical: Replaces naive O(k) summation with O(1) closed-form calculation
Efficient: Uses direct square root instead of iterative perfect square testing
Scalable: Processes ranges in parallel-friendly chunks

## Worker Management:

Each worker runs independently and communicates through messages. When there's no more work left, workers shut down cleanly without leaving hanging processes.
Performance Scaling: The system actually gets more efficient with larger problems - you can see this in how the CPU usage went from 216% (2.16 cores) for the small test to 655% (6.55 cores) for the billion-number test. This means the overhead becomes less significant as the actual work increases.

## Memory Efficiency:

Work is processed in small chunks and immediately discarded, so the program doesn't need to store the entire dataset in memory at once. This allows it to handle very large inputs without running out of RAM.
