$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

if (Test-Path LookingFor) { Remove-Item LookingFor -Recurse -Force }
if (Test-Path LookingFor.zip) { Remove-Item LookingFor.zip -Force }

New-Item -ItemType Directory -Path LookingFor | Out-Null
Copy-Item Core.lua, LookingFor.toc -Destination LookingFor
Compress-Archive -Path LookingFor -DestinationPath LookingFor.zip
Remove-Item LookingFor -Recurse -Force
