
function Xti-ProcessTempLog {
    param(
        [ValidateSet("Production", “Development", "Staging", "Test")]
        [string] $EnvName="Production"
    )
    $ErrorActionPreference = "Stop"
    function TempLogTool {
        param(
            [string] $EnvName
        )
        & "$($env:XTI_Tools)\TempLogTool\TempLogTool.exe" --environment=$EnvName
    }
    if($EnvName -eq "Production" -or $EnvName -eq "Staging") {
        $pscred = Get-XtiPsCredential -Key "xti_productionmachine_admin"
        $parameters = @{
            ComputerName = $env:XTI_ProductionMachine
            Credential = $pscred
            ScriptBlock = ${Function:TempLogTool}
            ArgumentList = $EnvName
        }
        Invoke-Command @parameters
    }
    else {
        TempLogTool -EnvName $EnvName
    }
}
