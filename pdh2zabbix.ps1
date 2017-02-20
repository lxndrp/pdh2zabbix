# pdh2zabbix.ps1

<#
.SYNOPSIS
    Creates Zabbix templates for Windows PDH and provides Zabbix instance LLD for counter instances.

.DESCRIPTION
    This script automates the creation of Zabbix templates based on Windows Performance
    Counters and the dicovery of counter instances for Zabbix low-level discovery.

    The templating functionality creates an importable XML template for Zabbix
    3.x, based on the available PDHs on the system the script was run on. It
    accepts a list of performance objects (defaulting to the "System" set),
    and outputs the corresponding Zabbix items, discovery rules, item prototypes,
    and value maps, where applicable.

    The translation of PDH elements is done as follows:
      - PDH countersets -> Zabbix applications
      - PDH counters (single-instance) -> Zabbix items
      - PDH counters (multi-instance) -> Zabbix discovery rules
      - PDH counter instances -> Zabbix item prototypes

    The discovery functionality returns an LLD-compatible JSON for Zabbix 3.x,
    based on the available PDHs on the system the script was run on. It
    accepts a single performance object and outputs backing instances as an
    LLD group of items. 

.NOTES
    Author: Dr. Alexander Papaspyrou <alexander@papaspyrou.name>

.LINK
    https://github.com/lxndrp/pdh2zabbix

.PARAMETER Mode
    Specifies the mode this script will run in. Possible alternatives are:
      - 'discovery' -> run in LLD mode, called by UserParameter. (default)
      - 'template' -> run in XML mode, called from the shell.
.PARAMETER FileName
    Specifies the output file name for XML output.
        *For 'template' mode only*
.PARAMETER Hostgroup
    Specifies the hostgroup the generated template belogs to.
        *For 'template' mode only*
.PARAMETER TemplateName
    Specifies the name of the generated template.
        *For 'template' mode only*
.PARAMETER EnableItems
    Specifies whether items, discovery rules and item prototypes are enabled by default.
        *For 'template' mode only*
.PARAMETER PdhCounterSetNames
    Specifies the counter sets to be processed. Multiple space-separated names
    are acceptable; counters with spaces in the name must be quoted properly.
.EXAMPLE
    pdh2zabbix.ps1 "Network Interface" 
    Run a low-level discovery on the 'Network Interface' counter set.
.EXAMPLE
    pdh2zabbix.ps1 -Mode template -TemplateName "example.com Template PDH ICMP" -EnableItems ICMP
    Create a template for the 'ICMP' counter set, named 'example.com Template PDH ICMP' with all items enabled.
#>
param (
    [Parameter(
        HelpMessage="Run in 'template' or 'discovery' mode"
    )]
    [Alias("m")]
    [ValidateSet(
        "template", "discovery"
    )]
    [string]$Mode="discovery",

    [Parameter(
        HelpMessage="Output file name",
        ParameterSetName="template"
    )]
    [Alias("f")]
    [string]$FileName="stdout",
    
    [Parameter(
        HelpMessage="Template group",
        ParameterSetName="template"
    )]
    [Alias("G")]
    [string]$Hostgroup="Templates",
    
    [Parameter(
        HelpMessage="Template name",
        ParameterSetName="template"
    )]
    [Alias("N")]
    [string]$TemplateName="Template PDH Windows",
    
    [Parameter(
        HelpMessage="Enable all template items",
        ParameterSetName="template"
    )]
    [Alias("e")]
    [switch]$EnableItems=$false,

    [Parameter(
        Mandatory=$true,
        ValueFromRemainingArguments=$true,
        HelpMessage="PDH counter set to use"
    )]
    [string[]]$PdhCounterSetNames
)

function validateCounterSets([string[]]$Names) {
    $CounterSets=@()
    ForEach($CounterSet in $Names) {
        Try {
            $CounterSets+=Get-Counter -ListSet $CounterSet -ErrorAction Stop
        }
        Catch {
            Write-Error $_.Exception.Message
            exit 1
        }
    }
    return $CounterSets
}

function extractPdhInstanceNames($PathsWithInstances) {
    $regex=[regex]"\\$($CounterSet.CounterSetName)\((.*)\).*"
        
    $PdhInstances=@()
    ForEach($PathWithInstance in $CounterSet.PathsWithInstances) {
        $PdhInstances+=$regex.Matches($PathWithInstance).Groups[1].Value
    }
    
    return $PdhInstances | Select-Object -Unique       
}

function handleDiscoveryMode($CounterSet) {
    if($CounterSet.CounterSetType -eq "MultiInstance") {
        $ZbxDiscoveryData=@()
        ForEach($PdhInstance in extractPdhInstanceNames($CounterSet.PathsWithInstances)) {
            $ZbxDiscoveryData+=@{"PDHINSTANCE"=$PdhInstance}
        }
        Write-Host $(ConvertTo-Json @{"data"=$ZbxDiscoveryData} -Depth 3)
    } else {
        Write-Error "counter set $($CounterSet.CounterSetName) is not discoverable; please use 'MultiInstance' CounterSetTypes only."
        exit 3
    }
}

function handleTemplateMode($CounterSets) {
    # not yet implemented
}

switch($Mode) {
    "discovery" {
        if($CounterSets.Length -eq 1) {
            handleDiscoveryMode(validateCounterSets($PdhCounterSetNames)[0])
        } else {
            Write-Error "'discovery' mode cannot handle multiple PDH counter sets; please specify only one."
            exit 2
        }
    }
    "template" {
        handleTemplateMode(validateCounterSets($PdhCounterSetNames))
    }
}