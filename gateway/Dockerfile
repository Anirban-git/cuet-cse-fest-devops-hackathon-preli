FROM node:20-alpine

WORKDIR /app

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

COPY package.json ./

RUN npm install --omit=dev && npm cache clean --force

COPY src ./src

USER nodejs

EXPOSE 5921

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5921/health || exit 1

CMD ["node", "src/gateway.js"]