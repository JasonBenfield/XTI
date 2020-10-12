
function Xti-PublishWebApp {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $AppKey,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Production", “Development", "Staging", "Test")]
        [string] $EnvName="Production",
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $ProjectDir
    )

    $ErrorActionPreference = "Stop"

    function Xti-Publish {
        param(
            $AppKey, 
            $EnvName,
            $VersionKey,
            $WebAppUserName,
            $WebAppPassword
        )

        $ErrorActionPreference = "Stop"

        Import-Module WebAdministration
        Import-Module CredentialManager
    
        function New-XtiWebApp {

            param (
                $AppKey,
                $EnvName,
                $Version,
                $WebAppUserName,
                $WebAppPassword
            )
    
            $appFolder = "c:\XTI\WebApps\$EnvName\$AppKey"
            $targetFolder = "$appFolder\$Version"
            if ( -not (Test-Path -Path $targetFolder -PathType Container) ) {
                New-Item -ItemType Directory -Path $targetFolder
            }
            $appPoolName = "Xti_$($EnvName)_$($AppKey)_$($Version)"
            $appPoolPath = "IIS:\AppPools\$appPoolName"
        
            if (-not (Test-Path $appPoolPath)) {
                New-WebAppPool -Name $appPoolName -Force
                Set-ItemProperty $appPoolPath -name processModel -value @{userName=$WebAppUserName;password=$WebAppPassword;identitytype=3}
            }
            if($EnvName -eq "Production") {
                $siteName = "WebApps"
            }
            else {
                $siteName = $EnvName
            }
            if(-not (Test-Path "IIS:\Sites\$siteName\$AppKey")) {
                New-WebVirtualDirectory -Site $siteName -Name $AppKey -PhysicalPath $appFolder
            }
            if((Get-WebApplication -Name $Version -Site "$siteName\$AppKey") -eq $null) {
                New-WebApplication -Name $Version -Site "$siteName\$AppKey" -PhysicalPath $targetFolder -ApplicationPool $appPoolName -Force
            }
        }

        New-XtiWebApp -AppKey $AppKey -EnvName $EnvName -WebAppUserName $WebAppUserName -WebAppPassword $WebAppPassword -Version "Current"
        if($EnvName -eq "Production") { 
            New-XtiWebApp -AppKey $AppKey -EnvName $EnvName -WebAppUserName $WebAppUserName -WebAppPassword $WebAppPassword -Version $VersionKey
        }
    }

    $webAppCred = Get-XtiCredential -Key "xti_webapp"

    if ($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $cred = Get-XtiPsCredential -Key "xti_productionmachine_admin"
    
        $branch = Get-CurrentBranchname

        if($envName -eq "Production") {
            Xti-BeginPublish -BranchName $branch
            $releaseBranch = Parse-ReleaseBranch -BranchName $branch
            $versionKey = $releaseBranch.VersionKey
        }
        else {
            $versionKey = ""
        }

        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $cred
            ScriptBlock = ${Function:Xti-Publish}
            ArgumentList = $AppKey, $EnvName, $VersionKey, $webAppCred.UserName, $webAppCred.Password
        }
        Invoke-Command @parameters
        if($EnvName -eq "Production"){
            dotnet publish $ProjectDir /p:PublishProfile=$EnvName /p:DeployIisAppPath=WebApps/$AppKey/${versionKey} /p:Password=$password
            dotnet publish $ProjectDir /p:PublishProfile=$EnvName /p:Password=$password
            Xti-EndPublish -BranchName $branch
        }
        else{
            dotnet publish $ProjectDir /p:PublishProfile=$EnvName /p:Password=$password
        }
    }
    else {
        Xti-Publish -appKey $appKey -envName $EnvName -versionKey "" -WebAppUserName $webAppCred.UserName -WebAppPassword $webAppCred.Password
        dotnet publish $ProjectDir /p:PublishProfile=$EnvName
    }
}