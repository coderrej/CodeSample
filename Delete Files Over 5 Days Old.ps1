#
# This will display files in a directory that haven't been modified in the last 5 days, path specified with -path parameter.
# Adding -delete parameter when calling script will remove files.
#

param (
    [string]$path = $(throw "Please designate directory with -path parameter"),
    [switch]$delete
)

# Gets any files not modified in the last 5 days, filters name and LastWriteTime for output
Get-ChildItem -path $path | where { $_.LastWriteTime -le (Get-Date).AddDays(-(5)) } | Select Name,LastWriteTime | Sort-Object LastWriteTime


# Deletes files if -delete parameter is used
if ($delete) {
   Get-ChildItem -path $path | Remove-Item
}