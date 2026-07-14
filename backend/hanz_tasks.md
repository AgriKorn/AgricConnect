# Hanz — Your Week 1 Tasks (AgriConnect Backend)

**Your role:** Listings, Marketplace, Audit Trail & External Integrations
**Stack:** Node.js · Express.js · TypeScript · Prisma
**Branch from:** `dev`
**PR to:** `dev` (Kelvin reviews)

---

## How to Get Started

1. **Day 1–2:** Kelvin is setting up the project. Use this time to:
   - Study how SHA-256 hashing works in Node.js (`crypto` module)
   - Study how QR codes are generated (`qrcode` npm package)
   - Read the Arkesel SMS API docs: https://developers.arkesel.com
   - Read the Firebase Cloud Messaging docs: https://firebase.google.com/docs/cloud-messaging
   - Read the AgriConnect SRS and User Flow documents carefully — especially the Farmer and Buyer flows
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
   git checkout -b feature/H1-listing-crud    # Use the task ID
   ```

4. **When done**, push and create a PR:
   ```bash
   git add .
   git commit -m "feat(listing): implement produce listing CRUD with SHA-256 and QR"
   git push origin feature/H1-listing-crud
   ```
   Then go to GitHub → create Pull Request → base: `dev` → Kelvin reviews.

---

## Task H1 — Produce Listing CRUD + SHA-256 Hash + QR Code

**Deadline: Day 5**
**Branch name:** `feature/H1-listing-crud`
**Depends on:** Kelvin's K1 (setup) + K3 (Prisma) + Afia's A2 (auth middleware)

> You can start writing the service logic and utility functions on Day 3–4 while waiting for Afia's auth middleware. The SHA-256 and QR code utilities don't depend on anything.

### What You're Building

When a farmer creates a listing, the system:
1. Saves the listing data to the database
2. Generates a **SHA-256 hash** of the listing (this proves the listing hasn't been tampered with)
3. Generates a **QR code** from that hash (the farmer shows this QR code when the buyer comes to collect)

### Files to Create

```
src/modules/listing/
├── listing.controller.ts    ← Handles HTTP requests/responses
├── listing.service.ts       ← Business logic
├── listing.routes.ts        ← Route definitions
└── listing.schema.ts        ← Zod validation schemas

src/utils/
├── hash.ts                  ← SHA-256 hashing function
└── qrcode.ts                ← QR code generation function
```

### First — Build the Utility Functions

#### src/utils/hash.ts

```typescript
import crypto from 'crypto';

/**
 * Generates a SHA-256 hash of the given data.
 * Used for listing verification and audit trail.
 */
export const generateHash = (data: object): string => {
  const jsonString = JSON.stringify(data);
  return crypto.createHash('sha256').update(jsonString).digest('hex');
};

/**
 * Verifies that a hash matches the given data.
 */
export const verifyHash = (data: object, hash: string): boolean => {
  const computedHash = generateHash(data);
  return computedHash === hash;
};
```

#### src/utils/qrcode.ts

```typescript
import QRCode from 'qrcode';

/**
 * Generates a QR code as a base64 data URL from a string (the SHA-256 hash).
 * The frontend will display this as an image.
 */
