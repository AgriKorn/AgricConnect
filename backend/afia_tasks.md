# Afia — Your Week 1 Tasks (AgriConnect Backend)

**Your role:** Authentication, User Management & Payments
**Stack:** Node.js · Express.js · TypeScript · Prisma
**Branch from:** `dev`
**PR to:** `dev` (Kelvin reviews)

---

## How to Get Started

1. **Day 1–2:** Kelvin is setting up the project. Use this time to:
   - Study how JWT works: access tokens, refresh tokens, token expiry
   - Read the Prisma docs: https://www.prisma.io/docs
   - Read the Zod docs: https://zod.dev
   - Read the AgriConnect SRS and User Flow documents so you understand the auth flow
   - Install Node.js and VS Code on your machine if not already done

2. **Day 3:** Kelvin will push the project to GitHub. He'll share the repo link. Then:
   ```bash
   git clone <repo-url>
   cd agriconnect-backend
   npm install
   cp .env.example .env        # Fill in your local values
   npm run dev                  # Should show "Server running on port 3000"
   ```

3. **Before starting each task**, create a branch:
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/A1-jwt-auth    # Use the task ID in the branch name
   ```

4. **When done**, push and create a PR:
   ```bash
   git add .
   git commit -m "feat(auth): implement JWT authentication system"
   git push origin feature/A1-jwt-auth
   ```
   Then go to GitHub → create Pull Request → base: `dev` → Kelvin will review.

---

## Task A1 — JWT Authentication System

**Deadline: Day 3**
**Branch name:** `feature/A1-jwt-auth`
**Depends on:** Kelvin's project setup (K1) and Prisma setup (K3) must be done first

### What You're Building

The authentication system for AgriConnect. Users register with their phone number, verify via OTP, then log in with JWT tokens.

### Files to Create

```
src/modules/auth/
├── auth.controller.ts    ← Handles HTTP requests/responses
├── auth.service.ts       ← Business logic (hashing, token generation, DB queries)
├── auth.routes.ts        ← Defines the routes
└── auth.schema.ts        ← Zod validation schemas
```

### Endpoint 1: `POST /api/auth/register`

**What it does:** A new user signs up as a farmer, buyer, or driver.

**Request body:**
```json
{
  "name": "Kwame Asante",
  "phone": "+233241234567",
  "password": "mypassword123",
  "role": "farmer"
}
```

**What the code should do (step by step):**
1. Validate the request body with Zod (name required, phone required in Ghana format, password min 6 chars, role must be one of: `farmer`, `buyer`, `driver`)
2. Check if a user with this phone number already exists → if yes, return error `"Phone number already registered"`
3. Hash the password using `bcryptjs`:
   ```typescript
   import bcrypt from 'bcryptjs';
   const hashedPassword = await bcrypt.hash(password, 10);
   ```
4. Generate a 6-digit OTP code:
   ```typescript
   const otp = Math.floor(100000 + Math.random() * 900000).toString();
   ```
5. Set OTP expiry to 5 minutes from now:
   ```typescript
   const otpExpiry = new Date(Date.now() + 5 * 60 * 1000);
   ```
6. Save the user to the database with Prisma:
   ```typescript
   const user = await prisma.user.create({
     data: {
       name,
       phone,
       password: hashedPassword,
       role,
       otp,
       otpExpiry,
       status: 'PENDING_OTP',    // Not verified yet
     }
   });
   ```
7. **For now:** Return the OTP in the response (this is temporary — Hanz will replace this with real SMS via Arkesel on Day 9). In production we would NEVER return the OTP in the response.

**Success response (201):**
```json
{
  "success": true,
  "data": {
    "message": "Registration successful. Please verify your OTP.",
    "userId": "uuid-here",
    "otp": "482916"
  }
}
```
> ⚠️ The `otp` field is temporary for testing. We'll remove it when Hanz connects Arkesel SMS.

**Error response (409):**
```json
{
  "success": false,
  "error": {
    "code": "PHONE_ALREADY_EXISTS",
    "message": "Phone number already registered"
  }
}
```

### Endpoint 2: `POST /api/auth/verify-otp`

**What it does:** User enters the OTP they received to verify their phone number.

**Request body:**
```json
{
  "phone": "+233241234567",
  "otp": "482916"
}
```

**What the code should do:**
1. Find the user by phone number
2. Check the OTP matches what's stored in the database
3. Check the OTP hasn't expired (`otpExpiry > now`)
4. If valid: update user status to `PENDING_APPROVAL` and clear the OTP fields
5. If invalid: return error

**Why `PENDING_APPROVAL` and not `ACTIVE`?** Because the AgriConnect User Flow says: *"the admin reviews and approves the account before that user gains any platform access."* So after OTP, the user waits for admin approval. Kelvin or you will build the admin approval endpoint later (Task A3).

**Success response (200):**
```json
{
  "success": true,
  "data": {
    "message": "Phone number verified. Your account is pending admin approval."
  }
}
```

**Error responses:**
- OTP doesn't match → `400` with `"Invalid OTP"`
- OTP expired → `400` with `"OTP has expired. Please request a new one."`
- User not found → `404` with `"User not found"`

### Endpoint 3: `POST /api/auth/login`

**What it does:** A verified user logs in and gets JWT tokens.

**Request body:**
```json
{
  "phone": "+233241234567",
  "password": "mypassword123"
}
```

**What the code should do:**
1. Find user by phone number
2. Compare password with bcrypt:
   ```typescript
   const isMatch = await bcrypt.compare(password, user.password);
   ```
3. If password doesn't match → return `401 Invalid credentials`
4. If user status is `PENDING_OTP` → return `403 Please verify your phone number first`
5. If user status is `PENDING_APPROVAL` → **still allow login** but include a flag so the frontend knows they can't transact yet
6. Generate JWT access token (15 minute expiry):
   ```typescript
   import jwt from 'jsonwebtoken';

   const accessToken = jwt.sign(
     { userId: user.id, role: user.role },
     process.env.JWT_SECRET!,
     { expiresIn: '15m' }
   );
   ```
7. Generate refresh token (7 day expiry):
   ```typescript
   const refreshToken = jwt.sign(
     { userId: user.id },
     process.env.JWT_REFRESH_SECRET!,
     { expiresIn: '7d' }
   );
   ```
8. Save the refresh token in the database (so we can invalidate it on logout)
9. Return both tokens + user info

**Success response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid-here",
      "name": "Kwame Asante",
      "phone": "+233241234567",
      "role": "farmer",
      "status": "PENDING_APPROVAL",
      "isApproved": false
    }
  }
}
```

