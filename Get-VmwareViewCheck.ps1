<#
.Synopsis
   Queries a Horizon View server and reports any desktops that are not in a 'healthy' state
.DESCRIPTION
   This cmdlet uses VMware.VimAutomation modules to query a specific horizon view server and returns an object to represent the number of failed desktops, plus the associated machine IDs. The horizon view modules need to be installed on the machine calling the function. Password for script user must be saved as secure string to the following file "C:\Program Files\WindowsPowerShell\Modules\viewcheck\securepass.txt".
.EXAMPLE
   Get-DodgyViewDesktops -connectionserver 10.45.12.78 -credential $credential
#>
function Get-DodgyViewDesktops {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)][string[]]$ConnectionServer,
        [Parameter(Mandatory = $true)][string]$user,
        [Parameter(Mandatory = $true)][SecureString]$password
    )

    begin {
        try {
            Write-Verbose "Importing VMware module dependencies"
            $VerbosePreference = 'SilentlyContinue'
            $null = Import-Module VMware.VimAutomation.HorizonView -ErrorAction Stop
            $null = Import-Module VMware.VimAutomation.Core -ErrorAction Stop
            $VerbosePreference = 'Continue'
        } 
        catch {
            Write-Warning "Couldn`'t load the horizon view modules"
        }
    }

    process {

        $healthy = @(
            'PROVISIONING'
            'CUSTOMIZING'
            'DELETING'
            'MAINTENANCE'
            'PROVISIONED'
            'CONNECTED'
            'ISCONNECTED'
            'AVAILABLE'
            'DISCONNECTED'
        )

        Foreach ($server in $ConnectionServer) {

            try {
                Write-Verbose "Attempting to connect to View server $server"
                $null = Connect-HVServer -Server $server -user $user -password $password -ErrorAction Stop 
            }
            catch {
                Write-Warning "Error connecting to $server"
            }

            Write-Verbose "Fetching session information from $server"
            $allVms = (Get-HVMachineSummary).base
            Write-Verbose "Found $($allVms.count) machines total"

            $ProblemVMs = $allVms | Where-Object {$_.basicstate -notin $healthy} #| select -Unique
            
            $vmlist = @()
            
            ForEach ($vm in $ProblemVMs) {
                $vmlist += ($vm.name + "(" + "$($vm.basicstate)" + ")")
            } 

            $vmlist = $vmlist -join ", "
            
            Write-Verbose "$($ProblemVMs.count) machine(s) found in error state"

            if ($ProblemVMs.Count -lt 1) {
                $status = '0'
                $desc = "No machines found in unhealthy state"
            }
            elseif ($ProblemVMs.Count -lt 5) {
                $status = '1'
                $desc = "$($ProblemVMs.Count) machine(s) found in unhealthy state: $vmlist"
            }
            else {
                $status = '2'
                $desc = "$($ProblemVMs.Count) machines found in unhealthy state. Check machines: $vmlist"
            }

            Write-Verbose "Cleaning up connection to $server"
            Disconnect-HVServer -Server $server -force -confirm:$false

            [PSCustomObject]@{
                'connectionserver' = $server
                'status'           = $status
                'desc'             = $desc
            }
        }
    }
    end {}
}