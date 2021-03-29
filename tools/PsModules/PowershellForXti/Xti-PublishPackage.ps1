function Xti-PublishPackage {
    param (
        [switch] $Prod,
        [switch] $DisableUpdateVersion,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        $RepoOwner = "",
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        $RepoName = ""
    )
    
    $ErrorActionPreference = "Stop"
    
    $branch = Get-CurrentBranchname

    $releaseBranch = Parse-ReleaseBranch -BranchName $branch
    if(-not $releaseBranch.IsValid) {
        if($Prod){
            throw "Branch '$branch' is not a valid release branch"
        }
        $issueBranch = Parse-IssueBranch -BranchName $branch
        if($issueBranch.IsValid) {
            $issueNumber = $issueBranch.IssueNumber
            $repo = Get-GitHubRepository -OwnerName $RepoOwner -RepositoryName $RepoName
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
            $branch = "xti/$($releaseMilestone.VersionType)/$($releaseMilestone.VersionKey)"
        }
        else {
            throw "Branch '$branch' is not a valid issue branch"
        }
    }
    
    dotnet build
    
    $projectDirs = Get-ChildItem -Path Lib -Directory
	if($Prod)
	{
        if($DisableUpdateVersion){
            $branchVersion = Get-BranchXtiVersion -BranchName $branch
        }
        else {
            $branchVersion = Xti-BeginPublish -BranchName $branch -OutputVersion
        }
        $branchVersion -match "(?<Major>\d+)\.(?<Minor>\d+)\.(?<Build>\d+)"
        $version = "$($Matches.Major).$($Matches.Minor).$($Matches.Build)"
        $projectDirs | ForEach-Object { 
		    dotnet pack $($_.FullName) -p:PackageVersion=$version -c Release -o $env:XTI_ProdPackagePath
	    }
        if(-not $DisableUpdateVersion){
            Xti-EndPublish -BranchName $branch
        }
    }
	else
	{
        $currentVersion = Get-CurrentXtiVersion -BranchName $branch
        $currentVersion -match "(?<Major>\d+)\.(?<Minor>\d+)\.(?<Build>\d+)"
        $nextBuild = [int]::Parse($Matches.Build) + 1
        $version = "$($Matches.Major).$($Matches.Minor).$($nextBuild)"
        $versionSuffix = "dev" + [System.DateTime]::Now.ToString("yyMMddHHmmssfff")
        $projectDirs | ForEach-Object { 
		    dotnet pack $($_.FullName) -p:PackageVersion="$($version)-$($versionSuffix)" -c Debug --include-source --include-symbols -o $env:XTI_DevPackagePath
	    }
	}
}