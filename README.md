# Sync-Website
PowerShell script that uses native commands to recursively download files

## Purpose 
Provide a barebones Powershell script tested on the following version:

|Major|Minor|Build|Revision|
|---|---|---|---
|5|1|17134|858

If you are in a locked down environment, and you can't install any vastly superior tools, then this script will at least let you mirror a website.

## Improvements
I will initially only add features that meet my bare minimum needs. If you want a feature implemented, please create an issue and I will happily add it.

## Usage
```
Sync-Website.ps1 -url https://example.com/packages -dest .\downloadDir -proxy 'http://XX.XX.X.XXX:443'
```
