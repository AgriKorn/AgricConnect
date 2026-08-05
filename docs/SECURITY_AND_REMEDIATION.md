# Security & Remediation Backlog

Findings from a full-codebase review on **2026-08-05**, recorded because the
presentation took priority over fixing them. Ordered by urgency, not by effort.

Each item states what was verified, why it matters, and the fix. Nothing in
"Not yet fixed" has been changed in the code.

---

## 1. 🔴 Production database password is public — rotate it

**Status: NOT FIXED. Do this first, before anything else in this document.**

Commit `359053a35febfd9bc95e6f03250c333fa50ad59a` ("fix(cd): supply DATABASE_URL
and DIRECT_URL fallbacks in deploy.yml…", 2026-07-28) added a hardcoded fallback
Supabase connection string — **with a real password** — to
`.github/workflows/deploy.yml` (lines 64-65).

Verified:

- `git merge-base --is-ancestor 359053a HEAD` → **it is in `main`'s permanent history**.
- The project ref in the URL matches the live `SUPABASE_URL` used by
  `backend/.env.example`, `backend/src/config/supabase.ts`, and
  `frontend/lib/core/config/supabase_config.dart` — i.e. **the production database**.
- The role is `postgres`: full read/write, bypassing every application-level
  auth check, RLS policy, and audit-trail write in this codebase.
- `gh repo view --json isPrivate` → **`false`**. The repository is public, and
  has been for the entire period the commit has existed.

`924b16ad` removed it from the working tree, which does **not** remove it from
history.

### Fix

1. **Rotate the password.** Supabase Dashboard → Settings → Database → Reset
   database password. This is the only step that actually closes the exposure —
   assume the current value is compromised, since anyone could have cloned the
   repo at any point.
2. Update the `DATABASE_URL` and `DIRECT_URL` GitHub secrets to the new value.
3. Redeploy (push to `main`, or run Backend CD via `workflow_dispatch`).
4. *Optional, secondary:* purge it from history with `git-filter-repo` or BFG and
   force-push. Do this only after rotating — it is hygiene, not remediation, and
   it rewrites every commit hash for the whole team.

---

## 2. 🔴 `JWT_REFRESH_SECRET` is a hardcoded value in a public repo

**Status: NOT FIXED — deliberately. Fixing it naively breaks production login.**

`backend/src/config/env.ts:12`:

```ts
JWT_REFRESH_SECRET: z.string().default('agriconnect_refresh_secret_min_32_chars_key_2026'),
```

`deploy.yml` never passes `JWT_REFRESH_SECRET`, so **production signs refresh
tokens with that committed literal** (`auth.service.ts:146,258` sign;
`:155,170` verify).

### ⚠️ Why the obvious fix is a trap

Adding `JWT_REFRESH_SECRET: ${{ secrets.JWT_REFRESH_SECRET }}` to the workflow
**before creating the secret** breaks login *and* registration on the next
deploy. Verified:

- No `JWT_REFRESH_SECRET` secret currently exists (`gh secret list`).
- A missing secret expands to `""`, not to unset.
- zod's `.default()` applies only to `undefined`, **not** to `""` — confirmed:
  `z.string().default('X').parse('')` → `''`.
- `jwt.sign(payload, '')` throws `secretOrPrivateKey must have a value`.

So the env var would be present-but-empty, the default would not kick in, and
every login would 500.

### Fix — in this order

1. Generate a secret: `openssl rand -base64 48`
2. Add it as the GitHub secret `JWT_REFRESH_SECRET`.
3. *Then* add to `deploy.yml` — both the step's `env:` block **and** the
   `--containers` environment JSON (the deployment call replaces the entire
   environment block, so anything absent from that JSON is wiped).
4. Change `env.ts:12` to `z.string().min(32)` with no `.default()`, so a missing
   value fails fast at boot instead of silently falling back.
5. Note that rotating this invalidates all existing refresh tokens — users get
   signed out once. Harmless, but don't do it mid-demo.

**Severity note / correction:** this is a serious defence-in-depth failure but
*not* trivially exploitable. `auth.service.ts:161` checks the presented token
against the token stored on the user row, so a forged token is rejected unless
it is byte-identical to the stored one — which requires guessing the exact `iat`
second of a live session. It is made more feasible by the fact that user UUIDs
leak via the marketplace API (see §5). Treat as HIGH, not CRITICAL.

---

## 3. 🟠 MoMo encryption is inert in production

**Status: NOT FIXED — see §8, the workflow edit was deliberately skipped.**

Commit `3067141` ("feat(security): encrypt Mobile Money numbers at rest (SRS
Security NFR)") is **doing nothing live**. `deploy.yml` does not pass
`FIELD_ENCRYPTION_KEY`, so `utils/encryption.ts:31-41` logs one warning and
stores Mobile Money numbers **in plaintext** — financial PII.

### ⚠️ Do NOT set this key in the Lightsail console

`aws lightsail create-container-service-deployment` replaces the container's
**entire** environment block. A key set by hand in the console is wiped by the
next push — and `decrypt()` (`encryption.ts:84`) then **throws on every
already-encrypted row**, breaking farmer payouts outright.

**So the workflow must be edited first — the console is never the right place.**

### Fix

1. Add `FIELD_ENCRYPTION_KEY: ${{ secrets.FIELD_ENCRYPTION_KEY }}` to
   `deploy.yml`'s deploy-step `env:` block, **and**
   `\"FIELD_ENCRYPTION_KEY\":\"$FIELD_ENCRYPTION_KEY\"` inside the
   `--containers` environment JSON. Both, or it is wiped on the next deploy.
2. `openssl rand -base64 32`
3. Add it as the GitHub secret `FIELD_ENCRYPTION_KEY`.
4. Existing plaintext rows stay readable — `decrypt()` passes through
   non-prefixed values — but they are **not** retroactively encrypted. Write a
   one-off backfill if that matters for the SRS claim.

Ordering note: step 1 is safe to land before step 3. An unset secret expands to
`""`, which `loadKey()` treats as absent, so behaviour stays exactly as it is
today until a real key is supplied. (Contrast §2, where the same pattern is
*not* safe.)

---

## 4. 🔴 Escrow can be released for an order that was never paid

**Status: NOT FIXED. Deliberately deferred — the fix changes the demo flow.**

Verified end to end:

- `transaction.repository.prisma.ts:71-77` creates the payment row with
  `status: 'held'` at checkout **initiation**, before Paystack confirms anything.
- `mapPrismaToTransaction:30` therefore reports `PAYMENT_HELD` for a brand-new,
  unpaid order.
- `transaction.service.ts:141` gates `confirmDelivery` on exactly that status.
- The `pending_payment` value exists in the `order_status` enum
  (`schema.prisma:327`) and is **used nowhere**; `payment_status` has no
  `pending` member at all.
- The QR hash that authorises payout is handed to buyers: a live
  `GET /api/marketplace` call as an ordinary buyer returns `listingHash` and
  `qrCodeData` for every listing.
- `PAYSTACK_SECRET_KEY` **is** configured in production, so
  `paymentService.initiateTransfer` performs a real transfer call rather than
  the `stub_transfer_` no-op.

**Exploit:** buy → never open the Paystack page → read `listingHash` from the
marketplace → `POST /api/transactions/:id/confirm-delivery` → the farmer is paid
out of platform funds for an order the buyer never paid for.

### Related defects in the same path

- **Double payout.** `initiateTransfer` (`:164`) runs *before* the
  `prisma.$transaction` (`:171`), the status read at `:139` takes no lock, and
  the transfer has no idempotency key. Two concurrent confirms both pay; the
  loser then dies on the `qr_scans.order_id` unique constraint and rolls back,
  leaving **no record of the second transfer**.
- **Any broadcast driver can release escrow.** `:146` accepts
  `j.status === 'PENDING'`, and `dispatch.service.ts:31-55` broadcasts a
  `notified` row to *every* eligible driver. A driver who never accepted can
  confirm delivery.
- **Dispute ordering.** `dispute.service.ts:55-64` never checks the transaction
  status, so `REFUND_BUYER` can be resolved *after* escrow was released —
  paying out twice. `confirmDelivery` likewise never checks for an open dispute,
  and the `disputed` order status is never set anywhere.
- **No cancellation path.** An abandoned checkout leaves the listing `sold` and
  the order `awaiting_driver` forever. Paystack sends no `charge.failed` for a
  never-attempted payment, and no worker expires stale orders.

### Why it was not fixed before the demo

Gating `confirmDelivery` on real payment confirmation means the demo can no
longer reach delivery confirmation without completing an actual Paystack
payment. A fix that breaks the flow being presented is worse than the bug.

### Fix (post-presentation)

1. Create orders as `pending_payment` / payment `pending`; only the verified
   `charge.success` webhook promotes to `held`.
2. Gate `confirmDelivery` on `held`, and reject when an open dispute exists.
3. Restrict confirmation to the buyer or the driver whose assignment is
   `accepted` — drop `'PENDING'` from `:146`.
4. Move `initiateTransfer` inside the transaction boundary, or make it
   idempotent on `order_id` and record the transfer before dispatching it.
5. Take a row lock (`SELECT … FOR UPDATE`) on the status check.
6. Add an order-cancellation/expiry path so abandoned checkouts release the listing.

---

## 5. 🟠 Smaller security items

| Item | Location | Note |
|---|---|---|
| Password-reset tokens work as access tokens | `middleware/authenticate.ts:16`, `auth.service.ts:88,110` | Reset token is signed with the same `JWT_SECRET` and carries no purpose check, and `forgot-password` returns it in the response body when `NODE_ENV !== 'production'`. Prod is unaffected; **any non-prod deploy is a full account-takeover vector from an email address alone.** Add a `purpose` claim and reject non-access tokens in `authenticate`. |
| `env.ts` falls back to in-repo secrets on validation failure | `config/env.ts:28-51` | If validation fails (e.g. `NODE_ENV=staging`, which is not in the enum), the process **keeps running** and signs access tokens with `'test_jwt_secret_min_16_characters_long'`. Should exit non-zero instead. |
| Webhook signature check bypassed when key unset | `services/payment.service.ts:206-210` | Returns `true` with no verification when `PAYSTACK_SECRET_KEY` is empty. **Not active in production** (the key is set), but any unconfigured environment accepts forged webhooks. The HMAC itself is correct (`timingSafeEqual`, length-checked). |
| Revoked admin keeps power until token expiry | `modules/admin/admin.routes.ts:23` | `requireApproved` exists but is not applied to admin routes, so a `REJECTED` admin can re-privilege themselves within the 15-minute access-token window. |
| User UUIDs leak | marketplace/transaction responses | `farmerId`, `buyerId`, `driverId` are returned to clients; relevant to §2. |
| Drivers can self-edit truck capacity | `user.schema.ts:24` | `PATCH /profile {"truckCapacity": 999999}` makes a driver eligible for every dispatch offer. Capacity is a trust attribute collected at registration. |

---

## 6. 🟠 Prisma migrations were deleted — the live schema is not reproducible

**Status: NOT FIXED. Needs a DB connection; do not attempt during a demo window.**

`backend/prisma/migrations/` does not exist. Traced precisely:

| Commit | migration files present |
|---|---|
| `ff908aa` (added them) | 3 |
| `8881bb0` | 3 |
| `2f374f9` | 3 |
| **`9d0cc5f`** — *"Merge origin/main into feature/frontend-integration (frontend only)"* | **0** |
| `HEAD` | 0 |

A merge labelled *frontend only* silently deleted all three backend migration
files (`20260728120907_init`, `20260728122127_add_user_refresh_token`,
`migration_lock.toml`).

Consequences:

- No workflow, `Dockerfile`, `Procfile`, or npm script runs `prisma migrate
  deploy` or `db push` — verified. Schema changes reach production **only by
  hand**, which is exactly how `e0a8646` ("add missing image_urls column that
  broke every listing-touching endpoint") happened.
- `backend/README.md:28` documents `npx prisma migrate dev  # applies
  prisma/migrations`. **That cannot work on a fresh clone.** Compounded by
  `schema.prisma` having no `datasource url` (it comes from
  `prisma.config.ts` → `DIRECT_URL`) and `.env.example` not listing `DIRECT_URL`.

### Fix

Do **not** blindly restore the files from `2f374f9` — the schema has grown a lot
since (multi-image listings, encryption fields), so those two migrations no
longer describe the live database and `migrate dev` would immediately report
drift.

Baseline instead:

1. Restore the two files for history: `git checkout 2f374f9 -- backend/prisma/migrations`
2. Point `DIRECT_URL` at the live DB and run
   `npx prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --script > prisma/migrations/<ts>_baseline/migration.sql`
3. Mark it applied without re-running DDL:
   `npx prisma migrate resolve --applied <ts>_baseline`
4. Verify `npx prisma migrate status` is clean.
5. Add a `prisma migrate deploy` step to Backend CD so this cannot drift again.

---

## 6b. ✅ Shelf-life days depended on the crop guess — resolved by removal

**Status: FIXED (`a1f6350`) — shelf life is no longer shown by the scan.**

`agriconnect.tflite` computes its third output, `shelf_life_days`, **in-graph
from its own crop guess** — `ArgMax` over the crop head, then `Gather` against a
constant table baked in from `ai/shelf_life.py` (see `ai/README.md` and
`ai/pipeline/07_add_shelf_life_output.py`). Because the crop head is unreliable
(fixed 9-crop vocabulary, no "not a crop" class), the day count inherited that
unreliability, and it could not be corrected in Dart.

Rather than display a number resting on an untrusted guess, shelf life was
removed from the scan entirely. Everything the scan now reports comes from the
freshness head alone, which is species-independent:

| Shown | Source | Depends on the crop guess? |
|---|---|---|
| Freshness score (0-100) | freshness head | No |
| Quality grade (A/B/C) | derived from the score | No |
| Low-confidence retake hint | freshness head | No |

`ScanRecord` carries no crop species, no price and no shelf life, enforced by
the type system. The listing form keeps its "Shelf life (days)" field because
the backend requires it — the farmer supplies it, along with the crop name and
price.

**If shelf life is wanted back**, the cheapest correct route needs no retrain:
ask the farmer for the crop first, then look the value up in Dart from
`ai/shelf_life.py`'s already-committed table using the farmer's answer plus the
model's freshness stage. That keeps every displayed number resting only on the
reliable freshness head and the farmer's own input. A retrain with an explicit
"not a crop" class remains the fuller fix and would also address §7's root cause.

---

## 7. Already fixed on 2026-08-05

- **Scan inference was completely broken.** `crop_scan_model_io.dart` fed
  `runForMultipleInputs` a `[224,224,3]` tensor where the model's single input
  is `[1,224,224,3]`, so every real on-device scan failed. Independently
  confirmed by PR #11, which found the same line via device testing.
- **The scan fabricated freshness scores** (`e191d26`). `scan_controller.dart`
  held a `_sampleResults` list — Tomatoes 94, Cassava 54, Pepper 31 — cycled by
  an index, and **three** paths fell into it *silently*, all invisible in a
  release APK: (1) camera never initialised, logged only under `kDebugMode`;
  (2) `takePicture()` threw, same debug-only log; (3) web, where
  `tflite_flutter` cannot run at all and `UnsupportedError` was swallowed. A
  broken camera and a genuine reading were indistinguishable — this is what
  users saw as "the model is hardcoded". The fallback is deleted; each failure
  now names itself. The APK packaging was verified innocent: the release APK
  bundles the model asset (exact byte match) and `libtensorflowlite_jni.so` for
  all three ABIs.
- **The engine no longer names crops** (`e191d26`). Beyond the display removal
  below, `crop_scan_presenter.dart` was still doing
  `_basePricePerKg[result.cropType]`, so the guessed species silently set
  `recommendedPrice`, which prefilled the add-listing price field — a head
  misread as a tomato moved the farmer's asking price. `cropType`,
  `recommendedPrice` and `priceUnit` are gone from `ScanRecord`, so the
  invariant is now enforced by the type system; the presenter reads no part of
  the crop head, and confidence comes from the freshness head alone. Remaining
  gap: see §6b.
- **No way to scan an existing photo.** Added a gallery picker to the scan
  screen; capture failures now surface as a toast instead of hanging the
  analysing overlay.
- **Out-of-scope crop naming removed.** The model has a fixed 9-crop vocabulary
  and no "not a crop" class, so it confidently named non-produce (a head as
  "tomato"). Its species guess is no longer displayed anywhere. A confidence
  threshold was evaluated and rejected: measured ranges overlap (real crops as
  low as 51%, non-crops up to 75%), so no cutoff separates them.
- **Scan caveats are now visible.** `buildScanRecord` always computed
  `attributes` — including *"Low Confidence — Retake in Better Light"* — and
  nothing rendered them. Now shown as chips on the result screen.
- **Real scans are no longer captioned as fake.** The result screen
  unconditionally read *"Preview — sample result, not a real scan"*; it is now
  conditional on the new `ScanRecord.isSampleResult`.
- **500s on malformed address IDs.** `PATCH`/`DELETE /api/users/addresses/:id`
  had no UUID validation, so a Postgres cast error surfaced as a raw 500 instead
  of a 404.
- **Dead code / analyzer warnings.** Removed an unused `_openComingSoon` helper
  and its import; removed an unreachable `default:` in a `UserRole` switch so a
  future role becomes a compile error rather than a silent `'farmer'`; dropped a
  stale `hide Provider`. `flutter analyze`: 3 warnings → **0**.

---

## 8. Deferred: three `.github/workflows/` changes

**Status: NOT APPLIED — the workflow files are deliberately unchanged.**

These were prepared and validated (YAML parsed, Lightsail container JSON
re-parsed with all vars expanded) but **not** committed, by decision. Each is a
small, self-contained edit whenever you want it.

Note: changing files under `.github/workflows/` requires a token with the
`workflow` scope. The `Kobi-Ampem` login used for this work has
`gist, read:org, repo` only, so these edits also cannot be pushed with it as-is
(`gh auth refresh -h github.com -s workflow` would add the scope).

**a. Lock production deploys to `main`.** `deploy.yml` triggers on `main`,
`feature/K1-scaffolding` and `feature/frontend-integration`;
`deploy-frontend.yml` on `main` and `feature/frontend-integration`. Both deploy
straight to live production (`container-service-1` / `-2`), so **any push to
either feature branch redeploys production** — including mid-demo. Drop the
`feature/*` entries; `workflow_dispatch` already covers deliberate branch
deploys.

*Leave `build-apk.yml` alone* — it only builds an artifact and never touches
production, so restricting it removes a useful branch check for no safety gain.

**b. Unmask frontend deploy failures.** `deploy-frontend.yml`'s last line ends
with `|| true`, so a failed Lightsail deployment reports green while the live
site stays stale. Delete the `|| true`.

**c. Wire `FIELD_ENCRYPTION_KEY`.** See §3 — this is the prerequisite for making
MoMo encryption actually work in production.

Two further workflow-level gaps worth fixing at the same time:

- Backend CD's job is named "**Test**, Build Docker & Deploy" but runs no test,
  lint, or build step, and `ci.yml` only fires on `pull_request` — so a direct
  push to `main` (the normal deploy path) reaches production with zero tests run.
- No CI job runs `flutter analyze` or `flutter test` at all; the APK and web
  builds are compile-only gates. This is why the broken scan tensor shape (§7)
  shipped green.

---

## 9. Correctness backlog (not security)

Confirmed by reading code; none is a demo blocker.

**Money / dispatch**

- Two of three background workers are **never started** — verified that
  `freshnessMonitorWorker.start()` is the only `.start()` in non-test source.
  `DriverTimeoutWorker` and `OutboxWorker` are unit-tested but dormant, so
  unanswered driver offers never expire or reassign, and `outbox_events` grows
  forever. Not started pre-demo to avoid new live background activity.
- `purchase()`/`confirmDelivery()` mix the interactive `tx` client with the
  global `prisma` client inside one `$transaction`, so the writes are not
  atomic — a late abort can commit the order while rolling back the listing's
  `active → sold` flip, reselling a listing that already has escrow held.
  `config/db.ts:8` also sets no pool `max`, so concurrent purchases can deadlock.
- An accepted driver's availability is only ever restored by a successful
  `confirmDelivery`; a refunded order leaves them `offline` and invisible to all
  future dispatch.
- Dispatch ignores `driver_details.operating_region` entirely — every available
  driver nationwide is offered every delivery.
- No SMS/push delivery exists (`notification.service.ts` writes a DB row and
  logs that push is unimplemented; no FCM/Twilio dependency). Worth knowing
  before narrating "the driver gets notified".

**Pricing**

- `pricing.repository.prisma.ts:25-31` returns a fabricated **GHS 10.00** for
  any unknown crop/region instead of `null`, presented as a government
  reference price. Makes `pricing.service.ts:70-72`'s `NotFoundError` dead code.
- `pricing.service.ts:74-75`: `ceiling = mofa * freshness/100` but
  `softFloor = mofa * 0.6`, so **any freshness below 60 inverts the band**
  (ceiling below floor).
- `price_floor` / `price_ceiling` / `below_floor_acknowledged` are written and
  **read nowhere** — the guardrail feature is inert.

**Audit**

- `verifyChainForEntity` never checks `previousHash` linkage, so deleting or
  reordering a row still returns `valid: true`.
- Audit writes are non-atomic (`findLatest` then `create` with
  `event_hash: 'PENDING'`, outside a transaction), so concurrent writes fork the
  chain or leave a permanent `PENDING` row that reports tampering forever.
- `audit.repository.prisma.ts:47` nulls non-UUID actors but hashes the original
  value, so entries written by `'cli-script'` / `'driver-timeout-worker'`
  **report false tampering**.
- `entity_type` is hardcoded to `'ENTITY'` on every insert, so the
  `entityType` filter can never match.

**API contracts / docs**

- `config/swagger.ts` is dead (nothing imports `swaggerSpec`), so every
  `@swagger` JSDoc block renders nowhere. The served spec comes only from the
  `*.openapi.ts` registry — which is why the two have drifted:
  - The Postman collection and OpenAPI both send `phone` for login/register;
    the API requires `email`. **The demo collection 400s on its first request.**
  - Swagger documents `GET /api/mofa/reference`, which does not exist, and omits
    `GET /api/pricing/recommend`, which does.
  - `GET /api/listings` is documented as a public paginated browse; it is
    farmer-only with a different response shape.
- Both admin-bootstrap paths create an admin with **no email**, and login
  resolves users only by email — so the printed dev admin credentials
  (`+233200000000` / `admin12345`) cannot actually log in. Only
  `src/scripts/create-admin.ts` sets one.
- `GET /api/audit/:entityId` is unauthenticated and unvalidated → 500 on any
  non-UUID segment. `GET /api/admin/audit` has no validation → several ordinary
  query strings 500.
- `PATCH /api/users/profile` validates `gpsLatitude`/`gpsLongitude`/
  `deliveryAddress` and then silently discards them.
- Audit CSV export is silently truncated to 50 rows (asks for 1000).

**Frontend**

- Marketplace **category filter can never match Fruits or Grains**:
  `marketplace_repository.dart:260` feeds the crop *name* into a
  FRUITS/VEGETABLES/GRAINS mapper that defaults to vegetables. The backend
  already sends a real `cropCategory`, and the detail parser reads it correctly —
  only the list parser ignores it. Demo-visible.
- A completed purchase invalidates nothing, so the Orders tab and marketplace
  grid stay stale until a manual pull-to-refresh.
- Several screens render a failed fetch as empty state rather than an error
  (Orders, Alerts, farmer dashboard) — offline looks like "you have no orders".
- Checkout's Pay button catches only `ApiException`, so any other throw leaves
  it stuck on "Processing…" forever.
- Driver job card's red "countdown" is actually elapsed time, wraps every hour,
  and never ticks.
- A failed QR confirm re-submits in a tight loop (`confirm_delivery_screen.dart`
  resets its guard while the scanner keeps streaming).
- Only 3 test files cover 114 `lib/` files, and **no CI job runs
  `flutter test` or `flutter analyze`** — the APK/web builds are compile-only
  gates. Adding an analyze+test job is the highest-leverage frontend fix.

**Hygiene**

- Seven `*.repository.memory.ts` files are unreferenced but export singleton
  names identical to the live Prisma ones — an import-path typo silently swaps a
  service onto an in-memory store.
- `backend/src/scripts/seed.ts` is dead and near-duplicates the live
  `backend/prisma/seed.ts`.
- `.env.example` omits `PAYSTACK_SECRET_KEY`, `DIRECT_URL`,
  `FIELD_ENCRYPTION_KEY`, `ENABLE_DOCS`, the `BOOTSTRAP_ADMIN_*` trio and the
  S3 vars, while listing `FIREBASE_SERVICE_ACCOUNT` and `AWS_S3_BUCKET`, which
  nothing reads.
- `ci.yml` claims `npm test` uses `--runInBand` for OOM protection;
  `package.json` does not.
- `jest.config.ts` omits `utils/encryption.ts` and
  `workers/driver-timeout.worker.ts` from `collectCoverageFrom` despite both
  having test suites — so the code protecting PII contributes nothing to the gate.
- Backend CD's job is named "**Test**, Build Docker & Deploy" but runs no test,
  lint, or build step, and `ci.yml` only fires on pull requests — so a direct
  push to `main` reaches production with zero tests run.
- `frontend/README.md` is the untouched `flutter create` template and never
  mentions that `api_endpoints.dart:5` defaults to the **live production
  backend**, so a bare `flutter run` reads and writes production data.
- Release APKs are signed with the checked-in debug key.
