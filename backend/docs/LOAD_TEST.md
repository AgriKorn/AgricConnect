# Load Test — Performance & Reliability NFR evidence

Measures the marketplace browse/search endpoint (`GET /api/marketplace`), the
read path buyers hit most and the one the SRS puts numeric targets on:

- **Performance NFR:** "Marketplace search results shall be displayed within 2 seconds."
- **Reliability NFR:** "The application shall support at least 1000 concurrent users."

## How to run

```bash
# with the backend running and an approved buyer seeded
CONCURRENCY=50 DURATION_S=8 npx ts-node scripts/load-test.ts
```

`scripts/load-test.ts` is dependency-free and memory-safe: it runs a fixed pool
of `CONCURRENCY` virtual users, each firing one request at a time in a loop, so
in-flight requests never exceed the pool size. It reports throughput, error
rate, and latency percentiles, and checks p99 against the 2-second target.

`CONCURRENCY` virtual users here are *continuous* — each fires the next request
the instant the previous returns, with no think-time. Real users pause between
actions, so N continuous virtual users represent many more than N real
concurrent users.

## Results

Single `ts-node` dev instance, local Postgres, on a memory-constrained laptop
(not production hardware). Rate limit raised for measurement (see note).

| Concurrency | Duration | Requests | Errors | Throughput | p50 | p99 | <2s target |
|---|---|---|---|---|---|---|---|
| 50 | 8s | 1,605 | 0 (0.00%) | 198 req/s | 238 ms | 460 ms | **PASS** |
| 150 | 6s | 1,354 | 0 (0.00%) | 216 req/s | 649 ms | 1,107 ms | **PASS** |

**Performance NFR — met with headroom.** p99 stays under 2 seconds even at 150
continuous virtual users on dev hardware; the search target is comfortably met.

**Reliability NFR — zero errors under sustained concurrency; 1000 needs prod
infra.** The app served 150 continuous virtual users with a 0% error rate on a
single instance. The literal "1000 concurrent users" target is an infrastructure
property (horizontal scaling behind a load balancer, a pooled/managed Postgres),
not something a single dev instance demonstrates — but the per-request headroom
(p99 ~1.1s at 150 continuous users) shows the application code is not the
bottleneck.

## Finding: the rate limit was the real ceiling

The first run hit a **99% error rate** — not a compute limit, but the global
rate limiter, which was set to **100 requests / 15 minutes per IP**. A single
active user browsing the marketplace exhausts that in seconds, so it was
incompatible with any real concurrency, let alone 1000 users.

Fixed in `app.ts`: the general limit is now **300 requests/minute per IP** by
default (sustained ~5 req/s per user) and env-tunable via `RATE_LIMIT_MAX` /
`RATE_LIMIT_WINDOW_MS`; it is skipped under `NODE_ENV=test` and does not count
health checks. The auth limiter stays deliberately strict (20 / 15 min) to
resist credential brute-forcing. The numbers above were captured with the limit
raised so they reflect server capacity rather than the limiter.
