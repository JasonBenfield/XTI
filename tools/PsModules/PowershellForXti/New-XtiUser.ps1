function New-XtiUser {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [string] $CredentialKey = "", 
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string] $AppKey = "",
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string] $AppType = "",
        [string] $UserName = "", 
        [string] $Password = "", 
        [string] $RoleNames = ""
    )

    $env:DOTNET_ENVIRONMENT=$EnvName
    & "$($env:XTI_Tools)\XTI_UserTool\XTI_UserTool.exe" --AppKey $AppKey --AppType $AppType --CredentialKey $CredentialKey --UserName $UserName --Password $Password RoleNames $RoleNames
    
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Unable to create user"
    }
}