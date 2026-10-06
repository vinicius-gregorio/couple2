# ============================================
# Builder — install, generate the Prisma client, compile
# ============================================
FROM node:22-alpine AS builder

WORKDIR /app

# Prisma's engine links OpenSSL. ca-certificates is the public trust store.
# Generate does not open a connection.
RUN apk add --no-cache openssl ca-certificates \
  && update-ca-certificates

COPY package.json package-lock.json ./
RUN npm ci

# Generate does not connect, but Prisma 7 reads DATABASE_URL from prisma.config.ts.
COPY prisma.config.ts ./
COPY prisma ./prisma
ENV DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres?schema=public
RUN npx prisma generate

COPY . .
# Host incremental state (tsconfig.build.tsbuildinfo) points at a dist/
# directory that is not in the build context. Drop it so nest emits dist/main.js.
RUN rm -f tsconfig.build.tsbuildinfo && npm run build

# ============================================
# Development — docker build --target development
# (docker-compose.yml pins this target)
# ============================================
FROM node:22-alpine AS development

WORKDIR /app

# Public CAs, plus Supabase Root 2021 so a cloud DATABASE_URL can verify TLS.
# NODE_EXTRA_CA_CERTS adds that root without replacing Node's built-in CAs.
# SSL_CERT_FILE is what Prisma's engine reads. Verification stays on.
RUN apk add --no-cache openssl ca-certificates
COPY certs/supabase-root-2021.crt /usr/local/share/ca-certificates/supabase-root-2021.crt
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/supabase-root-2021.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

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

RUN apk add --no-cache openssl ca-certificates \
  && update-ca-certificates

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

# node:22-alpine previously installed openssl without ca-certificates, so
# OpenSSL clients (Prisma migrate) had an empty trust store. Public roots
# fix Google and other public CAs. The Supabase pooler chains to Supabase
# Root 2021 CA, which is not in that bundle — install it too.
# NODE_EXTRA_CA_CERTS lets Node (pg, Firebase JWKS if it uses the extra
# store) trust that root. Do not set NODE_TLS_REJECT_UNAUTHORIZED.
RUN apk add --no-cache openssl ca-certificates \
  && addgroup -S app \
  && adduser -S app -G app
COPY certs/supabase-root-2021.crt /usr/local/share/ca-certificates/supabase-root-2021.crt
RUN update-ca-certificates \
  && chmod 644 /usr/local/share/ca-certificates/supabase-root-2021.crt \
  && chmod 644 /etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/supabase-root-2021.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY --from=prod-deps --chown=app:app /app/node_modules ./node_modules
COPY --from=prod-deps --chown=app:app /app/package.json ./package.json
COPY --from=prod-deps --chown=app:app /app/prisma.config.ts ./prisma.config.ts
COPY --from=prod-deps --chown=app:app /app/prisma ./prisma
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --chown=app:app certs/supabase-root-2021.crt ./certs/supabase-root-2021.crt

USER app

EXPOSE 3000

# Migrations, then listen on $PORT (fallback 3000 in the app and this image).
CMD ["sh", "-c", "./node_modules/.bin/prisma migrate deploy && exec node dist/main"]