### Endpoint 4: `POST /api/auth/refresh`

**What it does:** Get a new access token using a valid refresh token (when the 15-min access token expires).

**Request body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**What the code should do:**
1. Verify the refresh token with `jwt.verify()`
2. Check the refresh token exists in the database (it wasn't logged out)
3. Generate a new access token
4. Return it

**Success response (200):**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

### Endpoint 5: `POST /api/auth/logout`

**Request body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**What the code should do:**
1. Delete the refresh token from the database
2. Return success

**Success response (200):**
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

### Zod Schemas (auth.schema.ts)

```typescript
import { z } from 'zod';

export const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  phone: z.string().regex(/^\+233\d{9}$/, 'Phone must be a valid Ghana number (+233XXXXXXXXX)'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  role: z.enum(['farmer', 'buyer', 'driver']),
});

export const verifyOtpSchema = z.object({
  phone: z.string().regex(/^\+233\d{9}$/),
  otp: z.string().length(6, 'OTP must be 6 digits'),
});

export const loginSchema = z.object({
  phone: z.string().regex(/^\+233\d{9}$/),
  password: z.string().min(1, 'Password is required'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});
```

### Routes File (auth.routes.ts)

```typescript
import { Router } from 'express';
import { register, verifyOtp, login, refresh, logout } from './auth.controller';
import { validate } from '../../middleware/validate';
import { registerSchema, verifyOtpSchema, loginSchema, refreshSchema } from './auth.schema';

const router = Router();

router.post('/register', validate(registerSchema), register);
router.post('/verify-otp', validate(verifyOtpSchema), verifyOtp);
router.post('/login', validate(loginSchema), login);
router.post('/refresh', validate(refreshSchema), refresh);
router.post('/logout', logout);

export default router;
```

---

## Task A2 — Auth Middleware & Role Guards

**Deadline: Day 4**
**Branch name:** `feature/A2-auth-middleware`
**Depends on:** A1 must be done (needs JWT to exist)

### Files to Create

```
src/middleware/
├── authenticate.ts     ← JWT verification
├── authorize.ts        ← Role checking
└── validate.ts         ← Zod validation (if not already created in A1)
```

### authenticate.ts — What It Does

This middleware runs BEFORE any protected route. It checks if the user sent a valid JWT token.

**How the frontend will send the token:**
```
GET /api/listings
Headers:
  Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**What your middleware does:**
1. Get the `Authorization` header from the request
2. Check it starts with `Bearer `
3. Extract the token (everything after `Bearer `)
4. Verify it with `jwt.verify(token, JWT_SECRET)`
5. If valid: attach the decoded user info to `req.user` and call `next()`
6. If invalid/missing: return `401 Unauthorized`

```typescript
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

// Extend Express Request to include user
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        role: string;
      };
    }
  }
}

