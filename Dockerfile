# syntax=docker/dockerfile:1

# Small, pinned base image. Alpine keeps the attack surface and size down.
FROM node:20-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production

# Install dependencies first so this layer is cached when only source changes.
# This app has none today, but the pattern is future-proof.
COPY package*.json ./
RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev

# Copy application source.
COPY index.js ./

# Never run as root inside the container.
USER node

EXPOSE 3000

# Container-level health check (in addition to the ALB health check).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "index.js"]
