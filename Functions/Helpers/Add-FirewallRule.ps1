function Add-FirewallRule {
    Param (
        [Parameter()]
        [String]$Name,

        [Parameter()]
        [ValidateSet('HOPOPT','ICMPv4','IGMP','TCP','UDP','IPv6','IPv6Route','IPv6Frag','GRE','ICMPv6','IPv6NoNxt','IPv6Opts','VRRP','PGM','L2TP')]
        [String]$Protocol,
        
        [Parameter()]
        [Int[]]$Ports,
        
        [Parameter()]
        [String]$ApplicationName,
        
        [Parameter()]
        [String]$ServiceName
    )
    $Fw = New-Object -ComObject HNetCfg.FwPolicy2 
    $Rule = New-Object -ComObject HNetCfg.FWRule
        
    $Rule.Name = $Name
    if ($PSBoundParameters.ApplicationName) { $Rule.ApplicationName = $ApplicationName }
    if ($PSBoundParameters.ServiceName) { $Rule.ServiceName = $ServiceName }
    
    $Rule.Protocol = switch ($Protocol) {
           'HOPOPT' { 0 }
           'ICMPv4' { 1 }
             'IGMP' { 2 }
              'TCP' { 6 }
              'UDP' { 17 }
             'IPv6' { 41 }
        'IPv6Route' { 43 }
         'IPv6Frag' { 44 }
              'GRE' { 47 }
           'ICMPv6' { 58 }
        'IPv6NoNxt' { 59 }
         'IPv6Opts' { 60 }
             'VRRP' { 112 }
              'PGM' { 113 }
             'L2TP' { 115 }
    }
    $Rule.LocalPorts = $Ports
    $Rule.Enabled = $true
    $Rule.Grouping = "@firewallapi.dll,-23255"
    $Rule.Profiles = 7 # all
    $Rule.Action = 1 # NET_FW_ACTION_ALLOW
    $Rule.EdgeTraversal = $false
    
    $Fw.Rules.Add($Rule)
}