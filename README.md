# Connect Jupyter Lab

A simple tool to connect to Jupyter Lab on remote servers with persistent sessions. Once started, your Jupyter Lab session will keep running even if you disconnect your laptop!

## 📋 Prerequisites

Before using this tool, make sure you have:

1. **SSH access** to the remote machine (e.g., `ml003.research.partners.org`)
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

3. **Connect to Jupyter Lab:**
   ```bash
   ./connect_jupyter_lab.sh ml003.research.partners.org
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

On **your local machine**, run:
```bash
ssh-copy-id your_username@ml003.research.partners.org
```
Enter your password when prompted.

### Step 3: Test SSH Connection

Try connecting without a password:
```bash
ssh your_username@ml003.research.partners.org
```

If it works without asking for a password, you're all set! Type `exit` to disconnect.

### Step 4: (Optional) Set up SSH Config for Easier Access

Add this to `~/.ssh/config` on your local machine:
```
Host ml003
    HostName ml003.research.partners.org
    User your_username
```

Now you can use just `ml003` instead of the full hostname:
```bash
./connect_jupyter_lab.sh ml003
```

## 🔧 Setting Up Jupyter Password (First Time Only)

**⚠️ IMPORTANT: Run this ON THE REMOTE SERVER, not your local machine!**

1. **First, SSH into the remote server:**
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

Now you're ready to use the connect script!

## 💻 Daily Usage

### Start Jupyter Lab
```bash
./connect_jupyter_lab.sh ml003.research.partners.org
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
Just run the start command again:
```bash
./connect_jupyter_lab.sh ml003.research.partners.org
```

The script will detect your existing session and reconnect to it - all your notebooks will still be running!

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