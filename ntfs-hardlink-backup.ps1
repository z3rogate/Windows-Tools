<#
.DESCRIPTION
    This software is used for creating hard-link-backups.
	The real magic is done by DeLoreanCopy of ln: http://schinagl.priv.at/nt/ln/ln.html	So all credit goes to Hermann Schinagl.
	INSTALLATION:
	1. Read the documentation of "ln" http://schinagl.priv.at/nt/ln/ln.html
	2. Download "ln" and unpack the file.
	3. Download and place ntfs-hardlink-backup.ps1 into .\bat directory below the ln program
	4. Navigate with Explorer to the .\bat folder
	5. Right Click on the ntfs-hardlink-backup.ps1 file and select "Properties"
	6. If you see in the bottom something like "Security: This file came from an other computer ..." Click on "Unblock"
	7. start powershell from windows start menu (you need Windows 7 or Win Server for that, on XP you would need to install PowerShell 2 first)
	8. allow local non-signed scripts to run by typing "Set-ExecutionPolicy RemoteSigned"
	9. run ntfs-hardlink-backup.ps1 with full path
.SYNOPSIS
	c:\full\path\bat\ntfs-hardlink-backup.ps1 <Options>
.PARAMETER iniFile
	Path to an optional INI file that contains any of the parameters.
.PARAMETER backupSources
    Source path of the backup. Can be a list separated by comma.
.PARAMETER backupDestination
    Path where the data should go to.
.PARAMETER backupsToKeep
    How many backup copies should be kept. All older backups and their log files will be deleted. 1 means mirror. Default=50
.PARAMETER timeTolerance
    Sometimes useful to not have an exact timestamp comparison between source and dest, but kind of a fuzzy comparison, because the system time of NAS drives is not exactly synced with the host.
	To overcome this we use the -timeTolerance switch to specify a value in milliseconds.
.PARAMETER exclude
	Exclude files via wildcards. Can be a list separated by comma.
.PARAMETER traditional
	Some NAS boxes only support a very outdated version of the SMB protocol. SMB is used when network drives are connected. This old version of SMB in certain situations does not support the fast enumeration methods of ln.exe, which causes ln.exe to simply do nothing.
	To overcome this use the -traditional switch, which forces ln.exe to enumerate files the old, but a little slower way.
.PARAMETER noads
	The -noads option tells ln.exe not to copy Alternative Data Streams (ADS) of files and directories.
	This option can be useful if the destination supports NTFS, but can not deal with ADS, which happens on certain NAS drives.
.PARAMETER noea
	The -noea option tells ln.exe not to copy EA Records of files and directories.
	This option can be useful if the destination supports NTFS, but can not deal with EA Records, which happens on certain NAS drives.
.PARAMETER localSubnetOnly
    Switch on to only run the backup when the destination is a local disk or a server in the same subnet.
	This is useful for scheduled network backups that should only run when the laptop is on the home office network.
.PARAMETER localSubnetMask
	The size of the IPv4 netmask (CIDR) that covers all the networks that should be considered local to the backup destination IPv4 address.
	Use this in an office with multiple subnets that can all be covered (summarised) by a single netmask.
	Without this parameter the default is to use the subnet mask of the local machine interface(s).
.PARAMETER emailTo
    Address to be notified about success and problems. If not given no Emails will be sent.
.PARAMETER emailFrom
    Address the notification email is sent from. If not given no Emails will be sent.
.PARAMETER SMTPServer
    Domainname of the SMTP Server. If not given no Emails will be sent.
.PARAMETER SMTPUser
    Username if the SMTP Server needs authentication.
.PARAMETER SMTPPassword
    Password if the SMTP Server needs authentication.
.PARAMETER SMTPTimeout
    Timeout in ms for the Email to be send. Default 60000.
.PARAMETER NoSMTPOverSSL
    Switch off the use of SSL to send Emails.
.PARAMETER NoShadowCopy
    Switch off the use of Shadow Copies. Can be useful if you have no permissions to create Shadow Copies.
.PARAMETER SMTPPort
    Port of the SMTP Server. Default=587
.PARAMETER emailJobName
    This is added in to the auto-generated email subject "Backup of: hostname emailJobName by: username"
.PARAMETER emailSubject
    Subject for the notification Email. This overrides the auto-generated email subject and emailJobName.
.PARAMETER emailSendRetries
    How often should we try to resend the Email. Default = 100
.PARAMETER msToPauseBetweenEmailSendRetries
    Time in ms to wait between the resending of the Email. Default = 60000
.PARAMETER LogFile
    Path and filename for the logfile. If just a path is given, then "yyyy-mm-dd hh-mm-ss.log" is written to that folder.
	Default is to write "yyyy-mm-dd hh-mm-ss.log" in the backup destination folder.
.PARAMETER StepTiming
    Switch on display of the time at each step of the job.
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources D:\backup_source1 -backupDestination E:\backup_dest -emailTo "me@example.org" -emailFrom "backup@example.org" -SMTPServer example.org -SMTPUser "backup@example.org" -SMTPPassword "secr4et"
    Simple backup.
.EXAMPLE
    PS D:\> d:\ln\bat\ntfs-hardlink-backup.ps1 -backupSources "D:\backup_source1","C:\backup_source2" -backupDestination E:\backup_dest -emailTo "me@example.org" -emailFrom "backup@example.org" -SMTPServer example.org -SMTPUser "backup@example.org" -SMTPPassword "secr4et"
    Backup with more than one source.