export const generateQRCode = async (data: string): Promise<string> => {
  try {
    const qrCodeDataUrl = await QRCode.toDataURL(data, {
      width: 300,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#ffffff',
      },
    });
    return qrCodeDataUrl;
  } catch (error) {
    throw new Error('Failed to generate QR code');
  }
};
```

### Endpoint 1: `POST /api/listings` (Farmer Only)

**What it does:** A farmer creates a new produce listing.

**Protected by:** `authenticate` + `authorize('farmer')` (from Afia's middleware)

**Request body:**
```json
{
  "cropType": "tomato",
  "quantity": 500,
  "gpsLatitude": 6.6885,
  "gpsLongitude": -1.6244,
  "freshnessScore": 85,
  "shelfLifeDays": 5,
  "price": 150.00,
  "imageUrl": "https://s3.amazonaws.com/..."
}
```

**What the code should do (step by step):**

1. Validate request body with Zod
2. Get the farmer's ID from `req.user.userId` (set by Afia's authenticate middleware)
3. Generate the SHA-256 hash of the listing data:
   ```typescript
   import { generateHash } from '../../utils/hash';

   const hashData = {
     cropType,
     quantity,
     freshnessScore,
     farmerId: req.user.userId,
     timestamp: new Date().toISOString(),
   };
   const listingHash = generateHash(hashData);
   ```
4. Generate the QR code from the hash:
   ```typescript
   import { generateQRCode } from '../../utils/qrcode';

   const qrCode = await generateQRCode(listingHash);
   ```
5. Save to database with Prisma:
   ```typescript
   const listing = await prisma.listing.create({
     data: {
       farmerId: req.user.userId,
       cropType,
       quantity,
       gpsLatitude,
       gpsLongitude,
       freshnessScore,
       shelfLifeDays,
       price,
       imageUrl,
       listingHash,
       qrCode,
       status: 'ACTIVE',
       createdAt: new Date(),
     },
   });
   ```
6. Log to audit trail (if H3 is ready — otherwise add a TODO comment):
   ```typescript
   // TODO: AuditService.log('LISTING_CREATED', listing.id, hashData, req.user.userId);
   ```
7. Return the created listing

**Success response (201):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-here",
    "cropType": "tomato",
    "quantity": 500,
    "gpsLatitude": 6.6885,
    "gpsLongitude": -1.6244,
    "freshnessScore": 85,
    "shelfLifeDays": 5,
    "price": 150.00,
    "imageUrl": "https://s3.amazonaws.com/...",
    "listingHash": "a3f2b8c9d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1",
    "qrCode": "data:image/png;base64,iVBORw0KGgo...",
    "status": "ACTIVE",
    "createdAt": "2026-07-05T10:00:00Z"
  }
}
```

### Endpoint 2: `GET /api/listings` (Farmer Only — Own Listings)

**Protected by:** `authenticate` + `authorize('farmer')`

**What it does:** Returns all listings created by the logged-in farmer.

```typescript
const listings = await prisma.listing.findMany({
  where: {
    farmerId: req.user.userId,
    status: { not: 'DELETED' },  // Don't show soft-deleted
  },
  orderBy: { createdAt: 'desc' },
});
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "listings": [ ... ],
    "count": 5
  }
}
```

### Endpoint 3: `GET /api/listings/:id` (Public)

**What it does:** Get a single listing by ID. Anyone can view (no auth required — buyers need to see this).

```typescript
const listing = await prisma.listing.findUnique({
  where: { id: req.params.id },
});

if (!listing) {
  return res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: 'Listing not found' }
  });
}
```

### Endpoint 4: `PATCH /api/listings/:id` (Farmer Only — Own Listings)

**Protected by:** `authenticate` + `authorize('farmer')`

**What it does:** Farmer updates their own listing. Can update: price, quantity, imageUrl. Cannot update: freshnessScore, cropType (those are set at creation).

**Important:** Check that `listing.farmerId === req.user.userId` — a farmer can only edit their OWN listings.

```json
{
  "price": 130.00,
  "quantity": 450
}
```

### Endpoint 5: `DELETE /api/listings/:id` (Farmer Only — Own Listings)

**What it does:** Soft delete — don't actually delete from database, just set `status: 'INACTIVE'`.

**Why soft delete?** Because the audit trail needs the listing data to remain in the database for verification.

### Zod Schemas (listing.schema.ts)

```typescript
import { z } from 'zod';

export const createListingSchema = z.object({
  cropType: z.string().min(1, 'Crop type is required'),
  quantity: z.number().positive('Quantity must be positive'),
  gpsLatitude: z.number().min(-90).max(90),
  gpsLongitude: z.number().min(-180).max(180),
  freshnessScore: z.number().min(0).max(100),
  shelfLifeDays: z.number().int().positive(),
  price: z.number().positive('Price must be positive'),
  imageUrl: z.string().url().optional(),
});

export const updateListingSchema = z.object({
  price: z.number().positive().optional(),
  quantity: z.number().positive().optional(),
  imageUrl: z.string().url().optional(),
});
```

### Routes (listing.routes.ts)

