# AgriConnect Backend

Node.js + Express.js + TypeScript API for the AgriConnect agricultural marketplace.

## Getting Started

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Start development server
npm run dev
```

The API will start on `http://localhost:3000`.

Every route is mounted under `/api`. Open **http://localhost:3000/api/docs** for
the interactive Swagger UI; `GET /` just returns a pointer to it.

**A running PostgreSQL is now required.** Every module reads and writes Postgres;
nothing is in-memory any more. First-time setup:

```bash
createdb agriconnect                 # or: CREATE DATABASE agriconnect;
npx prisma migrate dev               # applies prisma/migrations
BOOTSTRAP_ADMIN_ENABLED=true \
  BOOTSTRAP_ADMIN_PHONE="+233200000001" \
  BOOTSTRAP_ADMIN_PASSWORD="<at least 12 chars>" \
  npx ts-node prisma/seed.ts         # crop types + MOFA benchmarks
```

`BOOTSTRAP_ADMIN_ENABLED` matters: the seed attaches every MOFA price reference
to an admin as its author, so with no admin present it creates the crop types
and silently skips **all 42 price rows** — after which pricing quietly serves a
flat GHS 10.00 fallback for every crop.

### Connection URLs

Two are needed, and they are not interchangeable:

| Variable | Used by | Why |
|---|---|---|
| `DATABASE_URL` | the app at runtime | pooled connection |
| `DIRECT_URL` | `prisma migrate` (see `prisma.config.ts`) | DDL needs a session connection, not a transaction-mode pooler |

Locally both point at the same place. On Supabase they diverge — `DATABASE_URL`
at the pooler (`:6543`), `DIRECT_URL` direct (`:5432`).

**Percent-encode special characters in the password.** An `@`, `:`, `/`, `?`,
`#`, `[` or `]` in a password will otherwise be parsed as URL structure — an `@`
in particular makes the host unresolvable. `p@ss` must be written `p%40ss`.

### Dev credentials

A dev admin is created on every non-production boot if it does not already
exist. It is now persisted to Postgres rather than memory, so it survives
restarts:

| Phone | Password |
|---|---|
| `+233200000000` | `admin12345` |

Farmers and drivers register as `PENDING_APPROVAL` and cannot log in until an
admin approves them via `PATCH /api/admin/users/:id/approve`. Buyers are
auto-verified to `ACTIVE` on registration.

## Persistence

All services now use the Prisma repositories against Postgres. The full journey
works end to end — register → admin approval → listing → marketplace →
purchase → escrow hold — and the audit hash chain is written for each step.

The `.repository.memory.ts` files are still present but **no longer imported by
any service**. They previously backed auth/user/admin/listing/marketplace/pricing
while transaction/dispatch/notification used Prisma, which meant a buyer created
by `auth` was invisible to `transaction` and purchase could not work at all.
Removing those files is safe cleanup once nothing references them.

### Known behaviour change: unknown crop/region no longer 404s

`PrismaMofaPriceRepository.findLatest` never returns `null` — it falls back to a
hardcoded **GHS 10.00**. The in-memory version returned `null`, which made
`PricingService` throw `NotFoundError`. That branch is now unreachable in
production: any crop/region pair returns a price, including one that has no
benchmark. Decide whether that fallback is wanted before relying on it.

Seeded MOFA benchmarks are also **flat per crop across all six regions**
(tomato GHS 15.50 everywhere), so regional price variation is currently
notional even though the engine is built around it.

## Health Check

```
GET /api/health
```

Returns:
```json
{
  "success": true,
  "data": {
    "message": "AgriConnect API is running"
  }
}
```

## Project Structure

```
src/
├── config/          # Environment config, database connection
├── middleware/       # Express middleware (error handler, auth, validation)
├── modules/         # Feature modules (auth, listing, payment, etc.)
│   ├── auth/        # [Afia] JWT authentication
│   ├── user/        # [Afia] User profile management
│   ├── listing/     # [Hanz] Produce listing CRUD
│   ├── marketplace/ # [Hanz] Marketplace browse & filter
│   ├── pricing/     # [Kelvin] Price recommendation engine
│   ├── payment/     # [Afia] Paystack integration
│   ├── dispatch/    # [Kelvin] Driver dispatch
│   ├── audit/       # [Hanz] Tamper-proof audit trail
│   └── admin/       # Admin endpoints
├── services/        # Shared external service wrappers (SMS, FCM, Paystack)
├── utils/           # Helpers (logger, errors, response format, hash, QR)
├── app.ts           # Express app setup
└── server.ts        # Entry point
```

## Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start dev server with hot reload |
| `npm run build` | Compile TypeScript to JavaScript |
| `npm start` | Run compiled production build |
| `npm run lint` | Run ESLint |
| `npm run format` | Run Prettier |
| `npm test` | Run Jest tests with coverage |

## Testing

`npm test` runs the suite with coverage and enforces global thresholds
(85% statements / 60% branches / 85% functions / 90% lines).

Coverage is collected from an explicit allow-list in `jest.config.ts` rather than
all of `src/`, so **a new service is not covered until you add it to
`collectCoverageFrom`** — otherwise it can sit at 0% without failing the gate.

Tests mock Prisma with `jest-mock-extended`, so **no database is required** —
CI runs no Postgres service. A suite that reaches for a live connection is a bug;
mock `../../config/db` as the existing suites do.

`jest.setup.ts` pins `JWT_SECRET`, `DATABASE_URL` **and `DIRECT_URL`** before any
app module loads. `DIRECT_URL` matters most: `config/db.ts` resolves its
connection as `DIRECT_URL || DATABASE_URL || env.DATABASE_URL`, so leaving it
unset let `dotenv` populate it from your `.env` and pointed the test-run Prisma
client at your real development database.
