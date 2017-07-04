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
.PARAMETER CheckDelay
    Specifies the Zabbix item update interval in seconds. See https://www.zabbix.com/documentation/3.2/manual/config/items/item for details.
        *For 'template' mode only*
.PARAMETER DiscoveryDelay
    Specifies the Zabbix discovery update interval in seconds. See https://www.zabbix.com/documentation/3.2/manual/config/items/item for details.
        *For 'template' mode only*
.PARAMETER KeepHistory
    Specifies the Zabbix history retention in days, See https://www.zabbix.com/documentation/3.2/manual/config/items/history_and_trends for details.
        *For 'template' mode only*
.PARAMETER KeepTrends
    Specifies the Zabbix LLD interval in seconds. See https://www.zabbix.com/documentation/3.2/manual/discovery/low_level_discovery for details.
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
        HelpMessage = "Run in 'template' or 'discovery' mode"
    )]
    [Alias("m")]
    [ValidateSet(
        "template", "discovery"
    )]
    [string]$Mode = "discovery",

    [Parameter(
        HelpMessage = "Output file name",
        ParameterSetName = "template"
    )]
    [Alias("f")]
    [string]$FileName = "stdout",
    
    [Parameter(
        HelpMessage = "Template group",
        ParameterSetName = "template"
    )]
    [Alias("G")]
    [string]$Hostgroup = "Templates",
    
    [Parameter(
        HelpMessage = "Template name",
        ParameterSetName = "template"
    )]
    [Alias("N")]
    [string]$TemplateName = "Template PDH Windows",
    
    [Parameter(
        HelpMessage = "Enable all template items",
        ParameterSetName = "template"
    )]
    [Alias("e")]
    [switch]$EnableItems = $false,

    [Parameter(
        HelpMessage = "Check interval in seconds",
        ParameterSetName = "template"
    )]
    [int]$CheckDelay = 60,

    [Parameter(
        HelpMessage = "Discovery interval in seconds",
        ParameterSetName = "template"
    )]
    [int]$DiscoveryDelay = 3600,

    [Parameter(
        HelpMessage = "History retention in days",
        ParameterSetName = "template"
    )]
    [int]$KeepHistory = 90,

    [Parameter(
        HelpMessage = "Trends retention in days",
        ParameterSetName = "template"
    )]
    [int]$KeepTrends = 365,

    [Parameter(
        Mandatory = $true,
        ValueFromRemainingArguments = $true,
        HelpMessage = "PDH counter sets to use"
    )]
    [ValidateScript( {
            foreach ($arg in $_) {
                if ([System.Diagnostics.PerformanceCounterCategory]::Exists($arg)) {
                    continue
                }
                else {
                    Throw [System.Management.Automation.ValidationMetadataException] "The PDH counter set '$arg' does not exist on this system."
                    return $false
                }
            }
            return $true
        })]
    [string[]]$PdhCounterSetNames
)

