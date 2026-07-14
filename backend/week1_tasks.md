# AgriConnect Backend — Week 1 Tasks

**Project:** AgriConnect (Freshness-Aware Agricultural Marketplace)
**Team:** Kelvin (Lead) · Afia · Hanz
**Stack:** Node.js · Express.js · TypeScript · Prisma · AWS

---

## Before You Start — Everyone Read This

- We are building the backend API for AgriConnect
- The database is handled by a separate team — we just connect to it using Prisma
- We use **TypeScript** (not plain JavaScript)
- All API responses follow this format:
  ```json
  { "success": true, "data": { ... } }
  { "success": false, "error": { "code": "VALIDATION_ERROR", "message": "..." } }
  ```
- Every endpoint you build must have **Zod validation** for request bodies
- When your task is done, create a **Pull Request** to the `dev` branch — Kelvin will review

---

## KELVIN's Tasks

### Task K1 — Create GitHub Repo & Project Setup
**Deadline: Day 1**

Create the GitHub repository and set up the entire project from scratch.

**What to do:**
1. Create a new GitHub repo called `agriconnect-backend` (private)
2. Create two branches: `main` (protected) and `dev`
3. Set branch protection on `main` — no direct pushes, require PR reviews
4. Initialize the project:
   ```
   npm init -y
   npm install express typescript ts-node @types/express @types/node
   npm install prisma @prisma/client
   npm install cors dotenv helmet morgan winston express-rate-limit
   npm install zod jsonwebtoken bcryptjs qrcode axios
   npm install -D nodemon eslint prettier jest ts-jest @types/jest supertest @types/supertest
   ```
5. Set up `tsconfig.json`, `.eslintrc.js`, `.prettierrc`
6. Create the folder structure:
   ```
   src/
   ├── config/          (env.ts, database.ts)
   ├── middleware/       (errorHandler.ts, rateLimiter.ts)
   ├── modules/         (empty folders for: auth, user, listing, marketplace, pricing, payment, dispatch, audit, verification, admin)
   ├── services/        (empty files for: sms.service.ts, notification.service.ts, payment.service.ts)
   ├── utils/           (errors.ts, response.ts, hash.ts, qrcode.ts)
   ├── app.ts           (Express app with all middleware)
   └── server.ts        (Entry point — listens on PORT)
   ```
7. Create `.env.example` with all required variables:
   ```
   PORT=3000
   DATABASE_URL=
   JWT_SECRET=
   JWT_REFRESH_SECRET=
   PAYSTACK_SECRET_KEY=
   ARKESEL_API_KEY=
   FIREBASE_SERVICE_ACCOUNT=
   AWS_ACCESS_KEY_ID=
   AWS_SECRET_ACCESS_KEY=
   AWS_S3_BUCKET=
   ```
8. Build the health check endpoint: `GET /api/health` → returns `{ success: true, message: "AgriConnect API is running" }`
9. Build the global error handler middleware
10. Build the standard response helper functions (`sendSuccess`, `sendError`)
11. Set up Winston logger
12. Push to `dev` branch

**Deliverable:** Everyone can clone the repo, run `npm install` then `npm run dev`, and hit `localhost:3000/api/health`.

---

### Task K2 — CI/CD Pipeline + AWS Deployment
**Deadline: Day 2**

**What to do:**
1. Create `.github/workflows/ci.yml`:
   - Triggers on every PR to `dev`
   - Runs: install → lint → type-check → test
2. Set up AWS deployment:
   - Option A: Elastic Beanstalk (simpler)
   - Option B: EC2 instance + PM2 (more control)
3. Create `.github/workflows/deploy.yml`:
   - Triggers on merge to `main`
   - Deploys to AWS
4. Verify: the health check endpoint is accessible on the AWS URL

**Deliverable:** CI runs on every PR. Merging to `main` auto-deploys to AWS. Share the live API URL with the team.

---

### Task K3 — Prisma ORM Setup
**Deadline: Day 3**

**What to do:**
1. Get the database connection string from the DB team
2. Run `npx prisma init`
3. Add the connection string to `.env`
4. Either:
   - Run `npx prisma db pull` to pull the DB team's existing schema, OR
   - Manually write the Prisma models based on the ER diagram they share
