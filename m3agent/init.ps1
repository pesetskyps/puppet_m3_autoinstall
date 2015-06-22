param(
	[Parameter(Position=0, Mandatory=$True)]
	$PuppetServer
)
Write-host "Disabling firewall..."
netsh advfirewall set allprofiles state off

Write-host "adding puppet sevrer to hosts file"
"$PuppetServer puppet" | Out-File c:\Windows\System32\drivers\etc\hosts -Encoding ASCII
"127.0.0.1 localhost" | Out-File c:\Windows\System32\drivers\etc\hosts -Encoding ASCII -Append

Write-host "removing stale certificates from client..."
Remove-item -re -fo c:\programdata\PuppetLabs\puppet\etc\ssl\*
Write-host "Done"