function createZabbixTemplateStub() {
    [xml]$xml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<zabbix_export>
  <date>2017-02-17T11:38:41Z</date>
  <version>3.0</version>
  <groups>
    <group>
      <name>Templates</name>
    </group>
  </groups>
  <templates>
    <template>
      <template>$TemplateName</template>
      <name></name>
      <applications>
      </applications>
      <description>Generated by pdh2zabbix</description>
      <groups>
        <group>
          <name>Templates</name>
        </group>
      </groups>
      <items>
      </items>
      <discovery_rules>
      </discovery_rules>
      <macros>
        <macro>
          <macro>{`$PDH2ZABBIX_CMD}</macro>
          <value>pdh2zabbix.ps1 -m $Mode -f $FileName -N $TemplateName -G $Hostgroup $PdhCounterSetNames</value>
        </macro>
      </macros>
    </template>
  </templates>
</zabbix_export>
"
    return $xml
}

function createZabbixApplicationXml ([string]$applicationName) {
    [xml]$xml = "<application>
  <name>$applicationName</name>
</application>"
    return $xml
}

function createZabbixItemXml ([string]$application, [string]$name, [string]$description, [int]$delta = 0) {
    
    [xml]$xml = "<item>
  <name>$name</name>
  <type>0</type>
  <snmp_community/>
  <multiplier>0</multiplier>
  <snmp_oid/>
  <key>perf_counter[&quot;\$application\$name&quot;]</key>
  <delay>$CheckDelay</delay>
  <history>$KeepHistory</history>
  <trends>$KeepTrends</trends>
  <status>$([byte]!$EnableItems)</status>
  <value_type>0</value_type>
  <allowed_hosts/>
  <units/>
  <delta>$delta</delta>
  <snmpv3_contextname/>
  <snmpv3_securityname/>
  <snmpv3_securitylevel>0</snmpv3_securitylevel>
  <snmpv3_authprotocol>0</snmpv3_authprotocol>
  <snmpv3_authpassphrase/>
  <snmpv3_privprotocol>0</snmpv3_privprotocol>
  <snmpv3_privpassphrase/>
  <formula>1</formula>
  <delay_flex/>
  <params/>
  <ipmi_sensor/>
  <data_type>0</data_type>
  <authtype>0</authtype>
  <username/>
  <password/>
  <publickey/>
  <privatekey/>
  <port/>
  <description>$description</description>
  <inventory_link>0</inventory_link>
  <applications>
    <application>
      <name>$application</name>
    </application>
  </applications>
  <valuemap/>
  <logtimefmt/>
</item>"
    return $xml
}

function createZabbixDiscoveryRuleXml ([string]$application, [string]$description) {
    [xml]$xml = "<discovery_rule>
  <name>$application Discovery</name>
  <type>0</type>
  <snmp_community/>
  <snmp_oid/>
  <key>pdh2zbx.discovery[`"$application`"]</key>
  <delay>$DiscoveryDelay</delay>
  <status>$([byte]!$EnableItems)</status>
  <allowed_hosts/>
  <snmpv3_contextname/>
  <snmpv3_securityname/>
  <snmpv3_securitylevel>0</snmpv3_securitylevel>
  <snmpv3_authprotocol>0</snmpv3_authprotocol>
  <snmpv3_authpassphrase/>
  <snmpv3_privprotocol>0</snmpv3_privprotocol>
  <snmpv3_privpassphrase/>
  <delay_flex/>
  <params/>
  <ipmi_sensor/>
  <authtype>0</authtype>
  <username/>
  <password/>
  <publickey/>
  <privatekey/>
  <port/>
  <filter>
    <evaltype>0</evaltype>
    <formula/>
    <conditions/>
  </filter>
  <lifetime>30</lifetime>
  <description>$description</description>
  <item_prototypes>
  </item_prototypes>
  <trigger_prototypes/>
  <graph_prototypes/>
  <host_prototypes/>
</discovery_rule>
"
    return $xml
}

