# Use nginx as base image to serve static files
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy application files to nginx html directory
# Copy HTML file and rename it to index.html
COPY globe_weather_app.html /usr/share/nginx/html/index.html
COPY script.js /usr/share/nginx/html/script.js
COPY style.css /usr/share/nginx/html/style.css

# Create custom nginx configuration
RUN echo 'server {' > /etc/nginx/conf.d/default.conf && \
    echo '    listen 8080;' >> /etc/nginx/conf.d/default.conf && \
    echo '    server_name localhost;' >> /etc/nginx/conf.d/default.conf && \
    echo '    root /usr/share/nginx/html;' >> /etc/nginx/conf.d/default.conf && \
    echo '    index index.html;' >> /etc/nginx/conf.d/default.conf && \
    echo '    location / {' >> /etc/nginx/conf.d/default.conf && \
    echo '        try_files $uri $uri/ /index.html;' >> /etc/nginx/conf.d/default.conf && \
    echo '        add_header Cache-Control "no-cache, no-store, must-revalidate";' >> /etc/nginx/conf.d/default.conf && \
    echo '        add_header Pragma "no-cache";' >> /etc/nginx/conf.d/default.conf && \
    echo '        add_header Expires "0";' >> /etc/nginx/conf.d/default.conf && \
    echo '    }' >> /etc/nginx/conf.d/default.conf && \
    echo '    error_page 404 /index.html;' >> /etc/nginx/conf.d/default.conf && \
    echo '}' >> /etc/nginx/conf.d/default.conf

# Expose port 8080
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
