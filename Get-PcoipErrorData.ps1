function Get-PcoipErrorData {

    Param (
        [Parameter(Mandatory=$true)][String]$file,
        [Parameter(Mandatory=$true)][Datetime]$startdate,
        [Parameter(Mandatory=$true)][Datetime]$enddate,
        [Parameter(Mandatory=$true)][Int]$Resolution
    )

    $span = New-TimeSpan -Start $startdate -End $enddate
    $totalpoints = $span.TotalMinutes / $resolution

    Write-Verbose "Total Datapoints is $totalpoints"

    $fileinfo = Get-ChildItem $file
    $content = get-content $file
    $Computername = $fileinfo.BaseName

    for ($point = 1; $point -le $totalpoints; $point++){

    $timeadd = $point * $resolution

    $collected = $startdate.AddMinutes($timeadd)
    $edgepoint = $collected.AddMinutes(-($resolution))

    [Int]$datahit = 0
    [decimal]$adjustment = 0
    [decimal]$loss = 0
    [Int]$lineno = 0
    [decimal]$adjustmenttotal = 0
    [decimal]$adjustmenttop = 0
    [decimal]$losstotal = 0
    [decimal]$losstop = 0
    [decimal]$lossAv = 0
    [decimal]$adjustav = 0

    Write-Verbose "Checking Hits for Datapoint: $point ($($startdate.addminutes($timeadd)))"

        foreach ($line in $content) {

            if ($line) {

                $lineno += 1
                $x = $line.indexof('factor=') + 7
                $datapoint = get-date ($line.Substring(0,19))

                [decimal]$adjustment = $line.substring($x,4)
                [decimal]$loss = $line.Substring(96,5)


                if ($datapoint -lt $collected -and $datapoint -gt $edgepoint) {

                    $datahit += 1
                    $adjustmenttotal += $adjustment
                    $losstotal += $loss

                    if ($adjustment -gt $adjustmenttop){$adjustmenttop = $adjustment}
                    if ($loss -gt $losstop){$losstop = $loss}

                    Write-Verbose "Datapoint $point entry $lineno time $datapoint is between $edgepoint and $collected"
                    Write-Verbose "Total hits: $datahit"
                    Write-Verbose "Adjustment for this hit is $adjustment"

                }

                <#
                else {
                    Write-Verbose "Datapoint $point`: no data between $edgepoint and $collected"
                }
                #>
            }
        }

    if ($datahit -gt 0) {

        $AdjustAv = [math]::round($adjustmenttotal / $datahit, 2)
        $lossAv = [math]::round($losstotal / $datahit, 2)

    }

    Write-Verbose "Total hits for datapoint $point`: $datahit"
    Write-Verbose "Average Loss for this datapoint is $lossAv"
    Write-Verbose "Average adjustment for this datapoint is $AdjustAv"
    Write-Verbose "Max adjustment for this datapoint is $adjustmenttop"

    $props = @{ 'Computername' = $Computername;
                'Collected'= $collected;
                'Loss'= $lossAv;
                'Adjustment'=$adjustav;
                'Hits' = $datahit
                'Maxadjust' = $adjustmenttop
                'Maxloss' = $losstop }

    $outputobj = New-Object -TypeName PSObject -Property $props
    $outputobj.PSObject.TypeNames.Insert(0,’Report.Pcoiperrors’)
    $outputobj | Write-Output
    }
}

