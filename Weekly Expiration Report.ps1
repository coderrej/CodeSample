#
# This script creates a report in Slack of users who will be expiring over the next week.
# Intended to be run as a weekly scheduled task.
#


Import-Module ActiveDirectory

# Pulls list of all users who are enabled and are not set to never expire
$userList = Get-ADUser -Filter {Enabled -eq $true -and PasswordNeverExpires -eq $false} -Properties "DisplayName","PasswordLastSet"

# Determines password age policy, subtracts max age from today's date, then adds 7 days for determining who falls in week range
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days
$oldestPLS = (Get-Date).AddDays(-($maxPasswordAge))
$expiringSoonPLS = $expiredDate.AddDays(7)

# Creates array for dumping list of expiring users used in foreach loop
$expiringList = @()

# Looks at each user in userList and determines whether their password will be expiring within 7 days. Users that are expiring are added into an array
foreach ($user in $userList) {
    $userPLS = $user.PasswordLastSet
    if ($userPLS -ge $oldestPLS -and $userPLS -le $expiringSoonPLS)
        {
            $expiringUser = [PSCustomObject]@{
                Name = $user.DisplayName
                # Calculates the user's expiration date
                ExpireDate = ($user.PasswordLastSet).AddDays($maxPasswordAge)
            }

            $expiringList += $expiringUser
        }

}

# Converts array into a string, formatting in Slack is a little off so I think something needs to be changed here
$slackOutput = $expiringList | out-string

# Add Slack webhook URL in slackWebHook, info is converted to Json and pushed to default settings on webhook
$slackWebHook="https://hooks.slack.com/services/x"
$body = @{ text=$slackOutput; } | ConvertTo-Json
Invoke-WebRequest -Method Post -Uri $slackWebHook -Body $body
