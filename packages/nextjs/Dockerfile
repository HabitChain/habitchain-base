# Build stage
FROM node:20-alpine AS builder

# Install dependencies required for node-gyp
RUN apk add --no-cache python3 make g++

# Enable Corepack for pnpm support
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Copy root package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Create directory structure and copy package.json files
RUN mkdir -p packages/nextjs packages/foundry
COPY packages/nextjs/package.json ./packages/nextjs/
COPY packages/foundry/package.json ./packages/foundry/

# Create .env.example to prevent Foundry postinstall from failing
RUN touch packages/foundry/.env.example

# Install all dependencies
RUN pnpm install --frozen-lockfile

# Copy nextjs source
COPY packages/nextjs ./packages/nextjs

# Copy contracts (needed for deployedContracts.ts)
RUN mkdir -p packages/foundry/contracts packages/foundry/out
COPY packages/foundry/contracts ./packages/foundry/contracts
COPY packages/foundry/out ./packages/foundry/out

WORKDIR /app/packages/nextjs

# Build the Next.js application
RUN pnpm build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/packages/nextjs/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/packages/nextjs/.next/static ./packages/nextjs/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/packages/nextjs/public ./packages/nextjs/public

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "packages/nextjs/server.js"]

