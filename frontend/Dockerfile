# ==============================================================================
# Dockerfile - Frontend React + Vite
# ==============================================================================

FROM node:20-alpine as builder

WORKDIR /app

COPY package*.json ./

# Instalar TODAS as dependências (incluindo devDependencies como vite)
# Não usar --only=production aqui, pois vite é devDependency!
RUN npm ci

COPY . .

RUN npm run build

# ==============================================================================
# RUNTIME - NGINX
# ==============================================================================
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
