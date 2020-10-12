
function Get-CurrentBranchname {
    $branchName = (git rev-parse --abbrev-ref HEAD) | Out-String
    return $branchName.Trim()
}

function Get-XtiCredential {
    param(
        [Parameter(Mandatory)]
        [string] $Key
    )
    $cred = Get-XtiPsCredential -Key $Key
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    return @{
        UserName = $cred.UserName
        Password = $password
    }
}

function Get-XtiPsCredential {
    param(
        [Parameter(Mandatory)]
        [string] $Key
    )
    return Get-StoredCredential -Target $Key
}

function Xti-GitHubAuthentication {
    $cred = Get-StoredCredential -Target xti_github
    Set-GitHubAuthentication -Credential $cred
}

function Parse-ReleaseBranch {
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )
    $isValid = $BranchName -match "xti/(?<VersionType>(major)|(minor)|(patch))/(?<VersionKey>V?\d+)"
    if($isValid) {
        $versionType = $Matches.VersionType
        $versionKey = $Matches.VersionKey
    }
    else {
        $versionType = ""
        $versionKey = ""
    }
    return [PSCustomObject]@{
        IsValid = $isValid
        VersionType = $versionType
        VersionKey = $versionKey
    }
}

function Parse-ReleaseMilestone {
    param(
        [Parameter(Mandatory)]
        [string] $Milestone
    )
    $isValid = $Milestone -match "xti_(?<VersionType>(major)|(minor)|(patch))_(?<VersionKey>V?\d+)"
    if($isValid) {
        $versionType = $Matches.VersionType
        $versionKey = $Matches.VersionKey
    }
    else {
        $versionType = ""
        $versionKey = ""
    }
    return [PSCustomObject]@{
        IsValid = $isValid
        VersionType = $versionType
        VersionKey = $versionKey
    }
}

function Get-GitHubXtiMilestone {
    param(
        $Repo,
        $ReleaseBranch
    )
    $milestoneTitle = "xti_$($releaseBranch.VersionType)_$($releaseBranch.VersionKey)"
    $milestones = $Repo | Get-GitHubMilestone
    $milestone = $milestones | Where-Object { $_.title -eq $milestoneTitle } | Select -First 1
    if($milestone -eq $null) {
        throw "Milestone '$($milestoneTitle)' was not found"
    }
    return $milestone
}

function Parse-IssueBranch {
    param(
        [Parameter(Mandatory)]
        [string] $BranchName
    )
    $isValid = $BranchName -match "issue/(?<IssueNumber>\d+)/.*"
    if($isValid) {
        $issueNumber = $Matches.IssueNumber
    }
    else {
        $issueNumber = ""
    }
    return [PSCustomObject]@{
        IsValid = $isValid
        IssueNumber = $issueNumber
    }
}

function Add-XtiLabel {
    param(
        $Repo,
        [string] $Label,
        $Color
    )
    $labels = Get-GitHubLabel
    $label = $labels | Where-Object { $_.name -eq $Label } | Select -First 1
    if($label -eq $null) {
        $Repo | New-GitHubLabel -Label $Label -Color $Color
    }
}

function Add-XtiIssueLabel {
    param(
        $Repo,
        $Issue,
        $Label
    )
    $issueLabels = $Issue.labels | ForEach-Object { $_.name }
    if(-not ($issueLabels -contains $Label)) {
        $Repo | Add-GitHubIssueLabel -Issue $Issue.number -LabelName @($Label)
    }
}

function Remove-XtiIssueLabel {
    param(
        $Repo,
        $Issue,
        $Label
    )
    $issueLabels = $Issue.labels | ForEach-Object { $_.name }
    if($issueLabels -contains $Label) {
        $repo | Remove-GitHubIssueLabel -Issue $Issue.number -Label $Label -Force
    }
}

function Get-CurrentXtiVersion {
    param(
        [ValidateSet("Production", “Development", "Staging", "Test")]
        $EnvName = "Production",
        [Parameter(Mandatory)]
        [string] $BranchName
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    $outputPath = "$($env:APPDATA)\XTI\Temp\version.json"
    & "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe" --no-launch-profile -- --Command=GetCurrent --BranchName=$BranchName --OutputPath=$outputPath
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
    $versionJson = Get-Content $OutputPath -Raw | ConvertFrom-Json
    Remove-Item $OutputPath
    return $versionJson.Version;
}

function Get-BranchXtiVersion {
    param(
        [ValidateSet("Production", “Development", "Staging", "Test")]
        $EnvName = "Production",
        [Parameter(Mandatory)]
        [string] $BranchName
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    $outputPath = "$($env:APPDATA)\XTI\Temp\version.json"
    & "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe" --no-launch-profile -- --Command=GetVersion --BranchName=$BranchName --OutputPath=$outputPath
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
    $versionJson = Get-Content $OutputPath -Raw | ConvertFrom-Json
    Remove-Item $OutputPath
    return $versionJson.Version;
}

function Xti-BeginPublish {
    param (
        [Parameter(Mandatory)]
        [string] $BranchName,
        [switch] $OutputVersion
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    $outputPath = ""
    $version = ""
    if($OutputVersion) {
        $outputPath = "$($env:APPDATA)\XTI\Temp\version.json"
    }
    & "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe" --no-launch-profile -- --Command=BeginPublish --BranchName=$BranchName --OutputPath=$outputPath
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
    if($OutputVersion) {
        $versionJson = Get-Content $outputPath -Raw | ConvertFrom-Json
        Remove-Item $outputPath
        $version = $versionJson.Version;
    }
    return $version
}

function Xti-EndPublish {
    param (
        [Parameter(Mandatory)]
        [string] $BranchName
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    & "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe" --no-launch-profile -- --Command=EndPublish --BranchName=$BranchName
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
}
