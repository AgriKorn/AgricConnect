# Production Nginx Container for AgriConnect Flutter Web
FROM nginx:alpine

# Copy pre-built Flutter Web artifacts from build step
COPY build/web /usr/share/nginx/html

# index.html must always be revalidated so a fresh visit picks up the latest
# deploy's bundle references — it's tiny, so revalidating it costs nothing.
# Everything else (main.dart.js, canvaskit, assets — several MB combined) used
# no-store, which forced a full re-download of the whole app on every single
# page load instead of a fast 304 when unchanged. no-cache still revalidates
# on every request (so a new deploy is picked up immediately, same safety as
# before) but lets the browser skip re-downloading the body when nothing
# changed, which is the actual fix for "the app takes forever to open."
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location = /index.html { \
        root /usr/share/nginx/html; \
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0"; \
        expires -1; \
    } \
    location ~* \.(js|json|wasm)$ { \
        root /usr/share/nginx/html; \
        add_header Cache-Control "no-cache, must-revalidate"; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
