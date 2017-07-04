# pdh2zabbix
Creates Zabbix templates for Windows PDH and provides Zabbix instance LLD for counter instances.

## Syntax
    pdh2zabbix.ps1 [-Mode <String>] [-FileName <String>] [-Hostgroup <String>] [-TemplateName <String>] [-EnableItems] [-CheckDelay <Int32>] [-DiscoveryDelay <Int32>] [-KeepHistory <Int32>] [-KeepTrends <Int32>] -PdhCounterSetNames <String[]> [<CommonParameters>]

## Description
This script automates the creation of [Zabbix](https://www.zabbix.com) templates based on [Windows Performance Counters](https://msdn.microsoft.com/de-de/library/windows/desktop/aa371643(v=vs.85).aspx) and the dicovery of counter instances for Zabbix low-level discovery.

### Template mode
The templating functionality creates an [importable XML template](https://www.zabbix.com/documentation/3.0/manual/config/templates) for Zabbix 3.x, based on the available PDHs on the system the script was run on. It accepts a list of performance objects (defaulting to the "System" set), and outputs the corresponding Zabbix items, discovery rules, item prototypes, and value maps, where applicable.

The translation of PDH elements is done as follows:
- PDH countersets -> Zabbix applications
- PDH counters (single-instance) -> Zabbix items
- PDH counters (multi-instance) -> Zabbix discovery rules
- PDH counter instances -> Zabbix item prototypes

This mode is supposed to be called directly from the Command Prompt or PowerShell console. It generates an importable XML file based on the PDH countersets specified.

### Discovery mode (default)
The discovery functionality returns an [LLD-compatible JSON](https://www.zabbix.com/documentation/3.0/manual/discovery/low_level_discovery#creating_custom_lld_rules) for Zabbix 3.x, based on the available PDHs on the system the script was run on. It accepts a single performance object and outputs backing instances as an LLD group of items.

This mode is supposed to be called from the Zabbix agent's `UserParameter` directive.

## Parameters
`-Mode <String>`
Specifies the mode this script will run in. Possible alternatives are:
- 'discovery' -> run in LLD mode, called by UserParameter. (default)
- 'template' -> run in XML mode, called from the shell.


`-FileName <String>`
Specifies the output file name for XML output.
*For 'template' mode only*

`-Hostgroup <String>`
Specifies the hostgroup the generated template belogs to.
*For 'template' mode only*

`-TemplateName <String>`
Specifies the name of the generated template.
*For 'template' mode only*

`-EnableItems [<SwitchParameter>]`
Specifies whether items, discovery rules and item prototypes are enabled by default.
*For 'template' mode only*

`-CheckDelay <Int32>`
Specifies the Zabbix [item update interval](https://www.zabbix.com/documentation/3.2/manual/config/items/item) in seconds.
*For 'template' mode only*

`-DiscoveryDelay <Int32>`
Specifies the Zabbix [discovery update interval](https://www.zabbix.com/documentation/3.2/manual/config/items/item) in seconds.
*For 'template' mode only*

`-KeepHistory <Int32>`
Specifies the Zabbix [history retention](https://www.zabbix.com/documentation/3.2/manual/config/items/history_and_trends) in days.
*For 'template' mode only*

`-KeepTrends <Int32>`
Specifies the Zabbix [LLD interval](https://www.zabbix.com/documentation/3.2/manual/discovery/low_level_discovery) in seconds.
*For 'template' mode only*

`-PdhCounterSetNames <String[]>`
Specifies the counter sets to be processed. Multiple space-separated names are acceptable; counters with spaces in the name must be quoted properly.

## Examples
Run a low-level discovery on the 'Network Interface' counter set:
```Powershell
PS ~>pdh2zabbix.ps1 "Network Interface"
```
Create a template for the 'ICMP' counter set, named 'example.com Template PDH ICMP' with all items enabled:
```Powershell   
PS ~>pdh2zabbix.ps1 -Mode template -TemplateName "example.com Template PDH ICMP" -EnableItems ICMP
```

