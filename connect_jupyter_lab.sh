#!/bin/bash

# Script to manage Jupyter Lab connections with tmux and SSH tunneling
# Robust version: always uses the actual port Jupyter Lab is running on
# Usage: 
#   connect_jupyter_lab <machine_name>        - Start Jupyter Lab and create tunnel
#   connect_jupyter_lab <machine_name> stop   - Stop Jupyter Lab and close tmux session

#SSH errors!
#set -e

SCRIPT_NAME=$(basename "$0")
TMUX_SESSION_PREFIX="jupyter_lab"
LOCAL_PORT=8888
MAMBA_ENV="jupyter_lab"
DEFAULT_WORK_DIR="/data/pinello/PROJECTS"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

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

check_remote_tmux_session() {
    local machine=$1
    local session_name=$2
    ssh "$machine" "tmux has-session -t '$session_name' 2>/dev/null" && return 0 || return 1
}

find_available_port() {
    local port=$1
    while lsof -i :$port >/dev/null 2>&1; do
        ((port++))
    done
    echo $port
}

# Start Jupyter Lab on the remote host, using --port=8888 so Jupyter picks a free port.
start_jupyter() {
    local machine=$1
    local session_name="${TMUX_SESSION_PREFIX}_$(echo $machine | tr '.' '_')"

    print_info "Finding available local port..."
    local local_port
    local_port=$(find_available_port $LOCAL_PORT)
    if [ "$local_port" != "$LOCAL_PORT" ]; then
        print_warning "Port $LOCAL_PORT is in use, using $local_port instead"
    fi

    # If tmux session exists, check if Jupyter is running and parse actual port
    if check_remote_tmux_session "$machine" "$session_name"; then
        print_success "Tmux session '$session_name' already exists on $machine"
        print_info "Checking if Jupyter Lab is running in the existing session..."
        local tmux_output
        tmux_output=$(ssh "$machine" "tmux capture-pane -t '$session_name' -S -100 -p" 2>/dev/null)
        local actual_remote_port=""
        actual_remote_port=$(echo "$tmux_output" | grep -oE 'http://127\.0\.0\.1:[0-9]{4,5}' | tail -1 | grep -oE '[0-9]{4,5}')
        if echo "$tmux_output" | grep -q "Jupyter Server.*is running\|http://.*:.*[0-9]\{4,5\}\|Use Control-C to stop"; then
            print_success "Jupyter Lab is already running! Setting up tunnel..."
            local token=""
            token=$(echo "$tmux_output" | grep -o 'token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 || echo "")
            if [[ -z "$token" ]]; then
                token=$(echo "$tmux_output" | grep -o '?token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 || echo "")
            fi 
            if [[ -z "$token" ]]; then
                if echo "$tmux_output" | grep -q "http://127.0.0.1:$actual_remote_port/lab"; then
                    print_info "Jupyter Lab is running without token authentication"
                    token="no_token_required"
                fi
            fi
            if [[ -n "$actual_remote_port" ]]; then
                setup_tunnel_and_open "$machine" "$token" "$local_port" "$actual_remote_port"
                return 0
            else
                print_error "Could not determine Jupyter Lab port from tmux session"
                return 1
            fi
        else
            print_warning "Tmux session exists but Jupyter Lab doesn't appear to be running"
            print_info "Session content preview:"
            echo "$tmux_output" | tail -5
            read -p "Do you want to restart Jupyter Lab in the existing session? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_info "Restarting Jupyter Lab in existing session..."
                restart_jupyter_in_session "$machine" "$session_name" "$local_port"
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
        create_new_jupyter_session "$machine" "$session_name" "$local_port"
    fi
}

restart_jupyter_in_session() {
    local machine=$1
    local session_name=$2
    local local_port=$3

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
    ssh "$machine" "tmux send-keys -t '$session_name' 'jupyter lab --no-browser --port=8888 --ip=127.0.0.1' Enter"
    wait_for_jupyter_and_connect "$machine" "$session_name" "$local_port"
}

create_new_jupyter_session() {
    local machine=$1
    local session_name=$2
    local local_port=$3

    print_info "Creating new tmux session '$session_name' on $machine"
    print_info "Working directory: $DEFAULT_WORK_DIR"
    print_info "Activating mamba environment '$MAMBA_ENV' and starting Jupyter Lab..."
    ssh "$machine" "tmux new-session -d -s '$session_name' bash"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'cd $DEFAULT_WORK_DIR' Enter"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'mamba activate $MAMBA_ENV' Enter"
    sleep 2
    ssh "$machine" "tmux send-keys -t '$session_name' 'clear' Enter"
    sleep 1
    ssh "$machine" "tmux send-keys -t '$session_name' 'jupyter lab --no-browser --port=8888 --ip=127.0.0.1' Enter"
    wait_for_jupyter_and_connect "$machine" "$session_name" "$local_port"
}

wait_for_jupyter_and_connect() {
    local machine=$1
    local session_name=$2
    local local_port=$3
    print_info "Waiting for Jupyter Lab to start..."
    local max_attempts=30
    local attempt=0
    local token=""
    local actual_remote_port=""
    while [[ $attempt -lt $max_attempts ]]; do
        sleep 3
        ((attempt++))
        local tmux_output
        tmux_output=$(ssh $machine tmux capture-pane -t $session_name -S -100 -p || echo "")
        #if [[ $attempt -le 2 ]]; then
        #    print_info "Debug - recent tmux output:"
        #    echo "$tmux_output" | tail -10
        #    echo "---"
        #fi
        # Parse the actual port from Jupyter Lab output
        actual_remote_port=$(echo "$tmux_output" | grep -oE 'http://127\.0\.0\.1:[0-9]{4,5}' | tail -1 | grep -oE '[0-9]{4,5}' || echo "")
        # Try token extraction
        token=$(echo "$tmux_output" | grep -o 'token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 2>/dev/null || echo "")
        if [[ -z "$token" ]]; then
            token=$(echo "$tmux_output" | grep -o '?token=[a-f0-9]\{1,\}' | head -1 | cut -d'=' -f2 2>/dev/null || echo "")
        fi
        if [[ -z "$token" ]]; then
            token=$(echo "$tmux_output" | grep -o '[a-f0-9]\{48\}' | head -1 2>/dev/null)
        fi
        if [[ -z "$token" ]]; then
            token=$(echo "$tmux_output" | grep -o '[a-f0-9]\{32\}' | head -1 2>/dev/null)
        fi

        if echo "$tmux_output" | grep -q "Jupyter Server.*is running\|jupyter lab\|http://.*:.*[0-9]\{4,5\}\|Use Control-C to stop"; then
            print_success "Jupyter Lab is running!"
            if [[ -z "$token" ]]; then
                print_warning "Jupyter is running but no token found. Checking for URL..."
                local jupyter_url
                if [[ -n "$actual_remote_port" ]]; then
                    jupyter_url=$(echo "$tmux_output" | grep -o "http://127.0.0.1:$actual_remote_port[^[:space:]]*" | head -1)
                    token=$(echo "$jupyter_url" | grep -o 'token=[a-f0-9]\{1,\}' | cut -d'=' -f2)
                    if [[ -z "$token" ]]; then
                        print_info "No token required - Jupyter is running without authentication"
                        token="no_token_required"
                    fi
                fi
            fi
            if [[ -n "$actual_remote_port" ]]; then
                setup_tunnel_and_open "$machine" "$token" "$local_port" "$actual_remote_port"
                return 0
            else
                print_error "Could not determine Jupyter Lab port from tmux output"
                #return 1
            fi
        fi
        if echo "$tmux_output" | grep -q -i "error\|failed\|exception"; then
            print_error "Detected error in Jupyter startup:"
            echo "$tmux_output" | grep -i "error\|failed\|exception" | tail -3
        fi
        print_info "Attempt $attempt/$max_attempts - Still waiting for Jupyter Lab..."
    done
    print_error "Failed to detect Jupyter Lab startup within timeout"
    print_info "Final tmux output:"
    ssh "$machine" "tmux capture-pane -t '$session_name' -S -20 -p" | tail -10
    print_info ""
    print_info "You can check the tmux session manually:"
    print_info "  ssh $machine"
    print_info "  tmux attach -t $session_name"
    print_info ""
    print_info "Or try connecting manually with a browser to:"
    print_info "  http://localhost:$local_port (after setting up tunnel)"
    read -p "Do you want to set up the SSH tunnel anyway? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_tunnel_and_open "$machine" "no_token_required" "$local_port" "$actual_remote_port"
    fi
    return 1
}

setup_tunnel_and_open() {
    local machine=$1
    local token=$2
    local local_port=$3
    local remote_port=$4
    print_info "Setting up SSH tunnel from localhost:$local_port to $machine:$remote_port"
    pkill -f "ssh.*$machine.*$local_port:127.0.0.1:$remote_port" 2>/dev/null || true
    ssh -f -N -L "$local_port:127.0.0.1:$remote_port" "$machine"
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
    if command -v open &> /dev/null; then
        open "$jupyter_url"
        print_success "Opened Jupyter Lab in browser"
    elif command -v xdg-open &> /dev/null; then
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
    print_info "Closing SSH tunnels..."
    pkill -f "ssh.*$machine.*:127.0.0.1:[0-9]\{4,5\}" 2>/dev/null || true
    if check_remote_tmux_session "$machine" "$session_name"; then
        print_info "Killing tmux session '$session_name'..."
        ssh "$machine" "tmux kill-session -t '$session_name'"
        print_success "Tmux session stopped"
    else
        print_warning "No tmux session '$session_name' found on $machine"
    fi
    print_success "Jupyter Lab stopped and tunnels closed"
}

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

main "$@"
