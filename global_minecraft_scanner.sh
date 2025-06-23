#!/bin/bash

# Global Minecraft Server Scanner
# Scans the entire IPv4 internet for Minecraft servers
# Uses masscan for discovery, nmap for verification, nc for banner grabbing

echo "========================================"
echo "    GLOBAL MINECRAFT SERVER SCANNER    "
echo "========================================"
echo "WARNING: This scans the ENTIRE INTERNET!"
echo "Use responsibly and ethically only!"
echo "========================================"
echo

# Configuration
MINECRAFT_PORT=25565
DEFAULT_SCAN_RATE=5000  # Aggressive rate for global scanning
OUTPUT_DIR="global_minecraft_scan"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXCLUDE_RANGES=(
    "255.255.255.255"    # Required by masscan
    "0.0.0.0/8"          # "This" network
    "127.0.0.0/8"        # Loopback
    "169.254.0.0/16"     # Link-local
    "224.0.0.0/4"        # Multicast
    "240.0.0.0/4"        # Reserved
    "10.0.0.0/8"         # Private RFC1918
    "172.16.0.0/12"      # Private RFC1918  
    "192.168.0.0/16"     # Private RFC1918
)

# File paths
MASSCAN_OUTPUT="$OUTPUT_DIR/masscan_global_$TIMESTAMP.txt"
VERIFIED_OUTPUT="$OUTPUT_DIR/verified_servers_$TIMESTAMP.txt" 
BANNER_OUTPUT="$OUTPUT_DIR/server_banners_$TIMESTAMP.txt"
SUMMARY_OUTPUT="$OUTPUT_DIR/global_summary_$TIMESTAMP.txt"
LOG_FILE="$OUTPUT_DIR/scan_log_$TIMESTAMP.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for masscan to work"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("masscan" "nmap" "nc" "timeout")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt-get install masscan nmap netcat-openbsd coreutils"
        exit 1
    fi
    
    log_success "All dependencies found"
}

# Setup output directory
setup_output() {
    mkdir -p "$OUTPUT_DIR"
    log "Created output directory: $OUTPUT_DIR"
    
    # Initialize log file
    echo "Global Minecraft Scanner Log - $TIMESTAMP" > "$LOG_FILE"
    echo "===========================================" >> "$LOG_FILE"
}

# Display scan configuration
show_config() {
    echo
    log "SCAN CONFIGURATION:"
    echo "Target: 0.0.0.0/0 (ENTIRE INTERNET)"
    echo "Port: $MINECRAFT_PORT"
    echo "Default Rate: $DEFAULT_SCAN_RATE packets/second"
    echo "Excludes: ${#EXCLUDE_RANGES[@]} ranges (private, multicast, etc.)"
    echo "Output: $OUTPUT_DIR"
    echo
}

# Get user confirmation and scan rate
get_scan_parameters() {
    log_warning "CRITICAL WARNING: This will scan ALL IPv4 addresses (~4.3 billion)"
    log_warning "This is an aggressive internet-wide scan!"
    echo
    echo "Scan rate options:"
    echo "1) Conservative: 1,000 pps (recommended for most connections)"
    echo "2) Moderate: 5,000 pps (fast broadband/server)"  
    echo "3) Aggressive: 10,000 pps (high-end connection only)"
    echo "4) Maximum: 50,000 pps (enterprise/datacenter only)"
    echo "5) Custom rate"
    echo
    
    read -p "Select scan rate (1-5): " rate_choice
    
    case $rate_choice in
        1) SCAN_RATE=1000 ;;
        2) SCAN_RATE=5000 ;;
        3) SCAN_RATE=10000 ;;
        4) SCAN_RATE=50000 ;;
        5) 
            read -p "Enter custom rate (packets/second): " SCAN_RATE
            if ! [[ "$SCAN_RATE" =~ ^[0-9]+$ ]]; then
                SCAN_RATE=$DEFAULT_SCAN_RATE
                log_warning "Invalid rate, using default: $SCAN_RATE"
            fi
            ;;
        *) 
            SCAN_RATE=$DEFAULT_SCAN_RATE
            log "Using default rate: $SCAN_RATE pps"
            ;;
    esac
    
    echo
    log "Selected scan rate: $SCAN_RATE packets/second"
    
    # Calculate estimated time
    local total_ips=4294967296  # 2^32
    local excluded_ips=0
    for range in "${EXCLUDE_RANGES[@]}"; do
        if [[ $range =~ /([0-9]+)$ ]]; then
            local cidr=${BASH_REMATCH[1]}
            excluded_ips=$((excluded_ips + 2**(32-cidr)))
        fi
    done
    local scannable_ips=$((total_ips - excluded_ips))
    local estimated_hours=$((scannable_ips / SCAN_RATE / 3600))
    
    echo
    log "Estimated scan time: ~$estimated_hours hours"
    log "Scannable IPs: ~$scannable_ips (after exclusions)"
    
    echo
    log_warning "FINAL CONFIRMATION REQUIRED"
    echo "This scan will:"
    echo "- Scan ~4.3 billion IP addresses"
    echo "- Take approximately $estimated_hours hours"  
    echo "- Generate significant network traffic"
    echo "- May trigger security alerts"
    echo "- Should only be done with proper authorization"
    echo
    
    read -p "Type 'GLOBAL_SCAN_CONFIRMED' to proceed: " confirmation
    
    if [[ "$confirmation" != "GLOBAL_SCAN_CONFIRMED" ]]; then
        log "Scan cancelled by user"
        exit 0
    fi
    
    log_success "Global scan confirmed by user"
}

# Build masscan exclude parameters
build_excludes() {
    local exclude_params=""
    for range in "${EXCLUDE_RANGES[@]}"; do
        exclude_params="$exclude_params --exclude $range"
    done
    echo "$exclude_params"
}

# Run global masscan
run_global_masscan() {
    log "Starting global masscan..."
    log "Target: 0.0.0.0/0"
    log "Rate: $SCAN_RATE pps"
    log "Port: $MINECRAFT_PORT"
    
    local exclude_params
    exclude_params=$(build_excludes)
    
    log "Exclusions: ${EXCLUDE_RANGES[*]}"
    
    # Build and display command
    local cmd="masscan -p$MINECRAFT_PORT 0.0.0.0/0 --rate=$SCAN_RATE $exclude_params --output-format list --output-filename \"$MASSCAN_OUTPUT\""
    log "Command: $cmd"
    
    # Start scan
    log "SCAN STARTING NOW - This will take many hours..."
    echo "Started at: $(date)"
    
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    local scan_result=$?
    
    echo "Completed at: $(date)"
    
    if [[ $scan_result -eq 0 ]]; then
        log_success "Masscan completed successfully"
    else
        log_error "Masscan failed with exit code: $scan_result"
        exit 1
    fi
}

# Analyze masscan results
analyze_results() {
    if [[ ! -f "$MASSCAN_OUTPUT" ]]; then
        log_error "Masscan output file not found: $MASSCAN_OUTPUT"
        exit 1
    fi
    
    local total_found
    total_found=$(grep -c "^open tcp" "$MASSCAN_OUTPUT" 2>/dev/null || echo "0")
    
    log "MASSCAN RESULTS:"
    log "Total servers found: $total_found"
    
    if [[ $total_found -eq 0 ]]; then
        log_warning "No servers found - this is unexpected for a global scan"
        return 1
    fi
    
    # Show sample results
    log "Sample discoveries:"
    head -10 "$MASSCAN_OUTPUT" | grep "^open tcp" | while read -r line; do
        if [[ $line =~ open\ tcp\ ([0-9]+)\ ([0-9.]+)\ ([0-9]+) ]]; then
            echo "  Found: ${BASH_REMATCH[2]}:${BASH_REMATCH[1]}"
        fi
    done
    
    return 0
}