.NOTES
    Author: Artur Neumann, Phil Davis *INFN*
	Version: 2.0.ALPHA.2
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	[String]$iniFile,
	[Parameter(Mandatory=$False)]
	[String[]]$backupSources,
	[Parameter(Mandatory=$False)]
	[String]$backupDestination,
	[Parameter(Mandatory=$False)]
	[Int32]$backupsToKeep,
	[Parameter(Mandatory=$False)]
	[string]$emailTo="",
	[Parameter(Mandatory=$False)]
	[string]$emailFrom="",
	[Parameter(Mandatory=$False)]
	[string]$SMTPServer="",
	[Parameter(Mandatory=$False)]
	[string]$SMTPUser="",
	[Parameter(Mandatory=$False)]
	[string]$SMTPPassword="",
	[Parameter(Mandatory=$False)]
	[switch]$NoSMTPOverSSL=$False,
	[Parameter(Mandatory=$False)]
	[switch]$NoShadowCopy=$False,
	[Parameter(Mandatory=$False)]
	[Int32]$SMTPPort,
	[Parameter(Mandatory=$False)]
	[Int32]$SMTPTimeout,
	[Parameter(Mandatory=$False)]
	[Int32]$emailSendRetries,
	[Parameter(Mandatory=$False)]
	[Int32]$msToPauseBetweenEmailSendRetries,
	[Parameter(Mandatory=$False)]
	[Int32]$timeTolerance,
	[Parameter(Mandatory=$False)]
	[switch]$traditional,
	[Parameter(Mandatory=$False)]
	[switch]$noads,
	[Parameter(Mandatory=$False)]
	[switch]$noea,
	[Parameter(Mandatory=$False)]
	[switch]$localSubnetOnly,
	[Parameter(Mandatory=$False)]
	[Int32]$localSubnetMask,
	[Parameter(Mandatory=$False)]
	[string]$emailSubject="",
	[Parameter(Mandatory=$False)]
	[string]$emailJobName="",
	[Parameter(Mandatory=$False)]
	[String[]]$exclude,
	[Parameter(Mandatory=$False)]
	[string]$LogFile="",
	[Parameter(Mandatory=$False)]
	[switch]$StepTiming=$False
)

Function Get-IniContent 
{ 
    <# 
    .Synopsis 
        Gets the content of an INI file 
         
    .Description 
        Gets the content of an INI file and returns it as a hashtable 
         
    .Notes 
        Author    : Oliver Lipkau <oliver@lipkau.net> 
        Blog      : http://oliver.lipkau.net/blog/ 
        Date      : 2014/06/23 
        Version   : 1.1 
         
        #Requires -Version 2.0 
         
    .Inputs 
        System.String 
         
    .Outputs 
        System.Collections.Hashtable 
         
    .Parameter FilePath 
        Specifies the path to the input file. 
         
    .Example 
        $FileContent = Get-IniContent "C:\myinifile.ini" 
        ----------- 
        Description 
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent 
     
    .Example 
        $inifilepath | $FileContent = Get-IniContent 
        ----------- 
        Description 
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent 
     
    .Example 
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini" 
        C:\PS>$FileContent["Section"]["Key"] 
        ----------- 
        Description 
        Returns the key "Key" of the section "Section" from the C:\settings.ini file 
         
    .Link 
        Out-IniFile 
    #> 
     
    [CmdletBinding()] 
    Param( 
        [ValidateNotNullOrEmpty()] 
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})] 
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)] 
        [string]$FilePath 
    ) 
     
    Begin 
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"} 
         
    Process 
    { 
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath" 
             
        $ini = @{} 
        switch -regex -file $FilePath 
        { 
            "^\[(.+)\]$" # Section 
            { 
                $section = $matches[1] 
				# Added ToLower line to make INI file case-insensitive - Phil Davis
				$section = $section.ToLower()
                $ini[$section] = @{} 
                $CommentCount = 0 
            } 
            "^(;.*)$" # Comment 
            { 
                if (!($section)) 
                { 
                    $section = "No-Section" 
                    $ini[$section] = @{} 
                } 
                $value = $matches[1] 
                $CommentCount = $CommentCount + 1 
                $name = "Comment" + $CommentCount 
                $ini[$section][$name] = $value 
            }  
            "(.+?)\s*=\s*(.*)" # Key 
            { 
                if (!($section)) 
                { 
                    $section = "No-Section" 
                    $ini[$section] = @{} 
                } 
                $name,$value = $matches[1..2] 
				# Added ToLower line to make INI file case-insensitive - Phil Davis
				$name = $name.ToLower()
                $ini[$section][$name] = $value 
            } 
        } 
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath" 
        Return $ini 
    } 
         
    End 
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"} 
}

