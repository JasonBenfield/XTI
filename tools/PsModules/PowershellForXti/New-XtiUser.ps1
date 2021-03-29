function New-XtiUser {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [string] $UserName = "", 
        [string] $Password = ""
    )
    & "$($env:XTI_Tools)\XTI_UserTool\XTI_UserTool.exe" --environment $EnvName --Command User --UserName "`"$UserName`"" --Password "`"$Password`""
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Unable to create user"
    }
}

function New-XtiUserRoles {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string] $AppName = "",
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("", "WebApp", "Package", "Service")]
        [string] $AppType = "",
        [string] $UserName = "", 
        [string] $RoleNames = ""
    )
    & "$($env:XTI_Tools)\XTI_UserTool\XTI_UserTool.exe" --environment $EnvName --Command UserRoles --AppName "`"$AppName`"" --AppType "`"$AppType`"" --UserName "`"$UserName`"" --RoleNames "`"$RoleNames`""
    
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Unable to add user roles"
    }
}

function Xti-GrantModCategoryAdmin {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string] $AppName = "",
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("", "WebApp", "Package", "Service")]
        [string] $AppType = "",
        [string] $UserName = "", 
        [string] $ModCategoryName = ""
    )
    & "$($env:XTI_Tools)\XTI_UserTool\XTI_UserTool.exe" --environment $EnvName --Command "grant-modcategoryadmin" --AppName "`"$AppName`"" --AppType "`"$AppType`"" --UserName "`"$UserName`"" --ModCategoryName $ModCategoryName
    
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Unable to grant mod category admin"
    }
}

function Xti-GeneratePassword {
    return [System.Guid]::NewGuid().ToString("N") + "!"
}

function New-XtiCredentials {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [string] $CredentialKey = "", 
        [string] $UserName = "", 
        [string] $Password = ""
    )
    
    function Make-New-XtiCredentials {
        param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName="Production", 
        [string] $CredentialKey = "", 
        [string] $UserName = "", 
        [string] $Password = ""
        )
        & "$($env:XTI_Tools)\XTI_UserTool\XTI_UserTool.exe" --environment $EnvName --Command Credentials --CredentialKey "`"$CredentialKey`"" --UserName "`"$UserName`"" --Password "`"$Password`""
    
        if( $LASTEXITCODE -ne 0 ) {
            Throw "Unable to create credentials"
        }
    }
    if ($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $pscred = Get-XtiPsCredential -Key "xti_productionmachine_admin"
        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $pscred
            ScriptBlock = ${Function:Make-New-XtiCredentials}
            ArgumentList = $EnvName, $CredentialKey, $UserName, $Password
        }
        Invoke-Command @parameters
    }
    else {
        Make-New-XtiCredentials  @PsBoundParameters
    }
}