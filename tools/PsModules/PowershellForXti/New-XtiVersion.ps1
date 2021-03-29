function New-XtiVersion {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $AppName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet(“WebApp”, "Package", "Service")]
        $AppType,
        [ValidateSet(“major”, "minor", "patch")]
        $VersionType = "minor"
    )
    $originalEnvironment = $env:DOTNET_ENVIRONMENT
    $env:DOTNET_ENVIRONMENT="Production"
    
    $ErrorActionPreference = "Stop"
    
    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName

    $branchName = Get-CurrentBranchName
    if($branchName -ne $repo.default_branch) {
        throw "Branch must be $($repo.default_branch)"
    }

    $versionApp = "$($env:XTI_Tools)\XTI_VersionTool\XTI_VersionTool.exe"
    $outputPath = "$($env:APPDATA)\XTI\Temp\version.json"
    & $versionApp --no-launch-profile -- --Command=New --AppName=$AppName --AppType=$AppType --VersionType=$VersionType --OutputPath=$outputPath
    $env:DOTNET_ENVIRONMENT = $originalEnvironment
    $version = Get-Content $outputPath | Out-String | ConvertFrom-Json
    Remove-Item $outputPath
    
    $branchName = "xti/$($version.type)/$($version.Key)"
    $repo | New-GitHubRepositoryBranch -BranchName $repo.default_branch -TargetBranchName $branchName

    $milestone = "xti_$($version.type)_$($version.Key)"
    $repo | New-GitHubMilestone -Title $milestone
    
    $ErrorActionPreference = "Continue"

    git remote update origin --prune
    git fetch -q origin
    git checkout -q --track origin/$branchName
}