5. Run `npx prisma generate` to create the Prisma client
6. Test: write a simple query in a test route to verify DB connection works
7. Push as a PR to `dev`

**Deliverable:** Prisma client works. Afia and Hanz can import it and start querying.

> ⚠️ **BLOCKER:** Contact the DB team BEFORE Day 1 to make sure they have the database ready or at least give you the connection string and schema.

---

### Task K4 — Price Recommendation Engine
**Deadline: Day 8**

**What to do:**
1. Create the `src/modules/pricing/` module
2. Build `GET /api/pricing/recommend`:
   - Query params: `crop`, `region`, `freshness` (0-100)
   - Fetch the MOFA reference price from the database (the `mofa_price_reference` table)
   - Calculate: `ceiling = mofaPrice × (freshness / 100)`
   - Calculate: `softFloor = mofaPrice × 0.60`
   - Return: `{ mofaPrice, ceiling, softFloor, freshness }`
3. If farmer tries to list below the soft floor → return a warning (not an error)
4. Add Zod validation for query params
5. Add Swagger annotations
6. Push as a PR to `dev`

**Deliverable:** Frontend can call `/api/pricing/recommend?crop=tomato&region=accra&freshness=85` and get price recommendations.

---

## AFIA's Tasks

### Task A1 — JWT Authentication System
**Deadline: Day 3**

> ⚠️ **Wait for:** Kelvin's K1 (project setup) and K3 (Prisma) to be done first. You can start studying JWT and planning your code on Day 1–2.

