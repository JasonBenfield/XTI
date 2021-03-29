
function Xti-PublishServiceApp {
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
    
    function Xti-StopWinService {
        param(
            $AppName, 
            $EnvName
        )

        $ErrorActionPreference = "Stop"

        Import-Module CredentialManager
    
        $serviceName = "xti_$($EnvName)_$($AppName)"
        $services = Get-Service -Include $serviceName
        if($services.Length -gt 0) {
            $service = Get-Service -Name $serviceName
            if($service.Status -eq "Running") {
                Write-Output "Stopping"
                Stop-Service -Name $serviceName
                Write-Output "Wait for Stop"
                $service.WaitForStatus("Stopped")
                Write-Output "Stopped"
            }
        }
        $appFolder = "c:\XTI\ServiceApps\$EnvName\$AppName\Current"
        if(Test-Path $appFolder) {
            Remove-Item "$($appFolder)\*" -Recurse -Force
        }
    }
    
    function Xti-StartWinService {
        param(
            $AppName, 
            $EnvName,
            $ServiceAppCred
        )

        $ErrorActionPreference = "Stop"
        $serviceName = "xti_$($EnvName)_$($AppName)"
        $services = Get-Service -Include $serviceName
        if($services.Length -eq 0) {
            $appFolder = "c:\XTI\ServiceApps\$EnvName\$AppName\Current"
            if($EnvName -eq "Production") {
                $displayName = "XTI $AppName"
            }
            else {
                $displayName = "XTI $EnvName $AppName"
            }
            $service = New-Service -Name $serviceName -BinaryPathName "$($appFolder)\$($AppName)ServiceApp.exe --environment=$EnvName" -DisplayName $displayName -StartupType Automatic -Credential $ServiceAppCred
            Start-Service -Name $serviceName
        }
        else { 
            $service = Get-Service -Name $serviceName
            if($service.Status -eq "Stopped") {
                Start-Service -Name $serviceName
            }
        }
    }

    if($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $credKey = "xti_domain_serviceapp"
    }
    else {
        $credKey = "xti_local_serviceapp"
    }

    $serviceAppCred = Get-XtiCredential -Key $credKey
    
    $pscred = New-XtiPsCredential -UserName $ServiceAppCred.UserName -Password $ServiceAppCred.Password

    if ($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $cred = Get-XtiPsCredential -Key "xti_productionmachine_admin"
    
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
            Credential = $cred
            ScriptBlock = ${Function:Xti-StopWinService}
            ArgumentList = $AppName, $EnvName
        }
        Invoke-Command @parameters
        Write-Output "Publishing to $($env:XTI_ProductionMachine)"
        if($versionKey -ne "") {
            dotnet publish $ProjectDir /p:PublishProfile=Default /p:Configuration=Release /p:PublishDir=\\$env:XTI_ProductionMachine\xti\ServiceApps\$EnvName\$AppName\$VersionKey
        }
        dotnet publish $ProjectDir /p:PublishProfile=Default /p:Configuration=Release /p:PublishDir=\\$env:XTI_ProductionMachine\xti\ServiceApps\$EnvName\$AppName\Current
        Start-Sleep -Seconds 5
        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $cred
            ScriptBlock = ${Function:Xti-StartWinService}
            ArgumentList = $AppName, $EnvName, $pscred
        }
        Invoke-Command @parameters
    }
    else {
        Write-Output "Publishing to Local"
        Xti-StopWinService -AppName $AppName -EnvName $EnvName
        dotnet publish $ProjectDir /p:PublishProfile=Default /p:Configuration=Debug /p:PublishDir=c:\xti\ServiceApps\$EnvName\$AppName\Current
        Start-Sleep -Seconds 5
        Xti-StartWinService -AppName $AppName -EnvName $EnvName -ServiceAppCred $pscred
    }
}