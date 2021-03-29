function Xti-Merge {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        $CommitMessage = ""
    )

    $ErrorActionPreference = "Stop"
    $pullRequestNumber = New-XtiPullRequest @PsBoundParameters
    if($pullRequestNumber -gt 0) {
        Invoke-GHRestMethod -UriFragment repos/$RepoOwner/$RepoName/pulls/$pullRequestNumber/merge -Method Put
        Xti-PostMerge -RepoOwner $RepoOwner -RepoName $RepoName
    }
}