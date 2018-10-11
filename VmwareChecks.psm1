function Get-VmHealthCheck {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)][string[]]$computername,
        [Parameter(Mandatory=$true,Position=1)][datetime]$startdate
    )

    Foreach ($computer in $computername){

        Write-Verbose "Checking CPU and Memory metrics for device $computer"

        # Metrics to measure: avrage CPU and RAM (avarage is taken over a 30 mins window)
        $metrics = 'mem.usage.average', 'cpu.usage.average'
        
        # Arrays to store any crit or warning events
        $MemCritCnt = $MemWarnCnt = $CpuCritCnt = $CpuWarnCnt = 0
        
        # Gather all data points on the VM
        $vmstat = get-stat -Entity $computer -Stat $metrics -Start $startDate -ErrorAction Ignore 

        if ($vmstat){

            Write-Verbose "Fetching memory stats for device $computer"
            # Filter RAM Metrics
            $MemMetrics = ($vmstat.Where{ $_.metricid -eq 'mem.usage.average' })
            
            if($MemMetrics){

                # Get Max MEM value
                $MaxRam     = $MemMetrics | Sort-Object value | Select-Object -Last 1
                # $CurrentRam = ($MemMetrics | Select-Object -first 1).value

                # Get details of peak alert
                $MemPeakValue = $MaxRam.Value
                $MemPeakTime  = $MaxRam.Timestamp.ToString("dd/MM/yyyy hh:mm:ss")

                # Grab warning and crit alerts
                $MemAlerts = $MemMetrics | Where-Object { $_.Value -ge 75 }

                # Sort 
                Foreach ($MemAlert in $MemAlerts){
                    if ($MemAlert.Value -ge 85) { $MemCritCnt += 1 }
                    elseif ($MemAlert.Value -ge 75) { $MemWarnCnt += 1 } 
                }
                Write-Verbose "Found $MemCritCnt critical and $MemWarnCnt Memory alerts for $computer in the past $days days"
            }
            else {
                Write-Verbose "No Memory events found for $computer in the past $days days"
            }

            Write-Verbose "Fetching memory stats for device $computer"
            # Select CPU Metrics
            $CpuMetrics = ($vmstat.Where{ $_.metricid -eq 'cpu.usage.average' })

            if($CpuMetrics){

                $MaxCpu       = $CpuMetrics | Sort-Object value | Select-Object -Last 1
                # $CpuCurrent   = ($CpuMetrics | select-object -first 1).value
                $CpuPeakValue = $MaxCpu.Value
                $CpuPeakTime  = $MaxCpu.Timestamp.ToString("dd/MM/yyyy hh:mm:ss")


                # Check RAM Metrics and store anything over 75%
                $CpuAlerts = $CpuMetrics | Where-Object { $_.Value -ge 75 }
                
                # Sort 
                Foreach ($CpuAlert in $CpuAlerts){
                    if ($CPUAlert.Value -ge 85) { $CpuCritCnt += 1; $CpuAlertClass = "Critical" }
                    elseif ($CPUAlert.Value -ge 75) { $CpuWarnCnt += 1;$CpuAlertClass = "Warning" } 
                }
                Write-Verbose "Found $CpuCritCnt critical and $CpuWarnCnt high CPU alerts for $computer in the past $days days"
            }
            else{
                Write-Verbose "Unable to find any CPU metrics for $computer over the last $days days"
            }
        }    
        [PSCustomObject]@{
            Machine      = [String]$computer
            CurrentRam   = $MemMetrics[0].value
            PeakMemVal   = $MemPeakValue 
            PeakMemTime  = $MemPeakTime
            MemWarnCnt   = $MemWarnCnt
            MemCritCnt   = $MemCritCnt
            CpuPeakValue = $CpuPeakValue
            CurrentCpu   = $CpuMetrics[0].value
            CpuPeakTime  = $CpuPeakTime
            CpuWarnCnt   = $CpuWarnCnt
            CpuCritCnt   = $CpuCritCnt
        }
    }
}

Function Get-TriggeredAlarmCheck {
    [CmdletBinding()]
    Param(
        #[Parameter(Mandatory=$True,Position=1)][INT]$date
    )
    #Get triggered alarms within the last day
    Write-Verbose "Checking for triggered VI alarms"

    $triggeredAlarms = Get-View -viewtype virtualmachine | Where-Object {$_.OverallStatus -eq "red"} | Select-Object name,overallstatus,triggeredalarmstate

    if($triggeredAlarms) {
        Write-Verbose "$($triggeredalarms.count) triggered alarms require review"
        $triggeredAlarms
    }
    Else{
        Write-Verbose "No triggered alarms found"
    }
}
function Get-ViEventCheck {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)][INT]$days
    )
    $start = [datetime]::Today.AddDays(-($days)).toshortdatestring()

    Write-Verbose "Checking warning and critical events for last $days days"
    $viEvents = Get-VIEvent -Start $start -MaxSamples ([int]::MaxValue) | Where-Object { $_ -is [VMware.Vim.AlarmStatusChangedEvent] -and $_.to -match 'Red|yellow' -and $_.fullformattedmessage -notmatch 'CPU|memory' } # | Group-Object -Property { $_.Entity.Entity } 

    if ($viEvents){
        ForEach ($viEvent in $viEvents) {
            [PSCustomObject]@{
                Machine   = $viEvent.Entity.Name
                Time      = $viEvent.CreatedTime
                Level     = $viEvent.To
                AlarmName = $viEvent.Alarm.Name
            }
        }
        <# Removed Where-Object {"green", "gray" -notcontains $_.To} from above to include all events #>
        Write-Verbose "Found $($viEvents.count) critical events over the past $days days"
    }
    else { Write-Verbose "No VI error events found over the last 24 hours." }
}
function Get-ViSnapshotCheck {
    [Cmdletbinding()]
    Param(
        [parameter(Mandatory=$true,Position=1)][int]$size
    )

    $snapshots = Get-Snapshot -VM * | Where-Object { $_.sizeGB -gt $size }

    if ($snapshots){
        
        Write-Verbose "Found $($snapshots.count) Snapshots"

        foreach ($snapshot in $snapshots){

            [int]$SnapShotSize  = $snapshot.sizeGB
            [int]$SnapShotAge   = (New-TimeSpan -End (get-date) -Start (Get-Date $snapshot.Created)).Days

            $owner      = "N/A"
            $owner      = Get-VIEvent -Entity $snapshot.VM -Types Info -Finish $snapshot.created -MaxSamples 1 | Where-Object { $_.FullFormattedMessage -imatch 'Task: Create virtual machine snapshot' }
            if ($owner){ $SnapshotOwner = $owner.UserName.trimstart('PARLIAMENT').trimstart("\") }

            [PScustomobject]@{
                Machine      = $snapshot.VM.name
                Owner        = $SnapshotOwner  
                State        = $snapshot.PowerState
                SnapshotName = $snapshot.name
                SnapshotID   = $snapshot.ID
                Size         = $SnapShotSize
                Age          = $SnapShotAge
            }
        }
    }
    else { Write-Verbose "No Snapshots found" }
}