Function Get-IniParameter
{
	# Note: iniFileContent hash table is not passed in each time.
	# Just use the global value to reference that.
	[CmdletBinding()]
	Param(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory=$True)]
		[string]$ParameterName,
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory=$True)]
		[string]$IniSection
	)

	Begin
		{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

	Process
    {
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing for IniSection: $IniSection and ParameterName: $ParameterName"

		# Use ToLower to make all parameter name comparisons case-insensitive
		$ParameterName = $ParameterName.ToLower()
		$ParameterValue = $Null

		if ($global:iniFileContent.ContainsKey("common")) {
			if (-not [string]::IsNullOrEmpty($global:iniFileContent["common"][$ParameterName])) {
				$ParameterValue = $global:iniFileContent["common"][$ParameterName]
			}
		}
		if ($global:iniFileContent.ContainsKey($IniSection)) {
			if (-not [string]::IsNullOrEmpty($global:iniFileContent[$IniSection][$ParameterName])) {
				$ParameterValue = $global:iniFileContent[$IniSection][$ParameterName]
			}
		}

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing for IniSection: $IniSection and ParameterName: $ParameterName ParameterValue: $ParameterValue"
		Return $ParameterValue
    }

    End
	{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

Function Is-TrueString
{
	# Pass in a string (or nothing) and return a boolean deciding if the string
	# is "1", "true", "t" (True) or otherwise it is (False)
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$False)]
		[string]$TruthString
	)

	Begin
		{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}

	Process
    {
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing for TruthString: $TruthString"

		# Use ToLower to make comparisons case-insensitive
		$TruthString = $TruthString.ToLower()
		$ParameterValue = $Null

		if (($TruthString -eq "t") -or ($TruthString -eq "true") -or ($TruthString -eq "1")) {
			$TruthValue = $True
		} else {
			$TruthValue = $False
		}

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing for TruthString: $TruthString TruthValue: $TruthValue"
		Return $TruthValue
    }

    End
	{Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}
}

$emailBody = ""
$error_during_backup = $false
$doBackup = $true
$maxMsToSleepForZipCreation = 1000*60*30
$msToWaitDuringZipCreation = 500
$shadow_drive_letter = ""
$num_shadow_copies = 0
$stepTime = ""
$backupMappedPath = ""
$backupHostName = ""
$deleteOldLogFiles = $False
$FQDN = [System.Net.DNS]::GetHostByName('').HostName
$userName = [Environment]::UserName

if ($iniFile) {
	if (Test-Path -Path $iniFile -PathType leaf) {
		$output = "Using ini file`r`n$iniFile`r`n"
		$emailBody = "$emailBody`r`n$output`r`n"
		echo $output
		$global:iniFileContent = Get-IniContent "${iniFile}"
	} else {
		$global:iniFileContent = @{}
		$output = "ERROR: Could not find ini file`r`n$iniFile`r`n"
		$emailBody = "$emailBody`r`n$output`r`n"
		echo $output
	}
} else {
		$global:iniFileContent = @{}
}

$parameters_ok = $True

if ([string]::IsNullOrEmpty($backupSources)) {
	$backupsourcelist = Get-IniParameter "backupsources" "${FQDN}"
	if (-not [string]::IsNullOrEmpty($backupsourcelist)) {
		$backupSources = $backupsourcelist.split(",")
	}
}

if ([string]::IsNullOrEmpty($backupDestination)) {
	$backupDestination = Get-IniParameter "backupdestination" "${FQDN}"
}

if ($backupsToKeep -eq 0) {
	$backupsToKeep = Get-IniParameter "backupstokeep" "${FQDN}"
	if ($backupsToKeep -eq 0) {
		$backupsToKeep = 50;
	}
}

if ([string]::IsNullOrEmpty($emailTo)) {
	$emailTo = Get-IniParameter "emailTo" "${FQDN}"
}

if ([string]::IsNullOrEmpty($emailFrom)) {
	$emailFrom = Get-IniParameter "emailFrom" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPServer)) {
	$SMTPServer = Get-IniParameter "SMTPServer" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPUser)) {
	$SMTPUser = Get-IniParameter "SMTPUser" "${FQDN}"
}

if ([string]::IsNullOrEmpty($SMTPPassword)) {
	$SMTPPassword = Get-IniParameter "SMTPPassword" "${FQDN}"
}

if (-not $NoSMTPOverSSL.IsPresent) {
	$IniFileString = Get-IniParameter "NoSMTPOverSSL" "${FQDN}"
	$NoSMTPOverSSL = Is-TrueString "${IniFileString}"
}

if (-not $NoShadowCopy.IsPresent) {
	$IniFileString = Get-IniParameter "NoShadowCopy" "${FQDN}"
	$NoShadowCopy = Is-TrueString "${IniFileString}"
}

if ($SMTPPort -eq 0) {
	$SMTPPort = Get-IniParameter "SMTPPort" "${FQDN}"
	if ($SMTPPort -eq 0) {
		$SMTPPort = 587;
	}
}

if ($SMTPTimeout -eq 0) {
	$SMTPTimeout = Get-IniParameter "SMTPTimeout" "${FQDN}"
	if ($SMTPTimeout -eq 0) {
		$SMTPTimeout = 60000;
	}
}

if ($emailSendRetries -eq 0) {
	$emailSendRetries = Get-IniParameter "emailSendRetries" "${FQDN}"
	if ($emailSendRetries -eq 0) {
		$emailSendRetries = 100;
	}
}

if ($msToPauseBetweenEmailSendRetries -eq 0) {
	$msToPauseBetweenEmailSendRetries = Get-IniParameter "msToPauseBetweenEmailSendRetries" "${FQDN}"
	if ($msToPauseBetweenEmailSendRetries -eq 0) {
		$msToPauseBetweenEmailSendRetries = 60000;
	}
}

if ($timeTolerance -eq 0) {
	$timeTolerance = Get-IniParameter "timeTolerance" "${FQDN}"
	if ($timeTolerance -eq 0) {
		# Looks dumb, but left here if you want to change the default from zero.
		$timeTolerance = 0;
	}
}

