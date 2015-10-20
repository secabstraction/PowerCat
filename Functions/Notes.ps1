# Initialize-NetworkStream                    >> Waits for network connection


# Initialize-IOStream -Console                >> 
# If ($NetStream.Available)
# Read-NetworkStream > Write-Console
#
# If ($Console.Availalbe)
# Read-Console > Write-NetworkStream
New-PowerCat -Listener -Port 444 
New-PowerCat -Client 8.8.8.8 -Port 444

# If ($NetStream.Available)
# Read-NetworkStream
# WriteAllBytes
New-PowerCat -Listener -Port 444 -OutputFile C:\Pathto\output.file

# Initialize-IOStream
# Read-IOStream
# Write-NetworkStream
New-PowerCat -Execute ConsoleApp
New-PowerCat -PowerShell -ScriptBlock


New-PowerCat -Input byte[]

New-PowerCat -SendFile C:\file

# Read-NetworkStream
# Write-NetworkStream
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -PowerShell