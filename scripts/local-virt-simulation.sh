#!/bin/bash

# Local OpenShift Virtualization Simulation
# This script sets up a local container environment to simulate OpenShift Virtualization
# while waiting for ROSA quota approval
# Usage: ./local-virt-simulation.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites for local simulation
check_local_prerequisites() {
    log_info "Checking local prerequisites for OpenShift Virtualization simulation..."
    
    local missing_tools=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing_tools+=("kubectl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install missing tools and try again"
        return 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker Desktop"
        return 1
    fi
    
    log_success "Local prerequisites satisfied!"
    return 0
}

# Create local simulation environment
create_local_simulation() {
    log_info "Creating local OpenShift Virtualization simulation environment..."
    
    # Create simulation directory
    mkdir -p ../simulation/local-virt
    cd ../simulation/local-virt
    
    # Create docker-compose for local virtualization simulation
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  linux-server-1:
    image: ubuntu:22.04
    container_name: virt-linux-server-1
    hostname: linux-server-1
    command: bash -c "
      apt-get update && 
      apt-get install -y openssh-server net-tools iproute2 curl wget vim nginx &&
      echo 'root:password123' | chpasswd &&
      service ssh start &&
      service nginx start &&
      tail -f /dev/null
    "
    ports:
      - "2201:22"
      - "8081:80"
    networks:
      virt-network:
        ipv4_address: 172.20.0.10
    cap_add:
      - NET_ADMIN
    volumes:
      - ./shared:/shared

  linux-server-2:
    image: ubuntu:22.04
    container_name: virt-linux-server-2
    hostname: linux-server-2
    command: bash -c "
      apt-get update && 
      apt-get install -y openssh-server net-tools iproute2 curl wget vim apache2 &&
      echo 'root:password123' | chpasswd &&
      service ssh start &&
      service apache2 start &&
      tail -f /dev/null
    "
    ports:
      - "2202:22"
      - "8082:80"
    networks:
      virt-network:
        ipv4_address: 172.20.0.11
    cap_add:
      - NET_ADMIN
    volumes:
      - ./shared:/shared

  network-testing-tools:
    image: nicolaka/netshoot
    container_name: virt-network-tools
    hostname: network-tools
    command: sleep infinity
    networks:
      virt-network:
        ipv4_address: 172.20.0.20
    volumes:
      - ./shared:/shared

  dns-server:
    image: coredns/coredns:latest
    container_name: virt-dns-server
    hostname: dns-server
    ports:
      - "5353:53/udp"
    networks:
      virt-network:
        ipv4_address: 172.20.0.53
    volumes:
      - ./coredns:/etc/coredns
    command: -conf /etc/coredns/Corefile

networks:
  virt-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  shared:
EOF

    # Create CoreDNS configuration
    mkdir -p coredns
    cat > coredns/Corefile << 'EOF'
.:53 {
    hosts {
        172.20.0.10 linux-server-1.virt.local
        172.20.0.11 linux-server-2.virt.local
        172.20.0.20 network-tools.virt.local
        fallthrough
    }
    forward . 8.8.8.8 8.8.4.4
    log
    errors
}
EOF

    # Create shared directory
    mkdir -p shared
    
    # Create network testing scripts
    cat > shared/test-network.sh << 'EOF'
#!/bin/bash

echo "=== OpenShift Virtualization Network Testing ==="
echo ""

echo "🔍 Testing DNS Resolution:"
nslookup linux-server-1.virt.local 172.20.0.53
nslookup linux-server-2.virt.local 172.20.0.53

echo ""
echo "🔍 Testing Connectivity:"
ping -c 3 172.20.0.10
ping -c 3 172.20.0.11

echo ""
echo "🔍 Testing HTTP Services:"
curl -s -o /dev/null -w "%{http_code}" http://172.20.0.10 && echo " - Linux Server 1 HTTP"
curl -s -o /dev/null -w "%{http_code}" http://172.20.0.11 && echo " - Linux Server 2 HTTP"

echo ""
echo "🔍 Port Scanning:"
nmap -p 22,80 172.20.0.10-11

echo ""
echo "🔍 Network Information:"
ip route
ip addr show
EOF

    chmod +x shared/test-network.sh
    
    log_success "Local simulation environment created!"
}

# Start the simulation
start_simulation() {
    log_info "Starting OpenShift Virtualization simulation..."
    
    cd ../simulation/local-virt
    
    # Start services
    docker-compose up -d
    
    log_info "Waiting for services to start..."
    sleep 15
    
    # Check service status
    log_info "Service status:"
    docker-compose ps
    
    log_success "Simulation environment is running!"
}

# Show usage instructions
show_usage_instructions() {
    echo ""
    log_success "🎉 OpenShift Virtualization Simulation Ready!"
    echo ""
    log_info "Available services:"
    echo "  🖥️  Linux Server 1: http://localhost:8081 (SSH: localhost:2201)"
    echo "  🖥️  Linux Server 2: http://localhost:8082 (SSH: localhost:2202)" 
    echo "  🔧 Network Tools: docker exec -it virt-network-tools bash"
    echo "  🌐 DNS Server: 172.20.0.53"
    echo ""
    
    log_info "Testing commands:"
    echo "  # SSH to servers"
    echo "  ssh root@localhost -p 2201  # Password: password123"
    echo "  ssh root@localhost -p 2202  # Password: password123"
    echo ""
    echo "  # Run network tests"
    echo "  docker exec -it virt-network-tools /shared/test-network.sh"
    echo ""
    echo "  # Access web services"
    echo "  curl http://localhost:8081"
    echo "  curl http://localhost:8082"
    echo ""
    echo "  # Check container networking"
    echo "  docker exec -it virt-linux-server-1 ip addr"
    echo "  docker exec -it virt-linux-server-2 ip route"
    echo ""
    
    log_info "Stop simulation:"
    echo "  docker-compose down"
    echo ""
    
    log_warning "This simulates OpenShift Virtualization networking concepts locally"
    log_warning "Actual ROSA cluster will be available once quota is approved"
}

# Monitor quota status
monitor_quota_status() {
    log_info "Monitoring AWS quota request status..."
    
    local quota_status=$(aws service-quotas list-requested-service-quota-change-history \
        --max-items 5 \
        --query 'RequestedQuotas[0].Status' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    echo "Current quota request status: $quota_status"
    
    case $quota_status in
        "PENDING")
            log_warning "Quota request is still pending. Typical processing time: 24-48 hours"
            ;;
        "APPROVED")
            log_success "Quota request approved! You can now create ROSA clusters"
            echo "Run: ./scripts/create-test-cluster-for-virt.sh"
            ;;
        "DENIED")
            log_error "Quota request was denied. You may need to contact AWS support"
            ;;
        *)
            log_info "Unable to determine quota status. Check AWS Console"
            ;;
    esac
}

