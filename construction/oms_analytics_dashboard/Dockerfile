FROM nginx:alpine

# Copy dashboard files
COPY index.html /usr/share/nginx/html/

# Create custom nginx config for SPA
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # Enable CORS for API calls \
    add_header Access-Control-Allow-Origin *; \
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS"; \
    add_header Access-Control-Allow-Headers "Content-Type, Authorization"; \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

