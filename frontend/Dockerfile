# Production Nginx Container for AgriConnect Flutter Web
FROM nginx:alpine

# Copy pre-built Flutter Web artifacts from build step
COPY build/web /usr/share/nginx/html

# Custom Nginx configuration with Cache-Control to prevent browser caching of stale web app bundles
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location ~* \.(html|js|json)$ { \
        root /usr/share/nginx/html; \
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0"; \
        expires -1; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
