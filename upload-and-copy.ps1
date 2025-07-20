param (
    [string]$FilePath  # Path to the file that will be uploaded
)

# =============================================================================
# PowerShell File Upload Script with GUI Rename Dialog
# 
# This script uploads files to a remote server via SSH using PuTTY's pscp.exe
# Features:
# - GUI dialog for renaming files before upload
# - Automatic URL generation and clipboard copy
# - Windows toast notifications for success/error feedback
# - Comprehensive logging with timestamps
# - File name sanitization for cross-platform compatibility
# - Configurable server settings and paths
# 
# Author: grymmjack <grymmjack@gmail.com>
# Dependencies: PuTTY suite (pscp.exe, pageant.exe), .NET Framework
# =============================================================================

# =============================================================================
# CONFIGURATION SECTION - Customize these variables for your environment
# =============================================================================

# Upload Server Configuration
# ---------------------------
# The SSH username for connecting to your server
$UPLOAD_USERNAME = "root"

# The hostname or IP address of your upload server
$UPLOAD_SERVER = "share.grymmjack.com"

# The remote directory path where files will be uploaded (must end with /)
$UPLOAD_REMOTE_DIR = "/var/www/html/grymmjack.com/public_html/share/"

# The PuTTY session profile name (created with PuTTY Connection Manager)
# This profile should contain your SSH key configuration and connection settings
$PUTTY_PROFILE = "linode"

# Local System Configuration
# --------------------------
# Path to pscp.exe (PuTTY Secure Copy). Adjust if PuTTY is installed elsewhere
$PSCP_PATH = "C:\Program Files\PuTTY\pscp.exe"

# Public URL Configuration
# ------------------------
# The base public URL where uploaded files will be accessible
# This should match your web server's document root for the upload directory
# Example: if files are uploaded to /var/www/html/share/ then this should be https://yourdomain.com/share/
$PUBLIC_BASE_URL = "https://share.grymmjack.com"

# Logging Configuration
# ---------------------
# Custom log file paths (leave empty to use default user profile location)
# Default locations: %USERPROFILE%\pscp_upload_success.log and %USERPROFILE%\pscp_upload_errors.log
$CUSTOM_SUCCESS_LOG = ""  # Example: "C:\Logs\upload_success.log"
$CUSTOM_ERROR_LOG = ""    # Example: "C:\Logs\upload_errors.log"

# =============================================================================
# END CONFIGURATION SECTION
# =============================================================================

# Required .NET types for GUI components, web encoding, and system integration
Add-Type -AssemblyName System.Windows.Forms    # For GUI dialogs and notifications
Add-Type -AssemblyName System.Drawing          # For GUI positioning and icons
Add-Type -AssemblyName System.Web              # For URL encoding
Add-Type -AssemblyName PresentationFramework   # For advanced UI components

# Set error handling to stop on any error (ensures proper error reporting)
$ErrorActionPreference = 'Stop'

# Setup logging paths (use custom paths if specified, otherwise use defaults)
$successLog = if ($CUSTOM_SUCCESS_LOG) { $CUSTOM_SUCCESS_LOG } else { "$env:USERPROFILE\pscp_upload_success.log" }
$errorLog = if ($CUSTOM_ERROR_LOG) { $CUSTOM_ERROR_LOG } else { "$env:USERPROFILE\pscp_upload_errors.log" }
$timestamp = Get-Date -Format o  # ISO 8601 timestamp format for precise logging

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Writes a success message to the log file with timestamp
.DESCRIPTION
    Appends a timestamped message to the success log file. Creates the log file
    if it doesn't exist. Used for tracking successful operations and debugging.
.PARAMETER msg
    The message to write to the success log
.EXAMPLE
    Log "File uploaded successfully: example.png"
#>
function Log($msg) {
    Add-Content -Path $successLog -Value "[${timestamp}] $msg"
}

<#
.SYNOPSIS
    Writes an error message to the error log file with timestamp
.DESCRIPTION
    Appends a timestamped error message to the error log file. Creates the log 
    file if it doesn't exist. Used for tracking failures and troubleshooting.
.PARAMETER msg
    The error message to write to the error log
.EXAMPLE
    LogError "Upload failed: connection timeout"
#>
function LogError($msg) {
    Add-Content -Path $errorLog -Value "[${timestamp}] $msg"
}

# =============================================================================
# NOTIFICATION FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Displays a Windows toast notification for upload errors
.DESCRIPTION
    Shows a system tray notification with an error icon and message when an upload
    fails. Also copies the error message to clipboard for easy sharing/debugging.
    Uses a 5-second display timeout and automatically disposes of the notification.
.PARAMETER message
    The error message to display in the toast notification
.EXAMPLE
    Show-ErrorToast "Connection failed: server unreachable"
