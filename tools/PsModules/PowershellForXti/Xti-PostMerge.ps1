function Xti-PostMerge {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName
    )
    
    $ErrorActionPreference = "Stop"

    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName
    $branchName = Get-CurrentBranchname
    $releaseBranch = Parse-ReleaseBranch $branchName
    if($releaseBranch.IsValid) {
    
        $pullRequest = $repo | Get-GitHubPullRequest -Base "master" -Head "$($RepoOwner):$($branchName)" -State All | Select -First 1
        if($pullRequest -eq $null) {
            throw "Pull request not found for $branchName -> master"
        }
        if($pullRequest.state -ne "closed") { 
            throw "Pull request $($pullRequest.number) is '$($pullRequest.state)'"
        }

        $milestone = Get-GitHubXtiMilestone -Repo $repo -ReleaseBranch $releaseBranch
    
        $issues = $repo | Get-GitHubIssue
        $issues | Where-Object { 
            $_.milestone -ne $null -and $_.milestone.title -eq $milestone.title
            } | ForEach-Object {
                Remove-XtiIssueLabel -Repo $repo -Issue $_.number -Label "close pending"
                $repo | Set-GitHubIssue -Issue $_.number -State Closed -Confirm:$false
            }
            
        $repo | Set-GitHubMilestone -Milestone $milestone.number -Title $milestone.title -State Closed -Confirm:$false

        git checkout master -q
    }
    else {
        $issueBranch = Parse-IssueBranch -BranchName $branchName
        if($issueBranch.IsValid) {
            $issueNumber = $issueBranch.IssueNumber
            $issue = $repo | Get-GitHubIssue -Issue $IssueNumber
            if($issue -eq $null) {
                throw "Issue $($IssueNumber) was not found"
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
            $VersionKey = $releaseMilestone.VersionKey
            $releaseBranchName = "xti/$($versionType)/$($versionKey)"

            $pullRequest = $repo | Get-GitHubPullRequest -Base $releaseBranchName -Head "$($RepoOwner):$($branchName)" -State All | Select -First 1
            
            if($pullRequest -eq $null) {
                throw "Pull request not found for $branchName -> $releaseBranchName"
            }
            if($pullRequest.state -ne "closed") { 
                throw "Pull request $($pullRequest.number) is '$($pullRequest.state)'"
            }

            git checkout -q $releaseBranchName
        }
        else {
            throw "'$($branchName)' is not a branch for an xti issue or release"
        }
    }

    git pull -q

    git branch -D $branchName
}
