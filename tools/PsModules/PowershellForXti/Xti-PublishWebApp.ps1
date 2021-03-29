
function Xti-PublishWebApp {
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $AppName,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("Production", “Development", "Staging", "Test")]
        [string] $EnvName="Production",
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $ProjectDir
    )

    $ErrorActionPreference = "Stop"
    
    function Xti-DeleteAppOffline {
        param(
            $AppName, 
            $SiteName,
            $VersionKey
        )
        $ErrorActionPreference = "Stop"

        Import-Module WebAdministration
        Import-Module CredentialManager
    
        $webApp = Get-WebApplication -Name "$($AppName)/Current" -Site $SiteName
        if(-not [string]::IsNullOrWhiteSpace($webApp.PhysicalPath)) {
            Remove-Item "$($webApp.PhysicalPath)\app_offline.htm" -Force
        }
        if($VersionKey -ne "") {
            $webApp = Get-WebApplication -Name "$($AppName)/$($VersionKey)" -Site $SiteName
            if(-not [string]::IsNullOrWhiteSpace($webApp.PhysicalPath)) {
                Remove-Item "$($webApp.PhysicalPath)\app_offline.htm" -Force
            }
        }
    }

    function Xti-PrepareIis {
        param(
            $AppName, 
            $EnvName,
            $VersionKey,
            $WebAppUserName,
            $WebAppPassword,
            $SiteName
        )

        $ErrorActionPreference = "Stop"

        Import-Module WebAdministration
        Import-Module CredentialManager
    
        function New-XtiWebApp {

            param (
                $AppName,
                $EnvName,
                $Version,
                $WebAppUserName,
                $WebAppPassword,
                $SiteName
            )
    
            $appFolder = "c:\XTI\WebApps\$($EnvName)\$($AppName)"
            $targetFolder = "$($appFolder)\$($Version)"
            if ( -not (Test-Path -Path $targetFolder -PathType Container) ) {
                New-Item -ItemType Directory -Path $targetFolder
            }
            $appPoolName = "Xti_$($EnvName)_$($AppName)_$($Version)"
            $appPoolPath = "IIS:\AppPools\$($appPoolName)"
        
            if (-not (Test-Path $appPoolPath)) {
                New-WebAppPool -Name $appPoolName -Force
                Set-ItemProperty $appPoolPath -name processModel -value @{userName=$WebAppUserName;password=$WebAppPassword;identitytype=3}
                Set-ItemProperty $appPoolPath managedRuntimeVersion ""
            }
            if(-not (Test-Path "IIS:\Sites\$SiteName\$AppName")) {
                New-WebVirtualDirectory -Site $SiteName -Name $AppName -PhysicalPath $appFolder
            }
            $webApp = Get-WebApplication -Name "$($AppName)/$($Version)" -Site $SiteName
            if($webApp -eq $null) {
                $webApp = New-WebApplication -Name "$($AppName)/$($Version)" -Site $SiteName -PhysicalPath $targetFolder -ApplicationPool $appPoolName -Force
            }
            $appPoolState = Get-WebAppPoolState -Name $appPoolName
            if($appPoolState.Value -eq "Stopped") {
                Start-WebAppPool -Name $appPoolName
            }
            else {
                Restart-WebAppPool -Name $appPoolName
            }
            if(-not [string]::IsNullOrWhiteSpace($webApp.PhysicalPath)) {
                Set-Content -Path "$($webApp.PhysicalPath)\app_offline.htm" -Value "<html><head></head><body><h1>Web App Offline</h1></body></html>"
                Start-Sleep -Seconds 5
                try {
                    Remove-Item "$($webApp.PhysicalPath)\*" -Exclude "app_offline.htm" -Recurse -Force
                }
                catch {
                    Start-Sleep -Seconds 5
                    try {
                        Remove-Item "$($webApp.PhysicalPath)\*" -Exclude "app_offline.htm" -Recurse -Force
                    }
                    catch {
                        Start-Sleep -Seconds 5
                        Remove-Item "$($webApp.PhysicalPath)\*" -Exclude "app_offline.htm" -Recurse -Force
                    }
                }
            }
        }
        New-XtiWebApp -AppName $AppName -EnvName $EnvName -WebAppUserName $WebAppUserName -WebAppPassword $WebAppPassword -Version "Current" -SiteName $siteName
        if($VersionKey -ne "") {
            New-XtiWebApp -AppName $AppName -EnvName $EnvName -WebAppUserName $WebAppUserName -WebAppPassword $WebAppPassword -Version $VersionKey -SiteName $siteName
        }
    }
    
    if($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $credKey = "xti_domain_webapp"
    }
    else {
        $credKey = "xti_local_webapp"
    }

    $webAppCred = Get-XtiCredential -Key $credKey
    
    if($EnvName -eq "Production") {
        $siteName = "WebApps"
    }
    else {
        $siteName = $EnvName
    }

    if ($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $pscred = Get-XtiPsCredential -Key "xti_productionmachine_admin"
        $cred = Get-XtiCredential -Key "xti_productionmachine_admin"
        $userName = $cred.UserName
        $password = $cred.Password

        $branch = Get-CurrentBranchname

        if($envName -eq "Production") {
            $releaseBranch = Parse-ReleaseBranch -BranchName $branch
            $versionKey = $releaseBranch.VersionKey
        }
        else {
            $versionKey = ""
        }
        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $pscred
            ScriptBlock = ${Function:Xti-PrepareIIS}
            ArgumentList = $AppName, $EnvName, $VersionKey, $webAppCred.UserName, $webAppCred.Password, $siteName
        }
        Invoke-Command @parameters
        if($versionKey -ne "") {
            dotnet publish $ProjectDir /p:PublishProfile=Default /p:UserName=$userName /p:Password=$password /p:MSDeployPublishMethod=WMSVC /p:Configuration=Release /p:MSDeployServiceURL=$($env:XTI_ProductionMachine):8172 /p:DeployIisAppPath=$SiteName/$AppName/$VersionKey /p:LaunchSiteAfterPublish=False
        }
        dotnet publish $ProjectDir /p:PublishProfile=Default /p:UserName=$userName /p:Password=$password /p:MSDeployPublishMethod=WMSVC /p:Configuration=Release /p:MSDeployServiceURL=$($env:XTI_ProductionMachine):8172 /p:DeployIisAppPath=$SiteName/$AppName/Current /p:SiteUrlToLaunchAfterPublish=https://$SiteName.xartogg.com/$AppName/Current

        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $pscred
            ScriptBlock = ${Function:Xti-DeleteAppOffline}
            ArgumentList = $AppName, $SiteName, $VersionKey
        }
        Invoke-Command @parameters
    }
    else {
        Xti-PrepareIIS -AppName $AppName -EnvName $EnvName -VersionKey "" -WebAppUserName $webAppCred.UserName -WebAppPassword $webAppCred.Password -SiteName $siteName
        dotnet publish $ProjectDir /p:PublishProfile=Default /p:MSDeployPublishMethod=InProc /p:Configuration=Debug /p:MSDeployServiceURL=localhost /p:DeployIisAppPath=$EnvName/$AppName/Current /p:SiteUrlToLaunchAfterPublish=https://$SiteName.guinevere.com/$AppName/Current
        Xti-DeleteAppOffline -AppName $AppName -SiteName $EnvName -VersionKey ""
    }
}