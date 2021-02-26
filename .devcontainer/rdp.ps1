﻿# Set RDP service port to 3390
$RdpPort = 3390
$RdpUserName = "CSRDPUSER1"
$RdpSettingsFile = "C:/workspace/.rdp.json"

if ($Env:OS -match 'Windows')
{
	# Create local Windows account for RDP user and set their password
	Add-Type -AssemblyName System.Web
	$RdpUserPassword = [System.Web.Security.Membership]::GeneratePassword(20, 3)
	$SecureRdpUserPassword = ConvertTo-SecureString $RdpUserPassword -AsPlainText -Force
	$RdpUserAccount = Get-LocalUser | Where-Object {$_.Name -eq $RdpUserName}
	if ( -not $RdpUserAccount)
	{
		$RdpUserAccount = New-LocalUser $RdpUserName -Password $SecureRdpUserPassword -FullName "RDP CS Account" -Description "Local account for CS RDP"
		Add-LocalGroupMember -Group "Remote Desktop Users" -Member $RdpUserName
	}
	else
	{
		$RdpUserAccount | Set-LocalUser -Password $SecureRdpUserPassword 
	}

	# Set RDP port
	$CurrentRdpPort = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "PortNumber"
	if ($CurrentRdpPort -ne $RdpPort)
	{
		Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name PortNumber -Value $RdpPort -Force
		$TermServicePid = Get-WmiObject -Class Win32_Service -Filter "Name LIKE 'TermService'" | Select-Object -ExpandProperty ProcessId
		Stop-Process $TermServicePid -Force
		Restart-Service "TermService" -Force -PassThru
	}

	# Write to rdp json file
	$passwordHash = $SecureRdpUserPassword | ConvertFrom-SecureString
	@{Type="RDP";Port=$RdpPort;User=$RdpUserName;PasswordHash=$passwordHash} | ConvertTo-Json | Out-File $RdpSettingsFile -Force
}
