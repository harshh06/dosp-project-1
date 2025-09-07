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
30
64
3000
12598
294030

On running this command: time gleam run -- lukas 1000000 4
o/p last line: gleam run -- lukas 1000000 4  0.75s user 0.27s system 216% cpu 0.472 total
```

**216% cpu usage**

**Performance Metrics:**

- **Real Time:** [0.472] seconds
- **CPU Time:** [1.02] seconds
- **CPU Time / Real Time Ratio:** [2.16] 1.02 / 0.472 = 2.16 (which matches the 216% cpu shown)

**Parallelism Analysis:**
[The ratio of 2.16 indicates effective utilization of approximately 2.16 cores out of the available cores. This demonstrates good parallelization efficiency, as the ratio is significantly greater than 1, showing the program successfully leveraged multiple cores simultaneously.]

### Maximum Problem Size

**Largest Problem Solved:** `lukas [1_000_000_000] [4]`

**Details:**
Successfully computed Lucas number for n = 1_000_000_000 and k = 4.

**Program Output:**

```
30
64
3000
12598
294030
2444128
28812000
474148414
```

**655% cpu usage**

**Performance Metrics:**

- **Real Time:** [258.51] seconds
- **CPU Time:** [1694.63] seconds
- **CPU Time / Real Time Ratio:** [6.55] (1694.63 / 258.51 = 6.55, which matches the 655% cpu shown)

**Parallelism Analysis:**
[The ratio of 6.55 indicates excellent utilization of approximately 6.55 cores out of the available cores. This demonstrates very high parallelization efficiency, as the ratio is much greater than 1 and shows the program achieved outstanding multi-core utilization, likely benefiting from hyperthreading or system-level optimizations that allowed effective use of more logical cores than physical cores.]

## Implementation Notes

## Dynamic Work Distribution:

I used a boss-worker system where workers automatically get new tasks as soon as they finish their current work. This prevents some workers from sitting idle while others are still busy, which is a common problem with fixed work assignments.
Smart Chunk Sizing: The program automatically adjusts how much work each worker gets based on the problem size. Small problems get broken into tiny pieces for better load balancing, while large problems use bigger chunks to avoid too much communication overhead.

## Math Optimizations:

Instead of adding up squares one by one, I used a mathematical formula to calculate the sum instantly
Added careful handling to prevent integer overflow when dealing with very large numbers
Used binary search to check if numbers are perfect squares, which is much faster than calculating square roots

## Worker Management:

Each worker runs independently and communicates through messages. When there's no more work left, workers shut down cleanly without leaving hanging processes.
Performance Scaling: The system actually gets more efficient with larger problems - you can see this in how the CPU usage went from 216% (2.16 cores) for the small test to 655% (6.55 cores) for the billion-number test. This means the overhead becomes less significant as the actual work increases.

## Memory Efficiency:

Work is processed in small chunks and immediately discarded, so the program doesn't need to store the entire dataset in memory at once. This allows it to handle very large inputs without running out of RAM.