```typescript
import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validate } from '../../middleware/validate';
import { createListingSchema, updateListingSchema } from './listing.schema';
import { createListing, getMyListings, getListing, updateListing, deleteListing } from './listing.controller';

const router = Router();

router.post('/', authenticate, authorize('farmer'), validate(createListingSchema), createListing);
router.get('/', authenticate, authorize('farmer'), getMyListings);
router.get('/:id', getListing);    // Public — no auth
router.patch('/:id', authenticate, authorize('farmer'), validate(updateListingSchema), updateListing);
router.delete('/:id', authenticate, authorize('farmer'), deleteListing);

export default router;
```

---

## Task H2 — Marketplace Browse & Filter

**Deadline: Day 6**
**Branch name:** `feature/H2-marketplace`
**Depends on:** H1 (listings must exist to browse them)

### Files to Create

```
src/modules/marketplace/
├── marketplace.controller.ts
├── marketplace.service.ts
├── marketplace.routes.ts
└── marketplace.schema.ts
```

### Endpoint: `GET /api/marketplace`

**Protected by:** `authenticate` (any logged-in user)

**What it does:** Buyers browse all ACTIVE listings. They can filter, sort, and paginate.

**Query parameters:**
| Param | Type | Default | Description |
|---|---|---|---|
| `crop` | string | — | Filter by crop type (e.g., `tomato`) |
| `region` | string | — | Filter by farmer's region |
| `minFreshness` | number | — | Minimum freshness score |
| `maxFreshness` | number | — | Maximum freshness score |
| `minQuantity` | number | — | Minimum quantity in kg |
| `sort` | string | `date` | Sort by: `date`, `freshness`, `price` |
| `order` | string | `desc` | Sort direction: `asc` or `desc` |
| `page` | number | 1 | Page number |
| `limit` | number | 20 | Items per page (max 50) |

**Example request:**
```
GET /api/marketplace?crop=tomato&minFreshness=70&sort=price&order=asc&page=1&limit=10
```

**How to build the Prisma query:**

```typescript
const { crop, region, minFreshness, maxFreshness, minQuantity, sort, order, page, limit } = req.query;

// Build the WHERE clause dynamically
const where: any = {
  status: 'ACTIVE',
};

if (crop) where.cropType = crop;
if (region) where.farmer = { farmRegion: region };  // Adjust based on actual DB schema
if (minFreshness) where.freshnessScore = { ...where.freshnessScore, gte: Number(minFreshness) };
if (maxFreshness) where.freshnessScore = { ...where.freshnessScore, lte: Number(maxFreshness) };
if (minQuantity) where.quantity = { gte: Number(minQuantity) };

// Build the ORDER BY
const sortField = sort === 'freshness' ? 'freshnessScore' : sort === 'price' ? 'price' : 'createdAt';
const sortOrder = order === 'asc' ? 'asc' : 'desc';

// Pagination
const pageNum = Math.max(1, Number(page) || 1);
const limitNum = Math.min(50, Math.max(1, Number(limit) || 20));
const skip = (pageNum - 1) * limitNum;

// Query
const [listings, total] = await Promise.all([
  prisma.listing.findMany({
    where,
    orderBy: { [sortField]: sortOrder },
    skip,
    take: limitNum,
    select: {
      id: true,
      cropType: true,
      quantity: true,
      price: true,
      freshnessScore: true,
      shelfLifeDays: true,
      imageUrl: true,
      createdAt: true,
      // Include farmer's region but NOT their personal info
      farmer: {
        select: {
          farmRegion: true,
        }
      }
    },
  }),
  prisma.listing.count({ where }),
]);
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "listings": [
      {
        "id": "uuid",
        "cropType": "tomato",
        "quantity": 500,
        "price": 150.00,
        "freshnessScore": 85,
        "shelfLifeDays": 5,
        "imageUrl": "https://...",
        "createdAt": "2026-07-05T10:00:00Z",
        "farmerRegion": "Ashanti"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45,
      "totalPages": 3
    }
  }
}
```

### Endpoint: `GET /api/marketplace/:id`

Same as `GET /api/listings/:id` but with more detail — include the freshness score, QR code hash, farmer region, and price recommendation range.

---

## Task H3 — Audit Trail System

**Deadline: Day 7**
**Branch name:** `feature/H3-audit-trail`
**Depends on:** K1 (setup) + K3 (Prisma). You can start the utility class on Day 3 without any dependencies.

