function New-XtiVersion {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppKey,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“WebApp”, "Package")]
        $AppType,
        [ValidateSet(“major”, "minor", "patch")]
        $VersionType = "minor"
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    
    $ErrorActionPreference = "Stop"

    $branchName = Get-CurrentBranchName
    if($branchName -ne "master") {
        throw "Branch must be master"
    }

    $versionApp = "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe"
    $outputPath = "$($env:APPDATA)\XTI\Temp\version.json"
    & $versionApp --no-launch-profile -- --Command=New --AppKey=$Appkey --AppType=$AppType --VersionType=$VersionType --OutputPath=$outputPath
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
    $version = Get-Content $outputPath | Out-String | ConvertFrom-Json
    Remove-Item $outputPath
    
    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName
    $branchName = "xti/$($version.type)/$($version.Key)"
    $repo | New-GitHubRepositoryBranch -TargetBranchName $branchName

    $milestone = "xti_$($version.type)_$($version.Key)"
    $repo | New-GitHubMilestone -Title $milestone
    
    $ErrorActionPreference = "Continue"

    git remote update origin --prune
    git fetch -q origin
    git checkout -q --track origin/$branchName
}