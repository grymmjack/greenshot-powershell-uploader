# PowerShell Upload Script Configuration Guide

This guide explains how to configure the `upload-and-copy.ps1` script for your own environment.

> **📝 Note**: Throughout this guide, replace `username` with your actual Windows username (e.g., if your user folder is `C:\Users\john`, replace `username` with `john`).

## �️ Tested Environment

This script and configuration guide has been tested and verified on the following environment:

| Component | Version | Notes |
|-----------|---------|-------|
| **Windows** | Windows 11 24H2 (Build 26100.4652) | Should work on Windows 10/11 |
| **PowerShell** | 5.1.26100.4652 | Built-in Windows PowerShell |
| **PuTTY Suite** | 0.83 | Includes PuTTY, PSCP, Pageant, PuTTYgen |
| **Greenshot** | v1.2.10 | Screenshot and annotation tool |

### 🚀 Quick Installation (Advanced Users)

For advanced users, you can install PuTTY using Windows Package Manager:
```cmd
winget install putty.putty
```

For regular installation, download from the official sources listed in the setup steps below.

## �📋 Configuration Variables

Edit the configuration section at the top of `upload-and-copy.ps1` to match your setup:

### 🌐 Upload Server Configuration

```powershell
$UPLOAD_USERNAME = "your-ssh-username"     # SSH username for your server
$UPLOAD_SERVER = "your-domain.com"         # Your server hostname/IP
$UPLOAD_REMOTE_DIR = "/path/to/upload/"    # Remote directory (must end with /)
$PUTTY_PROFILE = "your-profile-name"       # PuTTY session profile name
```

**Examples:**
- **Username**: `root`, `ubuntu`, `www-data`, `your-username`
- **Server**: `example.com`, `192.168.1.100`, `files.mysite.org`
- **Remote Dir**: `/var/www/html/uploads/`, `/home/user/public/`, `/srv/files/`
- **Profile**: `myserver`, `webhost`, `production`

### 💻 Local System Configuration

```powershell
$PSCP_PATH = "C:\Program Files\PuTTY\pscp.exe"
```

**Common PuTTY installation paths:**
- Default: `C:\Program Files\PuTTY\pscp.exe`
- 32-bit on 64-bit: `C:\Program Files (x86)\PuTTY\pscp.exe`
- Portable: `C:\Tools\PuTTY\pscp.exe`
- Chocolatey: `C:\ProgramData\chocolatey\bin\pscp.exe`

### 🔗 Public URL Configuration

```powershell
$PUBLIC_BASE_URL = "https://your-domain.com/uploads"
```

This should be the web-accessible URL that corresponds to your `$UPLOAD_REMOTE_DIR`.

**Mapping Examples:**
- Remote: `/var/www/html/uploads/` → URL: `https://mysite.com/uploads`
- Remote: `/var/www/html/files/` → URL: `https://mysite.com/files`
- Remote: `/srv/nginx/static/` → URL: `https://cdn.mysite.com`

### 📝 Logging Configuration

```powershell
$CUSTOM_SUCCESS_LOG = ""  # Leave empty for default location
$CUSTOM_ERROR_LOG = ""    # Leave empty for default location
```

**Default locations:**
- Success: `%USERPROFILE%\pscp_upload_success.log`
- Error: `%USERPROFILE%\pscp_upload_errors.log`

**Custom examples:**
- `"C:\Logs\upload_success.log"`
- `"D:\MyApp\Logs\upload_errors.log"`
- `"\\NetworkShare\Logs\upload.log"`

## 🔧 Setup Steps

### 1. Install PuTTY

**Option A: Official Download (Recommended for most users)**
Download from: https://www.putty.org/

**Option B: Windows Package Manager (Advanced users)**
```cmd
winget install putty.putty
```

This installs the complete PuTTY suite including PuTTY, PSCP, Pageant, and PuTTYgen.

### 2. File Placement and Directory Setup

**Create a dedicated directory for the upload scripts:**
```cmd
mkdir C:\Users\username\bin
```
(Replace `username` with your actual Windows username)

**Copy both script files to the same directory:**
- `upload-and-copy.ps1` (PowerShell script)
- `upload-wrapper.bat` (Batch wrapper)

> **⚠️ Important**: The `.bat` and `.ps1` files must be in the same directory. The batch file uses relative path references (`%~dp0`) to locate the PowerShell script, so they cannot be separated.

**Example directory structure:**
```
C:\Users\username\bin\
├── upload-and-copy.ps1
└── upload-wrapper.bat
```

### 3. SSH Key Setup and PuTTY Session Configuration

#### 3a. Generate SSH Key Pair
1. Open **PuTTYgen** (installed with PuTTY)
2. Select **RSA** key type and set **Number of bits** to **2048** or **4096**
3. Click **Generate** and move your mouse randomly to create entropy
4. Once generated:
   - **Key comment**: Enter a descriptive name (e.g., `yourusername@hostname-upload-key` - replace with your actual username and server)
   - **Key passphrase**: Enter a secure passphrase (optional but recommended)
