# Connect Jupyter Lab

A simple tool to connect to Jupyter Lab on remote servers with persistent sessions. Once started, your Jupyter Lab session will keep running even if you disconnect your laptop!

## 🖥️ Available Servers

This script works with all our lab servers:
- `ml003.research.partners.org`
- `ml007.research.partners.org`
- `ml008.research.partners.org`

## 📋 Prerequisites

Before using this tool, make sure you have:

1. **SSH access** to one of the remote machines listed above
2. **Your SSH key set up** (see setup instructions below if you haven't done this)

## 🚀 Quick Start (If SSH is already set up)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/pinellolab/connect_jupyter_lab.git
   cd connect_jupyter_lab
   ```

2. **Make the script executable:**
   ```bash
   chmod +x connect_jupyter_lab.sh
   ```

3. **Connect to Jupyter Lab on any of our servers:**
   ```bash
   # For ml003
   ./connect_jupyter_lab.sh ml003.research.partners.org
   
   # For ml007
   ./connect_jupyter_lab.sh ml007.research.partners.org
   
   # For ml008
   ./connect_jupyter_lab.sh ml008.research.partners.org
   ```

That's it! Your browser should open with Jupyter Lab running. 🎉

## 📖 First Time Setup - SSH Configuration

If you've never connected to the server before, follow these steps:

### Step 1: Generate an SSH Key (if you don't have one)

On **your local machine**, run:
```bash
ssh-keygen -t rsa -b 4096
```
Just press Enter for all prompts to use defaults.

### Step 2: Copy Your SSH Key to the Server

Since all our servers share the same filesystem, you only need to copy your SSH key once to any server:

On **your local machine**, run:
```bash
ssh-copy-id your_username@ml003.research.partners.org
```
Enter your password when prompted.

This will work for all servers (ml003, ml007, ml008) because they share the same home directory!

### Step 3: Test SSH Connection

Try connecting to any server without a password:
```bash
ssh your_username@ml003.research.partners.org
# or test with ml007 or ml008 - they should all work now!
```

If it works without asking for a password, you're all set! Type `exit` to disconnect.

### Step 4: (Optional) Set up SSH Config for Easier Access

Add this to `~/.ssh/config` on your local machine:
```
Host ml003
    HostName ml003.research.partners.org
    User your_username

Host ml007
    HostName ml007.research.partners.org
    User your_username

Host ml008
    HostName ml008.research.partners.org
    User your_username
```

Now you can use short names instead of the full hostname:
```bash
./connect_jupyter_lab.sh ml003
./connect_jupyter_lab.sh ml007
./connect_jupyter_lab.sh ml008
```

## 🔧 Setting Up Jupyter Password (First Time Only)

**⚠️ IMPORTANT: Run this ON THE REMOTE SERVER, not your local machine!**

**Note:** Since all our servers share the same filesystem, you only need to set the Jupyter password once on any server, and it will work on all of them (ml003, ml007, ml008).

1. **First, SSH into any remote server:**
   ```bash
   ssh ml003.research.partners.org
   ```

2. **Activate the jupyter environment:**
   ```bash
   mamba activate jupyter_lab
   ```

3. **Set a Jupyter password:**
   ```bash
   jupyter lab password
   ```
   
   You'll see:
   ```
   Enter password: 
   Verify password: 
   [JupyterPasswordApp] Wrote hashed password to /home/your_username/.jupyter/jupyter_server_config.json
   ```

4. **Exit from the remote server:**
   ```bash
   exit
   ```

Now you're ready to use the connect script on any of our servers!

## 💻 Daily Usage

### Start Jupyter Lab
Choose any available server:
```bash
./connect_jupyter_lab.sh ml003.research.partners.org
# or
./connect_jupyter_lab.sh ml007.research.partners.org
# or
./connect_jupyter_lab.sh ml008.research.partners.org
```

This will:
- ✅ Create a persistent session on the server
- ✅ Start Jupyter Lab in the `/data/pinello/PROJECTS` directory
- ✅ Set up a secure tunnel to your computer
- ✅ Open your browser automatically

### Stop Jupyter Lab
```bash
./connect_jupyter_lab.sh ml003.research.partners.org stop
```

### Reconnect After Closing Your Laptop
Just run the start command again with the same server:
```bash
./connect_jupyter_lab.sh ml003.research.partners.org
```

The script will detect your existing session and reconnect to it - all your notebooks will still be running!

### Managing Multiple Sessions
You can have different Jupyter sessions running on different servers simultaneously:
```bash
# Terminal 1
./connect_jupyter_lab.sh ml003.research.partners.org  # Opens on port 8888

# Terminal 2
./connect_jupyter_lab.sh ml007.research.partners.org  # Opens on port 8889

# Terminal 3
./connect_jupyter_lab.sh ml008.research.partners.org  # Opens on port 8890
```

## 🔍 Troubleshooting

### "Permission denied" when connecting
- Make sure you've set up your SSH key (see First Time Setup above)
- Check that you're using the correct username

### "Command not found: mamba"
- The server doesn't have mamba installed
- Contact your system administrator

### "Port 8888 is already in use"
- The script will automatically find another port
- You'll see: `[INFO] Creating SSH tunnel from localhost:8889...`

### See what's happening on the server
```bash
./connect_jupyter_lab.sh ml003.research.partners.org debug
```

### Manually attach to the tmux session
```bash
ssh ml003.research.partners.org
tmux attach -t jupyter_lab_ml003_research_partners_org
```
(Press `Ctrl+B` then `D` to detach)

## 📁 Working Directory

By default, Jupyter Lab starts in `/data/pinello/PROJECTS`. All your notebooks and files should be saved there.

## 🤝 Support

If you encounter any issues:
1. Try the debug command first
2. Check the Troubleshooting section
3. Ask in the lab Slack channel
4. Open an issue on GitHub

## 👥 Contributing

Feel free to submit issues and enhancement requests!

---
Made with ❤️ by the Pinello Lab