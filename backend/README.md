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
| `npm test` | Run Jest tests |