export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'Access token is required' }
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string; role: string };
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      error: { code: 'INVALID_TOKEN', message: 'Access token is invalid or expired' }
    });
  }
};
```

### authorize.ts — What It Does

This middleware checks if the logged-in user has the right role to access a route.

```typescript
import { Request, Response, NextFunction } from 'express';

export const authorize = (...allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required' }
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'You do not have permission to access this resource' }
      });
    }

    next();
  };
};
```

**How Kelvin and Hanz will use your middleware in their routes:**
```typescript
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';

// Only farmers can create listings
router.post('/listings', authenticate, authorize('farmer'), createListing);

// Only admins can approve users
router.patch('/admin/users/:id/approve', authenticate, authorize('admin'), approveUser);

// Any authenticated user can view the marketplace
router.get('/marketplace', authenticate, getMarketplace);
```

---

## Task A3 — User Management Endpoints

**Deadline: Day 6**
**Branch name:** `feature/A3-user-management`
**Depends on:** A2 must be done (needs auth middleware)

### Files to Create

```
src/modules/user/
├── user.controller.ts
├── user.service.ts
├── user.routes.ts
└── user.schema.ts
```

### Endpoints to Build

**`GET /api/users/profile`** — Get your own profile
- Protected: `authenticate` (any logged-in user)
- Get the user's ID from `req.user.userId`
- Query the database for their full profile including role-specific data
- Return user info (never return the password hash)

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Kwame Asante",
    "phone": "+233241234567",
    "role": "farmer",
    "status": "ACTIVE",
    "createdAt": "2026-07-03T10:00:00Z",
    "profile": {
      "farmRegion": "Ashanti",
      "gpsLatitude": 6.6885,
      "gpsLongitude": -1.6244
    }
  }
}
```

**`PATCH /api/users/profile`** — Update your own profile
- Protected: `authenticate`
- Only allow updating: `name`, and role-specific fields
- Never allow changing: `phone`, `role`, `status` (those are admin-controlled)
- Validate with Zod

**Request body (farmer example):**
```json
{
  "name": "Kwame Asante Jr.",
  "farmRegion": "Brong Ahafo",
  "gpsLatitude": 7.9527,
  "gpsLongitude": -1.6781
}
```

**Request body (driver example):**
```json
{
  "name": "Kofi Mensah",
  "truckCapacity": 5000,
  "operatingRegion": "Greater Accra",
  "isAvailable": true
}
```

### Zod Schemas (user.schema.ts)

```typescript
import { z } from 'zod';

export const updateFarmerProfileSchema = z.object({
  name: z.string().min(2).optional(),
  farmRegion: z.string().optional(),
  gpsLatitude: z.number().min(-90).max(90).optional(),
  gpsLongitude: z.number().min(-180).max(180).optional(),
});

export const updateBuyerProfileSchema = z.object({
  name: z.string().min(2).optional(),
  businessName: z.string().optional(),
  deliveryAddress: z.string().optional(),
});

export const updateDriverProfileSchema = z.object({
  name: z.string().min(2).optional(),
  truckCapacity: z.number().positive('Truck capacity must be positive').optional(),
  operatingRegion: z.string().optional(),
  isAvailable: z.boolean().optional(),
});
```

---

## Task A4 — Paystack Setup

**Deadline: Day 8**
**Branch name:** `feature/A4-paystack-setup`
**Depends on:** Only K1 (scaffolding). This is independent — you can start early if other tasks are done.

### Step 1 — Create Paystack Account

1. Go to https://dashboard.paystack.com
2. Sign up (use your email)
3. You'll be in **test mode** by default — this is what we want
4. Go to Settings → API Keys → copy your **Test Secret Key** (starts with `sk_test_`)
5. Add it to your `.env`: `PAYSTACK_SECRET_KEY=sk_test_xxxxx`

