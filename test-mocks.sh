#!/bin/bash

# Test script for WireMock API endpoints
# This script tests all the mock endpoints to verify they're working correctly

WIREMOCK_URL="http://wiremock-test:8080"
API_BASE="/api"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test an endpoint
test_endpoint() {
    local method=$1
    local path=$2
    local data=$3
    local description=$4
    local expected_status=${5:-200}
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${YELLOW}Testing: $description${NC}"
    echo "Method: $method"
    echo "URL: $WIREMOCK_URL$path"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$WIREMOCK_URL$path")
    else
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X GET "$WIREMOCK_URL$path")
    fi
    
    # Extract HTTP status code
    status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo $response | sed -e 's/HTTPSTATUS:.*//g')
    
    if [ "$status" = "$expected_status" ]; then
        echo -e "${GREEN}✓ SUCCESS - Status: $status${NC}"
        echo "Response: $(echo $body | jq . 2>/dev/null || echo $body)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED - Expected: $expected_status, Got: $status${NC}"
        echo "Response: $body"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo "==================================="
echo "WireMock API Mock Testing Script"
echo "==================================="

# Check if WireMock is running
echo -e "\n${YELLOW}Checking WireMock health...${NC}"
health_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$WIREMOCK_URL/__admin/health")
health_status=$(echo $health_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$health_status" = "200" ]; then
    echo -e "${GREEN}✓ WireMock is healthy${NC}"
else
    echo -e "${RED}✗ WireMock is not responding. Status: $health_status${NC}"
    echo "Make sure WireMock is running on $WIREMOCK_URL"
    exit 1
fi

# Test 1: Count users
test_endpoint "GET" "$API_BASE/count" "" "Count all users"

# Test 2: Search users (default)
test_endpoint "GET" "$API_BASE/search" "" "Search all users"

# Test 3: Search users with query parameter
test_endpoint "GET" "$API_BASE/search?q=john" "" "Search users with query parameter"

# Test 4: Search users with pagination
test_endpoint "GET" "$API_BASE/search?page=0&size=10" "" "Search users with pagination"

# Test 5: Find user by ID
test_endpoint "GET" "$API_BASE/find?type=id&id=user-1" "" "Find user by ID"

# Test 6: Find user by username
test_endpoint "GET" "$API_BASE/find?type=username&username=john.doe" "" "Find user by username"

# Test 7: Find user by email
test_endpoint "GET" "$API_BASE/find?type=email&email=john.doe@example.com" "" "Find user by email"

# Test 8: Find non-existent user
test_endpoint "GET" "$API_BASE/find?type=id&id=non-existent" "" "Find non-existent user" 404

# Test 9: Verify password for John
test_endpoint "POST" "$API_BASE/verify" '{"username": "john.doe", "password": "password123"}' "Verify password for John"

# Test 10: Verify password for Jane
test_endpoint "POST" "$API_BASE/verify" '{"username": "jane.smith", "password": "secret456"}' "Verify password for Jane"

# Test 11: Verify password with wrong credentials
test_endpoint "POST" "$API_BASE/verify" '{"username": "unknown", "password": "wrongpass"}' "Verify password with invalid credentials"

echo -e "\n==================================="
echo "Mock Testing Complete"
echo "==================================="

# Print test summary
echo -e "\n${YELLOW}TEST SUMMARY:${NC}"
echo "Total tests run: $TOTAL_TESTS"
echo -e "Tests passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Tests failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "\n${RED}✗ $FAILED_TESTS TEST(S) FAILED${NC}"
    exit 1
fi