if (-not $traditional.IsPresent) {
	$IniFileString = Get-IniParameter "traditional" "${FQDN}"
	$traditional = Is-TrueString "${IniFileString}"
}

if (-not $noads.IsPresent) {
	$IniFileString = Get-IniParameter "noads" "${FQDN}"
	$noads = Is-TrueString "${IniFileString}"
}

if (-not $noea.IsPresent) {
	$IniFileString = Get-IniParameter "noea" "${FQDN}"
	$noea = Is-TrueString "${IniFileString}"
}

if (-not $localSubnetOnly.IsPresent) {
	$IniFileString = Get-IniParameter "localSubnetOnly" "${FQDN}"
	$localSubnetOnly = Is-TrueString "${IniFileString}"
}

if ($localSubnetMask -eq 0) {
	$localSubnetMask = Get-IniParameter "localSubnetMask" "${FQDN}"
	if ($localSubnetMask -eq 0) {
		$localSubnetMask = 0;
	}
}

if ([string]::IsNullOrEmpty($emailSubject)) {
	$emailSubject = Get-IniParameter "emailSubject" "${FQDN}"
}

if ([string]::IsNullOrEmpty($emailJobName)) {
	$emailJobName = Get-IniParameter "emailJobName" "${FQDN}"
}

if ([string]::IsNullOrEmpty($exclude)) {
	$excludelist = Get-IniParameter "exclude" "${FQDN}"
	if (-not [string]::IsNullOrEmpty($excludelist)) {
		$exclude = $excludelist.split(",")
	}
}

if ([string]::IsNullOrEmpty($LogFile)) {
	$LogFile = Get-IniParameter "LogFile" "${FQDN}"
}

if (-not $StepTiming.IsPresent) {
	$IniFileString = Get-IniParameter "StepTiming" "${FQDN}"
	$StepTiming = Is-TrueString "${IniFileString}"
}

if ([string]::IsNullOrEmpty($emailSubject)) {
	if (-not ([string]::IsNullOrEmpty($emailJobName))) {
		$emailJobName += " "
	}
	$emailSubject = "Backup of: ${FQDN} ${emailJobName}by: ${userName}"
}

$dateTime = get-date -f "yyyy-MM-dd HH-mm-ss"
$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($LogFile)) {
	# No log file specified from command line - put one in the backup destination with date-time stamp.
	$logFileDestination = $backupDestination
	if ($logFileDestination) {
		$LogFile = "$logFileDestination\$dateTime.log"
	} else {
		# This can happen if both the logfile and backup destination parameters were not in the INI file and not on the command line.
		# In this case no log file is made. But we do proceed so there will be an email body and the receiver can find out what is wrong.
		$LogFile = ""
	}
	$deleteOldLogFiles = $True
} else {
	if (Test-Path -Path $LogFile -pathType container) {
		# The log file parameter points to a folder, so generate log file names in that folder.
		$logFileDestination = $LogFile
		$LogFile = "$logFileDestination\$dateTime.log"
		$deleteOldLogFiles = $True
	} else {
		# The log file name has been fully specified - just calculate the parent folder.
		$logFileDestination = Split-Path -parent $LogFile
	}
}

try
{
	New-Item "$LogFile" -type file -force -erroraction stop | Out-Null
}
catch
{
	$output = "ERROR: Could not create new log file`r`n$_`r`n"
	$emailBody = "$emailBody`r`n$output`r`n"
	echo $output
	$LogFile=""
	$error_during_backup = $True
	$deleteOldLogFiles = $False
}

if ([string]::IsNullOrEmpty($backupSources)) {
	# No backup sources on command line, in host-specific or common section of ini file
	# backup sources are mandatory, so flag the problem.
	$output = "`nERROR: No backup source(s) specified`n"
	echo $output
	$emailBody = "$emailBody`r`n$output`r`n"
	if ($LogFile) {
		$output | Out-File "$LogFile"  -encoding ASCII -append
	}
	$parameters_ok = $False
}

