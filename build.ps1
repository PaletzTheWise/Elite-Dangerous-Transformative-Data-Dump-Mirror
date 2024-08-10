param (
	[parameter()]
	[switch]$local
)

Push-Location $(Split-Path $MyInvocation.MyCommand.Path)

if ( -not $? ) { exit 1 }

try
{
	haxe build.hxml
	if ( -not $? ) { exit 1 }
	
	Write-Host Compilation done.
	
	& './package.ps1' -local:$local
	if ( -not $? ) { exit 1 }
	
	Write-Host Build done.
}
finally
{
	Pop-Location
}
