/**
 * Load test for the marketplace browse/search endpoint — the read path buyers
 * hit constantly, and the one the SRS puts a performance bar on:
 *   - Performance NFR: "Marketplace search results ... within 2 seconds"
 *   - Reliability NFR: "support at least 1000 concurrent users"
 *
 * Dependency-free by design (uses global fetch) and memory-safe: it runs a
 * FIXED pool of `CONCURRENCY` async workers, each firing one request at a time
 * in a loop for `DURATION_S` seconds. In-flight requests never exceed the pool
 * size, so the generator itself can't exhaust memory — it just measures whatever
 * concurrency you point it at.
 *
 * Usage (backend running on API_URL, an approved buyer seeded):
 *   BUYER_EMAIL=buyer@agriconnect.test BUYER_PASSWORD=buyerpass123 \
 *   CONCURRENCY=50 DURATION_S=10 API_URL=http://localhost:3000/api \
 *   npx ts-node scripts/load-test.ts
 *
 * CONCURRENCY is the number of simultaneous virtual users. Raise it toward 1000
 * on infrastructure that can host that many connections; a single local dev
 * instance on a constrained laptop is a baseline, not the ceiling.
 */

const API_URL = process.env.API_URL || 'http://localhost:3000/api';
const CONCURRENCY = Number(process.env.CONCURRENCY || 50);
const DURATION_S = Number(process.env.DURATION_S || 10);
const ENDPOINT = process.env.ENDPOINT || '/marketplace/';
const BUYER_EMAIL = process.env.BUYER_EMAIL || 'buyer@agriconnect.test';
const BUYER_PASSWORD = process.env.BUYER_PASSWORD || 'buyerpass123';

const percentile = (sorted: number[], p: number): number => {
  if (sorted.length === 0) return 0;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
};

async function login(): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: BUYER_EMAIL, password: BUYER_PASSWORD }),
  });
  const json: any = await res.json();
  const token = json?.data?.accessToken;
  if (!token) throw new Error(`Login failed for ${BUYER_EMAIL}: ${JSON.stringify(json?.error ?? json)}`);
  return token;
}

async function main() {
  const token = await login();
  const url = `${API_URL}${ENDPOINT}`;
  const authHeader = { Authorization: `Bearer ${token}` };

  const latencies: number[] = [];
  let ok = 0;
  let failed = 0;
  const deadline = Date.now() + DURATION_S * 1000;

  const worker = async () => {
    while (Date.now() < deadline) {
      const start = performance.now();
      try {
        const res = await fetch(url, { headers: authHeader });
        const elapsed = performance.now() - start;
        // Drain the body so the connection frees promptly.
        await res.arrayBuffer();
        if (res.ok) {
          ok++;
          latencies.push(elapsed);
        } else {
          failed++;
        }
      } catch {
        failed++;
      }
    }
  };

  console.log(
    `Load test → ${url}\n  concurrency=${CONCURRENCY}  duration=${DURATION_S}s  (warming up ${CONCURRENCY} virtual users)\n`,
  );
  const startedAt = Date.now();
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()));
  const wallSeconds = (Date.now() - startedAt) / 1000;

  latencies.sort((a, b) => a - b);
  const total = ok + failed;
  const rps = ok / wallSeconds;
  const mean = latencies.reduce((s, n) => s + n, 0) / (latencies.length || 1);

  const ms = (n: number) => `${n.toFixed(1)} ms`;
  console.log('Results');
  console.log(`  requests:        ${total}  (ok ${ok}, failed ${failed})`);
  console.log(`  error rate:      ${total ? ((failed / total) * 100).toFixed(2) : '0'}%`);
  console.log(`  throughput:      ${rps.toFixed(0)} req/s`);
  console.log(`  latency mean:    ${ms(mean)}`);
  console.log(`  latency p50:     ${ms(percentile(latencies, 50))}`);
  console.log(`  latency p90:     ${ms(percentile(latencies, 90))}`);
  console.log(`  latency p99:     ${ms(percentile(latencies, 99))}`);
  console.log(`  latency max:     ${ms(latencies[latencies.length - 1] || 0)}`);

  const p99 = percentile(latencies, 99);
  const SEARCH_TARGET_MS = 2000; // SRS: search within 2 seconds
  console.log(
    `\n  SRS search-latency target (<2s): p99 ${ms(p99)} -> ${p99 < SEARCH_TARGET_MS ? 'PASS' : 'OVER TARGET'}`,
  );
  if (failed > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error('Load test failed:', err.message);
  process.exit(1);
});
