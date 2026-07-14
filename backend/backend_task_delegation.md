# AgriConnect Backend — Task Delegation Plan

> **Team:** Kelvin (Lead) · Afia · Hanz
>
> **Stack:** Node.js + Express.js + TypeScript → AWS
>
> **Database:** Handled by a separate team (not our responsibility)

---

## 1. Confirmed & Recommended Technology Stack

### ✅ Confirmed (from PDFs + your input)

| Layer | Technology |
|---|---|
| Runtime | Node.js |
| Framework | Express.js |
| Language | TypeScript |
| Database | PostgreSQL on Supabase *(owned by DB team — we consume it)* |
| ORM | Prisma *(our interface to the DB team's schema)* |
| Hosting | **AWS** |
| Payment Gateway | Paystack API |
| SMS Provider | Arkesel Ghana SMS API |
| Push Notifications | Firebase Cloud Messaging (FCM) |

### 💡 My Recommendations (not in the PDFs)

These are technologies the PDFs don't mention but you'll need. I'm recommending based on what fits Express.js + TypeScript + AWS best:

| Category | Recommendation | Why This Choice |
|---|---|---|
| **AWS Hosting Service** | **AWS Elastic Beanstalk** or **AWS EC2 + PM2** | Elastic Beanstalk is the simplest — you push code, it handles scaling. EC2 + PM2 gives more control. Both are better than Lambda for a stateful Express app with WebSocket-potential. If budget is tight, a single EC2 `t3.micro` (free tier eligible) works for MVP. |
| **CI/CD** | **GitHub Actions → deploy to AWS** | Free for public repos, easy to set up. Use `aws-actions/configure-aws-credentials` and `aws-actions/beanstalk-deploy` actions. |
| **Authentication Tokens** | **JWT (access + refresh tokens)** | The PDFs mention "authentication issuance and refresh" — JWT is the clear fit. Use `jsonwebtoken` + `bcryptjs` packages. Access token: 15 min expiry. Refresh token: 7 days, stored in DB. |
| **Input Validation** | **Zod** | Type-safe, integrates perfectly with TypeScript and Prisma types. Lightweight. Better than Joi for TS projects. |
| **API Documentation** | **Swagger (OpenAPI 3.0)** via `swagger-jsdoc` + `swagger-ui-express` | Auto-generates interactive API docs at `/api/docs`. Frontend team can test endpoints directly. |
| **Error Handling** | Custom error classes + global `errorHandler` middleware | Standardize all API error responses: `{ success: false, error: { code, message } }` |
| **Logging** | **Winston** | Industry standard for Node.js. Structured JSON logs. Can pipe to AWS CloudWatch. |
| **Rate Limiting** | **express-rate-limit** | Protects auth endpoints from brute force. Simple middleware. |
| **CORS** | **cors** npm package | Required for Flutter app and admin web dashboard to call the API. |
| **Environment Variables** | **dotenv** + Zod validation | Load from `.env`, validate all required vars exist on startup with Zod. |
| **QR Code Generation** | **qrcode** npm package | Lightweight. Generate QR from SHA-256 hash string. Returns PNG buffer or data URL. |
| **SHA-256 Hashing** | Node.js built-in `crypto` module | No extra dependency needed. `crypto.createHash('sha256')`. |
| **Scheduled Jobs** | **node-cron** | For the 48-hour freshness alert check. Lightweight cron scheduler. |
| **File/Image Upload** | **AWS S3** + **multer** + **multer-s3** | Produce images uploaded to S3. Since you're already on AWS, S3 is the natural choice. |
| **Testing** | **Jest** + **Supertest** | Jest for unit tests, Supertest for API integration tests. Most popular combo for Express. |
| **Code Quality** | **ESLint** + **Prettier** | Enforce consistent code style across all 3 team members. |
| **HTTP Client** | **axios** | For calling Paystack, Arkesel, and FCM APIs from the backend. |

### 📦 Recommended `package.json` Dependencies

```
# Core
express, typescript, ts-node, @types/express, @types/node
prisma, @prisma/client

# Auth
jsonwebtoken, @types/jsonwebtoken, bcryptjs, @types/bcryptjs

# Validation & Docs
zod, swagger-jsdoc, swagger-ui-express

# External Services
axios, firebase-admin

# Utilities
cors, dotenv, helmet, express-rate-limit, morgan, winston
qrcode, @types/qrcode, node-cron, @types/node-cron, multer, multer-s3

# AWS
@aws-sdk/client-s3

# Dev/Testing
jest, ts-jest, @types/jest, supertest, @types/supertest
eslint, prettier, nodemon
```

---

## 2. Backend Team Roles

| Member | Role | Focus Area | Strengths Needed |
|---|---|---|---|
| **Kelvin (You)** | Lead + Infrastructure + Core Logic | Project scaffolding, AWS deployment, CI/CD, price recommendation engine, code reviews, cross-team coordination | Express setup, AWS, DevOps, architecture |
| **Afia** | Auth + User Management + Payments | JWT authentication, OTP flow, role-based access, user endpoints, Paystack integration | Security, auth patterns, payment APIs |
| **Hanz** | Listings + Integrations + Audit | Produce listing CRUD, QR/hash system, audit trail, Arkesel SMS, FCM notifications | CRUD patterns, external APIs, crypto |

---

## 3. Complete Task Breakdown

### Phase 0 — Foundation (Week 1)

These are the **must-complete** tasks before any real feature development. I'm aligning with the Phase 0 deadlines from the PDF but adding the missing critical tasks.

---

#### KELVIN's Tasks (Phase 0)

| # | Task | Description | Deliverable | Deadline |
|---|---|---|---|---|
| **K1** | **Project Scaffolding** | Initialize Node.js + TypeScript + Express project. Set up the full folder structure (see Section 4). Configure `tsconfig.json`, ESLint, Prettier, `.env.example`, `.gitignore`. Install all core dependencies. Create the health check endpoint `GET /api/health`. Set up global error handler middleware, standard API response format, Winston logger, CORS, Helmet, rate limiting. | Repo that runs `npm run dev`, hits `localhost:3000/api/health` and returns `{ success: true }`. All middleware configured. | **Day 1** |
| **K2** | **CI/CD + AWS Deployment** | Set up GitHub Actions: lint → type-check → test → build on every PR. Configure AWS deployment (Elastic Beanstalk or EC2). Set up environment variables on AWS. Verify auto-deploy on merge to `main`. | Working `.github/workflows/ci.yml` + `deploy.yml`. Deployed health check endpoint accessible on AWS. | **Day 2** |
| **K3** | **Swagger API Documentation Setup** | Install `swagger-jsdoc` + `swagger-ui-express`. Configure base Swagger spec (API title, version, auth scheme, base URL). Create `/api/docs` route. Write Swagger annotations for the health check endpoint as a template for the team. | Interactive Swagger UI at `/api/docs` with at least the health check documented. Share URL with Frontend team. | **Day 2** |
| **K4** | **Prisma ORM Setup** | Install Prisma. Get database connection string from DB team. Configure `prisma/schema.prisma` with the connection. Run `npx prisma db pull` to introspect the DB team's existing schema (or manually write models if they share the ER diagram). Generate Prisma client. Verify connection works. | Working `prisma/schema.prisma`, Prisma client generates without errors, can query the database. | **Day 3** |
| **K5** | **Frontend API Contract Meeting** | Meet with Frontend team. Agree on: (1) standard response format, (2) error code format, (3) auth header format (`Bearer <token>`), (4) how freshness score + GPS are sent, (5) QR code format, (6) push notification payload structure. Document everything. | Written API contract document shared with Frontend team. | **Day 3** |
| **K6** | **Price Recommendation Engine** | Build the pricing module. Fetch MOFA reference prices from the database (the `mofa_price_reference` table that the DB team manages). Implement the freshness-weighted formula: `ceiling = MOFA_price × (freshness_score / 100)`, `soft_floor = MOFA_price × 0.60`. Validate that farmer's listed price is between floor and ceiling. Return warning if below floor. | Working endpoints: `GET /api/pricing/recommend?crop=<type>&region=<region>&freshness=<score>`. Returns `{ ceiling, softFloor, mofaPrice }`. | **Day 8** |
| **K7** | **AWS S3 Image Upload Setup** | Create S3 bucket for produce images. Configure `multer` + `multer-s3` for image uploads. Build a reusable upload middleware. Set file size limit (5MB), allowed types (JPEG, PNG). Return S3 URL after upload. | Working upload middleware: `upload.single('image')`. Test upload returns S3 URL. | **Day 9** |

**Kelvin's ongoing responsibilities:**
- Code review every PR from Afia and Hanz (aim for <24hr review time)
- Coordinate with DB team on schema changes
- Coordinate with Frontend team on API contracts
- Unblock Afia and Hanz when they hit issues

---

#### AFIA's Tasks (Phase 0)

| # | Task | Description | Deliverable | Deadline |
|---|---|---|---|---|
| **A1** | **JWT Authentication System** | Build the complete auth module: (1) `POST /api/auth/register` — accept phone number, name, role (farmer/buyer/driver), hash password with bcrypt, save to Users table, send OTP via a stub SMS function (real Arkesel comes later from Hanz). (2) `POST /api/auth/verify-otp` — verify OTP code, activate account. (3) `POST /api/auth/login` — validate credentials, issue JWT access token (15 min) + refresh token (7 days). (4) `POST /api/auth/refresh` — issue new access token from valid refresh token. (5) `POST /api/auth/logout` — invalidate refresh token. | All 5 auth endpoints working. JWT tokens issued correctly. Passwords hashed. OTP works with a mock/stub (returns code in response for testing). | **Day 3** |
| **A2** | **Auth Middleware + Role Guards** | Build two middleware functions: (1) `authenticate` — extracts JWT from `Authorization: Bearer <token>` header, verifies signature, attaches user to `req.user`. (2) `authorize(...roles)` — checks if `req.user.role` is in the allowed roles list. Returns 403 if not. Apply to a test route to verify. | Working middleware: `router.get('/protected', authenticate, authorize('farmer', 'admin'), controller)`. Unauthorized requests get `401`/`403`. | **Day 4** |
| **A3** | **User Management Endpoints** | Build user profile endpoints for all 4 roles: (1) `GET /api/users/profile` — get own profile (any authenticated user). (2) `PATCH /api/users/profile` — update own profile. (3) Farmer-specific: include GPS location, farm region. (4) Buyer-specific: include business name, delivery address. (5) Driver-specific: include truck capacity (kg), operating region, availability status. (6) Add Zod validation schemas for all request bodies. | All profile endpoints working for all roles. Zod validation rejects bad input with clear error messages. Swagger annotations added. | **Day 6** |
| **A4** | **Admin User Approval System** | Build admin endpoints for user verification: (1) `GET /api/admin/users/pending` — list all users pending approval. (2) `PATCH /api/admin/users/:id/approve` — approve a user (admin only). (3) `PATCH /api/admin/users/:id/reject` — reject a user (admin only). Unapproved users can log in but cannot create listings, purchase, or accept jobs. | Admin can see pending registrations and approve/reject. Unapproved users get `403` on protected actions. | **Day 7** |
| **A5** | **Paystack Integration Setup** | Create Paystack developer account. Get sandbox API keys. Build the `PaystackService` wrapper class: (1) `initializeTransaction(amount, email, metadata)` — calls Paystack's Initialize Transaction API. (2) `verifyTransaction(reference)` — calls Paystack's Verify Transaction API. (3) `initiateTransfer(recipientCode, amount)` — calls Paystack's Transfer API (for releasing payment to farmer). Set up webhook endpoint `POST /api/payments/webhook` to receive Paystack callbacks. Test with sandbox. | Working `PaystackService` class. Sandbox payment can be initiated and verified. Webhook receives callbacks. Document the escrow flow. | **Day 8** |

**Afia's dependencies:**
- Needs K1 (scaffolding) done before starting A1
- Needs K4 (Prisma setup) done before starting A1 (needs Users table)
- A2 depends on A1 (needs JWT to exist)
- A3 depends on A2 (needs auth middleware)
- A4 depends on A2 + A3
- A5 is independent (only needs K1)

---

#### HANZ's Tasks (Phase 0)

| # | Task | Description | Deliverable | Deadline |
|---|---|---|---|---|
| **H1** | **Produce Listing CRUD** | Build the listing module: (1) `POST /api/listings` — farmer creates listing with crop type, quantity (kg), GPS coordinates, freshness score, shelf life days, price, optional image URL. Backend generates SHA-256 hash of listing data, generates QR code from hash, stores everything. Protected: farmer role only. (2) `GET /api/listings/:id` — get single listing with all details including QR code. (3) `GET /api/listings` — get own listings (farmer). (4) `PATCH /api/listings/:id` — update listing (farmer, own listings only). (5) `DELETE /api/listings/:id` — soft delete / mark as removed. Add Zod validation. | All 5 CRUD endpoints working. SHA-256 hash generated on creation. QR code generated and stored/returned. Swagger documented. | **Day 5** |
| **H2** | **Marketplace Browse & Filter** | Build the buyer-facing marketplace: (1) `GET /api/marketplace` — list all active listings with pagination (default 20/page). Support query params: `?crop=tomato&minFreshness=70&maxFreshness=100&region=accra&minQuantity=50&sort=freshness|price|date&order=asc|desc&page=1&limit=20`. Default sort: chronological (newest first). Each listing shows: freshness score, quantity, price, farmer region, crop type, listing age. (2) `GET /api/marketplace/:id` — detailed view of a single listing. | Marketplace endpoint with working filters, sorting, pagination. Returns proper response format. Swagger documented. | **Day 6** |
| **H3** | **Audit Trail System** | Build the tamper-proof audit trail: (1) Create `AuditService.log(eventType, entityId, data, userId)` — takes any event, SHA-256 hashes the data + timestamp + previous hash (hash chain), stores in Audit Trail table. Event types: `LISTING_CREATED`, `LISTING_UPDATED`, `PURCHASE_INITIATED`, `PAYMENT_HELD`, `DRIVER_DISPATCHED`, `DRIVER_ACCEPTED`, `DELIVERY_CONFIRMED`, `PAYMENT_RELEASED`. (2) `GET /api/audit/:transactionId` — public endpoint to verify the chain of custody for any transaction. Verifies all hashes in the chain are intact. | Working `AuditService` class that other modules can import and call. Verification endpoint validates hash chain integrity. | **Day 7** |
| **H4** | **QR Code Verification Endpoint** | Build the delivery verification flow: (1) `POST /api/verification/verify-qr` — receives the scanned QR code hash, looks up the original listing, compares hashes, confirms match. (2) On successful verification: mark listing as `DELIVERED`, log `DELIVERY_CONFIRMED` in audit trail, trigger payment release (call Afia's PaystackService). (3) Return verification result to the app. | Working endpoint. Hash comparison works. Integrates with audit trail and payment release. | **Day 8** |
| **H5** | **Arkesel SMS Service** | Build the shared SMS service: (1) Create Arkesel developer account, get API key. (2) Build `SmsService` wrapper class: `sendOtp(phoneNumber, code)`, `sendDriverNotification(phoneNumber, jobDetails)`, `sendGeneric(phoneNumber, message)`. (3) Integrate with Afia's auth module — replace OTP stub with real Arkesel calls. (4) Test: send a real SMS to a test number. | Working `SmsService` class. Real OTP SMS sent. Driver notification template ready. Integrated into auth flow. | **Day 9** |
| **H6** | **FCM Push Notification Service** | Build the push notification service: (1) Set up Firebase project, get service account key. (2) Build `NotificationService` wrapper class: `sendToDevice(fcmToken, title, body, data)`, `sendToTopic(topic, title, body, data)`. (3) Define notification types: `PURCHASE_NOTIFICATION` (farmer), `DRIVER_DISPATCHED` (buyer), `DRIVER_ACCEPTED` (buyer), `DELIVERY_CONFIRMED` (farmer + buyer), `FRESHNESS_ALERT` (farmer). (4) Test: send a test notification. | Working `NotificationService` class. Test notification received. Notification type templates defined. | **Day 9** |

**Hanz's dependencies:**
- Needs K1 (scaffolding) done before starting anything
- Needs K4 (Prisma setup) done before H1 (needs Listings table)
- Needs A2 (auth middleware) done before H1 (listings are protected by farmer role)
- H2 depends on H1 (marketplace reads listings)
- H3 is semi-independent (can start the service class without other modules)
- H4 depends on H1 + H3 + A5 (needs listings, audit, and payment)
- H5 is independent (only needs K1 + Arkesel API key)
- H6 is independent (only needs K1 + Firebase credentials)

---

### Phase 1 — Core Transactions (Week 2)

Once Phase 0 foundation is complete, build the transaction flow:

| # | Task | Owner | Description | Depends On |
|---|---|---|---|---|
| **K8** | **Driver Dispatch Module** | Kelvin | Build driver matching: find nearest available driver with sufficient truck capacity. Send job notification via FCM + SMS. Handle accept/decline. Auto-reassign on decline (next nearest driver). Endpoints: `POST /api/dispatch/assign`, `PATCH /api/dispatch/:jobId/accept`, `PATCH /api/dispatch/:jobId/decline`. | A2, H5, H6 |
| **A6** | **Purchase & Escrow Flow** | Afia | Build the full purchase flow: (1) `POST /api/transactions/purchase` — buyer selects listing, pays via Paystack, funds held. (2) Ask buyer: "Do you have transport?" → yes: notify farmer; no: trigger driver dispatch. (3) `POST /api/transactions/:id/confirm-delivery` — on QR verification, release funds to farmer via Paystack transfer. Log everything in audit trail. | A5, H1, H3, H4, K8 |
| **H7** | **Transaction History & Dashboard Data** | Hanz | Build endpoints: (1) `GET /api/transactions` — user's transaction history (role-aware). (2) `GET /api/transactions/:id` — transaction details. (3) `GET /api/admin/transactions` — all transactions (admin). (4) `GET /api/admin/dashboard/stats` — summary stats (total transactions, active listings, registered users, revenue). | A6 |

### Phase 2 — Admin & Alerts (Week 3)

| # | Task | Owner | Description | Depends On |
|---|---|---|---|---|
| **K9** | **MOFA Price Admin CRUD** | Kelvin | Build admin endpoints for managing MOFA reference prices: `GET /api/admin/mofa-prices`, `POST /api/admin/mofa-prices`, `PATCH /api/admin/mofa-prices/:id`, `DELETE /api/admin/mofa-prices/:id`. Include crop type, region, price, effective date. Support CSV bulk upload for weekly price bulletins. | A2 (admin role) |
| **A7** | **Dispute Resolution System** | Afia | Build: `POST /api/disputes` (any user), `GET /api/admin/disputes` (admin), `PATCH /api/admin/disputes/:id/resolve` (admin). Include dispute types: wrong produce, non-delivery, payment issue. Link to transaction and audit trail. | A6, H3 |
| **H8** | **Freshness Alert Scheduler** | Hanz | Build a `node-cron` job that runs every 6 hours: queries all unsold listings, calculates projected freshness decay, sends push notification to farmers whose produce is projected to drop below threshold within 48 hours. | H1, H6, K6 |

### Phase 3 — Polish & Testing (Week 4)

| # | Task | Owner | Description | Depends On |
|---|---|---|---|---|
| **K10** | **Integration Testing Suite** | Kelvin | Write end-to-end tests for the critical flows: register → verify → login → list produce → buy → dispatch driver → verify QR → release payment. Use Jest + Supertest. Target 80% coverage on service layer. | All modules |
| **A8** | **Security Hardening** | Afia | Audit all endpoints: verify auth middleware on every protected route. Add rate limiting to auth endpoints (5 req/min). Validate all Paystack webhooks with signature verification. Ensure no sensitive data in logs. HTTPS enforcement. | All modules |
| **H9** | **Complete Swagger Documentation** | Hanz | Ensure every single endpoint has Swagger annotations with: description, request schema, response schema (success + error), auth requirements, example payloads. Generate and share Postman collection export from Swagger. | All modules |

---

## 4. Project Folder Structure

```
agriconnect-backend/
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Lint + type-check + test on every PR
│       └── deploy.yml             # Deploy to AWS on merge to main
├── src/
│   ├── config/
│   │   ├── env.ts                 # Zod-validated environment variables
│   │   ├── database.ts            # Prisma client singleton
│   │   ├── paystack.ts            # Paystack config
│   │   ├── arkesel.ts             # Arkesel SMS config
│   │   ├── firebase.ts            # FCM config
│   │   └── s3.ts                  # AWS S3 config
│   ├── middleware/
│   │   ├── authenticate.ts        # JWT verification         [Afia]
│   │   ├── authorize.ts           # Role-based access guard   [Afia]
│   │   ├── validate.ts            # Zod validation wrapper    [Afia]
│   │   ├── errorHandler.ts        # Global error handler      [Kelvin]
│   │   ├── rateLimiter.ts         # Rate limiting             [Kelvin]
│   │   └── upload.ts              # Multer + S3 upload        [Kelvin]
│   ├── modules/
│   │   ├── auth/                  # [Afia]
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.routes.ts
│   │   │   └── auth.schema.ts     # Zod schemas
│   │   ├── user/                  # [Afia]
│   │   │   ├── user.controller.ts
│   │   │   ├── user.service.ts
│   │   │   ├── user.routes.ts
│   │   │   └── user.schema.ts
│   │   ├── listing/               # [Hanz]
│   │   │   ├── listing.controller.ts
│   │   │   ├── listing.service.ts
│   │   │   ├── listing.routes.ts
│   │   │   └── listing.schema.ts
│   │   ├── marketplace/           # [Hanz]
│   │   │   ├── marketplace.controller.ts
│   │   │   ├── marketplace.service.ts
│   │   │   ├── marketplace.routes.ts
│   │   │   └── marketplace.schema.ts
│   │   ├── pricing/               # [Kelvin]
│   │   │   ├── pricing.controller.ts
│   │   │   ├── pricing.service.ts
│   │   │   ├── pricing.routes.ts
│   │   │   └── pricing.schema.ts
│   │   ├── payment/               # [Afia]
│   │   │   ├── payment.controller.ts
│   │   │   ├── payment.service.ts
│   │   │   ├── payment.routes.ts
│   │   │   └── payment.schema.ts
│   │   ├── dispatch/              # [Kelvin]
│   │   │   ├── dispatch.controller.ts
│   │   │   ├── dispatch.service.ts
│   │   │   ├── dispatch.routes.ts
│   │   │   └── dispatch.schema.ts
│   │   ├── audit/                 # [Hanz]
│   │   │   ├── audit.controller.ts
│   │   │   ├── audit.service.ts
│   │   │   ├── audit.routes.ts
│   │   │   └── audit.schema.ts
│   │   ├── verification/          # [Hanz]
│   │   │   ├── verification.controller.ts
│   │   │   ├── verification.service.ts
│   │   │   └── verification.routes.ts
│   │   └── admin/                 # [Kelvin + Afia]
│   │       ├── admin.controller.ts
│   │       ├── admin.service.ts
│   │       ├── admin.routes.ts
│   │       └── admin.schema.ts
│   ├── services/                  # Shared external service wrappers
│   │   ├── sms.service.ts         # Arkesel SMS wrapper       [Hanz]
│   │   ├── notification.service.ts # FCM wrapper              [Hanz]
│   │   └── payment.service.ts     # Paystack wrapper          [Afia]
│   ├── utils/
│   │   ├── hash.ts                # SHA-256 hashing           [Hanz]
│   │   ├── qrcode.ts              # QR code generation        [Hanz]
│   │   ├── response.ts            # Standard API response helpers
│   │   └── errors.ts              # Custom error classes      [Kelvin]
│   ├── app.ts                     # Express app setup         [Kelvin]
│   └── server.ts                  # Server entry point        [Kelvin]
├── prisma/
│   └── schema.prisma              # DB team's schema via Prisma [Kelvin sets up]
├── tests/                         # Mirrors src/modules/
│   ├── auth.test.ts
│   ├── listing.test.ts
│   └── ...
├── .env.example
├── .eslintrc.js
├── .prettierrc
├── tsconfig.json
├── jest.config.ts
├── package.json
└── README.md
```

---

## 5. Phase 0 Day-by-Day Schedule (Week 1)

| Date | Kelvin | Afia | Hanz |
|---|---|---|---|
| **Day 1** | **K1:** Scaffolding — full project setup, all middleware, health check, push to GitHub | 📖 Study JWT patterns, review auth requirements in SRS + User Flow doc | 📖 Study listing requirements, SHA-256/QR code patterns, review User Flow doc |
| **Day 2** | **K2:** CI/CD pipeline + AWS deployment **K3:** Swagger setup | 📖 Study Zod validation, review Prisma schema (from Kelvin's K4) | 📖 Study Arkesel SMS API docs, FCM docs |
| **Day 3** | **K4:** Prisma ORM setup + DB connection **K5:** Frontend API contract meeting | **A1:** JWT auth system (register, login, OTP stub, refresh, logout) | Wait for K4 (Prisma) + start **H3** audit trail service class (no DB needed for the utility) |
| **Day 4** | 🔍 Code review A1 (auth) | **A2:** Auth middleware + role guards | **H3** continued: finish AuditService class |
| **Day 5** | 🔍 Code review A2 + H1 | 📖 Research Paystack API, plan escrow flow | **H1:** Produce listing CRUD + SHA-256 + QR code |
| **Day 6** | 🔍 Code review A3 + H2 | **A3:** User management endpoints (4 roles) + Zod validation | **H2:** Marketplace browse + filter |
| **Day 7** | 🔍 Code review A4 + H3 | **A4:** Admin user approval system | **H3:** Audit trail verification endpoint (plug service into route + DB) |
| **Day 8** | **K6:** Price recommendation engine + MOFA DB | **A5:** Paystack integration setup + sandbox test | **H4:** QR code verification endpoint |
| **Day 9** | **K7:** AWS S3 image upload setup + 🔍 code reviews | 📖 Plan purchase flow for Phase 1 | **H5:** Arkesel SMS service + **H6:** FCM notification service |
| **Friday** | 📋 **Check-in: demo all progress, raise blockers, plan Phase 1** | 📋 **Check-in** | 📋 **Check-in** |

---

## 6. Task Ownership Summary

### By Person — What You're Each Responsible For

#### Kelvin (7 Phase 0 tasks + 3 later)

| Phase | Tasks | What You Own |
|---|---|---|
| Phase 0 | K1, K2, K3, K4, K5, K6, K7 | Scaffolding, CI/CD, AWS, Swagger, Prisma, pricing engine, S3 uploads |
| Phase 1 | K8 | Driver dispatch module |
| Phase 2 | K9 | MOFA price admin CRUD |
| Phase 3 | K10 | Integration testing suite |
| Ongoing | — | All code reviews, DB team coordination, Frontend coordination, unblocking |

#### Afia (5 Phase 0 tasks + 3 later)

| Phase | Tasks | What You Own |
|---|---|---|
| Phase 0 | A1, A2, A3, A4, A5 | Auth, middleware, user management, admin approval, Paystack |
| Phase 1 | A6 | Purchase & escrow flow |
| Phase 2 | A7 | Dispute resolution |
| Phase 3 | A8 | Security hardening |

#### Hanz (6 Phase 0 tasks + 3 later)

| Phase | Tasks | What You Own |
|---|---|---|
| Phase 0 | H1, H2, H3, H4, H5, H6 | Listings, marketplace, audit trail, QR verification, SMS, push notifications |
| Phase 1 | H7 | Transaction history + dashboard data |
| Phase 2 | H8 | Freshness alert scheduler |
| Phase 3 | H9 | Complete Swagger documentation |

---

## 7. Git Workflow

### Branching Strategy

```
main (protected — deployable to AWS production)
  └── dev (integration branch)
       ├── feature/K1-scaffolding          [Kelvin]
       ├── feature/K2-cicd-aws             [Kelvin]
       ├── feature/A1-jwt-auth             [Afia]
       ├── feature/A2-auth-middleware      [Afia]
       ├── feature/H1-listing-crud         [Hanz]
       ├── feature/H3-audit-trail          [Hanz]
       ├── fix/otp-verification-bug        [whoever]
       └── chore/update-swagger-docs       [whoever]
```

### Rules

1. **Never push directly to `main` or `dev`** — always use Pull Requests
2. Branch naming: `feature/<task-id>-<short-name>`, `fix/<description>`, `chore/<description>`
3. Every PR needs **at least 1 approval** from Kelvin (as Lead)
4. PRs must pass CI checks (lint, type-check, tests)
5. Squash merge to keep history clean
6. Delete branch after merge

### Commit Messages (Conventional Commits)

```
feat(auth): implement OTP verification endpoint
fix(listing): handle null GPS coordinates
docs(swagger): add marketplace endpoint annotations
test(payment): add Paystack webhook integration test
chore(deps): update Prisma to v6.x
```

### Code Review Checklist

When reviewing PRs, Kelvin checks:
- [ ] Follows the agreed folder structure?
- [ ] Has Zod validation schemas for all request bodies?
- [ ] Has proper error handling (try-catch, custom errors)?
- [ ] Auth middleware applied to protected routes?
- [ ] Audit trail logging for important actions?
- [ ] Swagger annotations added?
- [ ] No API keys or secrets in code?
- [ ] At least 1 test for new functionality?

---

## 8. Communication Plan

| Channel | Purpose | Frequency |
|---|---|---|
| **WhatsApp/Telegram Group** | Quick questions, blockers, daily updates | Daily |
| **GitHub Issues** | Track tasks (create one issue per K/A/H task) | Ongoing |
| **GitHub Project Board** | Kanban: To Do → In Progress → Review → Done | Update daily |
| **Friday Check-in** | Demo progress, raise blockers, plan next week | Weekly (per Phase 0 PDF) |
| **Swagger UI** | Share with Frontend team as living API documentation | Always available |

---

## 9. Key Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| DB team delivers schema late → blocks Afia (Day 3) and Hanz (Day 5) | 🔴 Critical | Kelvin: contact DB team **before Day 1**. If delayed, create a temporary local schema to unblock development. |
| Paystack doesn't support true escrow for Ghana Mobile Money | 🔴 Critical | Afia: research this during Day 5–7 (before A5 on Day 8). Fallback: use Paystack Transfers (platform receives payment → manually transfers to farmer on delivery). |
| Afia needs OTP via SMS on Day 3, but Hanz's Arkesel task is Day 9 | 🟡 Medium | Afia: build a stub that returns OTP in the API response for testing. Hanz replaces with real Arkesel on Day 9. |
| AWS setup takes longer than 1 day | 🟡 Medium | Kelvin: if Elastic Beanstalk is complex, start with a simple EC2 instance + PM2. Optimize later. |
| Team member gets stuck on a task | 🟡 Medium | Daily WhatsApp check-in. Kelvin unblocks within 4 hours. Pair programming if needed. |
