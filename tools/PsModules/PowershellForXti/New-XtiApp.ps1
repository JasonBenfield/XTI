function New-XtiApp {
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Production", "Development", "Test", "Staging")]
        $EnvName = "Production",
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppName, 
        [ValidateSet("WebApp", "Package", "Service")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppType,
        $AppTitle = ""
    )
    & "$($env:XTI_Tools)\XTI_AppTool\XTI_AppTool.exe" --environment $EnvName --Command add --AppName $AppName --AppType $AppType --AppTitle $AppTitle
}