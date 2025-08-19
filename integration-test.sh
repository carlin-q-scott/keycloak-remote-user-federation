#!/bin/bash

# Integration test script for Keycloak Remote User Federation
# Tests the complete login flow and header forwarding functionality

# Configuration
KEYCLOAK_URL="http://keycloak:8080"
WIREMOCK_URL="http://wiremock:8080"
REALM="test"
FORWARDED_HEADER="X-My-Forwarded-Header"
FORWARDED_VALUE="Testing123"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to log test results
log_test() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ -n "$details" ] && echo "  Details: $details"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        [ -n "$details" ] && echo "  Details: $details"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to clear WireMock request history
clear_wiremock_history() {
    echo -e "\n${BLUE}Clearing WireMock request history...${NC}"
    curl -s -X DELETE "$WIREMOCK_URL/__admin/requests" > /dev/null
    echo "Request history cleared"
}

# Function to get WireMock request history
get_wiremock_requests() {
    curl -s -X GET "$WIREMOCK_URL/__admin/requests" | jq .
}

# Function to check if a request contains the forwarded header
check_header_in_requests() {
    local requests=$(curl -s -X GET "$WIREMOCK_URL/__admin/requests")
    local header_count=$(echo "$requests" | jq --arg header "$FORWARDED_HEADER" --arg value "$FORWARDED_VALUE" '[.requests[]? | select(.request.headers[$header]? == $value)] | length' 2>/dev/null || echo "0")
    echo "$header_count"
}

# Function to perform login test
login_test() {
    local username="$1"
    local password="$2"
    
    echo -e "\n${YELLOW}Starting login test for user: $username${NC}"
    
    # Create a cookie jar for this session
    local cookie_jar=$(mktemp)
    
    # Step 1: Navigate to the account page to initiate login
    echo "Step 1: Navigating to account page..."
    local initial_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "$FORWARDED_HEADER: $FORWARDED_VALUE" \
        -c "$cookie_jar" \
        -L \
        "$KEYCLOAK_URL/realms/$REALM/account")
    
    local initial_status=$(echo "$initial_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    local initial_body=$(echo "$initial_response" | sed -e 's/HTTPSTATUS:.*//g')
    
    if [ "$initial_status" != "200" ]; then
        log_test "Initial navigation to account page" "FAIL" "HTTP status: $initial_status"
        rm -f "$cookie_jar"
        return 1
    fi
    
    # Step 2: Check if we got a login form (look for login action URL)
    local login_action=$(echo "$initial_body" | grep -o 'action="[^"]*"' | head -1 | sed 's/action="//;s/"//')
    
    if [ -z "$login_action" ]; then
        log_test "Finding login form" "FAIL" "No login form action found in response"
        rm -f "$cookie_jar"
        return 1
    fi
    
    echo "Step 2: Found login form with action: $login_action"
    
    # Step 3: Submit login credentials
    echo "Step 3: Submitting login credentials..."
    local login_response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -H "$FORWARDED_HEADER: $FORWARDED_VALUE" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -b "$cookie_jar" \
        -c "$cookie_jar" \
        -L \
        -d "username=$username&password=$password" \
        "$login_action")
    
    local login_status=$(echo "$login_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    local login_body=$(echo "$login_response" | sed -e 's/HTTPSTATUS:.*//g')
    
    # Clean up cookie jar
    rm -f "$cookie_jar"
    
    # Step 4: Check if login was successful
    # A successful login should redirect us to the account page without a login form
    if [ "$login_status" = "200" ] && ! echo "$login_body" | grep -q 'id="kc-form-login"'; then
        log_test "Login for user $username" "PASS" "Successfully logged in"
        return 0
    else
        # Check if there's an error message
        local error_msg=$(echo "$login_body" | grep -o '<span class="kc-feedback-text">[^<]*</span>' | sed 's/<[^>]*>//g')
        if [ -n "$error_msg" ]; then
            log_test "Login for user $username" "FAIL" "Login failed with error: $error_msg"
        else
            log_test "Login for user $username" "FAIL" "Login failed - HTTP status: $login_status"
        fi
        return 1
    fi
}

# Function to verify header forwarding
verify_header_forwarding() {
    echo -e "\n${YELLOW}Verifying header forwarding...${NC}"
    
    # Get the number of requests that include our forwarded header
    local header_requests=$(check_header_in_requests)
    
    if [ "$header_requests" -gt "0" ]; then
        log_test "Header forwarding verification" "PASS" "$header_requests requests contained the $FORWARDED_HEADER header"
        return 0
    else
        log_test "Header forwarding verification" "FAIL" "No requests contained the $FORWARDED_HEADER header"
        
        # Show all requests for debugging
        echo -e "\n${BLUE}All WireMock requests for debugging:${NC}"
        get_wiremock_requests
        return 1
    fi
}

# Main test execution
echo "========================================"
echo "Keycloak Remote User Federation Integration Tests"
echo "========================================"

# Check if services are running
echo -e "\n${BLUE}Checking service availability...${NC}"

# Check Keycloak
keycloak_health=$(curl -s -w "%{http_code}" -o /dev/null "$KEYCLOAK_URL/realms/$REALM")
if [ "$keycloak_health" = "200" ]; then
    echo -e "${GREEN}✓ Keycloak is accessible${NC}"
else
    echo -e "${RED}✗ Keycloak is not accessible (HTTP $keycloak_health)${NC}"
    exit 1
fi

# Check WireMock
wiremock_health=$(curl -s -w "%{http_code}" -o /dev/null "$WIREMOCK_URL/__admin/health")
if [ "$wiremock_health" = "200" ]; then
    echo -e "${GREEN}✓ WireMock is accessible${NC}"
else
    echo -e "${RED}✗ WireMock is not accessible (HTTP $wiremock_health)${NC}"
    exit 1
fi

# Clear WireMock request history before starting tests
clear_wiremock_history

# Test 1: Successful login for john.doe
login_test "john.doe" "password123"

# Test 2: Verify header forwarding
verify_header_forwarding

# Print test summary
echo -e "\n========================================"
echo "Integration Test Summary"
echo "========================================"

echo -e "\n${YELLOW}TEST RESULTS:${NC}"
echo "Total tests run: $TOTAL_TESTS"
echo -e "Tests passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Tests failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ ALL INTEGRATION TESTS PASSED${NC}"
    exit 0
else
    echo -e "\n${RED}✗ $FAILED_TESTS INTEGRATION TEST(S) FAILED${NC}"
    exit 1
fi
