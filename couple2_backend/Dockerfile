# ============================================
# Build Stage
# ============================================
FROM node:22-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy Prisma schema and generate client.
# Generate does not connect, but Prisma 7 reads DATABASE_URL from prisma.config.ts.
COPY prisma.config.ts ./
COPY prisma ./prisma
ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npx prisma generate

# Copy source code and build
COPY . .
RUN npm run build

# ============================================
# Production Stage
# ============================================
FROM node:22-alpine AS production

WORKDIR /app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy Prisma schema and generated client
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Copy built application
COPY --from=builder /app/dist ./dist
COPY scripts ./scripts

# Expose application port
EXPOSE 3000

# Run migrations and start the application
CMD ["sh", "-c", "node scripts/wait-for-db.mjs && npx prisma migrate deploy && npm run prod"]

# ============================================
# Development Stage
# ============================================
FROM node:22-alpine AS development

WORKDIR /app

# Install dependencies (including devDependencies)
COPY package*.json ./
RUN npm ci

# Copy Prisma schema
COPY prisma.config.ts ./
COPY prisma ./prisma

# Generate Prisma client (no live database required)
ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npx prisma generate

# Copy source code
COPY . .

EXPOSE 3000

# Wait for local Supabase Postgres, migrate, then start in watch mode
CMD ["sh", "-c", "node scripts/wait-for-db.mjs && npx prisma migrate deploy && npm run dev"]
