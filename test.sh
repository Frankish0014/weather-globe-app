#!/bin/bash

# Weather Globe App Testing Script
# Tests application functionality, load balancing, and deployment

set -e

# Configuration
LB_URL="http://localhost"
WEB01_URL="http://localhost:8081"
WEB02_URL="http://localhost:8082"
STATS_URL="http://localhost:8404/stats"
TEST_RESULTS_DIR="test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Create results directory
mkdir -p ${TEST_RESULTS_DIR}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a ${TEST_RESULTS_DIR}/test_log_${TIMESTAMP}.txt
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a ${TEST_RESULTS_DIR}/test_log_${TIMESTAMP}.txt
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a ${TEST_RESULTS_DIR}/test_log_${TIMESTAMP}.txt
}

log_test_result() {
    local test_name=$1
    local result=$2
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ $test_name${NC}" | tee -a ${TEST_RESULTS_DIR}/test_log_${TIMESTAMP}.txt
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ $test_name${NC}" | tee -a ${TEST_RESULTS_DIR}/test_log_${TIMESTAMP}.txt
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test functions
test_health_check() {
    log_info "Testing health checks..."
    
    # Test load balancer
    if curl -f -s ${LB_URL} > /dev/null; then
        log_test_result "Load Balancer Health Check" "PASS"
    else
        log_test_result "Load Balancer Health Check" "FAIL"
    fi
    
    # Test individual servers
    if curl -f -s ${WEB01_URL} > /dev/null; then
        log_test_result "Web01 Health Check" "PASS"
    else
        log_test_result "Web01 Health Check" "FAIL"
    fi
    
    if curl -f -s ${WEB02_URL} > /dev/null; then
        log_test_result "Web02 Health Check" "PASS"
    else
        log_test_result "Web02 Health Check" "FAIL"
    fi
}

test_load_balancing() {
    log_info "Testing load balancing..."
    
    local web01_count=0
    local web02_count=0
    local total_requests=20
    
    for i in $(seq 1 $total_requests); do
        local response=$(curl -s -H "X-Test-Request: $i" ${LB_URL} | head -n 1)
        local server_id=$(curl -s -I ${LB_URL} | grep -i "x-server-id" | cut -d: -f2 | tr -d ' \r\n' || echo "unknown")
        
        if [[ "$server_id" == *"web01"* ]] || [[ "$server_id" == *"weather-app-web01"* ]]; then
            web01_count=$((web01_count + 1))
        elif [[ "$server_id" == *"web02"* ]] || [[ "$server_id" == *"weather-app-web02"* ]]; then
            web02_count=$((web02_count + 1))
        fi
        
        sleep 0.1
    done
    
    log_info "Load balancing results: Web01: $web01_count, Web02: $web02_count"
    
    # Check if both servers received requests (allowing for some imbalance)
    if [ $web01_count -gt 0 ] && [ $web02_count -gt 0 ]; then
        log_test_result "Load Balancing Distribution" "PASS"
    else
        log_test_result "Load Balancing Distribution" "FAIL"
    fi
    
    # Save detailed results
    echo "Load Balancing Test Results - $(date)" > ${TEST_RESULTS_DIR}/load_balance_${TIMESTAMP}.txt
    echo "Total Requests: $total_requests" >> ${TEST_RESULTS_DIR}/load_balance_${TIMESTAMP}.txt
    echo "Web01 Requests: $web01_count" >> ${TEST_RESULTS_DIR}/load_balance_${TIMESTAMP}.txt
    echo "Web02 Requests: $web02_count" >> ${TEST_RESULTS_DIR}/load_balance_${TIMESTAMP}.txt
}

test_application_functionality() {
    log_info "Testing application functionality..."
    
    # Test static file serving
    local html_content=$(curl -s ${LB_URL})
    if echo "$html_content" | grep -q "WEATHER GLOBE"; then
        log_test_result "HTML Content Loading" "PASS"
    else
        log_test_result "HTML Content Loading" "FAIL"
    fi
    
    # Test CSS loading
    if curl -f -s ${LB_URL}/style.css > /dev/null; then
        log_test_result "CSS File Loading" "PASS"
    else
        log_test_result "CSS File Loading" "FAIL"
    fi
    
    # Test JavaScript loading
    if curl -f -s ${LB_URL}/scipt.js > /dev/null; then
        log_test_result "JavaScript File Loading" "PASS"
    else
        log_test_result "JavaScript File Loading" "FAIL"
    fi
    
    # Test required HTML elements
    if echo "$html_content" | grep -q "cityInput"; then
        log_test_result "Search Input Element Present" "PASS"
    else
        log_test_result "Search Input Element Present" "FAIL"
    fi
    
    if echo "$html_content" | grep -q "getCurrentLocationWeather"; then
        log_test_result "Location Button Present" "PASS"
    else
        log_test_result "Location Button Present" "FAIL"
    fi
}

test_performance() {
    log_info "Testing performance..."
    
    # Response time test
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' ${LB_URL})
    local response_time_ms=$(echo "$response_time * 1000" | bc)
    
    echo "Response time: ${response_time_ms}ms" >> ${TEST_RESULTS_DIR}/performance_${TIMESTAMP}.txt
    
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        log_test_result "Response Time (<2s)" "PASS"
    else
        log_test_result "Response Time (<2s)" "FAIL"
    fi
    
    # Concurrent requests test
    log_info "Testing concurrent requests..."
    ab -n 50 -c 5 -g ${TEST_RESULTS_DIR}/ab_results_${TIMESTAMP}.tsv ${LB_URL}/ \
        > ${TEST_RESULTS_DIR}/ab_summary_${TIMESTAMP}.txt 2>&1
    
    if [ $? -eq 0 ]; then
        log_test_result "Concurrent Requests (50 requests, 5 concurrent)" "PASS"
    else
        log_test_result "Concurrent Requests (50 requests, 5 concurrent)" "FAIL"
    fi
}

test_failover() {
    log_info "Testing failover capabilities..."
    
    # This test requires docker-compose setup
    if command -v docker-compose &> /dev/null; then
        # Stop one container
        docker-compose stop weather-app-1 2>/dev/null || true
        sleep 5
        
        # Test if load balancer still responds
        if curl -f -s ${LB_URL} > /dev/null; then
            log_test_result "Failover Test (Web01 Down)" "PASS"
        else
            log_test_result "Failover Test (Web01 Down)" "FAIL"
        fi
        
        # Restart the container
        docker-compose start weather-app-1 2>/dev/null || true
        sleep 10
        
        # Test if both are working again
        test_health_check
    else
        log_warning "Docker-compose not available, skipping failover test"
    fi
}

test_security_headers() {
    log_info "Testing security headers..."
    
    local headers=$(curl -s -I ${LB_URL})
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        log_test_result "X-Frame-Options Header Present" "PASS"
    else
        log_test_result "X-Frame-Options Header Present" "FAIL"
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        log_test_result "X-Content-Type-Options Header Present" "PASS"
    else
        log_test_result "X-Content-Type-Options Header Present" "FAIL"
    fi
    
    # Save headers for analysis
    echo "$headers" > ${TEST_RESULTS_DIR}/security_headers_${TIMESTAMP}.txt
}

generate_report() {
    log_info "Generating test report..."
    
    local report_file="${TEST_RESULTS_DIR}/test_report_${TIMESTAMP}.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Weather Globe App Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .summary { background: #e8f4f8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌤️ Weather Globe App - Test Report</h1>
        <p><strong>Test Run:</strong> $(date)</p>
        <p><strong>Timestamp:</strong> ${TIMESTAMP}</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p><strong>Total Tests:</strong> ${TOTAL_TESTS}</p>
        <p><strong class="pass">Tests Passed:</strong> ${TESTS_PASSED}</p>
        <p><strong class="fail">Tests Failed:</strong> ${TESTS_FAILED}</p>
        <p><strong>Success Rate:</strong> $(echo "scale=2; $TESTS_PASSED * 100 / $TOTAL_TESTS" | bc)%</p>
    </div>
    
    <h2>Test Details</h2>
    <p>See individual test result files in the test-results directory:</p>
    <ul>
        <li>test_log_${TIMESTAMP}.txt - Complete test log</li>
        <li>load_balance_${TIMESTAMP}.txt - Load balancing results</li>
        <li>performance_${TIMESTAMP}.txt - Performance metrics</li>
        <li>security_headers_${TIMESTAMP}.txt - Security headers analysis</li>
        <li>ab_summary_${TIMESTAMP}.txt - Apache Bench results</li>
    </ul>
    
    <h2>Recommendations</h2>
EOF

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "    <p class='pass'>✅ All tests passed! Your deployment is working correctly.</p>" >> "$report_file"
    else
        echo "    <p class='fail'>⚠️ Some tests failed. Please check the detailed logs and fix the issues.</p>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
    
    <h2>Next Steps</h2>
    <ol>
        <li>Review failed tests and fix any issues</li>
        <li>Take screenshots of the working application</li>
        <li>Document your deployment process</li>
        <li>Create your demo video</li>
        <li>Update your README with test results</li>
    </ol>
</body>
</html>
EOF

    log_info "Test report generated: $report_file"
}

# Main execution
main() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}Weather Globe App - Comprehensive Tests${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed"
        exit 1
    fi
    
    # Run tests
    test_health_check
    test_application_functionality
    test_load_balancing
    test_performance
    test_security_headers
    test_failover
    
    # Generate report
    generate_report
    
    # Summary
    echo
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Check the logs in ${TEST_RESULTS_DIR}/${NC}"
        exit 1
    fi
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi