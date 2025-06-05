#!/bin/bash

# Script to manage Jupyter Lab connections with tmux and SSH tunneling
# Usage: 
#   connect_jupyter_lab <machine_name>        - Start Jupyter Lab and create tunnel
#   connect_jupyter_lab <machine_name> stop   - Stop Jupyter Lab and close tmux session

set -e

SCRIPT_NAME=$(basename "$0")
TMUX_SESSION_PREFIX="jupyter_lab"
LOCAL_PORT=8888
REMOTE_PORT=8888
MAMBA_ENV="jupyter_lab"
DEFAULT_WORK_DIR="/data/pinello/PROJECTS"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage:"
    echo "  $SCRIPT_NAME <machine_name>        - Start Jupyter Lab and create tunnel"
    echo "  $SCRIPT_NAME <machine_name> stop   - Stop Jupyter Lab and close tmux session"
    echo "  $SCRIPT_NAME <machine_name> debug  - Show tmux session output for debugging"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME ml003.research.partners.org"
    echo "  $SCRIPT_NAME ml003.research.partners.org stop"
    echo "  $SCRIPT_NAME ml003.research.partners.org debug"
}

# Function to check if tmux session exists on remote machine
check_remote_tmux_session() {
    local machine=$1
    local session_name=$2
    
    ssh "$machine" "tmux has-session -t '$session_name' 2>/dev/null" && return 0 || return 1
}

# Function to find available port
find_available_port() {
    local port=$LOCAL_PORT
    while netstat -tuln 2>/dev/null | grep -q ":$port "; do
        ((port++))
    done
    echo $port
}

