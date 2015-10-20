function Initialize-Cmd {
[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$FileName,
        
        [Parameter()]
        [String]$Arguments = ''
    )
    if ($PSBoundParameters.Arguments) {
        $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo -ArgumentList @($FileName, $Arguments)
    }
    else { $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo -ArgumentList @($FileName) }
    $ProcessStartInfo.CreateNoWindow = $true
    $ProcessStartInfo.LoadUserProfile = $False
    $ProcessStartInfo.UseShellExecute = $False
    $ProcessStartInfo.RedirectStandardInput = $true
    $ProcessStartInfo.RedirectStandardOutput = $true
    $ProcessStartInfo.RedirectStandardError = $true

    Write-Verbose "Starting process as $FileName $Arguments"

    try { [Diagnostics.Process]::Start($ProcessStartInfo) }
    catch {
        Write-Error -Message "Unable to start $FileName $Arguments $($_.Exception.Message)" 
        return
    }
}

function Read-CmdStream {
    Param ($FuncVars)
    
    [byte[]]$Data = @()
    
    if($FuncVars["StdOutReadOperation"].IsCompleted)
    {
      $StdOutBytesRead = $FuncVars["Process"].StandardOutput.BaseStream.EndRead($FuncVars["StdOutReadOperation"])
      if($StdOutBytesRead -eq 0){break}
      $Data += $FuncVars["StdOutDestinationBuffer"][0..([int]$StdOutBytesRead-1)]
      $FuncVars["StdOutReadOperation"] = $FuncVars["Process"].StandardOutput.BaseStream.BeginRead($FuncVars["StdOutDestinationBuffer"], 0, 65536, $null, $null)
    }
    if($FuncVars["StdErrReadOperation"].IsCompleted)
    {
      $StdErrBytesRead = $FuncVars["Process"].StandardError.BaseStream.EndRead($FuncVars["StdErrReadOperation"])
      if($StdErrBytesRead -eq 0){break}
      $Data += $FuncVars["StdErrDestinationBuffer"][0..([int]$StdErrBytesRead-1)]
      $FuncVars["StdErrReadOperation"] = $FuncVars["Process"].StandardError.BaseStream.BeginRead($FuncVars["StdErrDestinationBuffer"], 0, 65536, $null, $null)
    }
    return $Data,$FuncVars
  }
  function WriteData_CMD
  {
    param($Data,$FuncVars)
    $FuncVars["Process"].StandardInput.WriteLine($FuncVars["Encoding"].GetString($Data).TrimEnd("`r").TrimEnd("`n"))
    return $FuncVars
  }
  function Close_CMD
  {
    param($FuncVars)
    $FuncVars["Process"] | Stop-Process
  }  