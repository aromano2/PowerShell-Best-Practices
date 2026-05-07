# format-test.ps1 - intentionally ugly; format to clean up

function test-badlyformatted{
param([string]$name,[int]$count=1,[switch]$force)

if($null -eq $name){ Write-Output 'name is null' }

# casing issues - aliases and incorrect cmdlet casing
$items = gci c:\temp | ? { $_.length -gt 0 } | % { $_.fullname }
$result = get-childitem -path c:\windows | where-object {$_.psiscontainer}

# operator and separator whitespace
$x=1+2
$y = @(1,2,3,4)
$z=@{name='foo';value=42}

# brace style violations (these become Allman)
if ($count -gt 0) {
Write-Output "positive"
} else {
Write-Output "non-positive"
}

# one-line blocks (expand with ignoreOneLineBlock=false)
if ($force) { Write-Warning 'forcing' }
foreach ($i in 1..3) { Write-Output $i }

# pipeline indentation
Get-Process |
Where-Object { $_.cpu -gt 10 } |
Sort-Object cpu -Descending |
Select-Object -First 5

# whitespace inside braces / around pipes
$hash=@{a=1;b=2 ;c=3}
Get-Process|Where-Object{$_.id -gt 0}|Select-Object name

# whitespace before paren
if($count-eq 1){'one'}

# constant string preference (double quotes with no interpolation)
$greeting = "hello world"
$path = "C:\temp\file.txt"

# property/value alignment in hashtables
$config = @{
ShortKey = 1
MuchLongerKeyName = 2
Mid = 3
}

# trailing whitespace and missing final newline issues live here too   
try{
Get-Item $path -ErrorAction stop
}catch{
write-error $_.exception.message
}finally{
write-verbose 'done'
}

# nested one-liners
1..5 | ForEach-Object { if ($_ % 2 -eq 0) { "$_ even" } else { "$_ odd" } }
}

# single-line param block - formatter will NOT expand this (known limitation)
function Get-Thing { param($a,$b) $a+$b }

test-badlyformatted -name 'demo' -count 3 -force