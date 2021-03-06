#################################################################################################################
# 
# Version 1.1 May 2014
# Robert Pearman (WSSMB MVP)
# TitleRequired.com
# Script to Automated Email Reminders when Users Passwords due to Expire.
#
# Requires: Windows PowerShell Module for Active Directory
#
# For assistance and ideas, visit the TechNet Gallery Q&A Page. http://gallery.technet.microsoft.com/Password-Expiry-Email-177c3e27/view/Discussions#content
#
##################################################################################################################
# Please Configure the following variables....
$smtpServer="mail.altercareonline.net"
$expireindays = 21
$from = "NOREPLY - IT Support <no-reply@altercareonline.net>"
$logging = "Enabled" # Set to Disabled to Disable Logging
$logFile = "c:\scripts\scheduled\Logs\passwordexpire.log.csv" # ie. c:\mylog.csv
$testing = "Disabled" # Set to Disabled to Email Users
$testRecipient = "justin.herman@altercareonline.net"
$date = Get-Date -format MMddyyyy
#
###################################################################################################################

# Check Logging Settings
if (($logging) -eq "Enabled")
{
    # Test Log File Path
    $logfilePath = (Test-Path $logFile)
    if (($logFilePath) -ne "True")
    {
        # Create CSV File and Headers
        New-Item $logfile -ItemType File
        Add-Content $logfile "Date,Name,EmailAddress,DaystoExpire,ExpiresOn"
    }
} # End Logging Check

# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
Import-Module ActiveDirectory
$users = get-aduser -filter * -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress |where {$_.Enabled -eq "True"} | where { $_.PasswordNeverExpires -eq $false } | where { $_.passwordexpired -eq $false }
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

# Process Each User for Password Expiry
foreach ($user in $users)
{
    $Name = (Get-ADUser $user | foreach { $_.Name})
    $emailaddress = $user.emailaddress
    $passwordSetDate = (get-aduser $user -properties * | foreach { $_.PasswordLastSet })
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user)
    # Check for Fine Grained Password
    if (($PasswordPol) -ne $null)
    {
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge
    }
  
    $expireson = $passwordsetdate + $maxPasswordAge
    $today = (get-date)
    $daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
        
    # Set Greeting based on Number of Days to Expiry.

    # Check Number of Days to Expiry
    $messageDays = $daystoexpire

    if (($messageDays) -ge "1")
    {
        $messageDays = "in " + "$daystoexpire" + " days."
    }
    else
    {
        $messageDays = "today."
    }

    # Email Subject Set Here
    $subject="Your windows password will expire $messageDays"
  
    # Email Body Set Here, Note You can use HTML, including Images.
    $body ="
    <p>Dear $name,</p>
		<p>This is a friendly reminder. Your windows password will expire <strong>$messageDays</strong></p>
		<p>
			<br />To change your password on a PC, press CTRL + ALT + Delete, then choose Change Password.<br />
			<br />The following are the guidelines for acceptable passwords:</p>
		<ul>
			<li>Passwords must be at least 12 characters in length.</li>
			<li>Passwords can NOT contain your username, first name, last name, or be a previously used password.</li>
			<li>Your password must contain 3 of the following 4:
				<ol>
					<li>Capital Letters</li>
					<li>Lowercase Letters</li>
					<li>Numbers</li>
					<li>Special Characters</li>
				</ol>
			</li>
		</ul>
		<p>If you have any issues with this or any other questions please contact IT Support Dept at 330-498-8199.</p>
		<p>&nbsp;</p>
		<p>Thanks,</p>
		<p>IT Support Dept</p>
		<p>330-498-8199</p>
    "
    
   
    # If Testing Is Enabled - Email Administrator
    if (($testing) -eq "Enabled")
    {
        $emailaddress = $testRecipient
    } # End Testing

    # If a user has no email address listed
  #  if (($emailaddress) -eq $null)
  #  {
  #      $emailaddress = $testRecipient    
  #  }# End No Valid Email

    # Send Email Message
    if (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays) -and (($emailaddress) -ne $null))
    {
         # If Logging is Enabled Log Details
        if (($logging) -eq "Enabled")
        {
            Add-Content $logfile "$date,$Name,$emailaddress,$daystoExpire,$expireson" 
        }
        # Send Email Message
        Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High -UseSsl

    } # End Send Message
    
} # End User Processing



# End