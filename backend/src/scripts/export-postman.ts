import fs from 'fs';
import path from 'path';
import { generateOpenAPIDocument } from '../docs/openapi.generator';

export function convertOpenAPIToPostman() {
  const doc = generateOpenAPIDocument();

  const collection = {
    info: {
      name: 'AgriConnect API v1.0.0-stable Collection',
      description: 'Official production API collection for AgriConnect Flutter mobile application, supporting Auth, Marketplace, Produce Listings, Escrow Transactions, Driver Dispatch, Disputes, Cryptographic Audit Trail, Notifications, and MOFA Pricing.',
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    },
    variable: [
      {
        key: 'baseUrl',
        value: 'http://localhost:3000',
        type: 'string',
      },
      {
        key: 'accessToken',
        value: '',
        type: 'string',
      },
    ],
    item: [
      {
        name: '🔑 01 - Authentication',
        description: 'User registration, password login, Google OAuth identity linking, token refresh, and password reset workflows.',
        item: [
          {
            name: 'Register Account',
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify(
                  {
                    name: 'Kwame Asante',
                    phone: '+233541234567',
                    password: 'Password123!',
                    role: 'farmer',
                  },
                  null,
                  2,
                ),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/register',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'register'],
              },
              description: 'Registers a new user account (Farmer, Buyer, or Driver). User status is initially set to PENDING_APPROVAL.',
            },
          },
          {
            name: 'Login (Password)',
            event: [
              {
                listen: 'test',
                script: {
                  exec: [
                    'if (pm.response.code === 200) {',
                    '    var res = pm.response.json();',
                    '    if (res.data && res.data.accessToken) {',
                    '        pm.environment.set("accessToken", res.data.accessToken);',
                    '        pm.environment.set("refreshToken", res.data.refreshToken);',
                    '        console.log("Auto-saved accessToken and refreshToken into environment!");',
                    '    }',
                    '}',
                  ],
                  type: 'text/javascript',
                },
              },
            ],
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify(
                  {
                    phone: '+233541234567',
                    password: 'Password123!',
                  },
                  null,
                  2,
                ),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/login',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'login'],
              },
              description: 'Authenticates user and auto-saves accessToken and refreshToken into Postman environment.',
            },
          },
          {
            name: 'Refresh Access Token',
            event: [
              {
                listen: 'test',
                script: {
                  exec: [
                    'if (pm.response.code === 200) {',
                    '    var res = pm.response.json();',
                    '    if (res.data && res.data.accessToken) {',
                    '        pm.environment.set("accessToken", res.data.accessToken);',
                    '        console.log("Updated accessToken into environment!");',
                    '    }',
                    '}',
                  ],
                  type: 'text/javascript',
                },
              },
            ],
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ refreshToken: '{{refreshToken}}' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/refresh',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'refresh'],
              },
              description: 'Issues a fresh 15-minute Bearer JWT access token using a valid 7-day refresh token.',
            },
          },
          {
            name: 'Google OAuth URL',
            request: {
              method: 'GET',
              header: [],
              url: {
                raw: '{{baseUrl}}/api/auth/google/url?redirectTo=http://localhost:3000/callback',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'google', 'url'],
                query: [{ key: 'redirectTo', value: 'http://localhost:3000/callback' }],
              },
              description: 'Fetches the Supabase Google OAuth sign-in redirect URL for web/mobile browsers.',
            },
          },
          {
            name: 'Google OAuth Sign-In',
            event: [
              {
                listen: 'test',
                script: {
                  exec: [
                    'if (pm.response.code === 200) {',
                    '    var res = pm.response.json();',
                    '    if (res.data && res.data.accessToken) {',
                    '        pm.environment.set("accessToken", res.data.accessToken);',
                    '        pm.environment.set("refreshToken", res.data.refreshToken);',
                    '    }',
                    '}',
                  ],
                  type: 'text/javascript',
                },
              },
            ],
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ token: 'mock-google-id-token', role: 'buyer' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/google',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'google'],
              },
              description: 'Exchanges a Google ID Token or Supabase Access Token for an AgriConnect JWT token pair.',
            },
          },
          {
            name: 'Forgot Password (Request Token)',
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ phone: '+233541234567' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/forgot-password',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'forgot-password'],
              },
              description: 'Generates a 15-minute password reset token for the specified phone number.',
            },
          },
          {
            name: 'Reset Password',
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ token: 'reset-token-here', newPassword: 'NewPassword123!' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/reset-password',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'reset-password'],
              },
              description: 'Resets user password and automatically revokes all active refresh tokens.',
            },
          },
          {
            name: 'Logout',
            request: {
              method: 'POST',
              header: [{ key: 'Content-Type', value: 'application/json' }],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ refreshToken: '{{refreshToken}}' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/auth/logout',
                host: ['{{baseUrl}}'],
                path: ['api', 'auth', 'logout'],
              },
              description: 'Invalidates the refresh token on the server.',
            },
          },
        ],
      },
      {
        name: '🌽 02 - Produce Listings & Marketplace',
        description: 'Farmer produce listing creation, listing updates, soft deletion, and buyer marketplace browsing with MOFA price comparison.',
        item: [
          {
            name: 'Browse Marketplace (Filtered)',
            request: {
              method: 'GET',
              header: [],
              url: {
                raw: '{{baseUrl}}/api/marketplace?crop=tomato&minFreshness=80&page=1&limit=10',
                host: ['{{baseUrl}}'],
                path: ['api', 'marketplace'],
                query: [
                  { key: 'crop', value: 'tomato' },
                  { key: 'minFreshness', value: '80' },
                  { key: 'page', value: '1' },
                  { key: 'limit', value: '10' },
                ],
              },
              description: 'Browse active produce listings with filters for crop type, freshness score, quantity, region, and sorting.',
            },
          },
          {
            name: 'Get Listing Detail',
            request: {
              method: 'GET',
              header: [],
              url: {
                raw: '{{baseUrl}}/api/marketplace/{{listingId}}',
                host: ['{{baseUrl}}'],
                path: ['api', 'marketplace', '{{listingId}}'],
              },
              description: 'Returns detailed information for a single produce listing, enriched with farmer region context.',
            },
          },
          {
            name: 'Create Listing (Farmer Only)',
            request: {
              method: 'POST',
              header: [
                { key: 'Content-Type', value: 'application/json' },
                { key: 'Authorization', value: 'Bearer {{accessToken}}' },
              ],
              body: {
                mode: 'raw',
                raw: JSON.stringify(
                  {
                    cropType: 'tomato',
                    quantityKg: 200,
                    freshnessScore: 9.5,
                    shelfLifeDays: 7,
                    farmerLat: 5.6037,
                    farmerLong: -0.187,
                    pricePerKg: 15.0,
                  },
                  null,
                  2,
                ),
              },
              url: {
                raw: '{{baseUrl}}/api/listings',
                host: ['{{baseUrl}}'],
                path: ['api', 'listings'],
              },
              description: 'Allows an approved Farmer to list new produce on the marketplace.',
            },
          },
          {
            name: 'Get My Listings (Farmer)',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/listings/my',
                host: ['{{baseUrl}}'],
                path: ['api', 'listings', 'my'],
              },
              description: 'Returns all produce listings created by the authenticated farmer.',
            },
          },
          {
            name: 'Soft Delete Listing',
            request: {
              method: 'DELETE',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/listings/{{listingId}}',
                host: ['{{baseUrl}}'],
                path: ['api', 'listings', '{{listingId}}'],
              },
              description: 'Soft-deletes a listing (sets status to CANCELLED). Only the listing owner can delete it.',
            },
          },
        ],
      },
      {
        name: '💳 03 - Escrow Transactions & Delivery Confirmation',
        description: 'Buyer purchase execution, 60s idempotency window, atomic locking, payment hold/release, and QR delivery confirmation.',
        item: [
          {
            name: 'Purchase Produce (Initiate Escrow)',
            request: {
              method: 'POST',
              header: [
                { key: 'Content-Type', value: 'application/json' },
                { key: 'Authorization', value: 'Bearer {{accessToken}}' },
              ],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ listingId: '{{listingId}}', hasOwnTransport: false }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/transactions/purchase',
                host: ['{{baseUrl}}'],
                path: ['api', 'transactions', 'purchase'],
              },
              description: 'Initiates a produce purchase, locks listing atomically, holds funds in escrow (PAYMENT_HELD), and dispatches driver.',
            },
          },
          {
            name: 'Get My Transactions',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/transactions/my',
                host: ['{{baseUrl}}'],
                path: ['api', 'transactions', 'my'],
              },
              description: 'Returns transactions where the authenticated user is buyer or farmer.',
            },
          },
          {
            name: 'Get Transaction by ID',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/transactions/{{transactionId}}',
                host: ['{{baseUrl}}'],
                path: ['api', 'transactions', '{{transactionId}}'],
              },
              description: 'Returns details of a single transaction for authorized participants or admins.',
            },
          },
          {
            name: 'Confirm Delivery (Scan QR Code)',
            request: {
              method: 'POST',
              header: [
                { key: 'Content-Type', value: 'application/json' },
                { key: 'Authorization', value: 'Bearer {{accessToken}}' },
              ],
              body: {
                mode: 'raw',
                raw: JSON.stringify({ qrHash: 'hash-of-listing-qr-code' }, null, 2),
              },
              url: {
                raw: '{{baseUrl}}/api/transactions/{{transactionId}}/confirm-delivery',
                host: ['{{baseUrl}}'],
                path: ['api', 'transactions', '{{transactionId}}', 'confirm-delivery'],
              },
              description: 'Scans produce QR code upon physical delivery. On valid hash match, transitions transaction status to RELEASED and triggers instant farmer MoMo payout.',
            },
          },
        ],
      },
      {
        name: '🚚 04 - Driver Logistics & Dispatch',
        description: 'Driver capacity matching, pending job offer inspection, job acceptance, decline with auto-reassignment, and delivery completion.',
        item: [
          {
            name: 'Get Driver Jobs',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/dispatch/jobs?status=PENDING',
                host: ['{{baseUrl}}'],
                path: ['api', 'dispatch', 'jobs'],
                query: [{ key: 'status', value: 'PENDING' }],
              },
              description: 'Lists transport jobs offered to or assigned to the authenticated driver.',
            },
          },
          {
            name: 'Accept Dispatch Job',
            request: {
              method: 'POST',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/dispatch/jobs/{{jobId}}/accept',
                host: ['{{baseUrl}}'],
                path: ['api', 'dispatch', 'jobs', '{{jobId}}', 'accept'],
              },
              description: 'Driver accepts transport job. Job status transitions from PENDING to ACCEPTED.',
            },
          },
          {
            name: 'Decline Dispatch Job',
            request: {
              method: 'POST',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/dispatch/jobs/{{jobId}}/decline',
                host: ['{{baseUrl}}'],
                path: ['api', 'dispatch', 'jobs', '{{jobId}}', 'decline'],
              },
              description: 'Driver declines job offer. System automatically attempts auto-reassignment to the next available candidate driver.',
            },
          },
        ],
      },
      {
        name: '⚖️ 05 - Dispute Resolution',
        description: 'Buyer dispute creation, admin dispute queue listing, and dispute resolution with escrow side-effects (REFUND_BUYER / RELEASE_FARMER).',
        item: [
          {
            name: 'Raise Dispute (Buyer/Farmer)',
            request: {
              method: 'POST',
              header: [
                { key: 'Content-Type', value: 'application/json' },
                { key: 'Authorization', value: 'Bearer {{accessToken}}' },
              ],
              body: {
                mode: 'raw',
                raw: JSON.stringify(
                  {
                    transactionId: '{{transactionId}}',
                    type: 'NON_DELIVERY',
                    description: 'Produce arrived damaged and short by 50kg.',
                  },
                  null,
                  2,
                ),
              },
              url: {
                raw: '{{baseUrl}}/api/disputes',
                host: ['{{baseUrl}}'],
                path: ['api', 'disputes'],
              },
              description: 'Raises a dispute against an active transaction.',
            },
          },
          {
            name: 'List All Disputes (Admin Only)',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{adminToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/disputes',
                host: ['{{baseUrl}}'],
                path: ['api', 'disputes'],
              },
              description: 'Returns all open and resolved disputes. Requires Admin role.',
            },
          },
          {
            name: 'Resolve Dispute (Admin Only)',
            request: {
              method: 'POST',
              header: [
                { key: 'Content-Type', value: 'application/json' },
                { key: 'Authorization', value: 'Bearer {{adminToken}}' },
              ],
              body: {
                mode: 'raw',
                raw: JSON.stringify(
                  {
                    resolution: 'Produce was damaged in transit. Refund granted.',
                    action: 'REFUND_BUYER',
                  },
                  null,
                  2,
                ),
              },
              url: {
                raw: '{{baseUrl}}/api/disputes/{{disputeId}}/resolve',
                host: ['{{baseUrl}}'],
                path: ['api', 'disputes', '{{disputeId}}', 'resolve'],
              },
              description: 'Resolves dispute with action REFUND_BUYER (cancels order & re-activates listing) or RELEASE_FARMER (releases escrow funds).',
            },
          },
        ],
      },
      {
        name: '🔒 06 - Cryptographic Audit Trail',
        description: 'SHA-256 tamper-evident hash chain inspection and cryptographic integrity verification for regulatory compliance.',
        item: [
          {
            name: 'Get Audit Logs for Entity',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/audit/{{entityId}}',
                host: ['{{baseUrl}}'],
                path: ['api', 'audit', '{{entityId}}'],
              },
              description: 'Returns audit trail records for a given entity (order, listing, dispute).',
            },
          },
          {
            name: 'Verify Cryptographic Audit Chain',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/audit/{{entityId}}/verify',
                host: ['{{baseUrl}}'],
                path: ['api', 'audit', '{{entityId}}', 'verify'],
              },
              description: 'Re-computes SHA-256 hashes sequentially from GENESIS root and verifies cryptographic integrity.',
            },
          },
        ],
      },
      {
        name: '📊 07 - MOFA Market Pricing',
        description: 'Ministry of Food and Agriculture (MOFA) market price reference benchmarks and shelf-life freshness decay projections.',
        item: [
          {
            name: 'Recommend Produce Price',
            request: {
              method: 'GET',
              header: [],
              url: {
                raw: '{{baseUrl}}/api/pricing/recommend?crop=tomato&region=Ashanti&freshness=90&shelfLifeDays=7',
                host: ['{{baseUrl}}'],
                path: ['api', 'pricing', 'recommend'],
                query: [
                  { key: 'crop', value: 'tomato' },
                  { key: 'region', value: 'Ashanti' },
                  { key: 'freshness', value: '90' },
                  { key: 'shelfLifeDays', value: '7' },
                ],
              },
              description: 'Returns recommended price ceiling, soft floor, and day-by-day freshness decay projection based on MOFA benchmarks.',
            },
          },
        ],
      },
      {
        name: '🔔 08 - Notifications',
        description: 'In-app notification inbox and read status management.',
        item: [
          {
            name: 'Get User Notifications',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/notifications',
                host: ['{{baseUrl}}'],
                path: ['api', 'notifications'],
              },
              description: 'Returns notifications for the authenticated user.',
            },
          },
          {
            name: 'Mark Notification as Read',
            request: {
              method: 'PATCH',
              header: [{ key: 'Authorization', value: 'Bearer {{accessToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/notifications/{{notificationId}}/read',
                host: ['{{baseUrl}}'],
                path: ['api', 'notifications', '{{notificationId}}', 'read'],
              },
              description: 'Marks an in-app notification as read.',
            },
          },
        ],
      },
      {
        name: '👑 09 - Admin Operations',
        description: 'Platform user account approvals, user status management, and global transaction oversight.',
        item: [
          {
            name: 'List Pending User Approvals',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{adminToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/admin/users/pending',
                host: ['{{baseUrl}}'],
                path: ['api', 'admin', 'users', 'pending'],
              },
              description: 'Lists all user accounts awaiting admin sign-off before being allowed to transact.',
            },
          },
          {
            name: 'Approve User Account',
            request: {
              method: 'PATCH',
              header: [{ key: 'Authorization', value: 'Bearer {{adminToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/admin/users/{{userId}}/approve',
                host: ['{{baseUrl}}'],
                path: ['api', 'admin', 'users', '{{userId}}', 'approve'],
              },
              description: 'Approves a pending user account (sets status to ACTIVE).',
            },
          },
          {
            name: 'Reject User Account',
            request: {
              method: 'PATCH',
              header: [{ key: 'Authorization', value: 'Bearer {{adminToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/admin/users/{{userId}}/reject',
                host: ['{{baseUrl}}'],
                path: ['api', 'admin', 'users', '{{userId}}', 'reject'],
              },
              description: 'Rejects a pending user account (sets status to REJECTED).',
            },
          },
          {
            name: 'List All System Transactions',
            request: {
              method: 'GET',
              header: [{ key: 'Authorization', value: 'Bearer {{adminToken}}' }],
              url: {
                raw: '{{baseUrl}}/api/admin/transactions',
                host: ['{{baseUrl}}'],
                path: ['api', 'admin', 'transactions'],
              },
              description: 'Returns all system transactions for administrative oversight.',
            },
          },
        ],
      },
    ],
  };

  const environment = {
    name: 'AgriConnect Local Environment',
    values: [
      { key: 'baseUrl', value: 'http://localhost:3000', enabled: true },
      { key: 'accessToken', value: '', enabled: true },
      { key: 'refreshToken', value: '', enabled: true },
      { key: 'listingId', value: '', enabled: true },
      { key: 'transactionId', value: '', enabled: true },
      { key: 'disputeId', value: '', enabled: true },
      { key: 'jobId', value: '', enabled: true },
      { key: 'adminToken', value: '', enabled: true },
    ],
  };

  const collectionPath = path.join(__dirname, '../../AgriConnect_Postman_Collection.json');
  const envPath = path.join(__dirname, '../../AgriConnect_Local_Environment.json');

  fs.writeFileSync(collectionPath, JSON.stringify(collection, null, 2));
  fs.writeFileSync(envPath, JSON.stringify(environment, null, 2));

  console.log(`✅ Exported Postman Collection: ${collectionPath}`);
  console.log(`✅ Exported Postman Environment: ${envPath}`);
}

if (require.main === module) {
  convertOpenAPIToPostman();
}