5. **Save the private key**: Click **Save private key** → Save as `upload-key.ppk` in a secure location
6. **Copy the public key**: Select all text in the "Public key for pasting..." box and copy it

#### 3b. Install Public Key on Server
1. Connect to your server via SSH using existing credentials (password or existing key)
2. Create SSH directory: `mkdir -p ~/.ssh && chmod 700 ~/.ssh`
3. Add your public key: `echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys`
4. Set permissions: `chmod 600 ~/.ssh/authorized_keys`

**Note**: Replace `YOUR_PUBLIC_KEY_HERE` with the actual public key text you copied from PuTTYgen.

#### 3c. Configure Pageant (SSH Agent)
1. **Add Pageant to Windows Startup**:
   - Press `Win + R`, type `shell:startup`, press Enter
   - Create a shortcut to `pageant.exe` (usually in `C:\Program Files\PuTTY\`)
   - Right-click shortcut → **Properties** → **Target**: 
     ```
     "C:\Program Files\PuTTY\pageant.exe" "C:\Path\To\Your\upload-key.ppk"
     ```
   - This will auto-load your key on Windows startup

2. **Start Pageant Now**:
   - Run the command above manually or double-click the shortcut
   - Enter your key passphrase when prompted
   - Pageant will run in the system tray

#### 3d. Create PuTTY Session Profile
1. **Open PuTTY**
2. **Basic Connection Settings**:
   - **Host Name**: Enter your server hostname or IP (e.g., `your-server.com`)
   - **Port**: `22` (default SSH port)
   - **Connection type**: `SSH`

3. **Configure SSH Authentication**:
   - Navigate to **Connection** → **SSH** → **Auth** → **Credentials**
   - **Private key file**: Browse and select your `upload-key.ppk` file
   - ✅ Check **Allow agent forwarding** (optional)
   - ✅ Check **Allow attempted changes of username in SSH-2**

4. **Auto-login Configuration**:
   - Navigate to **Connection** → **Data**
   - **Auto-login username**: Enter your SSH username (e.g., `root`, `ubuntu`, `www-data`)

5. **Session Settings**:
   - Navigate back to **Session** (top of tree)
   - **Saved Sessions**: Enter a memorable name (e.g., `YourServerPuttySession`, `linode`, `webserver`)
   - Click **Save** to store the session

6. **Test the Connection**:
   - With your session selected, click **Open**
   - Should connect without password prompt (using SSH key)
   - If prompted for passphrase, ensure Pageant is running with your key loaded

#### 3e. Update Script Configuration
Edit your `$PUTTY_PROFILE` variable to match your saved session name:
```powershell
$PUTTY_PROFILE = "YourServerPuttySession"  # Match your saved PuTTY session name
```

**Example configurations:**
- `$PUTTY_PROFILE = "linode"`
- `$PUTTY_PROFILE = "webserver"`
- `$PUTTY_PROFILE = "production"`

### 4. Configure Script Variables
Edit the configuration section in `upload-and-copy.ps1` with your values.

### 5. Test the Script
```powershell
.\upload-and-copy.ps1 "C:\path\to\test-file.png"
```

### 6. Configure Greenshot Integration (Optional)

#### Step 6a: Install External Command Plugin
1. Open Greenshot
2. Go to **Settings** (right-click Greenshot tray icon → Configure)
3. Navigate to **Plugins** tab
4. If "External command Plugin" is not listed, install it:
   - Download from Greenshot plugins repository
   - Place the plugin DLL in Greenshot's plugins folder
   - Restart Greenshot

#### Step 6b: Configure External Command
1. In Greenshot Settings, go to **Plugins** tab
2. Select **External command Plugin** and click **Configure**
3. Click **New** to create a new command
4. Enter the following settings:

**Command Configuration:**
- **Name**: `Upload to your-domain.com` (customize as needed)
- **Command**: `C:\Users\username\bin\upload-wrapper.bat` (replace `username` with your Windows username)
- **Argument**: `{0}`

**Alternative PowerShell Direct Method:**
- **Name**: `Upload to your-domain.com`
- **Command**: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- **Argument**: `-NoProfile -STA -ExecutionPolicy Bypass -File "C:\Users\username\bin\upload-and-copy.ps1" "{0}"` (replace `username` with your Windows username)

5. Click **OK** to save the command
6. Click **OK** to close External command settings
7. Click **OK** to close Greenshot settings

#### Step 6c: Using the Upload Command
1. Take a screenshot with Greenshot (PrtScn, region select, etc.)
2. In the Greenshot editor, look for your custom command in the toolbar or **File** menu
3. Click your "Upload to your-domain.com" command
4. The rename dialog will appear - enter desired filename
5. File uploads automatically and URL is copied to clipboard

#### Alternative: Quick Upload Shortcut
You can also create a desktop shortcut for quick manual uploads:

**Target**: `C:\Users\username\bin\upload-wrapper.bat` (replace `username` with your Windows username)
**Start in**: `C:\Users\username\bin\` (replace `username` with your Windows username)

Then drag any file onto the shortcut to upload it.

## 🚨 Troubleshooting

### Common Issues:

**"pscp.exe not found"**
- Check `$PSCP_PATH` points to correct PuTTY installation
- Install PuTTY if missing

**"Connection failed"**
- Verify `$PUTTY_PROFILE` name matches saved session
- Test SSH connection manually with PuTTY
- Check firewall/network connectivity

**"Permission denied"**
- Verify `$UPLOAD_USERNAME` has write access to `$UPLOAD_REMOTE_DIR`
- Check SSH key permissions

**"File not accessible via URL"**
- Verify `$PUBLIC_BASE_URL` matches web server configuration
- Check web server permissions on upload directory
- Ensure directory is in web server document root

### SSH Key & Authentication Issues:

**"Server refused our key" or "Authentication failed"**
- Verify public key is properly installed in `~/.ssh/authorized_keys` on server
- Check file permissions: `chmod 600 ~/.ssh/authorized_keys` and `chmod 700 ~/.ssh`
- Ensure private key file path is correct in PuTTY session configuration
- Test key manually: open PuTTY session and verify passwordless login works

**"Unable to use key file" or "Couldn't load private key"**
- Verify `.ppk` file exists and is accessible
- Check if key file is corrupted - regenerate if necessary
- Ensure key was saved in PuTTY format (`.ppk`), not OpenSSH format

**"No supported authentication methods available"**
- Server may not allow SSH key authentication
- Check server's `/etc/ssh/sshd_config` for `PubkeyAuthentication yes`
- Verify `AuthorizedKeysFile` setting points to correct location

**Pageant Issues:**
- **"Agent refused to sign"**: Restart Pageant and reload your key
- **Key not auto-loading**: Check Pageant startup shortcut target path
- **Passphrase keeps prompting**: Verify Pageant is running with your key loaded
- **Multiple keys conflict**: Use `pageant.exe -c "your-command"` to clear all keys first

**PuTTY Session Configuration Issues:**
- **Wrong username**: Verify **Connection** → **Data** → **Auto-login username** matches server
- **Wrong hostname**: Double-check **Session** → **Host Name** field
- **Session not found**: Verify `$PUTTY_PROFILE` exactly matches saved session name (case-sensitive)
- **Key not loading**: Check **Connection** → **SSH** → **Auth** → **Credentials** → **Private key file**

### Greenshot Integration Issues:
- **Command not appearing**: Restart Greenshot after plugin installation
- **"File not found" error**: Verify paths in External Command configuration
- **PowerShell execution policy**: Run `Set-ExecutionPolicy RemoteSigned` as Administrator
- **Upload dialog not showing**: Ensure `-STA` parameter is included for PowerShell command

## 📖 Example Configurations

### Example 1: Standard Web Server
```powershell
$UPLOAD_USERNAME = "www-data"
$UPLOAD_SERVER = "mywebsite.com"
$UPLOAD_REMOTE_DIR = "/var/www/html/uploads/"
$PUTTY_PROFILE = "webserver"
$PUBLIC_BASE_URL = "https://mywebsite.com/uploads"
```

### Example 2: Personal VPS
```powershell
$UPLOAD_USERNAME = "ubuntu"
$UPLOAD_SERVER = "192.168.1.50"
$UPLOAD_REMOTE_DIR = "/home/ubuntu/public_html/files/"
$PUTTY_PROFILE = "homeserver"
$PUBLIC_BASE_URL = "https://files.home.local"
```

### Example 3: CDN/Static File Server
```powershell
$UPLOAD_USERNAME = "deploy"
$UPLOAD_SERVER = "cdn.company.com"
$UPLOAD_REMOTE_DIR = "/srv/nginx/static/uploads/"
$PUTTY_PROFILE = "cdn-server"
$PUBLIC_BASE_URL = "https://static.company.com/uploads"
```

## 📸 Greenshot Quick Reference

### External Command Plugin Settings
Based on the screenshots provided, here's the exact configuration:

**In Greenshot Settings → Plugins → External command Plugin → Configure:**

| Field | Value |
|-------|-------|
| **Name** | `Upload to share.username.com` (replace `username` with your domain) |
| **Command** | `C:\Users\username\bin\upload-wrapper.bat` (replace `username` with your Windows username) |
| **Argument** | `{0}` |

**Alternative PowerShell Direct:**
| Field | Value |
|-------|-------|
| **Command** | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| **Argument** | `-NoProfile -STA -ExecutionPolicy Bypass -File "C:\Users\username\bin\upload-and-copy.ps1" "{0}"` (replace `username` with your Windows username) |

### Usage Workflow
1. **Capture** → Take screenshot with Greenshot
2. **Edit** → Make any needed edits in Greenshot editor  
3. **Upload** → Click your custom "Upload to..." command
4. **Rename** → Enter filename in dialog that appears
5. **Share** → URL is automatically copied to clipboard

### Tips
- The `{0}` argument passes the screenshot file path to your script
- Use the batch wrapper for simpler configuration
- Use direct PowerShell method for more control
- Customize the "Name" field to match your domain/service
