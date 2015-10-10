function New-RuntimeParameter { 
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Type]$Type,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name,

        [Parameter()]
        [Int]$Position,

        [Parameter()]
        [Switch]$Mandatory,

        [Parameter()]
        [String]$HelpMessage,

        [Parameter()]
        [String]$ParameterSetName,

        [Parameter()]
        [Switch]$ValueFromPipeline,
        
        [Parameter()]
        [Switch]$ValueFromPipelineByPropertyName
    )      
    #create a new ParameterAttribute Object
    $Attribute = New-Object Management.Automation.ParameterAttribute

    if ($PSBoundParameters.Position) { $Attribute.Position = $Position }
    if ($Mandatory.IsPresent) { $Attribute.Mandatory = $true }
    if ($PSBoundParameters.HelpMessage) { $Attribute.HelpMessage = $HelpMessage }
    if ($PSBoundParameters.ParameterSetName) { $Attribute.ParameterSetName = $ParameterSetName }
    if ($ValueFromPipeline.IsPresent) { $Attribute.ValueFromPipeline = $true }
    if ($ValueFromPipelineByPropertyName.IsPresent) { $Attribute.ValueFromPipelineByPropertyName = $true }
 
    #create an attributecollection object for the attribute we just created.
    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
 
    #add our custom attribute
    $AttributeCollection.Add($Attribute)

    New-Object Management.Automation.RuntimeDefinedParameter($Name, $Type, $AttributeCollection)
}