# Function to start Jupyter Lab
start_jupyter() {
    local machine=$1
    local session_name="${TMUX_SESSION_PREFIX}_$(echo $machine | tr '.' '_')"
    
    print_info "Connecting to $machine..."
    
    # Check if session already exists
    if check_remote_tmux_session "$machine" "$session_name"; then
        print_success "Tmux session '$session_name' already exists on $machine"
        print_info "Checking if Jupyter Lab is running in the existing session..."
        
        # Check if Jupyter is actually running in the session
        local tmux_output
        tmux_output=$(ssh "$machine" "tmux capture-pane -t '$session_name' -S -50 -p" 2>/dev/null || echo "")
        
        if echo "$tmux_output" | grep -q "Jupyter Server.*is running\|http://.*:.*8888\|Use Control-C to stop"; then
            print_success "Jupyter Lab is already running! Setting up tunnel..."
            
            # Extract token if present, or determine if token-less
            local token=""
            token=$(echo "$tmux_output" | grep -o 'token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 || echo "")
            
            if [[ -z "$token" ]]; then
                # Try other token patterns
                token=$(echo "$tmux_output" | grep -o '?token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 || echo "")
            fi
            
            if [[ -z "$token" ]]; then
                # Check if token-less (no token in URL but Jupyter is running)
                if echo "$tmux_output" | grep -q "http://127.0.0.1:8888/lab"; then
                    print_info "Jupyter Lab is running without token authentication"
                    token="no_token_required"
                fi
            fi
            
            if [[ -n "$token" ]]; then
                setup_tunnel_and_open "$machine" "$token"
                return 0
            else
                print_warning "Jupyter is running but couldn't determine authentication method"
                print_info "Setting up tunnel anyway..."
                setup_tunnel_and_open "$machine" "no_token_required"
                return 0
            fi
        else
            print_warning "Tmux session exists but Jupyter Lab doesn't appear to be running"
            print_info "Session content preview:"
            echo "$tmux_output" | tail -5
            print_info ""
            read -p "Do you want to restart Jupyter Lab in the existing session? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_info "Restarting Jupyter Lab in existing session..."
                restart_jupyter_in_session "$machine" "$session_name"
                return $?
            else
                print_info "Keeping existing session as-is. You can manually check it:"
                print_info "  ssh $machine"
                print_info "  tmux attach -t $session_name"
                return 1
            fi
        fi
    else
        print_info "No existing tmux session found. Creating new session..."
        create_new_jupyter_session "$machine" "$session_name"
    fi
}

# Function to restart Jupyter in existing session
restart_jupyter_in_session() {
    local machine=$1
    local session_name=$2
    
    print_info "Stopping any running Jupyter processes in the session..."
    ssh "$machine" "tmux send-keys -t '$session_name' C-c" 2>/dev/null || true
    sleep 2
    ssh "$machine" "tmux send-keys -t '$session_name' C-c" 2>/dev/null || true
    sleep 1
    
    print_info "Changing to working directory and starting Jupyter Lab..."
    ssh "$machine" "tmux send-keys -t '$session_name' 'cd $DEFAULT_WORK_DIR' Enter"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'mamba activate $MAMBA_ENV' Enter"
    sleep 2
    ssh "$machine" "tmux send-keys -t '$session_name' 'jupyter lab --no-browser --port=$REMOTE_PORT --ip=127.0.0.1' Enter"
    
    wait_for_jupyter_and_connect "$machine" "$session_name"
}

# Function to create new Jupyter session
create_new_jupyter_session() {
    local machine=$1
    local session_name=$2
    
    print_info "Creating new tmux session '$session_name' on $machine"
    print_info "Working directory: $DEFAULT_WORK_DIR"
    print_info "Activating mamba environment '$MAMBA_ENV' and starting Jupyter Lab..."
    
    # Create tmux session and start Jupyter Lab
    ssh "$machine" "tmux new-session -d -s '$session_name' bash"
    
    # Wait a moment for the session to be ready
    sleep 1
    
    # Send commands to the tmux session with proper timing
    ssh "$machine" "tmux send-keys -t '$session_name' 'cd $DEFAULT_WORK_DIR' Enter"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'mamba activate $MAMBA_ENV' Enter"
    sleep 2
    ssh "$machine" "tmux send-keys -t '$session_name' 'clear' Enter"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'jupyter lab --no-browser --port=$REMOTE_PORT --ip=127.0.0.1' Enter"
    
    wait_for_jupyter_and_connect "$machine" "$session_name"
}

# Function to wait for Jupyter and then connect
wait_for_jupyter_and_connect() {
    local machine=$1
    local session_name=$2
    
    print_info "Waiting for Jupyter Lab to start..."
    
    # Wait for Jupyter to start and get the token
    local max_attempts=30
    local attempt=0
    local token=""
    
    while [[ $attempt -lt $max_attempts ]]; do
        sleep 3
        ((attempt++))
        
        # Capture the tmux output for debugging
        local tmux_output
        tmux_output=$(ssh "$machine" "tmux capture-pane -t '$session_name' -S -50 -p" 2>/dev/null || echo "")
        
        # Debug: Show what we're getting from tmux (only on first few attempts)
        if [[ $attempt -le 2 ]]; then
            print_info "Debug - recent tmux output:"
            echo "$tmux_output" | tail -10
            echo "---"
        fi
        
        # Try multiple token extraction patterns (using portable regex)
        # Pattern 1: token=<hexstring>
        token=$(echo "$tmux_output" | grep -o 'token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 2>/dev/null || echo "")
        
        if [[ -z "$token" ]]; then
            # Pattern 2: ?token=<hexstring>
            token=$(echo "$tmux_output" | grep -o '?token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 2>/dev/null || echo "")
        fi
        
        if [[ -z "$token" ]]; then
            # Pattern 3: Look for 48-character hex strings (typical token length)
            token=$(echo "$tmux_output" | grep -o '[a-f0-9]\{48\}' | head -1 2>/dev/null || echo "")
        fi
        
        if [[ -z "$token" ]]; then
            # Pattern 4: Look for 32-character hex strings (alternative token length)
            token=$(echo "$tmux_output" | grep -o '[a-f0-9]\{32\}' | head -1 2>/dev/null || echo "")
        fi
        
        # Check if Jupyter is running (look for various startup messages)
        if echo "$tmux_output" | grep -q "Jupyter Server.*is running\|jupyter lab\|http://.*:.*8888\|Use Control-C to stop"; then
            print_success "Jupyter Lab is running!"
            if [[ -n "$token" ]]; then
                print_success "Token extracted: ${token:0:8}..."
                break
            else
                print_warning "Jupyter is running but no token found. Checking for URL..."
                # Try to extract full URL (using portable regex)
                local jupyter_url
                jupyter_url=$(echo "$tmux_output" | grep -o 'http://[^[:space:]]*:8888[^[:space:]]*' | head -1 || echo "")
                if [[ -n "$jupyter_url" ]]; then
                    print_success "Found Jupyter URL: $jupyter_url"
                    # Extract token from URL if present
                    token=$(echo "$jupyter_url" | grep -o 'token=[a-f0-9]\{1,\}' | cut -d'=' -f2 || echo "")
                    if [[ -n "$token" ]]; then
                        print_success "Token extracted from URL: ${token:0:8}..."
                        break
                    else
                        print_info "No token required - Jupyter is running without authentication"
                        token="no_token_required"
                        break
                    fi
                else
                    # Check if we can find the standard URL pattern
                    if echo "$tmux_output" | grep -q "http://127.0.0.1:8888/lab"; then
                        print_info "Jupyter Lab is running without token authentication"
                        token="no_token_required"
                        break
                    fi
                fi
            fi
        fi
        
        # Check for errors
        if echo "$tmux_output" | grep -q -i "error\|failed\|exception"; then
            print_error "Detected error in Jupyter startup:"
            echo "$tmux_output" | grep -i "error\|failed\|exception" | tail -3
        fi
        
        print_info "Attempt $attempt/$max_attempts - Still waiting for Jupyter Lab..."
    done
    
    if [[ -z "$token" ]]; then
        print_error "Failed to detect Jupyter Lab startup within timeout"
        print_info "Final tmux output:"
        ssh "$machine" "tmux capture-pane -t '$session_name' -S -20 -p" | tail -10
        print_info ""
        print_info "You can check the tmux session manually:"
        print_info "  ssh $machine"
        print_info "  tmux attach -t $session_name"
        print_info ""
        print_info "Or try connecting manually with a browser to:"
        print_info "  http://localhost:8888 (after setting up tunnel)"
        
        # Still try to set up tunnel without token
        read -p "Do you want to set up the SSH tunnel anyway? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_tunnel_and_open "$machine" "no_token_required"
        fi
        return 1
    fi
    
    setup_tunnel_and_open "$machine" "$token"
}

# Function to setup SSH tunnel and open browser
setup_tunnel_and_open() {
    local machine=$1
    local token=$2
    local local_port
    
    local_port=$(find_available_port)
    
    print_info "Setting up SSH tunnel from localhost:$local_port to $machine:$REMOTE_PORT"
    
    # Kill any existing SSH tunnel on the same port
    pkill -f "ssh.*$machine.*$local_port:127.0.0.1:$REMOTE_PORT" 2>/dev/null || true
    
    # Create SSH tunnel in background
    ssh -f -N -L "$local_port:127.0.0.1:$REMOTE_PORT" "$machine"
    
    # Wait a moment for tunnel to establish
    sleep 2
    
    local jupyter_url
    if [[ "$token" == "no_token_required" ]]; then
        jupyter_url="http://localhost:$local_port/lab"
        print_success "Jupyter Lab is accessible at: $jupyter_url (no token required)"
    else
        jupyter_url="http://localhost:$local_port/lab?token=$token"
        print_success "Jupyter Lab is accessible at: $jupyter_url"
    fi
    
    print_success "SSH tunnel established!"
    
    # Try to open in browser
    if command -v open &> /dev/null; then
        # macOS
        open "$jupyter_url"
        print_success "Opened Jupyter Lab in browser"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "$jupyter_url"
        print_success "Opened Jupyter Lab in browser"
    else
        print_info "Please open the following URL in your browser:"
        print_info "$jupyter_url"
    fi
    
    print_info ""
    print_info "To stop Jupyter Lab and close the tunnel, run:"
    print_info "  $SCRIPT_NAME $machine stop"
    print_info ""
    print_info "To check the tmux session on the remote machine:"
    print_info "  ssh $machine"
    print_info "  tmux attach -t ${TMUX_SESSION_PREFIX}_$(echo $machine | tr '.' '_')"
}

# Function to debug tmux session
debug_session() {
    local machine=$1
    local session_name="${TMUX_SESSION_PREFIX}_$(echo $machine | tr '.' '_')"
    
    print_info "Debugging tmux session '$session_name' on $machine"
    
    if ! check_remote_tmux_session "$machine" "$session_name"; then
        print_error "No tmux session '$session_name' found on $machine"
        return 1
    fi
    
    print_info "Full tmux session history (last 100 lines):"
    echo "================================================"
    ssh "$machine" "tmux capture-pane -t '$session_name' -S -100 -p"
    echo "================================================"
    
    print_info "To attach to the session manually:"
    print_info "  ssh $machine"
    print_info "  tmux attach -t $session_name"
}
stop_jupyter() {
    local machine=$1
    local session_name="${TMUX_SESSION_PREFIX}_$(echo $machine | tr '.' '_')"
    
    print_info "Stopping Jupyter Lab on $machine..."
    
    # Kill SSH tunnels
    print_info "Closing SSH tunnels..."
    pkill -f "ssh.*$machine.*:127.0.0.1:$REMOTE_PORT" 2>/dev/null || true
    
    # Check if tmux session exists and kill it
    if check_remote_tmux_session "$machine" "$session_name"; then
        print_info "Killing tmux session '$session_name'..."
        ssh "$machine" "tmux kill-session -t '$session_name'"
        print_success "Tmux session stopped"
    else
        print_warning "No tmux session '$session_name' found on $machine"
    fi
    
    print_success "Jupyter Lab stopped and tunnels closed"
}

# Main script logic
main() {
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local machine=$1
    local action=${2:-"start"}
    
    case "$action" in
        "stop")
            stop_jupyter "$machine"
            ;;
        "debug")
            debug_session "$machine"
            ;;
        "start"|"")
            start_jupyter "$machine"
            ;;
        *)
            print_error "Unknown action: $action"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
