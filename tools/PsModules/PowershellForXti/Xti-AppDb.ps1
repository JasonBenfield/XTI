function Xti-ResetAppDb {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName='Test'
    )
    $env:DOTNET_ENVIRONMENT=$EnvName
    & "$($env:XTI_Tools)\AppDbTool\AppDbTool.exe" --no-launch-profile -- --Command=reset
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Reset failed"
    }
}

function Xti-BackupAppDb {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName='Production', 
        [Parameter(Mandatory)]
        [string] $backupFilePath
    )
    $env:DOTNET_ENVIRONMENT=$EnvName
    & "$($env:XTI_Tools)\AppDbTool\AppDbTool.exe" --no-launch-profile -- --Command=backup --BackupFilePath $BackupFilePath
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Backup failed"
    }
}

function Xti-RestoreAppDb {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        [string] $EnvName='Staging', 
        [Parameter(Mandatory)]
        [string] $BackupFilePath
    )
    $env:DOTNET_ENVIRONMENT=$EnvName
    & "$($env:XTI_Tools)\AppDbTool\AppDbTool.exe" --no-launch-profile -- --Command=restore --BackupFilePath $BackupFilePath
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Restore failed"
    }
}

function Xti-UpdateAppDb {
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“Development", "Production", "Staging", "Test")]
        $EnvName='Test'
    )
    $env:ASPNETCORE_ENVIRONMENT=$EnvName
    dotnet ef database update --project "$($env:XTI_Tools)\..\..\XTI_WebApp\Tools\AppDbTool"
    if( $LASTEXITCODE -ne 0 ) {
        Throw "Update failed"
    }
}