function createZabbixItemPrototypeXml ([string]$application, [string]$item, [string]$description, [int]$delta = 0) {
    [xml]$xml = "<item_prototype>
  <name>$item ({#PDHINSTANCE})</name>
  <type>0</type>
  <snmp_community/>
  <multiplier>0</multiplier>
  <snmp_oid/>
  <key>perf_counter[`"\$application({#PDHINSTANCE})\$item`"]</key>
  <delay>$CheckDelay</delay>
  <history>$KeepHistory</history>
  <trends>$KeepTrends</trends>
  <status>$([byte]!$EnableItems)</status>
  <value_type>0</value_type>
  <allowed_hosts/>
  <units/>
  <delta>$delta</delta>
  <snmpv3_contextname/>
  <snmpv3_securityname/>
  <snmpv3_securitylevel>0</snmpv3_securitylevel>
  <snmpv3_authprotocol>0</snmpv3_authprotocol>
  <snmpv3_authpassphrase/>
  <snmpv3_privprotocol>0</snmpv3_privprotocol>
  <snmpv3_privpassphrase/>
  <formula>1</formula>
  <delay_flex/>
  <params/>
  <ipmi_sensor/>
  <data_type>0</data_type>
  <authtype>0</authtype>
  <username/>
  <password/>
  <publickey/>
  <privatekey/>
  <port/>
  <description>$description</description>
  <inventory_link>0</inventory_link>
  <applications />
  <valuemap/>
  <logtimefmt/>
  <application_prototypes>
    <application_prototype>
      <name>$application</name>
    </application_prototype>
  </application_prototypes>
</item_prototype>
"
    return $xml
}

switch ($Mode) {
    "discovery" {
        if ($PdhCounterSetNames.Length -eq 1) {
            $pdhCategory = New-Object System.Diagnostics.PerformanceCounterCategory $PdhCounterSetNames[0]
            if ($pdhCategory.CategoryType -eq [System.Diagnostics.PerformanceCounterCategoryType]::MultiInstance) {
                $zbxDiscoveryData = @()
                ForEach ($pdhInstance in $pdhCategory.GetInstanceNames()) {
                    $zbxDiscoveryData += @{"{#PDHINSTANCE}" = $pdhInstance}
                }
                Write-Output $(ConvertTo-Json @{"data" = $ZbxDiscoveryData} -Depth 3)
            }
            else {
                Write-Error "counter set $($pdhCategory.CategoryName) is not discoverable; please use 'MultiInstance' CounterSetTypes only."
                exit 3
            }
            
        }
        else {
            Write-Error "'discovery' mode cannot handle multiple PDH counter sets; please specify only one."
            exit 2
        }
    }
    "template" {
        $templateXml = createZabbixTemplateStub
        $applicationsXmlHook = $templateXml.SelectSingleNode("/zabbix_export/templates/template/applications")
        $itemsXmlHook = $templateXml.SelectSingleNode("/zabbix_export/templates/template/items")
        $discoveryRulesXmlHook = $templateXml.SelectSingleNode("/zabbix_export/templates/template/discovery_rules")
        foreach ($pdhCounterSetName in $PdhCounterSetNames) {
            $pdhCategory = New-Object System.Diagnostics.PerformanceCounterCategory $pdhCounterSetName
            if ([System.Diagnostics.PerformanceCounterCategoryType]::SingleInstance.Equals($pdhCategory.CategoryType)) {
                # create "Application" and "Item" XML fragments:
                $applicationsXmlHook.AppendChild($templateXml.ImportNode((createZabbixApplicationXml $pdhCategory.CategoryName).get_DocumentElement(), $true)) | Out-Null
                foreach ($pdhCounter in $pdhCategory.GetCounters()) {
                    $itemsXmlHook.AppendChild($templateXml.ImportNode((createZabbixItemXml $pdhCounter.CategoryName $pdhCounter.CounterName $pdhCounter.CounterHelp).get_DocumentElement(), $true)) | Out-Null
                }
            }
            elseif ([System.Diagnostics.PerformanceCounterCategoryType]::MultiInstance.Equals($pdhCategory.CategoryType)) {
                # create "<discovery_rule>" and "<item_prototype>" XML fragments:
                $discoveryRuleNode = $templateXml.ImportNode((createZabbixDiscoveryRuleXml $pdhCategory.CategoryName $pdhCategory.CategoryHelp).get_DocumentElement(), $true)
                $discoveryRulesXmlHook.AppendChild($discoveryRuleNode) | Out-Null
                # .NET clusterf*ck: Since we cannot iterate over the generalized
                #     counter objects of a multi-instance category, we always
                #     pick the first instance and use its counters. Of course,
                #     this is a bad idea(tm) and will break on categories
                #     with different counter sets on different instances.
                #     However, this never seems to be the case; as such, we
                #     have to live with this API limitation.
                $counterInstanceNames = $pdhCategory.GetInstanceNames()
                $pdhCounters = $pdhCategory.GetCounters($counterInstanceNames[0])
                foreach ($pdhCounter in $pdhCounters) {
                    $itemPrototypeXmlHook = $discoveryRuleNode.SelectSingleNode("//discovery_rule/item_prototypes")
                    $itemPrototypeXmlHook.AppendChild($templateXml.ImportNode((createZabbixItemPrototypeXml $pdhCounter.CategoryName $pdhCounter.CounterName $pdhCounter.CounterHelp).get_DocumentElement(), $true)) | Out-Null
                }
            }
        }
        
        # provide result as rendered XML
        $sw = New-Object System.IO.StringWriter;
        $xw = New-Object System.Xml.XmlTextWriter $sw;
        $xw.Formatting = "indented";
        $templateXml.WriteTo($xw);
        $xw.Flush();
        $sw.Flush();
        if ($FileName -eq "stdout") {
            Write-Output $sw.ToString()
        }
        else {
            Out-File -FilePath $FileName -InputObject $sw.ToString()
        }
    }
}