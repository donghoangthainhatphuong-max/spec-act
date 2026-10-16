# ---- build the static site ----------------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# Only the base path is baked in; every other VITE_* value is applied at container start.
ARG VITE_BASE_PATH=/
ENV VITE_BASE_PATH=${VITE_BASE_PATH}
RUN npm run build

# ---- serve it (no backend, non-root) -------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine
USER root
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/security-headers.conf.tpl /etc/nginx/security-headers.conf.tpl
COPY docker/40-specact-env.sh /docker-entrypoint.d/40-specact-env.sh
COPY --from=build /app/dist /usr/share/nginx/html
RUN chmod +x /docker-entrypoint.d/40-specact-env.sh
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
