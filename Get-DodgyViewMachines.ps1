<#
Where state can be one of the below variables -

Error States -
PROVISIONING_ERROR
WAIT_FOR_AGENT
ERROR
AGENT_UNREACHABLE
UNASSIGNED_USER_CONNECTED
UNASSIGNED_USER_DISCONNECTED
AGENT_ERR_STARTUP_IN_PROGRESS
AGENT_ERR_DISABLED
AGENT_ERR_INVALID_IP
AGENT_ERR_NEED_REBOOT
AGENT_ERR_PROTOCOL_FAILURE
AGENT_ERR_DOMAIN_FAILURE
AGENT_CONFIG_ERROR
ALREADY_USED
IN_PROGRESSDISABLED
DISABLE_IN_PROGRESS
VALIDATING
UNKNOWN

Normal States
PROVISIONING
CUSTOMIZING
DELETING
MAINTENANCE
PROVISIONED
CONNECTED
DISCONNECTED
AVAILABLE

Ideally we'd want to check for all the error states and if machines are detected in any of them raise an alert of some sort.

ALREADY_USED
PROVISIONING_ERROR
ERROR
AGENT_UNREACHABLE
UNKNOWN

 C:\Users\administrator.RQIH-CLOUD> Get-HVMachineSummary  | select -first 1 | gm


   TypeName: VMware.Hv.MachineNamesView

Name                    MemberType Definition
----                    ---------- ----------
Equals                  Method     bool Equals(System.Object obj)
GetHashCode             Method     int GetHashCode()
GetType                 Method     type GetType()
ToString                Method     string ToString()
Base                    Property   VMware.Hv.MachineBase Base {get;set;}
Id                      Property   VMware.Hv.MachineId Id {get;set;}
ManagedMachineNamesData Property   VMware.Hv.MachineManagedMachineNamesData ManagedMachineNamesData {get;set;}
MessageSecurityData     Property   VMware.Hv.MachineMessageSecurityData MessageSecurityData {get;set;}
NamesData               Property   VMware.Hv.MachineNamesData NamesData {get;set;}

 C:\Users\administrator.RQIH-CLOUD> $problemvms | gm


   TypeName: VMware.Hv.MachineBase

Name                             MemberType Definition
----                             ---------- ----------
Equals                           Method     bool Equals(System.Object obj)
GetHashCode                      Method     int GetHashCode()
GetType                          Method     type GetType()
ToString                         Method     string ToString()
AccessGroup                      Property   VMware.Hv.AccessGroupId AccessGroup {get;set;}
AgentBuildNumber                 Property   string AgentBuildNumber {get;set;}
AgentVersion                     Property   string AgentVersion {get;set;}
BasicState                       Property   string BasicState {get;set;}
Desktop                          Property   VMware.Hv.DesktopId Desktop {get;set;}
DnsName                          Property   string DnsName {get;set;}
Name                             Property   string Name {get;set;}
OperatingSystem                  Property   string OperatingSystem {get;set;}
RemoteExperienceAgentBuildNumber Property   string RemoteExperienceAgentBuildNumber {get;set;}
RemoteExperienceAgentVersion     Property   string RemoteExperienceAgentVersion {get;set;}
Session                          Property   VMware.Hv.SessionId Session {get;set;}
Type                             Property   string Type {get;set;}
User                             Property   VMware.Hv.UserOrGroupId User {get;set;}
#>

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
        <#
        Foreach ($CsServer in $ConnectionServer) {
            try {
                      
                Write-Verbose "Attempting to connect to View Connection Server `'$CsServer`'"
                Connect-HVServer -Server $CsServer -User $user -Password $password -domain $domain -ErrorAction Stop
            } 
            catch {
            Write-Error "Error connecting to $ConnectionServer"
            }
        }
        #>
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
        
        <#
        # Remove connection to CS Server as no longer required
        Foreach ($CsServer in $ConnectionServer) {
            Disconnect-HvServer -Server $ConnectionServer -Force
        }
        #>
    }
}