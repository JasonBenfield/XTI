function New-XtiApp {
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Production", "Development", "Test", "Staging")]
        $EnvName = "Production",
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppKey, 
        [ValidateSet("WebApp", "Package")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppType,
        $AppTitle = ""
    )

    $appTool = "$($env:XTI_Tools)\XTI_AppTool\XTI_AppTool.exe"
    $env:DOTNET_ENVIRONMENT = $EnvName
    & $appTool --Command add --AppKey $AppKey --AppType $AppType --AppTitle $AppTitle
}