#>
function Show-ErrorToast($message) {
    try {
        # Copy error to clipboard for easy access/sharing
        Set-Clipboard -Value "Upload error: $message"

        # Create and configure the notification icon
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Error
        $notify.BalloonTipTitle = "Upload failed"
        $notify.BalloonTipText = $message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)  # Show for 5 seconds

        # Wait for display time then cleanup
        Start-Sleep -Seconds 6
        $notify.Dispose()
    } catch {
        # Silently handle any notification failures (non-critical)
    }
}

<#
.SYNOPSIS
    Displays a Windows toast notification for successful uploads
.DESCRIPTION
    Shows a system tray notification with an information icon when an upload
    completes successfully. Displays the public URL and uses a 5-second timeout.
    Automatically disposes of the notification to prevent resource leaks.
.PARAMETER message
    The success message (typically the public URL) to display
.EXAMPLE
    Show-SuccessToast "https://example.com/uploads/myfile.png"
#>
function Show-SuccessToast($message) {
    try {
        # Create and configure the success notification
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = "Upload complete"
        $notify.BalloonTipText = $message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)  # Show for 5 seconds

        # Wait for display time then cleanup
        Start-Sleep -Seconds 6
        $notify.Dispose()
    } catch {
        # Silently handle any notification failures (non-critical)
    }
}

# =============================================================================
# FILE NAME PROCESSING FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Removes invalid characters from file names for cross-platform compatibility
.DESCRIPTION
    Sanitizes a file name by removing or replacing characters that are invalid 
    for file systems or problematic for URLs. Handles Windows invalid characters,
    URL-unsafe characters, and consolidates multiple dashes. Ensures the result
    is not empty after sanitization.
.PARAMETER name
    The original file name to sanitize
.RETURNS
    A sanitized file name safe for file systems and URLs
.EXAMPLE
    $cleanName = Format-SafeFileName "My File<>:Name.txt"
    # Returns: "My-File-Name.txt"
