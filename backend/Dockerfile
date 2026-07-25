# ==========================================
# Stage 1: Build & Compile TypeScript
# ==========================================
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package manifests and Prisma schema
COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Install dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY tsconfig.json ./
COPY src ./src/

# Generate Prisma Client & Compile TypeScript
RUN npx prisma generate
RUN npm run build

# ==========================================
# Stage 2: Production Execution Runtime
# ==========================================
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Install production dependencies only
COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./
RUN npm ci --only=production

# Copy compiled JavaScript output and generated Prisma Client from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/generated ./src/generated

# Create non-root user for security
RUN addgroup -S agriconnect && adduser -S agriconnect -G agriconnect
USER agriconnect

EXPOSE 3000

# Health check endpoint verification
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

CMD ["node", "dist/server.js"]
