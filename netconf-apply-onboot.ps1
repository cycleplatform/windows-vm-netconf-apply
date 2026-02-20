# ============================================================
# Cycle Windows VM Helpers
# *Netconf Apply OnBoot*
# 
# Applies cloud-init "network-config" to Windows NICs on boot
# Tested with PowerShell 5 on Windows Server 2025
#
# Copyright (c) 2025 Petrichor Holdings, Inc. (Cycle)
# ============================================================

# Requires Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# 1) Create folder on system drive
$FolderPath = "$env:SystemDrive\cycleio\scripts"
Write-Host "Creating folder: $FolderPath" -ForegroundColor Cyan

if (!(Test-Path -Path $FolderPath)) {
    New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
    Write-Host "Folder created successfully" -ForegroundColor Green
} else {
    Write-Host "Folder already exists" -ForegroundColor Yellow
}

# 2) Create netconf-startup.ps1 script
$StartupScriptPath = Join-Path $FolderPath "netconf-startup.ps1"
Write-Host "Creating startup script: $StartupScriptPath" -ForegroundColor Cyan

$StartupScriptContent = @'
# Startup script to find cycle-utils drive and run netconf-apply.ps1
Write-Host "Starting network configuration script..." -ForegroundColor Cyan

try {
    # Find the drive with label "cycle-utils"
    $TargetDrive = Get-Volume | Where-Object { $_.FileSystemLabel -eq "cycle-utils" } | Select-Object -First 1
    
    if ($TargetDrive) {
        $DriveLetter = $TargetDrive.DriveLetter
        Write-Host "Found cycle-utils drive at: ${DriveLetter}:" -ForegroundColor Green
        
        # Build path to the script
        $ScriptPath = "${DriveLetter}:\netconf-apply.ps1"
        
        # Check if script exists
        if (Test-Path -Path $ScriptPath) {
            Write-Host "Executing: $ScriptPath" -ForegroundColor Green
            & $ScriptPath
            Write-Host "Script execution completed" -ForegroundColor Green
        } else {
            Write-Host "Error: Script not found at $ScriptPath" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Error: Drive with label 'cycle-utils' not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
    exit 1
}
'@

# Write the startup script to file
Set-Content -Path $StartupScriptPath -Value $StartupScriptContent -Force
Write-Host "Startup script created successfully" -ForegroundColor Green

# 3) Create scheduled task
Write-Host "Creating scheduled task..." -ForegroundColor Cyan

$TaskName = "Cycle Network Configuration"
$Description = "Runs network configuration from cycle-utils drive at system startup"

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create the action
$Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartupScriptPath`""

# Create the trigger (when the task will run - at startup)
$Trigger = New-ScheduledTaskTrigger -AtStartup

# Create the principal (run as SYSTEM with highest privileges)
$Principal = New-ScheduledTaskPrincipal `
    -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Create the settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# Register the scheduled task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Description $Description `
    -Force | Out-Null

# Verify the task was created
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "`nScheduled task '$TaskName' created successfully!" -ForegroundColor Green
    
    # Display task details
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State, TaskPath | Format-List
    
    Write-Host "`nSetup completed successfully!" -ForegroundColor Green
    Write-Host "The task will run at next system startup." -ForegroundColor Yellow
    
    # Optional: Test the task
    $response = Read-Host "`nDo you want to run cycle netconf-apply now? (Y/N)"
    if ($response -eq 'Y') {
        Write-Host "Running task..." -ForegroundColor Cyan
        Start-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
        
        # Check task status
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Host "Last run time: $($taskInfo.LastRunTime)" -ForegroundColor Cyan
        Write-Host "Last result: $($taskInfo.LastTaskResult)" -ForegroundColor Cyan
    }
} else {
    Write-Host "Failed to create scheduled task." -ForegroundColor Red
}

Write-Host "`nScript execution complete!" -ForegroundColor Green