Push-Location $(Split-Path $MyInvocation.MyCommand.Path)
if ( -not $? ) { exit 1 }

try
{
	if ( $(Test-Path -Path "release") )
	{
		Remove-Item -Path "release" -Recurse
	}
	
	Copy-Item -Path "bin\lib" -Destination "release\lib" -recurse
	if ( -not $? ) { exit 1 }
	Copy-Item bin\index.php -destination "release\"
	if ( -not $? ) { exit 1 }
	
	$branch = git rev-parse --abbrev-ref HEAD
	if ( -not $? ) { exit 1 }
	$commitCount = git rev-list --count $branch
	if ( -not $? ) { exit 1 }
	$commitHash = git rev-parse HEAD
	if ( -not $? ) { exit 1 }
	echo "$branch-$commitCount-$commitHash" > "release\version.txt"
	if ( -not $? ) { exit 1 }
	
	Copy-Item edsm.systemsPopulated.sample.json.gz -Destination "release\"
	if ( -not $? ) { exit 1 }
	
	Compress-Archive -Path "release\*" -DestinationPath "release\EliteDangerousAlteringDataDumpMirror.zip" -Force
	if ( -not $? ) { exit 1 }
	
	
	# local deployment
	
	Expand-Archive -Path "release\EliteDangerousAlteringDataDumpMirror.zip" -DestinationPath "bin\www" -Force
	if ( -not $? ) { exit 1 }
	
	Write-Host Packaging done.
}
finally
{
	Pop-Location
}