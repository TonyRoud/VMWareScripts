function Get-DodgyViewDesktopsCheck {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)][string[]]$ConnectionServer<#,
        [Parameter(Mandatory = $true)][string]$user,
        [Parameter(Mandatory = $true)][string]$domain,
        [Parameter(Mandatory = $true)][SecureString]$password
        #>
    )

    begin {
        try {
            Write-Verbose "Importing Horizon View PowerShell Modules"
            Import-Module VMware.VimAutomation.HorizonView -ErrorAction Stop
            Import-Module VMware.VimAutomation.Core -ErrorAction Stop
        }
        catch {
            Write-Error 'Error loading the horizon view modules'
        }
    }

    process {
        $ProblemVms = ''
        $ProblemVmNames = ''
        $healthy = "connected", "provisioned", "available", "maintenance", "PROVISIONING", "CUSTOMIZING", "DELETING", "DISCONNECTED"

        Write-verbose "Looking for unhealthy machines"
        $ProblemVms = (Get-HVMachineSummary).base | Where-Object { $_.basicstate -notin $healthy }
        $ProblemVmNames = $ProblemVMs.name -join ", "

        if ($ProblemVMs.count -lt 1) {
            $status = '0'
            $desc = "No machines found in unhealthy state"
        }
        elseif ($ProblemVMs.count -lt 5) {
            $status = '1'
            $desc = "$($ProblemVMs.count) machines found in unhealthy state: $ProblemVmNames"
        }
        else {
            $status = '2'
            $desc = "$($ProblemVMs.count) machines found in unhealthy state: $ProblemVmNames"
        }
    }
    end {

        [PSCustomObject]@{
            'status'     = $status
            'desc'       = $desc
            'ProblemVms' = $ProblemVmNames
        }
    }
}