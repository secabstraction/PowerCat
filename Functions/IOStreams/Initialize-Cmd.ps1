function Open-ProcessStreams {
[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$FileName,
        
        [Parameter()]
        [String]$Arguments
    )

    if ($PSBoundParameters.Arguments) { $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo -ArgumentList @($FileName, $Arguments) }
    else { $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo -ArgumentList @($FileName) }
    
    $ProcessStartInfo.CreateNoWindow = $true
    $ProcessStartInfo.LoadUserProfile = $false
    $ProcessStartInfo.UseShellExecute = $false
    $ProcessStartInfo.RedirectStandardInput = $true
    $ProcessStartInfo.RedirectStandardOutput = $true
    $ProcessStartInfo.RedirectStandardError = $true

    Write-Verbose "Starting process: $FileName $Arguments"

    try { [Diagnostics.Process]::Start($ProcessStartInfo) }
    catch {
        Write-Error -Message "Unable to start $FileName $Arguments $($_.Exception.Message)" 
        return
    }
}

function Read-StdOut {
    Param ([Diagnostics.Process]$Process)
    
    #$EncodingType = [System.Text.Encoding]::ASCII

    $Chars = New-Object char[] 65536
    $CharsRead = $Process.StandardOutput.Read($Chars, 0, $Chars.Length)

    if ($CharsRead) { $OutBytes = $EncodingType.GetBytes($Chars, 0, $CharsRead) }
     
    return $OutBytes
}

function Read-StdErr {
    Param ([Diagnostics.Process]$Process)
    
    #$EncodingType = [System.Text.Encoding]::ASCII

    $Chars = New-Object char[] 65536
    $CharsRead = $Process.StandardError.Read($Chars, 0, $Chars.Length)

    if ($CharsRead) { $ErrBytes = $EncodingType.GetBytes($Chars, 0, $CharsRead) }
     
    return $ErrBytes
}

function Write-StdIn {
    Param ([Diagnostics.Process]$Process, [Byte[]]$Data)
    
    $Process.StandardInput.WriteLine($EncodingType.GetString($Data).TrimEnd("`r").TrimEnd("`n"))
}

function Close-ProcessStreams {
    Param ([Diagnostics.Process]$Process)
    
    $Process.Kill()
}  