#>
function Format-SafeFileName($name) {
    # Get invalid characters for file names from the system
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    
    # Also remove additional problematic characters for URLs and file systems
    # These characters can cause issues in web URLs or different operating systems
    $additionalInvalid = @('<', '>', ':', '"', '|', '?', '*', '`', '~', '#', '%', '&', '{', '}', '\', '^', '[', ']', '=')
    $allInvalid = $invalid + $additionalInvalid
    
    # Replace all invalid characters with dashes
    foreach ($char in $allInvalid) {
        $name = $name.Replace($char, '-')
    }
    
    # Remove multiple consecutive dashes and trim leading/trailing dashes
    $name = $name -replace '-+', '-'  # Replace multiple dashes with single dash
    $name = $name.Trim('-')           # Remove leading and trailing dashes
    
    # Ensure the name is not empty after sanitization
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = "file-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    }
    
    return $name
}

# =============================================================================
# MAIN SCRIPT EXECUTION
# =============================================================================

try {
    # -------------------------------------------------------------------------
    # INPUT VALIDATION AND FILE PATH PROCESSING
    # -------------------------------------------------------------------------
    
    # Validate that a file path was provided as a parameter
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        throw "No file path provided as parameter."
    }
    
    # Resolve the full path to handle relative paths and validate existence
    # This converts relative paths to absolute paths and verifies the file exists
    try {
        $resolvedPath = Resolve-Path $FilePath -ErrorAction Stop
        $FilePath = $resolvedPath.Path
    } catch {
        throw "Invalid or missing input file path: '$FilePath'"
    }
    
    # Double-check that the path points to an actual file (not a directory)
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        throw "File does not exist or is not a file: '$FilePath'"
    }

    Log "Input file path: $FilePath"

    # -------------------------------------------------------------------------
    # FILE INFORMATION EXTRACTION
    # -------------------------------------------------------------------------
    
    # Extract file information using safer .NET methods to avoid path issues
    try {
        $fileInfo = Get-Item $FilePath
        $originalName = $fileInfo.Name                                    # Full filename with extension
        $ext = $fileInfo.Extension                                        # File extension (.jpg, .png, etc.)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalName)  # Name without extension
    } catch {
        throw "Error processing file path: $($_.Exception.Message)"
    }

    Log "Original file name: $originalName"

    # -------------------------------------------------------------------------
    # GUI RENAME DIALOG CREATION AND CONFIGURATION
    # -------------------------------------------------------------------------

    # Create the main form window for file renaming
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Rename File Before Upload"
    $form.Width = 400
    $form.Height = 180
    $form.StartPosition = "CenterScreen"     # Center the dialog on screen
    $form.FormBorderStyle = "FixedDialog"    # Prevent resizing
    $form.MaximizeBox = $false               # Remove maximize button

    # Create and configure the instruction label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "New filename (no extension):"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(10,20)
    $form.Controls.Add($label)

    # Create and configure the text input box
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Width = 360
    $textBox.Text = $baseName                # Pre-fill with original filename (no extension)
    $textBox.Location = New-Object System.Drawing.Point(10,45)
    $textBox.SelectAll()                     # Select all text for easy replacement
    $form.Controls.Add($textBox)

    # Initialize dialog result variables
    $result = $null      # Will store the user's filename input
    $cancelled = $false  # Tracks if user cancelled the dialog

    # Create and configure the OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Width = 75
    $okButton.Height = 25
    $okButton.Location = New-Object System.Drawing.Point(215,80)
    $okButton.Add_Click({
        $script:result = $textBox.Text    # Capture the user's input
        $form.Close()                     # Close the dialog
    })
    $form.AcceptButton = $okButton        # Allow Enter key to trigger OK
    $form.Controls.Add($okButton)

    # Create and configure the Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Width = 75
    $cancelButton.Height = 25
    $cancelButton.Location = New-Object System.Drawing.Point(295,80)
    $cancelButton.Add_Click({
        $script:cancelled = $true         # Mark as cancelled
        $form.Close()                     # Close the dialog
    })
    $form.CancelButton = $cancelButton    # Allow Escape key to trigger Cancel
    $form.Controls.Add($cancelButton)

    # Set focus to textbox when form is shown (for immediate typing)
    $form.Add_Shown({$textBox.Focus()})

    # Display the dialog and wait for user input
    [void][System.Windows.Forms.Application]::Run($form)

    # -------------------------------------------------------------------------
    # DIALOG RESULT PROCESSING AND FILENAME PREPARATION
    # -------------------------------------------------------------------------

    # Check if user cancelled the operation
    if ($cancelled) {
        Log "Upload cancelled by user"
        return  # Exit gracefully without error
    }

    # Validate that user entered a filename
    if (-not $result) {
        throw "No filename entered - cancelled or empty."
    }

    # Clean up the user input and ensure it's not empty
    $safeBase = $result.Trim()
    if ([string]::IsNullOrWhiteSpace($safeBase)) {
        # Generate a unique filename if user input is empty
        $safeBase = "uploaded-" + [guid]::NewGuid().ToString()
    }

    # -------------------------------------------------------------------------
    # FILE NAME SANITIZATION AND TEMP FILE CREATION
    # -------------------------------------------------------------------------

    # Step 1: Sanitize for local filesystem compatibility
    $fsSafeName = Format-SafeFileName($safeBase + $ext)

    # Step 2: Generate temporary file path in system temp directory
    $tempFile = Join-Path $env:TEMP $fsSafeName

    # Step 3: URL-encode the final filename for web safety
    $safeName = [System.Web.HttpUtility]::UrlEncode($fsSafeName)

    Log "Copying renamed temp file to: $tempFile"
    # Copy the original file to temp location with new name
    Copy-Item $FilePath -Destination $tempFile -Force

    # -------------------------------------------------------------------------
    # SSH UPLOAD PROCESS USING PSCP
    # -------------------------------------------------------------------------

    # Build the remote destination path using configuration variables
    # Format: username@hostname:/remote/directory/path/
    $remotePath = "${UPLOAD_USERNAME}@${UPLOAD_SERVER}:${UPLOAD_REMOTE_DIR}"
    Log "Starting upload with pscp.exe to: $remotePath"
    
    # Verify that pscp.exe exists at the configured path
    if (-not (Test-Path $PSCP_PATH)) {
        throw "pscp.exe not found at specified path: $PSCP_PATH"
    }
    
    # Execute pscp.exe with the following parameters:
    # -agent: Use Pageant for SSH key authentication
    # -load: Load the specified PuTTY session profile
    # -batch: Non-interactive mode (no prompts)
    # Capture both stdout and stderr for error handling
    $pscpResult = & "$PSCP_PATH" -agent -load "$PUTTY_PROFILE" -batch "$tempFile" "$remotePath" 2>&1
    
    # Check the exit code to determine if upload was successful
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "pscp.exe failed with exit code $LASTEXITCODE. Output: $pscpResult"
        throw $errorMsg
    }
    
    Log "pscp.exe completed successfully"

    # -------------------------------------------------------------------------
    # SUCCESS HANDLING AND CLEANUP
    # -------------------------------------------------------------------------

    # Build the public URL where the file can be accessed
    # Combines the configured base URL with the URL-encoded filename
    $url = "${PUBLIC_BASE_URL}/$safeName"
    
    # Copy the URL to clipboard for easy sharing
    Set-Clipboard -Value $url
    Log "Upload successful: $url"

    # Display success notification to user
    Show-SuccessToast $url

    # Clean up the temporary file to save disk space
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
catch {
    # -------------------------------------------------------------------------
    # ERROR HANDLING AND LOGGING
    # -------------------------------------------------------------------------
    
    # Log the error details for troubleshooting
    LogError $_.Exception.Message
    
    # Show user-friendly error notification
    Show-ErrorToast $_.Exception.Message
}
