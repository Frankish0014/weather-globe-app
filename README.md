🌤️ Weather Globe - Global Weather Search Application
A responsive web application that provides real-time weather information for cities worldwide using the OpenWeatherMap API. The app features location-based weather detection and manual city search capabilities.
📋 Table of Contents

Features
API Integration
Local Development
Docker Containerization
Deployment Instructions
Load Balancer Configuration
Testing & Verification
Security Considerations
Troubleshooting

✨ Features

Real-time Weather Data: Fetches current weather conditions from OpenWeatherMap API
Location Detection: Automatically detects user's location for instant weather updates
Manual Search: Search for weather in any city worldwide
Responsive Design: Works seamlessly on desktop, tablet, and mobile devices
Interactive UI: Smooth animations and hover effects for enhanced user experience
Error Handling: Comprehensive error handling for API failures and network issues
Data Filtering: Users can interact with weather data through search and location features

🔌 API Integration
This application uses the OpenWeatherMap API to fetch weather data:

API Documentation: OpenWeatherMap API Docs
Endpoint Used: Current Weather Data API
Data Retrieved: Temperature, humidity, wind speed, pressure, weather conditions, and icons
Rate Limits: Free tier allows 1,000 calls/day

API Credits
Special thanks to OpenWeatherMap for providing reliable weather data services that make this application possible.
🏠 Local Development
Prerequisites

Modern web browser (Chrome, Firefox, Safari, Edge)
Internet connection for API calls
OpenWeatherMap API key

Running Locally

Clone the repository:
bashgit clone <your-repo-url>
cd weather-globe-app

Open global_weather_app.html in your web browser, or serve using a simple HTTP server:
bash# Using Python 3
python -m http.server 8000

# Using Node.js
npx http-server

Navigate to http://localhost:8000 in your browser

🐳 Docker Containerization
Image Details

Docker Hub Repository: <your-dockerhub-username>/weather-globe:v1
Base Image: nginx:alpine
Port: 8080
Size: ~25MB (optimized with Alpine Linux)

Build Instructions

Build the Docker image:
bashdocker build -t <your-dockerhub-username>/weather-globe:v1 .

Test locally:
bashdocker run -p 8080:8080 <your-dockerhub-username>/weather-globe:v1

Verify the application:
bashcurl http://localhost:8080
# Should return the HTML content of the application

Push to Docker Hub:
bashdocker login
docker push <your-dockerhub-username>/weather-globe:v1

# Tag as latest for convenience
docker tag <your-dockerhub-username>/weather-globe:v1 <your-dockerhub-username>/weather-globe:latest
docker push <your-dockerhub-username>/weather-globe:latest


🚀 Deployment Instructions
Deploy on Web Servers (Web01 & Web02)

SSH into each web server:
bashssh user@web-01
ssh user@web-02

Pull and run the container on each server:
bash# Pull the latest image
docker pull <your-dockerhub-username>/weather-globe:v1

# Stop any existing container
docker stop weather-app || true
docker rm weather-app || true

# Run the new container
docker run -d \
  --name weather-app \
  --restart unless-stopped \
  -p 8080:8080 \
  <your-dockerhub-username>/weather-globe:v1

Verify each deployment:
bash# Test from within each server
curl http://localhost:8080

# Check container status
docker ps
docker logs weather-app

Ensure internal accessibility:
bash# From web-01, test web-02
curl http://web-02:8080

# From web-02, test web-01
curl http://web-01:8080


⚖️ Load Balancer Configuration
HAProxy Configuration

SSH into the load balancer (lb-01):
bashssh user@lb-01

Update HAProxy configuration (/etc/haproxy/haproxy.cfg):
haproxyglobal
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend weather_frontend
    bind *:80
    default_backend weather_backend

backend weather_backend
    balance roundrobin
    option httpchk GET /
    server web01 172.20.0.11:8080 check
    server web02 172.20.0.12:8080 check

