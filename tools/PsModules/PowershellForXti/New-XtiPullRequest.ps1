function New-XtiPullRequest {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        $CommitMessage = ""
    )

    $ErrorActionPreference = "Stop"
    
    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName
    $branchName = Get-CurrentBranchname
    $releaseBranch = Parse-ReleaseBranch $branchName
    if($releaseBranch.IsValid) {
        $repo | New-GitHubPullRequest -Title "Pull Request for $($releaseBranch.VersionKey)" -Base "master" -Head $branchName
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
            Add-XtiLabel -Repo $repo -Label $closePendingName -Color BFD4F2
    
            if($CommitMessage -eq "") {
                $CommitMessage = $issue.title
            }
            $ErrorActionPreference = "Continue"
            git add --all
            git commit -m "$CommitMessage"
            git push origin $branchName
            $ErrorActionPreference = "Stop"

            $repo | New-GitHubPullRequest -Title "Pull Request for $($issue.title)" -Body "Closes #$($issueNumber)" -Base $parentBranchName -Head $branchName

            Add-XtiIssueLabel -Repo $repo -Issue $issue -Label $closePendingName
            Remove-XtiIssueLabel -Repo $repo -Issue $issue -Label "in progress"
        }
        else {
            throw "'$($branchName)' is not a branch for an xti issue or release"
        }
    }
}