**What to do:**
1. Create the `src/modules/auth/` module
2. Build these 5 endpoints:

   **`POST /api/auth/register`**
   - Accepts: `name`, `phone`, `password`, `role` (farmer | buyer | driver)
   - Hash password with `bcryptjs`
   - Save user to database with status `PENDING_OTP`
   - Generate a 6-digit OTP code
   - For now: return the OTP in the response (we'll replace this with real SMS later when Hanz finishes the Arkesel integration)
   - Store OTP in the database with 5-minute expiry

   **`POST /api/auth/verify-otp`**
   - Accepts: `phone`, `otp`
   - Verify OTP matches and hasn't expired
   - Update user status to `PENDING_APPROVAL` (admin must approve before they can transact)

   **`POST /api/auth/login`**
   - Accepts: `phone`, `password`
   - Verify credentials
   - Issue JWT access token (15 min expiry) + refresh token (7 days)
   - Return both tokens + user profile

   **`POST /api/auth/refresh`**
   - Accepts: `refreshToken`
   - Verify refresh token is valid
   - Issue new access token
   
   **`POST /api/auth/logout`**
   - Invalidate the refresh token

3. Add Zod validation schemas for all request bodies
4. Add Swagger annotations
5. Push as a PR to `dev`

**Deliverable:** A user can register → verify OTP → login → get JWT token → refresh token → logout.

---

### Task A2 — Auth Middleware + Role Guards
**Deadline: Day 4**

**What to do:**
1. Create `src/middleware/authenticate.ts`:
   - Extract JWT from `Authorization: Bearer <token>` header
   - Verify the token signature
   - Attach the decoded user to `req.user`
   - Return `401 Unauthorized` if token is missing or invalid

2. Create `src/middleware/authorize.ts`:
   - Accepts a list of allowed roles: `authorize('farmer', 'admin')`
   - Checks if `req.user.role` is in the allowed list
   - Return `403 Forbidden` if role is not allowed

3. Create `src/middleware/validate.ts`:
   - Accepts a Zod schema
   - Validates `req.body` against it
   - Returns `400 Bad Request` with clear error messages if validation fails

4. Test with a protected route:
   ```typescript
   router.get('/test', authenticate, authorize('farmer'), (req, res) => {
     res.json({ success: true, data: req.user });
   });
   ```
5. Push as a PR to `dev`

**Deliverable:** Any route can be protected with `authenticate` and `authorize('role')`. Kelvin and Hanz can use these in their modules.

---

### Task A3 — User Management Endpoints
**Deadline: Day 6**

**What to do:**
1. Create the `src/modules/user/` module
2. Build these endpoints (all require authentication):

   **`GET /api/users/profile`** — Get your own profile
   **`PATCH /api/users/profile`** — Update your own profile

3. Role-specific profile fields:
   - Farmer: farm region, GPS coordinates
   - Buyer: business name, delivery address
   - Driver: truck capacity (kg), operating region, availability (available/unavailable)

4. Add Zod validation
5. Add Swagger annotations
6. Push as a PR to `dev`

**Deliverable:** Any logged-in user can view and update their own profile.

---

### Task A4 — Paystack Setup
**Deadline: Day 8**

**What to do:**
1. Create a Paystack developer account at [dashboard.paystack.com](https://dashboard.paystack.com)
2. Get your **test/sandbox API keys**
3. Create `src/services/payment.service.ts` — a PaystackService class with:
   - `initializeTransaction(amount, email, metadata)` — starts a payment
   - `verifyTransaction(reference)` — checks if payment was successful
   - `createTransferRecipient(name, accountNumber, bankCode)` — registers farmer for payout
   - `initiateTransfer(recipientCode, amount)` — sends money to farmer
4. Create `POST /api/payments/webhook` — receives Paystack callbacks (verify with Paystack signature)
5. Test: make a sandbox payment and verify it works
6. Document the escrow flow: buyer pays → platform holds → delivery confirmed → platform transfers to farmer
7. Push as a PR to `dev`

**Deliverable:** Working Paystack sandbox integration. Can process a test payment and receive webhooks.

---

## HANZ's Tasks

### Task H1 — Produce Listing CRUD
**Deadline: Day 5**

> ⚠️ **Wait for:** Kelvin's K1 + K3 (setup + Prisma) and Afia's A2 (auth middleware). You can start writing the service logic on Day 3–4 while waiting for A2.

**What to do:**
1. Create the `src/modules/listing/` module
2. Build these endpoints:

   **`POST /api/listings`** *(farmer only)*
   - Accepts: `cropType`, `quantity` (kg), `gpsLatitude`, `gpsLongitude`, `freshnessScore` (0-100), `shelfLifeDays`, `price`, `imageUrl` (optional)
   - Generate SHA-256 hash of the listing data using Node.js `crypto`:
     ```typescript
     const hash = crypto.createHash('sha256')
       .update(JSON.stringify({ cropType, quantity, freshnessScore, farmerId, timestamp }))
       .digest('hex');
     ```
   - Generate QR code from the hash using the `qrcode` package
   - Save listing + hash + QR to database
   - Return the created listing with QR code

   **`GET /api/listings`** *(farmer only)* — Get your own listings
   **`GET /api/listings/:id`** — Get a single listing (public)
   **`PATCH /api/listings/:id`** *(farmer only, own listings)* — Update listing
   **`DELETE /api/listings/:id`** *(farmer only, own listings)* — Soft delete (mark as inactive)

3. Add Zod validation for all request bodies
4. Add Swagger annotations
5. Push as a PR to `dev`

**Deliverable:** A farmer can create a listing with auto-generated SHA-256 hash and QR code, view their listings, update, and delete.

---

### Task H2 — Marketplace Browse & Filter
**Deadline: Day 6**

**What to do:**
1. Create the `src/modules/marketplace/` module
2. Build:

   **`GET /api/marketplace`** *(authenticated users)*
   - Returns all **active** listings with pagination
   - Query params for filtering:
     - `crop` — filter by crop type
     - `region` — filter by farmer's region
     - `minFreshness` / `maxFreshness` — freshness score range
     - `minQuantity` — minimum quantity in kg
     - `sort` — `freshness` | `price` | `date` (default: `date`)
     - `order` — `asc` | `desc` (default: `desc`)
     - `page` — page number (default: 1)
     - `limit` — items per page (default: 20)
   - Each listing shows: crop type, quantity, price, freshness score, farmer region, listing date

   **`GET /api/marketplace/:id`** — Single listing detail view

3. Add Swagger annotations
4. Push as a PR to `dev`

**Deliverable:** Buyers can browse listings with filters and sorting. Paginated results.

---

### Task H3 — Audit Trail System
**Deadline: Day 7**

**What to do:**
1. Create the `src/modules/audit/` module
2. Build a reusable `AuditService` class in `src/modules/audit/audit.service.ts`:
   ```typescript
   class AuditService {
     static async log(eventType: string, entityId: string, data: object, userId: string) {
       // 1. Get the previous audit entry's hash (for hash chaining)
       // 2. Create SHA-256 hash of: eventType + entityId + data + timestamp + previousHash
       // 3. Store in audit_trail table
     }
   }
   ```
   Event types to support:
   - `LISTING_CREATED`
   - `LISTING_UPDATED`
   - `PURCHASE_INITIATED`
   - `PAYMENT_HELD`
   - `DRIVER_DISPATCHED`
   - `DRIVER_ACCEPTED`
   - `DELIVERY_CONFIRMED`
   - `PAYMENT_RELEASED`

3. Build: **`GET /api/audit/:transactionId`** — public endpoint to verify the full chain of custody for a transaction. Checks that all hashes in the chain are valid.
4. Integrate: call `AuditService.log()` in your listing creation endpoint (H1)
5. Push as a PR to `dev`

**Deliverable:** Any module can call `AuditService.log()` to record an event. The chain can be publicly verified.

---

### Task H4 — Arkesel SMS + FCM Setup
**Deadline: Day 9**

**What to do:**

**Part 1 — Arkesel SMS:**
1. Create an Arkesel account at [arkesel.com](https://arkesel.com)
2. Get your API key
3. Build `src/services/sms.service.ts`:
   ```typescript
   class SmsService {
     static async sendOtp(phone: string, code: string): Promise<void> { ... }
     static async sendDriverNotification(phone: string, jobDetails: object): Promise<void> { ... }
   }
   ```
4. Replace Afia's OTP stub in the auth module with real Arkesel SMS calls
5. Test: send a real OTP SMS to a test phone number

**Part 2 — Firebase Cloud Messaging:**
1. Create a Firebase project (or get access to the existing one)
2. Download the service account key
3. Build `src/services/notification.service.ts`:
   ```typescript
   class NotificationService {
     static async sendToDevice(fcmToken: string, title: string, body: string, data?: object): Promise<void> { ... }
   }
   ```
4. Test: send a test push notification

5. Push both as a PR to `dev`

**Deliverable:** Real SMS sends via Arkesel. Push notifications send via FCM. Both services are importable by any module.

---

## Summary — Who Does What, When

| Day | Kelvin | Afia | Hanz |
|---|---|---|---|
| **Day 1** | 🔨 **K1:** Create repo + full project setup | 📖 Study JWT + Prisma docs | 📖 Study SHA-256, QR, Arkesel docs |
| **Day 2** | 🔨 **K2:** CI/CD + AWS deploy | 📖 Plan auth flow + write code locally | 📖 Plan listing logic + write code locally |
| **Day 3** | 🔨 **K3:** Prisma setup + DB connection | 🔨 **A1:** JWT auth system | Start **H3** audit service class |
| **Day 4** | 🔍 Review A1 PR | 🔨 **A2:** Auth middleware + role guards | Continue **H3** |
| **Day 5** | 🔍 Review A2 + H1 PRs | 📖 Research Paystack API | 🔨 **H1:** Listing CRUD + hash + QR |
| **Day 6** | 🔍 Review A3 + H2 PRs | 🔨 **A3:** User management endpoints | 🔨 **H2:** Marketplace browse + filter |
| **Day 7** | 🔍 Review H3 PR | 📖 Plan Paystack escrow flow | 🔨 **H3:** Audit trail endpoint |
| **Day 8** | 🔨 **K4:** Price recommendation engine | 🔨 **A4:** Paystack setup | 📖 Prep Arkesel + FCM accounts |
| **Day 9** | 🔍 Review H4 + A4 PRs | — | 🔨 **H4:** Arkesel SMS + FCM setup |
| **Friday** | 📋 **Team check-in** | 📋 **Team check-in** | 📋 **Team check-in** |

---

## Quick Reference

**Repo:** `agriconnect-backend` (to be created by Kelvin on Day 1)
**Branches:** `main` (protected) → `dev` (integration) → `feature/*` (your work)
**PR Rule:** Always PR to `dev`. Kelvin reviews. Minimum 1 approval.
**Branch naming:** `feature/K1-scaffolding`, `feature/A1-jwt-auth`, `feature/H1-listing-crud`
**Commit format:** `feat(auth): add OTP verification`, `fix(listing): handle null GPS`
**Daily update:** Post what you did and any blockers in the group chat
**Friday:** Check-in meeting — demo what works, raise issues, plan next week
