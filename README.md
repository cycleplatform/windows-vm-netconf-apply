# Cycle Windows VM Metadata Apply Script

<a href="https://cycle.io">
<picture class="red">
  <source media="(prefers-color-scheme: dark)" srcset="https://static.cycle.io/icons/logo/logo-white.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://static.cycle.io/icons/logo/cycle-logo-fullcolor.svg">
  <img alt="cycle" width="300px" src="https://static.cycle.io/icons/logo/cycle-logo-fullcolor.svg">
</picture>
</a>

A collection of PowerShell scripts for applying a Linux-style cloud-init configuration to a Windows VM on Cycle.


## Running Scripts Inside a Cycle Windows VM

Cycle automatically attaches a config-drive to every VM during provisioning. This drive contains metadata including:

- `user-data`
- `meta-data`
- `network-config`

To run these scripts inside the VM:

### 1. Use an attachment to mount the ISO containing this script into the VM.

It will most likely be available under the `F:\` drive, but may be different for you.

### 2. Connect to the VM using VNC in the Cycle Portal

Open the VM in the Cycle Portal and use the built-in VNC console to connect and log in.

### 3. Open PowerShell

Right-click Start → Windows PowerShell.

### 4. Run the selected script

```powershell
F:\netconf-apply.ps1
```

Expected output example:

```
[Cycle] Applying network configuration...
[Cycle] Found network-config on D:
[Cycle] Nics in YAML:
  Key=eth0 MAC=xx:xx:xx:xx:xx:xx Name=Ethernet
  Key=eth1 MAC=xx:xx:xx:xx:xx:xx Name=Ethernet 2
...
[Cycle] Network configuration applied successfully.
```
### Network Configuration Script

`netconf-apply.ps1`

This script reads the Linux-style network-config file from the VM’s config-drive and applies the full network setup to Windows. It parses the YAML, matches adapters by MAC address, renames NICs if specified, and configures IPv4/IPv6 addresses, routes, DNS, and MTU values using netsh.

### Setup task on windows boot

Setup a windows scheduled task to always run netconf-apply on system boot.

```powershell
F:\netconf-apply-onboot.ps1
```

This will add a cycleio directory and script on your systemdrive along with a scheduled task to always apply netconf-apply.ps1 on system startup. This is recommended as networking configuration can change between stopping and starting your VM.