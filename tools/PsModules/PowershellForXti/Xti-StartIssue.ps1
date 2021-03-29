function Xti-StartIssue {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoOwner,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true)]
        $RepoName,
        [long]
        $IssueNumber = 0,
        $IssueBranchTitle = "",
        $AssignTo = ""
    )

    $ErrorActionPreference = "Stop"

    $branchName = Get-CurrentBranchname
    $releaseBranch = Parse-ReleaseBranch -BranchName $branchName
    if(-not $releaseBranch.IsValid) {
        throw "'$branchName' is not an XTI release branch"
    }
    
    Xti-GitHubAuthentication

    $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName

    $milestone = Get-GitHubXtiMilestone -Repo $repo -ReleaseBranch $releaseBranch

    if($IssueNumber -eq 0) {
        $issues = $repo | Get-GitHubIssue
        $issues | Where-Object { 
            ($_.milestone -eq $null -or $_.milestone.title -eq $milestone.title) -and ($_.labels | Where-Object -Property Name -In -Value "close pending") -eq $null
            } | ForEach-Object {
                Write-Output "Issue $($_.number)"
                Write-Output "`t$($_.title)"
                if($_.milestone -ne $null) {
                    Write-Output "`t$($_.milestone.title)"
                }
            }
    }
    else {
        $issue = $repo | Get-GitHubIssue -Issue $IssueNumber
        if($issue -eq $null) {
            throw "Issue $($IssueNumber) was not found"
        }
        if($issue.state -ne "open") {
            throw "Issue $($IssueNumber): $($issue.title) has state $($issue.state)"
        }
        if($IssueBranchTitle -eq ""){
            $IssueBranchTitle = $issue.title -replace "\s+", "-"
            if($IssueBranchTitle.Length -gt 50) {
                $IssueBranchTitle = $IssueBranchTitle.Substring(0,50)
            }
            $IssueBranchTitle = $IssueBranchTitle.ToLower()
        }
        $newBranch = "issue/$($issue.number)/$($IssueBranchTitle)"
        $assignees = $issue.assignees | ForEach { $_.login }
        if($AssignTo -eq "") {
            $AssignTo = $RepoOwner
        }
        if(-not ($assignees -contains $AssignTo)) {
            $repo | Add-GitHubAssignee -Assignee $AssignTo -Issue $IssueNumber
        }
        $inProgressLabel = "in progress"
        Add-XtiLabel -Repo $repo  -Label $inProgressLabel -Color 0E8A16
        Add-XtiIssueLabel -Repo $repo -Issue $issue -Label $inProgressLabel
        if($issue.milestone -eq $null) {
            $repo | Set-GitHubIssue -Issue $IssueNumber -MilestoneNumber $milestone.number
        }
        git checkout -q -b $newBranch
    }
}