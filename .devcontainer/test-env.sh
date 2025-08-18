#!/bin/bash

# Test Environment Management Script for Dev Container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build     Build the plugin JAR"
    echo "  start     Start Keycloak and WireMock services"
    echo "  stop      Stop the services"
    echo "  restart   Restart the services"
    echo "  logs      Show logs from services"
    echo "  status    Show status of services"
    echo "  test      Run basic connectivity tests"
    echo "  clean     Stop and remove all containers and volumes"
    echo "  help      Show this help message"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

build_plugin() {
    log_info "Building the plugin JAR..."
    cd "$SCRIPT_DIR/.."
    mvn clean package
    
    if [ ! -f "target/remote-user-federation-jar-with-dependencies.jar" ]; then
        log_error "Plugin JAR not found after build. Build may have failed."
        exit 1
    fi
    
    log_info "Plugin JAR built successfully"
}

start_services() {
    log_info "Starting Keycloak and WireMock services..."
    cd "$SCRIPT_DIR"
    
    # Check if plugin JAR exists
    if [ ! -f "../target/remote-user-federation-jar-with-dependencies.jar" ]; then
        log_warn "Plugin JAR not found. Building first..."
        build_plugin
    fi
    
    # Start only the services (not vscode which is already running)
    docker-compose up -d keycloak wiremock
    log_info "Services starting. Use 'logs' command to monitor startup."
    log_info "Keycloak Admin Console: http://localhost:8080/admin (admin/admin)"
    log_info "WireMock Admin: http://localhost:8081/__admin"
}

stop_services() {
    log_info "Stopping services..."
    cd "$SCRIPT_DIR"
    docker-compose stop keycloak wiremock
}

restart_services() {
    log_info "Restarting services..."
    stop_services
    start_services
}

show_logs() {
    cd "$SCRIPT_DIR"
    docker-compose logs -f keycloak wiremock
}

show_status() {
    cd "$SCRIPT_DIR"
    docker-compose ps keycloak wiremock
}

clean_services() {
    log_info "Cleaning up services (removing containers and volumes)..."
    cd "$SCRIPT_DIR"
    docker-compose down -v keycloak wiremock
    log_info "Cleanup complete"
}

run_tests() {
    log_info "Running basic connectivity tests..."
    
    # Test WireMock
    log_info "Testing WireMock..."
    if curl -f -s http://localhost:8081/__admin/health >/dev/null; then
        log_info "✓ WireMock is responding"
    else
        log_error "✗ WireMock is not responding"
        return 1
    fi
    
    # Test Keycloak
    log_info "Testing Keycloak..."
    if curl -f -s http://localhost:8080/health/ready >/dev/null; then
        log_info "✓ Keycloak is ready"
    else
        log_error "✗ Keycloak is not ready"
        return 1
    fi
    
    # Test mock endpoints
    log_info "Testing mock endpoints..."
    if curl -f -s "http://localhost:8081/api/users/count" >/dev/null; then
        log_info "✓ Mock endpoints are responding"
    else
        log_error "✗ Mock endpoints are not responding"
        return 1
    fi
    
    log_info "All tests passed!"
}

# Main script logic
case "${1:-help}" in
    build)
        build_plugin
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    clean)
        clean_services
        ;;
    test)
        run_tests
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        log_error "Unknown command: $1"
        print_usage
        exit 1
        ;;
esac