### What You're Building

A **tamper-proof** record of everything that happens on the platform. Every event is SHA-256 hashed, and each hash includes the previous hash — creating a **hash chain** (like a simple blockchain). If anyone tries to change a past record, the chain breaks and we can detect it.

### Files to Create

```
src/modules/audit/
├── audit.controller.ts
├── audit.service.ts        ← The core service — other modules import this
└── audit.routes.ts
```

### The AuditService (audit.service.ts)

This is the most important file. Every other module in the system will call this service.

```typescript
import { generateHash } from '../../utils/hash';
import prisma from '../../config/database';

export class AuditService {
  /**
   * Log an event to the audit trail with hash chaining.
   * 
   * @param eventType - What happened (e.g., 'LISTING_CREATED')
   * @param entityId - The ID of the thing it happened to (e.g., listing ID)
   * @param data - The relevant data to hash
   * @param userId - Who triggered this event
   */
  static async log(
    eventType: string,
    entityId: string,
    data: object,
    userId: string
  ) {
    // Step 1: Get the most recent audit entry's hash (for chaining)
    const previousEntry = await prisma.auditTrail.findFirst({
      orderBy: { createdAt: 'desc' },
      select: { hash: true },
    });

    const previousHash = previousEntry?.hash || '0';  // Genesis entry has no previous

    // Step 2: Create the hash of this event
    const timestamp = new Date().toISOString();
    const hashData = {
      eventType,
      entityId,
      data,
      userId,
      timestamp,
      previousHash,
    };
    const hash = generateHash(hashData);

    // Step 3: Store in the database
    const auditEntry = await prisma.auditTrail.create({
      data: {
        eventType,
        entityId,
        data: JSON.stringify(data),
        userId,
        hash,
        previousHash,
        createdAt: new Date(timestamp),
      },
    });

    return auditEntry;
  }

  /**
   * Verify the integrity of the audit chain for a specific entity.
   * Returns true if all hashes are valid (no tampering).
   */
  static async verifyChain(entityId: string): Promise<{
    isValid: boolean;
    entries: number;
    brokenAt?: number;
  }> {
    const entries = await prisma.auditTrail.findMany({
      where: { entityId },
      orderBy: { createdAt: 'asc' },
    });

    if (entries.length === 0) {
      return { isValid: true, entries: 0 };
    }

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];

      // Recompute the hash from the stored data
      const expectedHash = generateHash({
        eventType: entry.eventType,
        entityId: entry.entityId,
        data: JSON.parse(entry.data as string),
        userId: entry.userId,
        timestamp: entry.createdAt.toISOString(),
        previousHash: entry.previousHash,
      });

      if (expectedHash !== entry.hash) {
        return { isValid: false, entries: entries.length, brokenAt: i };
      }
    }

    return { isValid: true, entries: entries.length };
  }
}
```

### Endpoint: `GET /api/audit/:entityId`

**What it does:** Anyone can verify the chain of custody for a listing or transaction. This is the public transparency endpoint.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "isValid": true,
    "entries": 4,
    "trail": [
      {
        "eventType": "LISTING_CREATED",
        "timestamp": "2026-07-05T10:00:00Z",
        "hash": "a3f2b8c9..."
      },
      {
        "eventType": "PURCHASE_INITIATED",
        "timestamp": "2026-07-06T14:30:00Z",
        "hash": "b4c3d9e0..."
      },
      {
        "eventType": "DELIVERY_CONFIRMED",
        "timestamp": "2026-07-07T09:15:00Z",
        "hash": "c5d4e0f1..."
      },
      {
        "eventType": "PAYMENT_RELEASED",
        "timestamp": "2026-07-07T09:16:00Z",
        "hash": "d6e5f1a2..."
      }
    ]
  }
}
```

### How Other Modules Use Your Service

Tell Afia and Kelvin to add this to their code whenever something important happens:

```typescript
import { AuditService } from '../audit/audit.service';

// In the listing creation handler:
await AuditService.log('LISTING_CREATED', listing.id, { cropType, quantity, price }, req.user.userId);

// In the payment handler:
await AuditService.log('PAYMENT_HELD', transaction.id, { amount, buyerId }, req.user.userId);

