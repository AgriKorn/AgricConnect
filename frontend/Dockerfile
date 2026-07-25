# Production Nginx Container for AgriConnect Flutter Web
FROM nginx:alpine

# Copy pre-built Flutter Web artifacts from build step
COPY build/web /usr/share/nginx/html

# Custom Nginx configuration for single-page app (SPA) routing
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
