function Xti-PublishPackage {
    param (
        [switch] $Dev,
        [switch] $DisableUpdateVersion
    )
    
    $ErrorActionPreference = "Stop"
    
    $branch = Get-CurrentBranchname

    $releaseBranch = Parse-ReleaseBranch -BranchName $branch
    if(-not $releaseBranch.IsValid) {
        throw "Branch '$branch' is not a valid release branch"
    }
    
    dotnet build
    
    $projectDirs = Get-ChildItem -Path Lib -Directory
	if($Dev)
	{
        $currentVersion = Get-CurrentXtiVersion -BranchName $branch
        $currentVersion -match "(?<Major>\d+)\.(?<Minor>\d+)\.(?<Build>\d+)"
        $nextBuild = [int]::Parse($Matches.Build) + 1
        $version = "$($Matches.Major).$($Matches.Minor).$($nextBuild)"
        $versionSuffix = "dev" + [System.DateTime]::Now.ToString("yyMMdd_HHmmssfff")
        $projectDirs | ForEach-Object { 
		    dotnet pack $($_.FullName) -p:PackageVersion=$version -c Debug --include-source --include-symbols --version-suffix $versionSuffix -o $env:XTI_DevPackagePath
	    }
    }
	else
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
}