Reload HAProxy configuration:
bash# Method 1: Graceful reload (recommended)
docker exec -it lb-01 sh -c 'haproxy -sf $(pidof haproxy) -f /etc/haproxy/haproxy.cfg'

# Method 2: Restart container if needed
docker restart lb-01

Verify HAProxy status:
bashdocker exec -it lb-01 sh -c 'echo "show stat" | socat stdio /var/run/haproxy.sock'


🧪 Testing & Verification
End-to-End Testing

Test load balancer functionality:
bash# From your host machine, test multiple requests
for i in {1..10}; do
  curl -s http://localhost | grep -o "Web[0-9][0-9]" || echo "Request $i"
  sleep 1
done

Verify round-robin distribution:
bash# Check server response headers (if implemented)
curl -I http://localhost

# Monitor HAProxy logs
docker logs lb-01 | tail -20

Test application functionality:

Open http://localhost in browser
Test location detection feature
Search for different cities (Kigali, London, New York)
Verify error handling with invalid city names
Test responsive design on different screen sizes



Load Balancing Evidence
Document your testing with:

Screenshots of the application running
HAProxy stats page showing both servers active
Network logs showing requests distributed between servers
Performance metrics during load testing

Health Check Verification
bash# Verify both servers are healthy
curl http://localhost/health  # Should return 200 OK from either server

# Check HAProxy backend status
curl http://localhost/haproxy-stats  # If stats page is enabled
🔒 Security Considerations
API Key Management
The current implementation includes the API key in the client-side code. For production deployment, consider these security improvements:

Environment Variables (Recommended):
bash# Run container with environment variable
docker run -d \
  --name weather-app \
  --restart unless-stopped \
  -p 8080:8080 \
  -e OPENWEATHER_API_KEY=your-api-key-here \
  <your-dockerhub-username>/weather-globe:v1

Backend Proxy (Most Secure):

Create a backend service to proxy API requests
Keep API keys server-side only
Add rate limiting and request validation


Docker Secrets (For Docker Swarm):
bashecho "your-api-key" | docker secret create openweather_key -


Additional Security Measures

Enable HTTPS in production
Implement CORS policies
Add rate limiting to prevent abuse
Regular security updates of base images
Input validation and sanitization

🔧 Troubleshooting
Common Issues

Container won't start:
bashdocker logs weather-app
# Check for port conflicts or configuration errors

API key errors:

Verify API key is valid at OpenWeatherMap
Check API usage limits
Ensure proper environment variable setup


Load balancer not distributing traffic:
bash# Check HAProxy configuration
docker exec -it lb-01 cat /etc/haproxy/haproxy.cfg

# Verify backend server health
docker exec -it lb-01 sh -c 'echo "show stat" | socat stdio /var/run/haproxy.sock'

CORS issues:

Add proper CORS headers in nginx configuration
Ensure API endpoints allow browser requests



Debugging Commands
bash# Check container status
docker ps -a

# View application logs
docker logs weather-app -f

# Inspect container
docker inspect weather-app

# Test internal connectivity
docker exec -it weather-app ping web-01
📊 Performance Monitoring
Metrics to Monitor

Response times for API calls
Container resource usage (CPU, memory)
Load balancer request distribution
Error rates and types

Monitoring Commands
bash# Container resource usage
docker stats weather-app

# Network connectivity
docker exec -it weather-app netstat -tlnp

# Application performance
curl -w "@curl-format.txt" -o /dev/null -s http://localhost
🎯 Future Enhancements

 Add weather forecasts (5-day/16-day)
 Implement user favorites for cities
 Add weather maps integration
 Implement offline caching
 Add push notifications for weather alerts
 Multi-language support
 Weather data visualization charts
 Progressive Web App (PWA) features

📄 License
This project is for educational purposes. Please respect the OpenWeatherMap API terms of service.
🤝 Contributing
Feel free to fork this project and submit pull requests for improvements.

Created by: Frank Ishimwe
Last Updated: 30th/7/2025
Version: 1.0