### Step 2 — Build the PaystackService

Create `src/services/payment.service.ts`:

```typescript
import axios from 'axios';

class PaystackService {
  private baseUrl = 'https://api.paystack.co';
  private secretKey = process.env.PAYSTACK_SECRET_KEY!;

  private get headers() {
    return {
      Authorization: `Bearer ${this.secretKey}`,
      'Content-Type': 'application/json',
    };
  }

  // Step 1: Buyer pays → money goes to Paystack (our platform account)
  async initializeTransaction(amount: number, email: string, metadata: object) {
    // amount is in pesewas (GHS 10 = 1000 pesewas)
    const response = await axios.post(`${this.baseUrl}/transaction/initialize`, {
      amount: amount * 100,  // Convert GHS to pesewas
      email,
      currency: 'GHS',
      metadata,
      // For mobile money:
      channels: ['mobile_money'],
    }, { headers: this.headers });

    return response.data;
  }

  // Step 2: Verify the payment was successful
  async verifyTransaction(reference: string) {
    const response = await axios.get(
      `${this.baseUrl}/transaction/verify/${reference}`,
      { headers: this.headers }
    );
    return response.data;
  }

  // Step 3: Register the farmer as a transfer recipient
  async createTransferRecipient(name: string, accountNumber: string, bankCode: string) {
    const response = await axios.post(`${this.baseUrl}/transferrecipient`, {
      type: 'mobile_money',
      name,
      account_number: accountNumber,
      bank_code: bankCode,  // MTN = "MTN", Vodafone = "VOD"
      currency: 'GHS',
    }, { headers: this.headers });

    return response.data;
  }

  // Step 4: Send money to the farmer (after delivery is confirmed)
  async initiateTransfer(recipientCode: string, amount: number, reason: string) {
    const response = await axios.post(`${this.baseUrl}/transfer`, {
      source: 'balance',
      amount: amount * 100,
      recipient: recipientCode,
      reason,
      currency: 'GHS',
    }, { headers: this.headers });

    return response.data;
  }
}

export default new PaystackService();
```

### Step 3 — Build the Webhook Endpoint

Paystack sends notifications to your server when payments happen. Create the webhook endpoint:

Create `src/modules/payment/payment.routes.ts`:
```typescript
router.post('/api/payments/webhook', handlePaystackWebhook);
```

In the controller:
```typescript
import crypto from 'crypto';

const handlePaystackWebhook = (req: Request, res: Response) => {
  // Verify webhook is really from Paystack
  const hash = crypto
    .createHmac('sha512', process.env.PAYSTACK_SECRET_KEY!)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (hash !== req.headers['x-paystack-signature']) {
    return res.status(401).json({ message: 'Invalid signature' });
  }

  const event = req.body;

  if (event.event === 'charge.success') {
    // Payment was successful — hold the money (don't transfer to farmer yet)
    console.log('Payment received:', event.data.reference);
    // TODO: Update transaction status in database to "PAYMENT_HELD"
  }

  res.status(200).json({ received: true });
};
```

### Step 4 — Test It

1. Use Paystack's test mode
2. Call `initializeTransaction` with a test amount
3. Paystack returns an `authorization_url` — open it in a browser
4. Use test card numbers from Paystack docs to simulate payment
5. Check if your webhook receives the callback

### How the Escrow Flow Works (Document This)

```
1. Buyer clicks "Purchase" → Frontend calls our API
2. Our API calls Paystack initializeTransaction → Paystack returns payment URL
3. Buyer pays via Mobile Money → Money goes to OUR Paystack balance (not the farmer's)
4. Paystack sends webhook → We update transaction status to "PAYMENT_HELD"
5. ... delivery happens ... QR code scanned ...
6. Our API calls Paystack initiateTransfer → Money moves from our balance to farmer's Mobile Money
7. Done!
```

**Deliverable:** Working PaystackService class. Can make a test payment in sandbox. Webhook receives callbacks. Write a short document explaining the escrow flow above.

---

## Questions? 

If you're stuck on something:
1. Check the project README first
2. Check the Prisma docs (for database queries)
3. Check the Paystack docs: https://paystack.com/docs/api
4. Ask in the group chat — Kelvin will help
5. If it's a code issue, push what you have and create a **Draft PR** so Kelvin can see your code and help
