#!/bin/bash

# Weather Globe App Deployment Script
# Usage: ./deploy.sh <dockerhub-username> <version>

set -e  # Exit on any error

# Configuration
DOCKERHUB_USERNAME=${1:-"your-dockerhub-username"}
APP_NAME="weather-globe"
VERSION=${2:-"v1"}
IMAGE_NAME="${DOCKERHUB_USERNAME}/${APP_NAME}:${VERSION}"
CONTAINER_NAME="weather-app"
PORT=8080

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

# Check if Docker is installed and running
check_docker() {
    print_header "Checking Docker Installation"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker and try again."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    print_status "Docker is installed and running ✓"
}

# Build Docker image
build_image() {
    print_header "Building Docker Image"
    
    print_status "Building ${IMAGE_NAME}..."
    docker build -t ${IMAGE_NAME} .
    
    # Tag as latest
    docker tag ${IMAGE_NAME} ${DOCKERHUB_USERNAME}/${APP_NAME}:latest
    
    print_status "Docker image built successfully ✓"
}

# Test image locally
test_local() {
    print_header "Testing Image Locally"
    
    # Stop any existing container
    if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
        print_warning "Stopping existing container..."
        docker stop ${CONTAINER_NAME}
        docker rm ${CONTAINER_NAME}
    fi
    
    # Run container
    print_status "Starting container on port ${PORT}..."
    docker run -d --name ${CONTAINER_NAME} -p ${PORT}:${PORT} ${IMAGE_NAME}
    
    # Wait for container to start
    sleep 5
    
    # Test endpoint
    print_status "Testing application endpoint..."
    if curl -f -s http://localhost:${PORT} > /dev/null; then
        print_status "Application is responding ✓"
    else
        print_error "Application is not responding"
        docker logs ${CONTAINER_NAME}
        exit 1
    fi
    
    # Clean up test container
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
}

# Push to Docker Hub
push_image() {
    print_header "Pushing to Docker Hub"
    
    print_status "Logging into Docker Hub..."
    if ! docker login; then
        print_error "Failed to login to Docker Hub"
        exit 1
    fi
    
    print_status "Pushing ${IMAGE_NAME}..."
    docker push ${IMAGE_NAME}
    
    print_status "Pushing latest tag..."
    docker push ${DOCKERHUB_USERNAME}/${APP_NAME}:latest
    
    print_status "Images pushed successfully ✓"
}

# Deploy to web servers
deploy_to_servers() {
    print_header "Deployment Instructions for Web Servers"
    
    cat << EOF
${GREEN}Copy and run the following commands on each web server (web-01, web-02):${NC}

${YELLOW}1. SSH into each server:${NC}
   ssh user@web-01
   ssh user@web-02

${YELLOW}2. Pull and run the container:${NC}
   docker pull ${IMAGE_NAME}
   
   # Stop existing container (if any)
   docker stop weather-app || true
   docker rm weather-app || true
   
   # Run new container
   docker run -d \\
     --name weather-app \\
     --restart unless-stopped \\
     -p 8080:8080 \\
     ${IMAGE_NAME}

${YELLOW}3. Verify deployment:${NC}
   docker ps
   curl http://localhost:8080
   docker logs weather-app

${YELLOW}4. Test internal connectivity:${NC}
   # From web-01, test web-02:
   curl http://web-02:8080
   
   # From web-02, test web-01:
   curl http://web-01:8080

EOF
}

# Load balancer configuration
configure_lb() {
    print_header "Load Balancer Configuration"
    
    cat << EOF
${GREEN}Configure HAProxy on lb-01:${NC}

${YELLOW}1. SSH into load balancer:${NC}
   ssh user@lb-01

${YELLOW}2. Update HAProxy configuration:${NC}
   # Edit /etc/haproxy/haproxy.cfg or use the provided haproxy.cfg file
   
${YELLOW}3. Reload HAProxy:${NC}
   docker exec -it lb-01 sh -c 'haproxy -sf \$(pidof haproxy) -f /etc/haproxy/haproxy.cfg'

${YELLOW}4. Test load balancing:${NC}
   # Run multiple requests to see round-robin in action
   for i in {1..10}; do curl -s http://localhost && echo; done

EOF
}

# Testing instructions
testing_instructions() {
    print_header "Testing & Verification"
    
    cat << EOF
${GREEN}Comprehensive Testing Steps:${NC}

${YELLOW}1. Functional Testing:${NC}
   - Open http://localhost in browser
   - Test location detection
   - Search for cities: Kigali, London, New York
   - Test error handling with invalid city names
   - Test on mobile/tablet (responsive design)

${YELLOW}2. Load Balancer Testing:${NC}
   # Test multiple requests
   for i in {1..20}; do
     curl -s -I http://localhost | grep "X-Server-ID" || echo "Request \$i"
     sleep 1
   done

${YELLOW}3. Health Check Testing:${NC}
   # Check HAProxy stats
   curl http://localhost/haproxy-stats
   
   # Check individual servers
   curl http://web-01:8080
   curl http://web-02:8080

${YELLOW}4. Performance Testing:${NC}
   # Simple load test
   ab -n 100 -c 10 http://localhost/

${YELLOW}5. Container Monitoring:${NC}
   docker stats weather-app
   docker logs weather-app -f

EOF
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        print_error "Usage: $0 <dockerhub-username> [version]"
        print_error "Example: $0 johndoe v1.0"
        exit 1
    fi
    
    print_header "Weather Globe App Deployment"
    echo -e "${BLUE}Docker Hub Username: ${DOCKERHUB_USERNAME}${NC}"
    echo -e "${BLUE}App Name: ${APP_NAME}${NC}"
    echo -e "${BLUE}Version: ${VERSION}${NC}"
    echo -e "${BLUE}Full Image Name: ${IMAGE_NAME}${NC}"
    echo ""
    
    check_docker
    build_image
    test_local
    push_image
    deploy_to_servers
    configure_lb
    testing_instructions
    
    print_header "Deployment Preparation Complete!"
    print_status "Next steps:"
    echo "  1. Follow the server deployment instructions above"
    echo "  2. Configure the load balancer"
    echo "  3. Run the testing procedures"
    echo "  4. Document your results with screenshots"
    echo ""
    print_status "Image available at: https://hub.docker.com/r/${DOCKERHUB_USERNAME}/${APP_NAME}"
}

# Run main function with all arguments
main "$@"