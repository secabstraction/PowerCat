function Send-PingAsync {

[CmdLetBinding()]
     Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$ComputerName
    ) #End Param

    $Pings = New-Object Collections.Arraylist

    foreach ($Computer in $ComputerName) {
        [void]$Pings.Add((New-Object Net.NetworkInformation.Ping).SendPingAsync($Computer, 250))
    }
    [Threading.Tasks.Task]::WaitAll($Pings)

    foreach ($Ping in $Pings) { Write-Output $Ping.Result }
}
