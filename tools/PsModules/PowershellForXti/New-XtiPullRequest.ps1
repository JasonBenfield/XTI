function New-XtiPullRequest {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        $CommitMessage = ""
    )

    $ErrorActionPreference = "Stop"
    
    Xti-GitHubAuthentication | Out-Null

    $pullRequestNumber = 0

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName
    $branchName = Get-CurrentBranchname
    $releaseBranch = Parse-ReleaseBranch $branchName
    if($releaseBranch.IsValid) {
        if($CommitMessage -eq "") {
            $CommitMessage = "Changes for $($releaseBranch.VersionKey)"
        }
        Xti-CommitChanges -CommitMessage $CommitMessage -BranchName $branchName | Out-Null
        $pullRequest = $repo | New-GitHubPullRequest -Title "Pull Request for $($releaseBranch.VersionKey)" -Base $repo.default_branch -Head $branchName
        $pullRequestNumber = $pullRequest.number
    }
    else {
        $issueBranch = Parse-IssueBranch -BranchName $branchName
        if($issueBranch.IsValid) {
            $issueNumber = $issueBranch.IssueNumber

            $issue = $repo | Get-GitHubIssue -Issue $IssueNumber
            if($issue -eq $null) {
                throw "Issue $($IssueNumber) was not found"
            }
            if($issue.state -ne "open") {
                throw "Issue $($IssueNumber): $($issue.title) has state $($issue.state)"
            }
            $milestone = $issue.milestone
            if($milestone -eq $null){
                throw "Milestone for issue $($IssueNumber) was not found"
            }
            $milestoneTitle = $milestone.title 
            $releaseMilestone = Parse-ReleaseMilestone -Milestone $milestone.title
            if(-not $releaseMilestone.IsValid) {
                throw "Milestone $($milestone.title) is not a valid XTI milestone"
            }
            $versionType = $releaseMilestone.VersionType
            $versionKey = $releaseMilestone.VersionKey

            $parentBranchName = "xti/$($versionType)/$($versionKey)"

            $closePendingName = "close pending"
            Add-XtiLabel -Repo $repo -Label $closePendingName -Color BFD4F2 | Out-Null
    
            if($CommitMessage -eq "") {
                $CommitMessage = $issue.title
            }
            Xti-CommitChanges -CommitMessage $CommitMessage -BranchName $branchName | Out-Null
            $pullRequest = $repo | New-GitHubPullRequest -Title "Pull Request for $($issue.title)" -Body "Closes #$($issueNumber)" -Base $parentBranchName -Head $branchName
            $pullRequestNumber = $pullRequest.number

            Add-XtiIssueLabel -Repo $repo -Issue $issue -Label $closePendingName | Out-Null
            Remove-XtiIssueLabel -Repo $repo -Issue $issue -Label "in progress" | Out-Null
        }
        else {
            throw "'$($branchName)' is not a branch for an xti issue or release"
        }
    }
    return $pullRequestNumber
}