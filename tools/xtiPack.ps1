param([String]$config="Dev")

$versionSuffix = "dev" + [System.DateTime]::Now.Ticks.ToString()
Get-ChildItem -Path Lib -Directory | ForEach-Object { 
	#dotnet pack $($_.FullName) --no-restore -o $packPath 
	if($config -eq "Release" -or $config -eq "Prod")
	{
		dotnet pack $($_.FullName) -c Release -o $env:XTI_ProdPackagePath
	}
	else
	{
		dotnet pack $($_.FullName) --no-build -c Debug --include-source --include-symbols --version-suffix $versionSuffix -o $env:XTI_DevPackagePath
	}
}