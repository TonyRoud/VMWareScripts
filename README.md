# Description

Assorted VMware PowerShell / PowerCLI scripts for automating tasks and checks in vSphere.

## Contents

### VmwareChecks.psm1

Module containing various functions to automate daily manual VMWare checks.

### Get-VmwareViewCheck.ps1

Script I created which checks for unhealthy machines in a VMware View farm and returns a Nagios formatted object with the status of each.

### Get-PcoiopErrorData.ps1

I created this script to parse PCoIP logs on VMware View machines and chart any occurrences of entries that indicated bandwidth throttling. This was to assist with an investigation into ongoing poor performance of VDI desktops for a customer.