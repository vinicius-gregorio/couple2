# ============================================
# Builder — install, generate the Prisma client, compile
# ============================================
FROM node:22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
RUN npm ci

# Generate does not connect, but Prisma 7 reads DATABASE_URL from prisma.config.ts.
COPY prisma.config.ts ./
COPY prisma ./prisma
ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npx prisma generate

COPY . .
RUN npm run build

# ============================================
# Development — docker build --target development
# (docker-compose.yml pins this target)
# ============================================
FROM node:22-alpine AS development

WORKDIR /app

RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
RUN npm ci

COPY prisma.config.ts ./
COPY prisma ./prisma

ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npx prisma generate

COPY . .

EXPOSE 3000

# Wait for local Supabase Postgres, migrate, then start in watch mode
CMD ["sh", "-c", "node scripts/wait-for-db.mjs && npx prisma migrate deploy && npm run dev"]

# ============================================
# Production dependencies
# prisma and dotenv are runtime dependencies so migrate deploy can run.
# ============================================
FROM node:22-alpine AS prod-deps

WORKDIR /app

RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
COPY prisma.config.ts ./
COPY prisma ./prisma

ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npm ci --omit=dev && npx prisma generate

# ============================================
# Production — final, default stage (Railway)
# Dummy DATABASE_URL used above is not copied into this image.
# ============================================
FROM node:22-alpine AS production

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

RUN apk add --no-cache openssl \
  && addgroup -S app \
  && adduser -S app -G app

COPY --from=prod-deps --chown=app:app /app/node_modules ./node_modules
COPY --from=prod-deps --chown=app:app /app/package.json ./package.json
COPY --from=prod-deps --chown=app:app /app/prisma.config.ts ./prisma.config.ts
COPY --from=prod-deps --chown=app:app /app/prisma ./prisma
COPY --from=builder --chown=app:app /app/dist ./dist

USER app

EXPOSE 3000

# Migrations, then listen on $PORT (fallback 3000 in the app and this image).
CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && exec node dist/main"]