// In the delivery confirmation handler:
await AuditService.log('DELIVERY_CONFIRMED', transaction.id, { listingHash, verifiedAt: new Date() }, req.user.userId);
```

---

## Task H4 — Arkesel SMS + FCM Push Notifications

**Deadline: Day 9**
**Branch name:** `feature/H4-sms-fcm`
**Depends on:** Only K1 (scaffolding). This is mostly independent.

### Part 1 — Arkesel SMS Service

#### Step 1: Create Arkesel Account
1. Go to https://arkesel.com
2. Sign up and get your API key
3. Add to `.env`: `ARKESEL_API_KEY=your-key-here`
4. You'll get some free SMS credits for testing

#### Step 2: Build the SMS Service

Create `src/services/sms.service.ts`:

```typescript
import axios from 'axios';

class SmsService {
  private apiKey = process.env.ARKESEL_API_KEY!;
  private baseUrl = 'https://sms.arkesel.com/api/v2/sms/send';
  private sender = 'AgriConnect';  // This shows as the sender name on the phone

  /**
   * Send an OTP code to a phone number.
   * Used during registration.
   */
  async sendOtp(phone: string, code: string): Promise<void> {
    const message = `Your AgriConnect verification code is: ${code}. It expires in 5 minutes. Do not share this code.`;
    await this.send(phone, message);
  }

  /**
   * Send a driver dispatch notification.
   * Contains the job details so the driver can decide to accept/decline.
   */
  async sendDriverNotification(phone: string, jobDetails: {
    farmerLocation: string;
    buyerPhone: string;
    cropType: string;
    quantity: number;
    destination: string;
  }): Promise<void> {
    const message = `AgriConnect Job Alert!\n` +
      `Crop: ${jobDetails.cropType} (${jobDetails.quantity}kg)\n` +
      `Pickup: ${jobDetails.farmerLocation}\n` +
      `Deliver to: ${jobDetails.destination}\n` +
      `Contact buyer: ${jobDetails.buyerPhone}\n` +
      `Open the app to accept or decline.`;
    await this.send(phone, message);
  }

  /**
   * Send a generic SMS message.
   */
  async sendGeneric(phone: string, message: string): Promise<void> {
    await this.send(phone, message);
  }

  /**
   * Internal send method — calls the Arkesel API.
   */
  private async send(phone: string, message: string): Promise<void> {
    try {
      await axios.post(this.baseUrl, {
        sender: this.sender,
        message,
        recipients: [phone],
      }, {
        headers: {
          'api-key': this.apiKey,
        },
      });
      console.log(`SMS sent to ${phone}`);
    } catch (error: any) {
      console.error(`Failed to send SMS to ${phone}:`, error.response?.data || error.message);
      throw new Error('Failed to send SMS');
    }
  }
}

export default new SmsService();
```

#### Step 3: Replace Afia's OTP Stub

In Afia's auth service, find where the OTP is returned in the response and replace it with a real SMS call:

```typescript
import smsService from '../../services/sms.service';

// Replace this:
// return { message: "OTP sent", otp: otp };  // ← Remove the otp from response

// With this:
await smsService.sendOtp(phone, otp);
return { message: "OTP sent to your phone number" };
```

#### Step 4: Test

Send a real SMS to your own phone number. Verify it arrives.

---

### Part 2 — Firebase Cloud Messaging (FCM)

#### Step 1: Set Up Firebase
1. Go to https://console.firebase.google.com
2. Create a new project (or get access to the existing one if Frontend already created it)
3. Go to Project Settings → Service Accounts → Generate New Private Key
4. Save the JSON file
5. Add the path to `.env`: `FIREBASE_SERVICE_ACCOUNT=./firebase-service-account.json`

#### Step 2: Build the Notification Service

Create `src/services/notification.service.ts`:

```typescript
import admin from 'firebase-admin';
import path from 'path';

// Initialize Firebase Admin (do this once)
const serviceAccount = require(path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT!));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