# Verify servers with nmap
verify_servers() {
    local total_found
    total_found=$(grep -c "^open tcp" "$MASSCAN_OUTPUT" 2>/dev/null || echo "0")
    
    if [[ $total_found -eq 0 ]]; then
        return 1
    fi
    
    log "Starting server verification with nmap..."
    log "Verifying $total_found discovered servers..."
    
    # Initialize verification output
    echo "# Verified Minecraft Servers - $TIMESTAMP" > "$VERIFIED_OUTPUT"
    echo "# Verified using nmap secondary scan" >> "$VERIFIED_OUTPUT"
    echo "" >> "$VERIFIED_OUTPUT"
    
    local count=0
    local verified=0
    local batch_size=100  # Process in batches to avoid overwhelming
    
    while IFS= read -r line; do
        [[ $line =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        if [[ $line =~ ^open\ tcp\ ([0-9]+)\ ([0-9.]+)\ ([0-9]+)$ ]]; then
            local port="${BASH_REMATCH[1]}"
            local ip="${BASH_REMATCH[2]}"
            
            ((count++))
            
            if ((count % 100 == 0)); then
                log "Verified $count/$total_found servers so far..."
            fi
            
            # Verify with nmap
            if timeout 10 nmap -sS -Pn -p "$port" "$ip" 2>/dev/null | grep -q "open"; then
                ((verified++))
                echo "$line" >> "$VERIFIED_OUTPUT"
                log_success "Verified: $ip:$port"
            fi
            
            # Rate limiting for verification
            sleep 0.1
        fi
    done < "$MASSCAN_OUTPUT"
    
    log_success "Verification complete: $verified/$total_found servers confirmed"
    echo "$verified" > "$OUTPUT_DIR/verified_count.txt"
}

# Banner grab from verified servers
banner_grab_servers() {
    local verified_file="$VERIFIED_OUTPUT"
    
    if [[ ! -f "$verified_file" ]]; then
        log_warning "No verified servers file found, using masscan results"
        verified_file="$MASSCAN_OUTPUT"
    fi
    
    local total_verified
    total_verified=$(grep -c "^open tcp" "$verified_file" 2>/dev/null || echo "0")
    
    if [[ $total_verified -eq 0 ]]; then
        log_warning "No verified servers to banner grab"
        return 1
    fi
    
    log "Starting banner grabbing from $total_verified servers..."
    
    # Initialize banner output
    cat > "$BANNER_OUTPUT" << BANNER_EOF
Global Minecraft Server Banner Results
=====================================
Scan Date: $(date)
Total Servers: $total_verified
Scanner: Global Minecraft Scanner v1.0

BANNER_EOF
    
    local count=0
    local successful_banners=0
    
    while IFS= read -r line; do
        [[ $line =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        
        if [[ $line =~ ^open\ tcp\ ([0-9]+)\ ([0-9.]+)\ ([0-9]+)$ ]]; then
            local port="${BASH_REMATCH[1]}"
            local ip="${BASH_REMATCH[2]}"
            
            ((count++))
            
            if ((count % 50 == 0)); then
                log "Banner grabbed $count/$total_verified servers..."
            fi
            
            log "Banner grabbing: $ip:$port"
            
            # Try multiple banner grabbing methods
            local banner=""
            local server_info=""
            
            # Method 1: Basic netcat
            banner=$(timeout 5 bash -c "echo '' | nc -w 3 $ip $port" 2>/dev/null)
            
            # Method 2: Try HTTP-style request (some servers respond to this)
            if [[ -z "$banner" ]]; then
                banner=$(timeout 5 bash -c "echo -e 'GET / HTTP/1.0\r\n\r\n' | nc -w 3 $ip $port" 2>/dev/null)
            fi
            
            # Record results
            echo "" >> "$BANNER_OUTPUT"
            echo "=== $ip:$port ===" >> "$BANNER_OUTPUT"
            echo "Scan Time: $(date)" >> "$BANNER_OUTPUT"
            echo "Status: $(if [[ -n "$banner" ]]; then echo "Response Received"; else echo "No Response"; fi)" >> "$BANNER_OUTPUT"
            
            if [[ -n "$banner" ]]; then
                ((successful_banners++))
                echo "Response Length: $(echo "$banner" | wc -c) bytes" >> "$BANNER_OUTPUT"
                echo "Response Preview:" >> "$BANNER_OUTPUT"
                echo "$banner" | head -10 >> "$BANNER_OUTPUT"
                log_success "Got banner from $ip:$port"
            else
                echo "No banner data received" >> "$BANNER_OUTPUT"
            fi
            
            echo "---" >> "$BANNER_OUTPUT"
            
            # Rate limiting - be respectful
            sleep 0.2
        fi
    done < "$verified_file"
    
    log_success "Banner grabbing complete: $successful_banners/$total_verified responses"
    echo "$successful_banners" > "$OUTPUT_DIR/banner_count.txt"
}

# Generate comprehensive summary
generate_summary() {
    local masscan_count=$(grep -c "^open tcp" "$MASSCAN_OUTPUT" 2>/dev/null || echo "0")
    local verified_count=$(cat "$OUTPUT_DIR/verified_count.txt" 2>/dev/null || echo "0")
    local banner_count=$(cat "$OUTPUT_DIR/banner_count.txt" 2>/dev/null || echo "0")
    
    cat > "$SUMMARY_OUTPUT" << SUMMARY_EOF
GLOBAL MINECRAFT SERVER SCAN SUMMARY
===================================

Scan Information:
----------------
Date: $(date)
Scanner: Global Minecraft Scanner
Target: 0.0.0.0/0 (Entire IPv4 Internet)
Port: $MINECRAFT_PORT
Scan Rate: $SCAN_RATE packets/second
Excludes: ${EXCLUDE_RANGES[*]}

Results Summary:
---------------
Total IPs Scanned: ~4.3 billion (minus exclusions)
Servers Discovered: $masscan_count
Servers Verified: $verified_count  
Successful Banners: $banner_count
Success Rate: $(if [[ $masscan_count -gt 0 ]]; then echo "scale=2; $verified_count * 100 / $masscan_count" | bc; else echo "0"; fi)%

File Locations:
--------------
- Masscan Results: $MASSCAN_OUTPUT
- Verified Servers: $VERIFIED_OUTPUT
- Banner Data: $BANNER_OUTPUT
- Scan Log: $LOG_FILE
- This Summary: $SUMMARY_OUTPUT

Top Server Locations:
--------------------
SUMMARY_EOF

    # Add top countries/ASNs if we have results
    if [[ $masscan_count -gt 0 ]]; then
        echo "Sample Discovered Servers:" >> "$SUMMARY_OUTPUT"
        grep "^open tcp" "$MASSCAN_OUTPUT" | head -20 | while read -r line; do
            if [[ $line =~ open\ tcp\ ([0-9]+)\ ([0-9.]+)\ ([0-9]+) ]]; then
                echo "  ${BASH_REMATCH[2]}:${BASH_REMATCH[1]}" >> "$SUMMARY_OUTPUT"
            fi
        done
    fi
    
    cat >> "$SUMMARY_OUTPUT" << SUMMARY_EOF

Scan Statistics:
---------------
Start Time: $(head -1 "$LOG_FILE" | grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' || echo "Unknown")
End Time: $(date)
Total Duration: $(if [[ -f "$LOG_FILE" ]]; then echo "See log file"; else echo "Unknown"; fi)

Ethical Notes:
-------------
This scan was conducted for educational/research purposes.
All scanning was done responsibly with:
- Reasonable rate limiting
- Standard exclusions for private/reserved ranges
- No disruption to discovered services
- Minimal banner grabbing

SUMMARY_EOF

    log_success "Summary report generated: $SUMMARY_OUTPUT"
}

# Main execution function
main() {
    echo
    log "Global Minecraft Scanner Starting..."
    
    check_root
    check_dependencies
    setup_output
    show_config
    get_scan_parameters
    
    log "=== PHASE 1: GLOBAL DISCOVERY ==="
    run_global_masscan
    
    log "=== PHASE 2: RESULT ANALYSIS ==="
    if analyze_results; then
        log "=== PHASE 3: SERVER VERIFICATION ==="
        verify_servers
        
        log "=== PHASE 4: BANNER GRABBING ==="
        banner_grab_servers
    fi
    
    log "=== PHASE 5: FINAL SUMMARY ==="
    generate_summary
    
    echo
    log_success "GLOBAL SCAN COMPLETE!"
    log "All results saved to: $OUTPUT_DIR"
    log "Summary report: $SUMMARY_OUTPUT"
    
    # Display final stats
    echo
    echo "FINAL STATISTICS:"
    echo "================"
    if [[ -f "$SUMMARY_OUTPUT" ]]; then
        grep -E "(Servers Discovered|Servers Verified|Successful Banners)" "$SUMMARY_OUTPUT"
    fi
    echo
    echo "Check $OUTPUT_DIR for all detailed results."
}

# Script entry point
main "$@"
