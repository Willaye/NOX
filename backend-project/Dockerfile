FROM node:20-alpine AS builder

WORKDIR /app

# Install OpenSSL for Prisma
RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
COPY prisma ./prisma/

RUN npm install --frozen-lockfile || npm install
RUN npx prisma generate

COPY . .
RUN npm run build

# Prune dev dependencies
RUN npm prune --production

# ─── Production ──────────────────────────────────────────────
FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache openssl
RUN addgroup -S nox && adduser -S nox -G nox

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma
# Bake the signed APK(s) into the image. The backend has no persistent volume,
# so this is how /api/enroll/download/:kind and /api/enroll/apk/:token find a
# file to serve on Railway.
COPY --from=builder /app/apk ./apk

USER nox

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- http://localhost:3000/api || exit 1

CMD ["sh", "-c", "npx prisma db push --skip-generate && node dist/main.js"]
