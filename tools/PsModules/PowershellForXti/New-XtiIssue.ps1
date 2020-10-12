function New-XtiIssue {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        [string] $RepoName,
        [Parameter(Mandatory)]
        [string] $IssueTitle,
        $Labels = @(),
        [string] $Body = ""
    )

    $ErrorActionPreference = "Stop"

    $branchName = Get-CurrentBranchname
    $releaseBranch = Parse-ReleaseBranch -BranchName $branchName
    if(-not $releaseBranch.IsValid) {
        throw "'$branchName' is not an XTI release branch"
    }

    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName


    $issue = $repo | New-GitHubIssue -Title $IssueTitle -Label $Labels -Body $Body
    $repo | Set-GitHubIssue -Issue $issue.number -MilestoneNumber $milestone.number
    
    $releaseBranch = Parse-ReleaseBranch -BranchName $branchName
    if($releaseBranch.IsValid) {
        $milestone = Get-GitHubXtiMilestone -Repo $repo -ReleaseBranch $releaseBranch
        $repo | Set-GitHubIssue -Issue $issue.number -MilestoneNumber $milestone.number
    }
    Write-Output "Created issue $($issue.number): $($issue.title)"
}