# Main execution
main() {
    echo ""
    echo "========================================="
    echo "🖥️  Local OpenShift Virtualization Simulation"
    echo "========================================="
    echo ""
    
    case ${1:-start} in
        start)
            if check_local_prerequisites; then
                create_local_simulation
                start_simulation
                show_usage_instructions
            fi
            ;;
        stop)
            log_info "Stopping simulation..."
            cd ../simulation/local-virt 2>/dev/null && docker-compose down
            log_success "Simulation stopped"
            ;;
        status)
            log_info "Checking simulation status..."
            cd ../simulation/local-virt 2>/dev/null && docker-compose ps
            ;;
        test)
            log_info "Running network tests..."
            docker exec -it virt-network-tools /shared/test-network.sh
            ;;
        quota)
            monitor_quota_status
            ;;
        clean)
            log_info "Cleaning up simulation..."
            cd ../simulation/local-virt 2>/dev/null && docker-compose down -v
            rm -rf ../simulation
            log_success "Simulation cleaned up"
            ;;
        *)
            echo "Usage: $0 [start|stop|status|test|quota|clean]"
            echo "  start  - Start the simulation (default)"
            echo "  stop   - Stop the simulation"
            echo "  status - Check simulation status"
            echo "  test   - Run network tests"
            echo "  quota  - Check AWS quota status"
            echo "  clean  - Clean up everything"
            ;;
    esac
}

main "$@"