if ([string]::IsNullOrEmpty($backupDestination)) {
	# No backup destination on command line or in INI file
	# backup destination is mandatory, so flag the problem.
	$output = "`nERROR: No backup destination specified`n"
	echo $output
	$emailBody = "$emailBody`r`n$output`r`n"
	if ($LogFile) {
		$output | Out-File "$LogFile"  -encoding ASCII -append
	}
	$parameters_ok = $False
} else {
	# Process the backup destination to find out where it might be
	$backupDestinationArray = $backupDestination.split("\")

	if (($backupDestinationArray[0] -eq "") -and ($backupDestinationArray[1] -eq "")) {
		# The destination is a UNC path (file share)
		$backupDestinationTop = "\\" + $backupDestinationArray[2] + "\" + $backupDestinationArray[3] + "\"
		$backupMappedPath = $backupDestinationTop
		$backupHostName = $backupDestinationArray[2]
	} else {
		if (-not ($backupDestination -match ":")) {
			# No drive letter specified. This could be an attempt at a relative path, so first resolve it to the full path.
			# This allows us to use split-path -Qualifier below to get the actual drive letter
			$backupDestination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($backupDestination)
		}
		$backupDestinationDrive = split-path $backupDestination -Qualifier
		$backupDestinationTop = $backupDestinationDrive + "\"
		# See if the disk letter is mapped to a file share somewhere.
		$backupDriveObject = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$backupDestinationDrive'"
		$backupMappedPath = $backupDriveObject.ProviderName
		if ($backupMappedPath) {
			$backupPathArray = $backupMappedPath.split("\")
			if (($backupPathArray[0] -eq "") -and ($backupPathArray[1] -eq "")) {
				# The underlying destination is a UNC path (file share)
				$backupHostName = $backupPathArray[2]
			}
		} else {
			# Maybe the user did a "subst" command. Check for that.
			$subst = (Subst) | findstr "$backupDestinationDrive\\"
			# Looks like R:\: => UNC\hostname.myoffice.company.org\sharename
			$parts = $subst -Split "UNC\\"
			if ($parts) {
				$host_FQDN = $parts[1].split("\")[0]
				if ($host_FQDN) {
					$backupHostName = $host_FQDN
					$backupMappedPath = "\\" + $parts[1]
				}
			}
		}
	}

	if (($localSubnetOnly -eq $True) -and ($backupHostName)) {
		# Check that the name is in the same subnet as us.
		# Note: This also works if the user gives a real IPv4 like "\\10.20.30.40\backupshare"
		# $backupHostName would be 10.20.30.40 in that case.
		# TODO: Handle IPv6 addresses also some day.
		$doBackup = $false
		try {
			$destinationIpAddresses = [System.Net.Dns]::GetHostAddresses($backupHostName)
			[IPAddress]$destinationIp = $destinationIpAddresses[0]

			$localAdapters = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter 'ipenabled = "true"')

			foreach ($adapter in $localAdapters) {
				# Belts and braces here - we have seen some systems that returned unusual adapters that had IPaddress 0.0.0.0 and no IPsubnet
				# We want to ignore that sort of rubbish - the mask comparisons do not work.
				if ($adapter.IPAddress[0]) {
					[IPAddress]$IPv4Address = $adapter.IPAddress[0]
					if ($adapter.IPSubnet[0]) {
						if ($localSubnetMask -eq 0) {
							[IPAddress]$mask = $adapter.IPSubnet[0]
						} else {
							[IPAddress]$mask = $localSubnetMask
						}

						if (($IPv4address.address -band $mask.address) -eq ($destinationIp.address -band $mask.address)) {
							$doBackup = $true
						}
					}
				}
			}
		}
		catch {
			$output = "ERROR: Could not get IP address for destination $backupDestination mapped to $backupMappedPath"
			$emailBody = "$emailBody`r`n$output`r`n$_"
			$error_during_backup = $true
			echo $output  $_
		}
	}
}

# Just test for the existence of the top of the backup destination. "ln" will create any folders as needed, as long as the top exists.
if (($parameters_ok -eq $True) -and ($doBackup -eq $True) -and (test-path $backupDestinationTop)) {
	foreach($backup_source in $backupSources)
	{
		if (test-path $backup_source) {
			$stepCounter = 1
			$backupSourceArray = $backup_source.split("\")
			if (($backupSourceArray[0] -eq "") -and ($backupSourceArray[1] -eq "")) {
				# The source is a UNC path (file share) which has no drive letter. We cannot do volume shadowing from that.
				$backup_source_drive_letter = ""
			} else {
				if (-not ($backup_source -match ":")) {
					# No drive letter specified. This could be an attempt at a relative path, so first resolve it to the full path.
					# This allows us to use split-path -Qualifier below to get the actual drive letter
					$backup_source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($backup_source)
				}
				$backup_source_drive_letter = split-path $backup_source -Qualifier
				$backup_source_path =  split-path $backup_source -noQualifier
			}
			$backup_source_folder =  split-path $backup_source -leaf
			$actualBackupDestination = "$backupDestination\$backup_source_folder"

			#if the user wants to keep just one backup we do a mirror without any date, so we don't need
			#to copy files that are already there
			if ($backupsToKeep -gt 1) {
				$actualBackupDestination = "$actualBackupDestination - $dateTime"
			}

			echo "============Creating Backup of $backup_source============"
			if ($NoShadowCopy -eq $False) {
				if ($backup_source_drive_letter -ne "") {
				# We can try processing a shadow copy.
					if ($shadow_drive_letter -eq $backup_source_drive_letter) {
						# The previous shadow copy must have succeeded because $NoShadowCopy is still false, and we are looping around with a matching shadow drive letter.
						if ($StepTiming -eq $True) {
							$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
						}
						echo "$stepCounter. $stepTime Re-using previous Shadow Volume Copy"
						$stepCounter++
						$backup_source_path = $s2.DeviceObject+$backup_source_path
					} else {
						if ($num_shadow_copies -gt 0) {
							# Delete the previous shadow copy that was from some other drive letter
							foreach ($shadowCopy in $shadowCopies) {
								if ($s2.ID -eq $shadowCopy.ID) {
									if ($StepTiming -eq $True) {
										$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
									}
									echo  "$stepCounter. $stepTime Deleting previous Shadow Copy"
									$stepCounter++
									try {
										$shadowCopy.Delete()
									}
									catch {
										$output = "ERROR: Could not delete Shadow Copy"
										$emailBody = "$emailBody`r`n$output`r`n$_"
										$error_during_backup = $true
										echo $output  $_
									}
									$num_shadow_copies--
									echo "done`n"
									break
								}
							}
						}
						if ($StepTiming -eq $True) {
							$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
						}
						echo "$stepCounter. $stepTime Creating Shadow Volume Copy"
						$stepCounter++
						try {
							$s1 = (gwmi -List Win32_ShadowCopy).Create("$backup_source_drive_letter\", "ClientAccessible")
							$s2 = gwmi Win32_ShadowCopy | ? { $_.ID -eq $s1.ShadowID }

							if ($s1.ReturnValue -ne 0 -OR !$s2) {
								#ToDo add explanation of return codes http://msdn.microsoft.com/en-us/library/aa389391%28v=vs.85%29.aspx
								throw "Shadow Copy Creation failed. Return Code: " + $s1.ReturnValue
							}

							echo "Shadow Volume ID: $($s2.ID)"
							echo "Shadow Volume DeviceObject: $($s2.DeviceObject)"

							$shadowCopies = Get-WMIObject -Class Win32_ShadowCopy

							echo "done`n"

							$backup_source_path = $s2.DeviceObject+$backup_source_path
							$num_shadow_copies++
							$shadow_drive_letter = $backup_source_drive_letter
						}
						catch {
							$output = "ERROR: Could not create Shadow Copy`r`n$_ `r`nATTENTION: Skipping creation of Shadow Volume Copy. ATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`r`n"
							$emailBody = "$emailBody`r`n$output`r`n"
							$error_during_backup = $true
							echo $output
							if ($LogFile) {
								$output | Out-File "$LogFile" -encoding ASCII -append
							}
							$backup_source_path = $backup_source
							$NoShadowCopy = $True
						}
					}
				} else {
					# We were asked to do shadow copy but the source is a UNC path.
					$output = "Skipping creation of Shadow Volume Copy because source is a UNC path `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
					if ($StepTiming -eq $True) {
						$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
					}
					echo "$stepCounter. $stepTime $output"
					if ($LogFile) {
						$output | Out-File "$LogFile" -encoding ASCII -append
					}
					$stepCounter++
					$backup_source_path = $backup_source
				}
			}
			else {
				$output = "Skipping creation of Shadow Volume Copy `r`nATTENTION: if files are changed during the backup process, they might end up being corrupted in the backup!`n"
				if ($StepTiming -eq $True) {
					$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
				}
				echo "$stepCounter. $stepTime $output"
				if ($LogFile) {
					$output | Out-File "$LogFile" -encoding ASCII -append
				}
				$stepCounter++
				$backup_source_path = $backup_source
			}

			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			echo "$stepCounter. $stepTime Running backup"
			$stepCounter++
			echo "Source: $backup_source_path"
			echo "Destination: $actualBackupDestination"

			$lastBackupFolderName = ""
			$lastBackupFolders = @()
			If (Test-Path $backupDestination -pathType container) {
				$oldBackupItems = Get-ChildItem -Force -Path $backupDestination | Where-Object {$_ -is [IO.DirectoryInfo]} | Sort-Object -Property Name

				# get me the last backup if any
				foreach ($item in $oldBackupItems) {
					if ($item.Name  -match '^'+$backup_source_folder+' - \d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}$' ) {
						$lastBackupFolderName = $item.Name
						$lastBackupFolders += $item
					}
				}
			}

			if ($traditional -eq $True) {
				$traditionalArgument = " --traditional "
			} else {
				$traditionalArgument = ""
			}

			if ($noads -eq $True) {
				$noadsArgument = " --noads "
			} else {
				$noadsArgument = ""
			}

			if ($noea -eq $True) {
				$noeaArgument = " --noea "
			} else {
				$noeaArgument = ""
			}

			if ($timeTolerance -ne 0) {
				$timeToleranceArgument = " --timetolerance $timeTolerance "
			} else {
				$timeToleranceArgument = ""
			}

			$excludeString=" "
			foreach($item in $exclude) {
				if ($item -AND $item.Trim()) {
					$excludeString = "$excludeString --exclude $item "
				}
			}

			$commonArgumentString = "$traditionalArgument $noadsArgument $noeaArgument $timeToleranceArgument $excludeString"

			if ($LogFile) {
				$logFileCommandAppend = " >> `"$LogFile`""
			}

			$start_time = get-date -f "yyyy-MM-dd HH-mm-ss"

			if ($lastBackupFolderName -eq "" ) {
				echo "Full copy from $backup_source_path to $actualBackupDestination"
				if ($LogFile) {
					"`r`nFull copy from $backup_source_path to $actualBackupDestination" | Out-File "$LogFile"  -encoding ASCII -append
				}

				#echo "$script_path\..\ln.exe $commonArgumentString --copy `"$backup_source_path`" `"$actualBackupDestination`"    >> $LogFile"
				`cmd /c  "$script_path\..\ln.exe $commonArgumentString --copy `"$backup_source_path`" `"$actualBackupDestination`"    $logFileCommandAppend"`
			} else {
				echo "Delorian copy from $backup_source_path to $actualBackupDestination against $backupDestination\$lastBackupFolderName"
				if ($LogFile) {
					"`r`nDelorian copy from $backup_source_path to $actualBackupDestination against $backupDestination\$lastBackupFolderName" | Out-File "$LogFile"  -encoding ASCII -append
				}

				#echo "$script_path\..\ln.exe $commonArgumentString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`"  >> $LogFile"
				`cmd /c  "$script_path\..\ln.exe $commonArgumentString --delorean `"$backup_source_path`" `"$backupDestination\$lastBackupFolderName`" `"$actualBackupDestination`" $logFileCommandAppend"`
			}

			$summary = ""
			if ($LogFile) {
				$backup_response = get-content "$LogFile"
				foreach( $line in $backup_response.length..1 ) {
					$summary =  $backup_response[$line] + "`n" + $summary
					
					if ($backup_response[$line] -match '(.*):\s+(?:\d+(?:\,\d*)?|-)\s+(?:\d+(?:\,\d*)?|-)\s+(?:\d+(?:\,\d*)?|-)\s+(?:\d+(?:\,\d*)?|-)\s+(?:\d+(?:\,\d*)?|-)\s+(?:\d+(?:\,\d*)?|-)\s*([1-9]+\d*(?:\,\d*)?)') {
						$error_during_backup = $true
					}
					if ($backup_response[$line] -match '.*Total\s+Copied\s+Linked\s+Skipped.*\s+Excluded\s+Failed.*') {
						break
					}
				}
			}

			echo "done`n"

			$summary = "`n------Summary-----`nBackup AT: $start_time FROM: $backup_source TO: $backupDestination $backupMappedPath`n" + $summary
			echo $summary

			$emailBody = $emailBody + $summary

			echo "`n"

			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}

			echo  "$stepCounter. $stepTime Deleting old backups"
			$stepCounter++

			#plus 1 because we just created a new backup but we have checked for old backups before we have
			#created the new one
			$backupsInDestination = $lastBackupFolders.length + 1
			$summary = "`nFound $backupsInDestination backup(s), keeping a maximum of $backupsToKeep backup(s)`n"
			echo $summary

			if ($LogFile) {
				$summary | Out-File "$LogFile"  -encoding ASCII -append
			}
			$emailBody = $emailBody + $summary

			$backupsToDelete=$backupsInDestination - $backupsToKeep
			if ($backupsToDelete -gt 0) {
				echo  "Deleting $backupsToDelete old backup(s)"
				if ($LogFile) {
					"`r`nDeleting $backupsToDelete old backup(s)" | Out-File "$LogFile"  -encoding ASCII -append
				}
				$backupsDeleted = 0
				while ($backupsDeleted -lt $backupsToDelete) {
					$folderToDelete =  $backupDestination +"\"+ $lastBackupFolders[$backupsDeleted].Name
					echo "Deleting $folderToDelete"
					if ($LogFile) {
						"`r`nDeleting $folderToDelete" | Out-File "$LogFile"  -encoding ASCII -append
					}
					$backupsDeleted++

					`cmd /c  "$script_path\..\ln.exe --deeppathdelete `"$folderToDelete`" $logFileCommandAppend"`
				}

				$summary = "`nDeleted $backupsDeleted old backup(s)`n"
				echo $summary
				if ($LogFile) {
					$summary | Out-File "$LogFile"  -encoding ASCII -append
				}

				$emailBody = $emailBody + $summary
			} else {
				$summary = "`nNo old backups were deleted`n"
				echo $summary
				if ($LogFile) {
					$summary | Out-File "$LogFile"  -encoding ASCII -append
				}

				$emailBody = $emailBody + $summary
			}
		} else {
			# The backup source does not exist - there was no point processing this source.
			$output = "ERROR: Backup source does not exist - $backup_source - backup NOT done for this source`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			$error_during_backup = $true
			echo $output
			if ($LogFile) {
				$output | Out-File "$LogFile" -encoding ASCII -append
			}
		}
	}

	if (($deleteOldLogFiles -eq $True) -and ($logFileDestination)) {
		$lastLogFiles = @()
		If (Test-Path $logFileDestination -pathType container) {
			$oldLogItems = Get-ChildItem -Force -Path $logFileDestination | Where-Object {$_ -is [IO.FileInfo]} | Sort-Object -Property Name

			# get me the old logs if any
			foreach ($item in $oldLogItems) {
				if ($item.Name  -match '^\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}.log$' ) {
					$lastLogFiles += $item
				}
			}
		}

		if ($StepTiming -eq $True) {
			$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
		}
		echo  "$stepCounter. $stepTime Deleting old log files"
		$stepCounter++

		#No need to add 1 here because the new log existed already when we checked for old log files
		$logFilesInDestination = $lastLogFiles.length
		$summary = "`nFound $logFilesInDestination log file(s), keeping maximum of $backupsToKeep log file(s)`n"
		echo $summary
		if ($LogFile) {
			$summary | Out-File "$LogFile"  -encoding ASCII -append
		}
		$emailBody = $emailBody + $summary

		$logFilesToDelete=$logFilesInDestination - $backupsToKeep
		if ($logFilesToDelete -gt 0) {
			echo  "Deleting $logFilesToDelete old logfile(s)"
			if ($LogFile) {
				"`r`nDeleting $logFilesToDelete old logfile(s)" | Out-File "$LogFile"  -encoding ASCII -append
			}
			$logFilesDeleted = 0
			while ($logFilesDeleted -lt $logFilesToDelete) {
				$logFileToDelete = $logFileDestination +"\"+ $lastLogFiles[$logFilesDeleted].Name

				echo "Deleting $logFileToDelete(.zip)"
				if ($LogFile) {
					"`r`nDeleting $logFileToDelete(.zip)" | Out-File "$LogFile"  -encoding ASCII -append
				}

				If (Test-Path "$logFileToDelete") {
					Remove-Item "$logFileToDelete"
				}
				If (Test-Path "$logFileToDelete.zip") {
					Remove-Item "$logFileToDelete.zip"
				}

				$logFilesDeleted++
			}

			$summary = "`nDeleted $logFilesDeleted old logfile(s)`n"
			echo $summary
			if ($LogFile) {
				$summary | Out-File "$LogFile"  -encoding ASCII -append
			}
			$emailBody = $emailBody + $summary
		} else {
			$summary = "`nNo old logfiles were deleted`n"
			echo $summary
			if ($LogFile) {
				$summary | Out-File "$LogFile"  -encoding ASCII -append
			}
			$emailBody = $emailBody + $summary
		}
	}

	# We have processed each backup source. Now cleanup any remaining shadow copy.
	if ($num_shadow_copies -gt 0) {
		# Delete the last shadow copy
		foreach ($shadowCopy in $shadowCopies) {
		if ($s2.ID -eq $shadowCopy.ID) {
			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			echo  "$stepCounter. $stepTime Deleting last Shadow Copy"
			$stepCounter++
			try {
				$shadowCopy.Delete()
			}
			catch {
				$output = "ERROR: Could not delete Shadow Copy. "
				$emailBody = "$emailBody`r`n$output`r`n$_"
				$error_during_backup = $true
				echo $output  $_
			}
			$num_shadow_copies--
			echo "done`n"
			break
			}
		}
	}

} else {
	if ($backupMappedPath) {
		$backupMappedString = " (" + $backupMappedPath + ")"
	} else {
		$backupMappedString = ""
	}

	if ($parameters_ok -eq $True) {
		if ($doBackup -eq $True) {
			# The destination drive or \\server\share does not exist.
			$output = "ERROR: Destination drive or share $backupDestinationTop$backupMappedString does not exist - backup NOT done`r`n"
		} else {
			# The backup was not done because localSubnetOnly was on, and the destination \\server\share is not in the local subnet.
			$output = "ERROR: Destination share $backupDestinationTop$backupMappedString is not in a local subnet - backup NOT done`r`n"
		}
	} else {
		# There was some error in the supplied parameters.
		# The specific problem will have been mentioned in the email body/log file earlier.
		# Put a general message here.
		$output = "ERROR: There was a problem with the input parameters"
	}
	$emailBody = "$emailBody`r`n$output`r`n"
	$error_during_backup = $true
	echo $output
	if ($LogFile) {
		$output | Out-File "$LogFile" -encoding ASCII -append
	}
}

if ($emailTo -AND $emailFrom -AND $SMTPServer) {
	echo "============Sending Email============"
	$stepCounter = 1

	if ($LogFile) {
		if ($StepTiming -eq $True) {
			$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
		}
		echo  "$stepCounter. $stepTime Zipping log file"
		$stepCounter++
		$zipFilePath = "$LogFile.zip"
		$fileToZip = get-item $LogFile

		try
		{
			New-Item $zipFilePath -type file -force -erroraction stop | Out-Null
			if (-not (test-path $zipFilePath)) {
			  set-content $zipFilePath ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
			}

			$ZipFile = (new-object -com shell.application).NameSpace($zipFilePath)
			$zipfile.CopyHere($fileToZip.fullname)

			$timeSlept = 0
			while ($zipfile.Items().Count -le 0 -AND $timeSlept -le $maxMsToSleepForZipCreation ) {
				Start-sleep -milliseconds $msToWaitDuringZipCreation
				$timeSlept = $timeSlept + $msToWaitDuringZipCreation
			}
			$attachment = New-Object System.Net.Mail.Attachment("$zipFilePath" )
		}
		catch {
			$error_during_backup = $True
			$output = "`r`nERROR: Could not create log ZIP file. Will try to attach the unzipped log file and hope it's not to big.`r`n$_`r`n"
			$emailBody = "$emailBody`r`n$output`r`n"
			echo $output
			$output | Out-File "$LogFile"  -encoding ASCII -append
			$attachment = New-Object System.Net.Mail.Attachment("$LogFile" )
		}
	}

	if ($error_during_backup) {
		$EmailSubject = "ERROR - $EmailSubject"
	}
	$SMTPMessage = New-Object System.Net.Mail.MailMessage($emailFrom,$emailTo,$emailSubject,$emailBody)

	if ($LogFile) {
		$SMTPMessage.Attachments.Add($attachment)
	}
	$SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)

	$SMTPClient.Timeout = $SMTPTimeout
	if ($NoSMTPOverSSL -eq $False) {
		$SMTPClient.EnableSsl = $True
	}

	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPassword);

	$emailSendSucess = $False
	if ($StepTiming -eq $True) {
		$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
	}
	echo  "$stepCounter. $stepTime Sending email"
	$stepCounter++
	while ($emailSendRetries -gt 0 -AND !$emailSendSucess) {
		try {
			$emailSendRetries--
			$SMTPClient.Send($SMTPMessage)
			$emailSendSucess = $True
		} catch {
			if ($StepTiming -eq $True) {
				$stepTime = get-date -f "yyyy-MM-dd HH-mm-ss"
			}
			$output = "ERROR: $stepTime Could not send Email.`r`n$_`r`n"
			echo $output
			if ($LogFile) {
				$output | Out-File "$LogFile" -encoding ASCII -append
			}
		}

		if (!$emailSendSucess) {
			Start-sleep -milliseconds $msToPauseBetweenEmailSendRetries
		}
	}

	if ($LogFile) {
		$attachment.Dispose()
	}

	echo "done"
}
