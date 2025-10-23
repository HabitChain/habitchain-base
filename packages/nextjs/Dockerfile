# Build stage
FROM node:20-alpine AS builder

# Install dependencies required for node-gyp
RUN apk add --no-cache python3 make g++

# Enable Corepack for Yarn 3.x support
RUN corepack enable && corepack prepare yarn@3.2.3 --activate

WORKDIR /app

# Copy root package files (includes .yarnrc.yml for Yarn 3)
COPY package.json yarn.lock .yarnrc.yml ./

# Copy yarn directory if using zero-installs or patches
COPY .yarn ./.yarn

# Copy all workspace package.json files (Yarn needs to see the entire workspace structure)
COPY packages/nextjs/package.json ./packages/nextjs/
COPY packages/foundry/package.json ./packages/foundry/

# Install dependencies (skip immutability checks in Docker since we're in a clean build environment)
RUN yarn install

# Copy nextjs source
COPY packages/nextjs ./packages/nextjs

# Copy contracts (needed for deployedContracts.ts)
COPY packages/foundry/contracts ./packages/foundry/contracts
COPY packages/foundry/out ./packages/foundry/out

WORKDIR /app/packages/nextjs

# Build the Next.js application
RUN yarn build

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

