# -------- Stage 1: Build dependencies --------
  FROM node:18-alpine AS builder

  # Set working directory
  WORKDIR /app
  
  # Copy package files
  COPY package*.json ./
  
  # Install all dependencies (including dev)
  RUN npm ci --audit false
  
  # Copy application code
  COPY . .
  
  # Run build step if needed (e.g., transpile, bundle)
  # RUN npm run build
  
  # -------- Stage 2: Production runtime --------
  FROM node:18-alpine AS production
  
  # Set working directory
  WORKDIR /app
  
  # Copy only production dependencies from builder
  COPY --from=builder /app/node_modules ./node_modules
  
  # Copy application code from builder
  COPY --from=builder /app ./
  
  # Create non-root user and set permissions
  RUN addgroup -g 1001 -S nodejs && \
      adduser -S nodejs -u 1001 && \
      chown -R nodejs:nodejs /app
  
  # Expose port
  EXPOSE 3001
  
  # Set environment variables
  ENV PORT=3001
  ENV NODE_ENV=production
  
  # Run as non-root user
  USER node
  
  # Health check
  HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
  
  # Start the application
  CMD ["npm", "start"]