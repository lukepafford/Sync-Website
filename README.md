# Sync-Website
PowerShell script that uses native commands to recursively download files

## Purpose 
Provide a barebones Powershell script tested on the following version:

|Major|Minor|Build|Revision|
|---|---|---|---
|5|1|17134|858

If you are in a locked down environment, and you can't install any vastly superior tools, then this script will at least let you mirror a website.

## Installation
```
1. Open Powershell

2. Create your user module directory
   New-Item -ItemType Directory -Force -Path $env:UserPROFILE\Documents\WindowsPowerShell\Modules
3. Download the [SyncWebsite.psm1 module](https://raw.githubusercontent.com/lukepafford/Sync-Website/master/Sync-Website.ps1) and save the module to the previously created modules directory
```

## Usage
```
Import-Module SyncWebsite
Sync-Website.ps1 -url https://example.com/packages -dest .\downloadDir -proxy 'http://XX.XX.X.XXX:443'
```

## Improvements
I will initially only add features that meet my bare minimum needs. If you want a feature implemented, please create an issue and I will happily add it.
