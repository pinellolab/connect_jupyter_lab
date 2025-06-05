# connect_jupyter_lab

A bash script to manage persistent Jupyter Lab sessions on remote machines with SSH tunneling and tmux.

## Features

- 🚀 Creates persistent Jupyter Lab sessions using tmux
- 🔗 Automatic SSH tunnel setup for secure remote access
- 💾 Preserves sessions across disconnections
- 🔄 Smart session management - reuses existing sessions
- 🌐 Automatic browser opening with authentication
- 📁 Configurable working directory (defaults to `/data/pinello/PROJECTS`)

## Prerequisites

- SSH access to remote machine
- `tmux` installed on remote machine
- `mamba` installed on remote machine with `jupyter_lab` environment
- `jupyter lab` installed in the mamba environment

## Installation

```bash
git clone https://github.com/yourusername/connect_jupyter_lab.git
cd connect_jupyter_lab
chmod +x connect_jupyter_lab.sh
```

## Usage

### Start Jupyter Lab
```bash
./connect_jupyter_lab.sh ml003.research.partners.org
```

This will:
1. Create a tmux session on the remote machine
2. Activate the `jupyter_lab` mamba environment
3. Start Jupyter Lab on port 8888
4. Create an SSH tunnel from your local machine
5. Open your browser with the correct URL and token

### Stop Jupyter Lab
```bash
./connect_jupyter_lab.sh ml003.research.partners.org stop
```

### Debug Session
```bash
./connect_jupyter_lab.sh ml003.research.partners.org debug
```

## Persistent Sessions

The script maintains persistent tmux sessions, so if you disconnect your laptop and reconnect later:
- Your Jupyter Lab server continues running on the remote machine
- Running the script again will detect the existing session
- It will create a new SSH tunnel to the existing session
- No work is lost!

## Configuration

Edit the script to modify:
- `DEFAULT_WORKING_DIR`: Change the default directory (currently `/data/pinello/PROJECTS`)
- `JUPYTER_PORT`: Change the Jupyter port (default 8888)
- `LOCAL_PORT`: Change the local port (default 8888, auto-increments if busy)

## Troubleshooting

- **Can't connect**: Ensure you have SSH access to the remote machine
- **Jupyter won't start**: Check that the `jupyter_lab` mamba environment exists
- **Port conflicts**: The script automatically finds available local ports
- **Session issues**: Use the `debug` command to see tmux output

## License

MIT