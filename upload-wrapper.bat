@echo off
REM =============================================================================
REM Upload Wrapper Batch Script
REM 
REM This batch file serves as a wrapper for the upload-and-copy.ps1 PowerShell
REM script. It provides a simple command-line interface and handles PowerShell
REM execution policy issues that might prevent the script from running directly.
REM 
REM Features:
REM - Input validation (file path parameter and file existence)
REM - PowerShell execution with bypass policy for security
REM - Error handling and exit codes
REM - User-friendly error messages
REM - Drag-and-drop compatibility (can be used as desktop shortcut target)
REM 
REM Usage: upload-wrapper.bat "C:\path\to\file.png"
REM 
REM IMPORTANT: This batch file must be in the same directory as upload-and-copy.ps1
REM 
REM Author: grymmjack <grymmjack@gmail.com>
REM Dependencies: PowerShell, upload-and-copy.ps1 (in same directory)
REM =============================================================================

REM -------------------------------------------------------------------------
REM INPUT VALIDATION
REM -------------------------------------------------------------------------

REM Check if a file path was provided as the first parameter
REM %~1 expands to the first parameter with quotes removed
if "%~1"=="" (
    echo Error: No file path provided
    echo Usage: %0 "C:\path\to\file.ext"
    echo.
    echo This script uploads files to a remote server via SSH.
    echo You can also drag and drop files onto this batch file.
    pause
    exit /b 1
)

REM Verify that the specified file actually exists
REM This prevents PowerShell errors and provides immediate feedback
if not exist "%~1" (
    echo Error: File does not exist: %~1
    echo.
    echo Please check the file path and try again.
    pause
    exit /b 1
)

REM -------------------------------------------------------------------------
REM POWERSHELL SCRIPT EXECUTION
REM -------------------------------------------------------------------------

REM Execute the PowerShell upload script with the following parameters:
REM -NoProfile: Skip loading PowerShell profiles (faster startup, fewer conflicts)
REM -STA: Single-Threaded Apartment mode (required for GUI components)
REM -ExecutionPolicy Bypass: Temporarily bypass execution policy restrictions
REM -File: Specify the PowerShell script to execute
REM %~dp0: Expands to the drive and path of this batch file (ensures script is found)
REM         This is why upload-and-copy.ps1 must be in the same directory as this .bat file
REM "%~1": Pass the file path parameter to PowerShell (quotes preserve spaces)

echo Uploading file: %~1
echo.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0upload-and-copy.ps1" "%~1"

REM -------------------------------------------------------------------------
REM ERROR HANDLING AND EXIT CODES
REM -------------------------------------------------------------------------

REM Check the exit code from PowerShell to determine success or failure
REM %ERRORLEVEL% contains the exit code from the last executed command
if %ERRORLEVEL% neq 0 (
    echo.
    echo Upload failed with error code %ERRORLEVEL%
    echo Check the error log for details: %USERPROFILE%\pscp_upload_errors.log
    echo.
    pause
    exit /b %ERRORLEVEL%
)

REM If we reach this point, the upload was successful
echo.
echo Upload completed successfully!
echo The file URL has been copied to your clipboard.
echo.
