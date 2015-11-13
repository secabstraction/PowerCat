function Send-PingAsync {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
[CmdLetBinding()]
     Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$ComputerName,
        
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Int32]$Timeout = 250
    ) #End Param

    $Pings = New-Object Collections.Arraylist

    foreach ($Computer in $ComputerName) {
        [void]$Pings.Add((New-Object Net.NetworkInformation.Ping).SendPingAsync($Computer, $Timeout))
    }
    Write-Verbose "Waiting for ping tasks to complete..."
    [Threading.Tasks.Task]::WaitAll($Pings)

    foreach ($Ping in $Pings) { Write-Output $Ping.Result }
}
