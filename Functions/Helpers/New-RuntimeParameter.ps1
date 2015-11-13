function New-RuntimeParameter { 
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
[CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Type]$Type,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]$Alias,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Int]$Position,

        [Parameter()]
        [Switch]$Mandatory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$HelpMessage,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]$ValidateSet,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Regex]$ValidatePattern,

        [Parameter()]
        [Switch]$ValueFromPipeline,
        
        [Parameter()]
        [Switch]$ValueFromPipelineByPropertyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$ParameterSetName = '__AllParameterSets',

        [Parameter()]
        [System.Management.Automation.RuntimeDefinedParameterDictionary]$ParameterDictionary
    )      
    #create a new ParameterAttribute Object
    $Attribute = New-Object Management.Automation.ParameterAttribute
    $Attribute.ParameterSetName = $ParameterSetName

    if ($PSBoundParameters.Position) { $Attribute.Position = $Position }

    if ($Mandatory.IsPresent) { $Attribute.Mandatory = $true }
    else { $Attribute.Mandatory = $false }

    if ($PSBoundParameters.HelpMessage) { $Attribute.HelpMessage = $HelpMessage }
    
    if ($ValueFromPipeline.IsPresent) { $Attribute.ValueFromPipeline = $true }
    else { $Attribute.ValueFromPipeline = $false }

    if ($ValueFromPipelineByPropertyName.IsPresent) { $Attribute.ValueFromPipelineByPropertyName = $true }
    else { $Attribute.ValueFromPipelineByPropertyName = $false }
 
    #create an attributecollection object for the attribute we just created.
    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
 
    if ($PSBoundParameters.ValidateSet) {
        $ParamOptions = New-Object Management.Automation.ValidateSetAttribute -ArgumentList $ValidateSet
        $AttributeCollection.Add($ParamOptions)
    }

    if ($PSBoundParameters.Alias) {
        $ParamAlias = New-Object Management.Automation.AliasAttribute -ArgumentList $Alias
        $AttributeCollection.Add($ParamAlias)
    }

    if ($PSBoundParameters.ValidatePattern) {
        $ParamPattern = New-Object Management.Automation.ValidatePatternAttribute -ArgumentList $ValidatePattern
        $AttributeCollection.Add($ParamPattern)
    }

    #add our custom attribute
    $AttributeCollection.Add($Attribute)

    $Parameter = New-Object Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)

    if($PSBoundParameters.ParameterDictionary) { $ParameterDictionary.Add($Name, $Parameter) }
    else {
        $Dictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        $Dictionary.Add($Name, $Parameter)
        Write-Output $Dictionary
    }
}