class NotificationService {
  /**
   * Send a push notification to a specific device.
   * The FCM token is stored in the user's profile (frontend provides it after login).
   */
  async sendToDevice(
    fcmToken: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<void> {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: data || {},
      });
      console.log(`Push notification sent to device`);
    } catch (error: any) {
      console.error('Failed to send push notification:', error.message);
      // Don't throw — notification failure shouldn't break the main flow
    }
  }

  // ============ Pre-built notification templates ============

  /** Notify farmer that their produce has been purchased */
  async notifyFarmerPurchase(fcmToken: string, cropType: string, quantity: number, price: number) {
    await this.sendToDevice(fcmToken,
      'Produce Sold! 🎉',
      `Your ${quantity}kg of ${cropType} has been purchased for GHS ${price}. Payment is being held securely.`,
      { type: 'PURCHASE_NOTIFICATION' }
    );
  }

  /** Notify buyer that a driver has been dispatched */
  async notifyBuyerDriverDispatched(fcmToken: string, driverName: string) {
    await this.sendToDevice(fcmToken,
      'Driver on the way 🚛',
      `${driverName} has been contacted to deliver your produce.`,
      { type: 'DRIVER_DISPATCHED' }
    );
  }

  /** Notify buyer that the driver accepted and produce is in transit */
  async notifyBuyerInTransit(fcmToken: string) {
    await this.sendToDevice(fcmToken,
      'Produce in Transit 📦',
      'Your produce has been picked up and is on its way to you.',
      { type: 'DRIVER_ACCEPTED' }
    );
  }

  /** Notify farmer that delivery was confirmed and payment is released */
  async notifyFarmerPaymentReleased(fcmToken: string, amount: number) {
    await this.sendToDevice(fcmToken,
      'Payment Received! 💰',
      `GHS ${amount} has been sent to your Mobile Money account.`,
      { type: 'PAYMENT_RELEASED' }
    );
  }

  /** Warn farmer that produce freshness is dropping */
  async notifyFarmerFreshnessAlert(fcmToken: string, cropType: string, hoursLeft: number) {
    await this.sendToDevice(fcmToken,
      'Freshness Alert ⚠️',
      `Your ${cropType} freshness is projected to drop below threshold in ${hoursLeft} hours. Consider reducing your price to sell faster.`,
      { type: 'FRESHNESS_ALERT' }
    );
  }
}

export default new NotificationService();
```

#### Step 3: Test

Write a simple test script or route that sends a test notification:
```typescript
// Temporary test route — remove after testing
router.post('/test-notification', async (req, res) => {
  const { fcmToken } = req.body;
  await notificationService.sendToDevice(fcmToken, 'Test', 'AgriConnect notification works!');
  res.json({ success: true, message: 'Notification sent' });
});
```

**Deliverable:** Both services work. Real SMS via Arkesel. Real push via FCM. OTP stub in auth is replaced with real SMS. Both services are importable by any module.

---

## Summary — Your Week at a Glance

| Day | What You're Doing |
|---|---|
| **Day 1–2** | 📖 Study: SHA-256, QR codes, Arkesel docs, FCM docs. Read the project documents. |
| **Day 3** | Start writing `hash.ts` and `qrcode.ts` utilities. Start the `AuditService` class (H3). |
| **Day 4** | Continue H3 (audit service). Wait for Afia's auth middleware (A2). |
| **Day 5** | 🔨 **H1:** Build listing CRUD with SHA-256 hash + QR code. PR to dev. |
| **Day 6** | 🔨 **H2:** Build marketplace browse + filter. PR to dev. |
| **Day 7** | 🔨 **H3:** Build audit trail verification endpoint. Connect service to DB. PR to dev. |
| **Day 8** | 📖 Set up Arkesel account + Firebase project. Get API keys. Prep code. |
| **Day 9** | 🔨 **H4:** Build Arkesel SMS + FCM services. Replace OTP stub. PR to dev. |
| **Friday** | 📋 **Team check-in** — demo your work, raise any issues. |

---

## Questions?

If you're stuck:
1. Check the project README
2. Check these docs:
   - Prisma: https://www.prisma.io/docs
   - QR Code: https://www.npmjs.com/package/qrcode
   - Arkesel: https://developers.arkesel.com
   - FCM: https://firebase.google.com/docs/cloud-messaging/send-message
3. Ask in the group chat
4. If it's a code issue, push what you have and create a **Draft PR** so Kelvin can look at it
