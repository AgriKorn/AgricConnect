# Multi-stage Docker build for AgriConnect Flutter Web Frontend
FROM ghcr.io/cirrusci/flutter:stable AS build-stage

WORKDIR /app

# Copy dependency files and fetch packages
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy all frontend source files
COPY . .

# Build production web bundle
RUN flutter build web --release --base-href "/"

# Stage 2: Production Nginx Server
FROM nginx:alpine

# Copy built web artifacts to Nginx html directory
COPY --from=build-stage /app/build/web /usr/share/nginx/html

# Custom Nginx configuration for single-page app (SPA) client-side routing
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
