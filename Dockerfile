# Samsung Logistics MCP Server Dockerfile
# Multi-stage build for production optimization

# Build stage
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:20-alpine AS production

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S samsung -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies and source
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
COPY resources ./resources

# Create necessary directories
RUN mkdir -p /app/logs && \
    chown -R samsung:nodejs /app

# Switch to non-root user
USER samsung

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/healthz', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["node", "src/index.js"]
