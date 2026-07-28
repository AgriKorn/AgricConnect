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

`npm run dev` needs only `JWT_SECRET` and `DATABASE_URL` set — the server boots
without a reachable database, because the modules listed under "in-memory" below
never touch Postgres. See the next section for what that does and doesn't cover.

### Dev credentials

A dev admin is seeded on every non-production boot (in memory, so it resets when
you restart):

| Phone | Password |
|---|---|
| `+233200000000` | `admin12345` |

Farmers and drivers register as `PENDING_APPROVAL` and cannot log in until an
admin approves them via `PATCH /api/admin/users/:id/approve`. Buyers are
auto-verified to `ACTIVE` on registration.

## ⚠️ Persistence: split state

**The same entity is read through two different repositories depending on which
service you are in.** Every module has both a `.repository.memory.ts` and a
`.repository.prisma.ts`; these are the ones actually wired up today:

| Service | `User` from | `Listing` from |
|---|---|---|
| `auth`, `user`, `admin` | **memory** | — |
| `listing`, `marketplace` | **memory** | **memory** |
| `pricing` | — | memory (MOFA prices) |
| `transaction` | **Prisma** | **Prisma** |
| `dispatch`, `notification` | **Prisma** | — |
| `audit`, `dispute`, `outbox`, `payment` | — | Prisma |

What this means in practice:

- **Works end to end without a database**: register, login, admin approval,
  profile updates, listing CRUD, marketplace browse/filter, price recommendation.
  All of it resets on restart.
- **Cannot work as wired**: purchase, escrow, delivery confirmation, driver
  dispatch. A buyer created by `auth` (memory) is invisible to `transaction`
  (Prisma), as is their listing — so the lookup fails before any business logic
  runs. This is a wiring problem, not a bug in those services.

`prisma/schema.prisma` already defines all 14 models, so the blocker the memory
repositories were written around is gone. **There is no `prisma/migrations/`
directory yet** — the schema has never been applied to a database.

Unifying onto the Prisma repositories is the next significant piece of work. It
is mostly rewiring: the Prisma implementations exist and satisfy the same
interfaces, so response shapes do not change.

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

Tests use in-memory repositories or `jest-mock-extended` mocks for Prisma, so no
database is required. `jest.setup.ts` pins `JWT_SECRET`/`DATABASE_URL` before any
app module loads, so results do not depend on your local `.env`.
