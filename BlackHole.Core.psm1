Set-StrictMode -Version Latest

function Get-OptionalProperty {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()]$Value
    )
    if ($InputObject -is [System.Collections.IDictionary]) {
        $InputObject[$Name] = $Value
        return
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $property.Value = $Value
    }
}

function ConvertFrom-UrlEncodedValue {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Uri]::UnescapeDataString(($Value -replace '\+', ' '))
}

function ConvertFrom-QueryString {
    param([AllowNull()][string]$Query)
    $result = @{}
    if ([string]::IsNullOrWhiteSpace($Query)) { return $result }
    foreach ($pair in $Query.TrimStart('?').Split('&')) {
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }
        $parts = $pair.Split('=', 2)
        $key = ConvertFrom-UrlEncodedValue $parts[0]
        $value = if ($parts.Count -gt 1) { ConvertFrom-UrlEncodedValue $parts[1] } else { "" }
        $result[$key] = $value
    }
    return $result
}

function ConvertFrom-VlessUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [int]$SocksPort = 1819,
        [int]$HttpPort = 1920
    )

    $trimmed = $Uri.Trim()
    if (-not $trimmed.StartsWith('vless://', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Only vless:// links are accepted in link mode."
    }

    $withoutScheme = $trimmed.Substring(8)
    $fragmentIndex = $withoutScheme.IndexOf('#')
    $name = "Imported VLESS"
    if ($fragmentIndex -ge 0) {
        $name = ConvertFrom-UrlEncodedValue $withoutScheme.Substring($fragmentIndex + 1)
        $withoutScheme = $withoutScheme.Substring(0, $fragmentIndex)
    }

    $queryIndex = $withoutScheme.IndexOf('?')
    $query = @{}
    if ($queryIndex -ge 0) {
        $query = ConvertFrom-QueryString $withoutScheme.Substring($queryIndex + 1)
        $withoutScheme = $withoutScheme.Substring(0, $queryIndex)
    }

    $atIndex = $withoutScheme.LastIndexOf('@')
    if ($atIndex -lt 1) { throw "The VLESS link does not contain a UUID and server address." }
    $uuid = ConvertFrom-UrlEncodedValue $withoutScheme.Substring(0, $atIndex)
    $endpoint = $withoutScheme.Substring($atIndex + 1)

    $address = ""
    $port = 443
    if ($endpoint.StartsWith('[')) {
        $closing = $endpoint.IndexOf(']')
        if ($closing -lt 2) { throw "Invalid IPv6 endpoint." }
        $address = $endpoint.Substring(1, $closing - 1)
        if ($endpoint.Length -gt ($closing + 2)) {
            $port = [int]$endpoint.Substring($closing + 2)
        }
    } else {
        $colon = $endpoint.LastIndexOf(':')
        if ($colon -gt 0) {
            $address = ConvertFrom-UrlEncodedValue $endpoint.Substring(0, $colon)
            $port = [int]$endpoint.Substring($colon + 1)
        } else {
            $address = ConvertFrom-UrlEncodedValue $endpoint
        }
    }

    if ([string]::IsNullOrWhiteSpace($address)) { throw "Server address is empty." }
    if ($port -lt 1 -or $port -gt 65535) { throw "Server port is out of range." }
    if ($uuid -notmatch '^[0-9a-fA-F-]{32,36}$') { throw "The VLESS UUID is not valid." }

    $network = if ($query.ContainsKey('type') -and $query['type']) { $query['type'] } else { 'ws' }
    $security = if ($query.ContainsKey('security') -and $query['security']) { $query['security'] } else { 'tls' }
    $host = if ($query.ContainsKey('host')) { $query['host'] } else { "" }
    $sni = if ($query.ContainsKey('sni')) { $query['sni'] } else { $host }
    if ([string]::IsNullOrWhiteSpace($sni)) { $sni = $address }
    $path = if ($query.ContainsKey('path') -and $query['path']) { $query['path'] } else { '/' }
    $fingerprint = if ($query.ContainsKey('fp') -and $query['fp']) { $query['fp'] } else { 'chrome' }
    $flow = if ($query.ContainsKey('flow')) { $query['flow'] } else { "" }
    $allowInsecure = $false
    if ($query.ContainsKey('allowInsecure')) {
        $allowInsecure = $query['allowInsecure'] -in @('1', 'true', 'True')
    }

    $user = [ordered]@{
        id = $uuid
        encryption = if ($query.ContainsKey('encryption') -and $query['encryption']) { $query['encryption'] } else { 'none' }
    }
    if (-not [string]::IsNullOrWhiteSpace($flow)) { $user.flow = $flow }

    $streamSettings = [ordered]@{
        network = $network
        security = $security
    }

    if ($security -eq 'tls') {
        $streamSettings.tlsSettings = [ordered]@{
            serverName = $sni
            allowInsecure = $allowInsecure
            fingerprint = $fingerprint
        }
    }

    if ($network -eq 'ws') {
        $streamSettings.wsSettings = [ordered]@{
            path = $path
            headers = [ordered]@{ Host = $host }
        }
    } elseif ($network -eq 'xhttp' -or $network -eq 'splithttp') {
        $streamSettings.xhttpSettings = [ordered]@{
            path = $path
            host = $host
            mode = if ($query.ContainsKey('mode')) { $query['mode'] } else { 'auto' }
        }
    }

    return [ordered]@{
        log = [ordered]@{ loglevel = 'warning' }
        inbounds = @(
            [ordered]@{
                tag = 'socks-in'
                listen = '0.0.0.0'
                port = $SocksPort
                protocol = 'socks'
                settings = [ordered]@{ udp = $true }
            },
            [ordered]@{
                tag = 'http-in'
                listen = '0.0.0.0'
                port = $HttpPort
                protocol = 'http'
                settings = [ordered]@{}
            }
        )
        outbounds = @(
            [ordered]@{
                tag = 'proxy'
                protocol = 'vless'
                settings = [ordered]@{
                    vnext = @(
                        [ordered]@{
                            address = $address
                            port = $port
                            users = @($user)
                        }
                    )
                }
                streamSettings = $streamSettings
                mux = [ordered]@{ enabled = $false }
            },
            [ordered]@{
                tag = 'direct'
                protocol = 'freedom'
                settings = [ordered]@{}
            }
        )
    }
}

function ConvertFrom-XrayInput {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    $trimmed = $Text.Trim()
    if ($trimmed.StartsWith('vless://', [System.StringComparison]::OrdinalIgnoreCase)) {
        return ConvertFrom-VlessUri -Uri $trimmed
    }
    try {
        $config = $trimmed | ConvertFrom-Json
    } catch {
        throw "Input is neither a valid vless:// link nor valid Xray JSON."
    }
    if ($null -eq (Get-OptionalProperty $config 'outbounds')) { throw "Xray JSON has no outbounds array." }
    return $config
}

function Get-VlessOutbound {
    param([Parameter(Mandatory)]$Config)
    $outbounds = Get-OptionalProperty $Config 'outbounds'
    foreach ($outbound in @($outbounds)) {
        $protocol = Get-OptionalProperty $outbound 'protocol'
        $settings = Get-OptionalProperty $outbound 'settings'
        $vnext = Get-OptionalProperty $settings 'vnext'
        if ($protocol -eq 'vless' -and $null -ne $vnext -and @($vnext).Count -gt 0) {
            return $outbound
        }
    }
    throw "No VLESS outbound with settings.vnext was found."
}

function Get-ConfigMetadata {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Config)
    $outbound = Get-VlessOutbound $Config
    $settings = Get-OptionalProperty $outbound 'settings'
    $server = @((Get-OptionalProperty $settings 'vnext'))[0]
    $stream = Get-OptionalProperty $outbound 'streamSettings'
    $sni = ""
    $host = ""
    if ($null -ne $stream) {
        $tlsSettings = Get-OptionalProperty $stream 'tlsSettings'
        $serverName = Get-OptionalProperty $tlsSettings 'serverName'
        if ($null -ne $serverName) {
            $sni = [string]$serverName
        }
        $wsSettings = Get-OptionalProperty $stream 'wsSettings'
        $headers = Get-OptionalProperty $wsSettings 'headers'
        $hostValue = Get-OptionalProperty $headers 'Host'
        if ($null -ne $hostValue) {
            $host = [string]$hostValue
        }
        $xhttpSettings = Get-OptionalProperty $stream 'xhttpSettings'
        $xhttpHost = Get-OptionalProperty $xhttpSettings 'host'
        if ([string]::IsNullOrWhiteSpace($host) -and $null -ne $xhttpHost) {
            $host = [string]$xhttpHost
        }
    }
    if ([string]::IsNullOrWhiteSpace($sni)) { $sni = $host }
    if ([string]::IsNullOrWhiteSpace($host)) { $host = $sni }
    return [pscustomobject]@{
        Address = [string](Get-OptionalProperty $server 'address')
        Port = [int](Get-OptionalProperty $server 'port')
        Sni = $sni
        Host = $host
        Network = [string](Get-OptionalProperty $stream 'network')
        Security = [string](Get-OptionalProperty $stream 'security')
    }
}

function Test-GrayAddress {
    param([Parameter(Mandatory)][string]$Address)
    $candidate = $Address.Trim()
    $parsed = $null
    return [System.Net.IPAddress]::TryParse($candidate, [ref]$parsed)
}

function Set-GrayAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Address
    )
    if (-not (Test-GrayAddress $Address)) {
        throw "Gray IP/address is invalid."
    }
    $outbound = Get-VlessOutbound $Config
    $settings = Get-OptionalProperty $outbound 'settings'
    $server = @((Get-OptionalProperty $settings 'vnext'))[0]
    Set-ObjectProperty -InputObject $server -Name 'address' -Value $Address.Trim()
    return $Config
}

function Ensure-LocalInbounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Config,
        [int]$SocksPort = 1819,
        [int]$HttpPort = 1920
    )
    $currentInbounds = Get-OptionalProperty $Config 'inbounds'
    if ($SocksPort -lt 1 -or $SocksPort -gt 65535) { throw "SOCKS port is out of range." }
    if ($HttpPort -lt 1 -or $HttpPort -gt 65535) { throw "HTTP port is out of range." }
    if ($SocksPort -eq $HttpPort) { throw "SOCKS and HTTP ports must be different." }
    if ($null -eq $currentInbounds) {
        Set-ObjectProperty -InputObject $Config -Name 'inbounds' -Value @()
    }
    $inbounds = @((Get-OptionalProperty $Config 'inbounds'))
    $socksInbound = $inbounds | Where-Object {
        (Get-OptionalProperty $_ 'tag') -eq 'socks-in' -or
        ((Get-OptionalProperty $_ 'protocol') -eq 'socks' -and
         (Get-OptionalProperty $_ 'listen') -in @($null, '', '0.0.0.0', '127.0.0.1', 'localhost'))
    } | Select-Object -First 1
    $httpInbound = $inbounds | Where-Object {
        (Get-OptionalProperty $_ 'tag') -eq 'http-in' -or
        ((Get-OptionalProperty $_ 'protocol') -eq 'http' -and
         (Get-OptionalProperty $_ 'listen') -in @($null, '', '0.0.0.0', '127.0.0.1', 'localhost'))
    } | Select-Object -First 1
    if ($null -eq $socksInbound) {
        $inbounds += [pscustomobject]@{
            tag = 'socks-in'; listen = '0.0.0.0'; port = $SocksPort
            protocol = 'socks'; settings = [pscustomobject]@{ udp = $true }
        }
    } else {
        Set-ObjectProperty -InputObject $socksInbound -Name 'tag' -Value 'socks-in'
        Set-ObjectProperty -InputObject $socksInbound -Name 'listen' -Value '0.0.0.0'
        Set-ObjectProperty -InputObject $socksInbound -Name 'port' -Value $SocksPort
    }
    if ($null -eq $httpInbound) {
        $inbounds += [pscustomobject]@{
            tag = 'http-in'; listen = '0.0.0.0'; port = $HttpPort
            protocol = 'http'; settings = [pscustomobject]@{}
        }
    } else {
        Set-ObjectProperty -InputObject $httpInbound -Name 'tag' -Value 'http-in'
        Set-ObjectProperty -InputObject $httpInbound -Name 'listen' -Value '0.0.0.0'
        Set-ObjectProperty -InputObject $httpInbound -Name 'port' -Value $HttpPort
    }
    Set-ObjectProperty -InputObject $Config -Name 'inbounds' -Value $inbounds
    return $Config
}

function Disable-XrayMux {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Config)
    $outbound = Get-VlessOutbound $Config
    $mux = Get-OptionalProperty $outbound 'mux'
    if ($null -eq $mux) {
        $mux = [pscustomobject]@{ enabled = $false }
        Set-ObjectProperty -InputObject $outbound -Name 'mux' -Value $mux
    } else {
        Set-ObjectProperty -InputObject $mux -Name 'enabled' -Value $false
    }
    return $Config
}

function Get-DesyncProfiles {
    return [ordered]@{
        'Off (normal connection)' = [ordered]@{
            Enabled = $false
            Strategy = 'off'
            Description = 'Runs Xray without packet manipulation.'
            Advanced = [ordered]@{
                SplitMode = 'multisplit'
                SplitPositions = '1,midsld'
                Fooling = 'none'
                BadSequence = -10000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 1
                FakeSni = ''
            }
        }
        'Speed - Light split' = [ordered]@{
            Enabled = $true
            Strategy = 'split'
            Description = 'Lowest-overhead Desync preset: ordered split at the middle of SNI, without Fake packets.'
            Advanced = [ordered]@{
                SplitMode = 'multisplit'
                SplitPositions = 'midsld'
                Fooling = 'none'
                BadSequence = -10000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 1
                FakeSni = ''
            }
        }
        'Balanced - BadSeq' = [ordered]@{
            Enabled = $true
            Strategy = 'badseq'
            Description = 'Daily-use preset: one Fake TLS packet with BadSeq plus an ordered multi-split.'
            Advanced = [ordered]@{
                SplitMode = 'multisplit'
                SplitPositions = '1,midsld'
                Fooling = 'badseq'
                BadSequence = -10000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 1
                FakeSni = ''
            }
        }
        'Severe filtering - BadSeq' = [ordered]@{
            Enabled = $true
            Strategy = 'severe_badseq'
            Description = 'Aggressive preset: reversed real TLS parts and two BadSeq Fake packets.'
            Advanced = [ordered]@{
                SplitMode = 'multidisorder'
                SplitPositions = '1,sniext+1,midsld'
                Fooling = 'badseq'
                BadSequence = -10000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 2
                FakeSni = ''
            }
        }
        'SNI spoof - WrongSeq' = [ordered]@{
            Enabled = $true
            Strategy = 'sni_spoof_badseq'
            Description = 'Inspired by SNI-Spoofing: sends a controlled Fake SNI with a stronger wrong TCP sequence, while the real Xray SNI and Host stay unchanged.'
            Advanced = [ordered]@{
                SplitMode = 'multidisorder'
                SplitPositions = '1,sniext+1,midsld'
                Fooling = 'badseq'
                BadSequence = -100000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 2
                FakeSni = 'hcaptcha.com'
            }
        }
        'Severe filtering - AutoTTL' = [ordered]@{
            Enabled = $true
            Strategy = 'autottl'
            Description = 'Aggressive route-dependent preset: AutoTTL Fake packets plus reversed real TLS parts.'
            Advanced = [ordered]@{
                SplitMode = 'multidisorder'
                SplitPositions = '1,midsld'
                Fooling = 'ttl'
                BadSequence = -10000
                AutoTtlDelta = 2
                AutoTtlMin = 3
                AutoTtlMax = 20
                Repeats = 1
                FakeSni = ''
            }
        }
        'Custom' = [ordered]@{
            Enabled = $true
            Strategy = 'custom'
            Description = 'Uses the values from Advanced settings without profile overrides.'
            Advanced = $null
        }
    }
}

function New-Winws2ArgumentList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('split','badseq','severe_badseq','sni_spoof_badseq','autottl','custom')]
        [string]$Profile,
        [Parameter(Mandatory)][string]$HostListPath,
        [Parameter(Mandatory)][string]$IpSetPath,
        [Parameter(Mandatory)][string]$LuaLibraryPath,
        [Parameter(Mandatory)][string]$LuaAntiDpiPath,
        [int]$Port = 443,
        [ValidateSet('multisplit','multidisorder')][string]$SplitMode = 'multidisorder',
        [string]$SplitPositions = '1,midsld',
        [ValidateSet('none','badseq','badsum','md5sig','ttl')][string]$Fooling = 'badseq',
        [int]$BadSequence = -10000,
        [int]$AutoTtlDelta = 2,
        [int]$AutoTtlMin = 3,
        [int]$AutoTtlMax = 20,
        [int]$Repeats = 1,
        [string]$FakeSni = ''
    )

    # Keep the public profile defaults for direct/core callers, but honor every
    # explicitly supplied Advanced-settings value. The GUI supplies all of
    # these parameters, so the command preview and the launched process always
    # use exactly what is visible in Advanced settings.
    switch ($Profile) {
        'split' {
            if (-not $PSBoundParameters.ContainsKey('SplitMode')) { $SplitMode = 'multisplit' }
            if (-not $PSBoundParameters.ContainsKey('Fooling')) { $Fooling = 'none' }
        }
        'badseq' {
            if (-not $PSBoundParameters.ContainsKey('SplitMode')) { $SplitMode = 'multisplit' }
            if (-not $PSBoundParameters.ContainsKey('Fooling')) { $Fooling = 'badseq' }
        }
        'severe_badseq' {
            if (-not $PSBoundParameters.ContainsKey('SplitMode')) { $SplitMode = 'multidisorder' }
            if (-not $PSBoundParameters.ContainsKey('SplitPositions')) { $SplitPositions = '1,sniext+1,midsld' }
            if (-not $PSBoundParameters.ContainsKey('Fooling')) { $Fooling = 'badseq' }
            if (-not $PSBoundParameters.ContainsKey('Repeats')) { $Repeats = 2 }
        }
        'sni_spoof_badseq' {
            if (-not $PSBoundParameters.ContainsKey('SplitMode')) { $SplitMode = 'multidisorder' }
            if (-not $PSBoundParameters.ContainsKey('SplitPositions')) { $SplitPositions = '1,sniext+1,midsld' }
            if (-not $PSBoundParameters.ContainsKey('Fooling')) { $Fooling = 'badseq' }
            if (-not $PSBoundParameters.ContainsKey('BadSequence')) { $BadSequence = -100000 }
            if (-not $PSBoundParameters.ContainsKey('Repeats')) { $Repeats = 2 }
            if (-not $PSBoundParameters.ContainsKey('FakeSni')) { $FakeSni = 'hcaptcha.com' }
        }
        'autottl' {
            if (-not $PSBoundParameters.ContainsKey('SplitMode')) { $SplitMode = 'multidisorder' }
            if (-not $PSBoundParameters.ContainsKey('Fooling')) { $Fooling = 'ttl' }
        }
    }

    if ($Port -lt 1 -or $Port -gt 65535) { throw "Port is out of range." }
    if ($SplitPositions -notmatch '^[a-zA-Z0-9,+-]+$') { throw "Split positions contain unsafe characters." }
    $fakeEnabled = $Fooling -ne 'none'
    if ($Fooling -eq 'badseq' -and
        ($BadSequence -gt -1 -or $BadSequence -lt -2000000000)) {
        throw "Bad sequence increment must be negative."
    }
    if ($Fooling -eq 'ttl') {
        if ($AutoTtlDelta -lt 1 -or $AutoTtlDelta -gt 10) {
            throw "AutoTTL delta must be between 1 and 10."
        }
        if ($AutoTtlMin -lt 1 -or $AutoTtlMax -gt 255 -or $AutoTtlMin -gt $AutoTtlMax) {
            throw "AutoTTL range is invalid."
        }
    }
    if ($fakeEnabled -and ($Repeats -lt 1 -or $Repeats -gt 10)) {
        throw "Repeats must be between 1 and 10."
    }
    if ($fakeEnabled -and -not [string]::IsNullOrWhiteSpace($FakeSni) -and
        $FakeSni -notmatch '^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$') {
        throw "Fake SNI is not a valid hostname."
    }

    $argumentList = @(
        "--wf-tcp-out=$Port",
        "--lua-init=@$LuaLibraryPath",
        "--lua-init=@$LuaAntiDpiPath",
        "--filter-tcp=$Port",
        '--filter-l7=tls',
        "--hostlist=$HostListPath",
        "--ipset=$IpSetPath",
        '--out-range=-d10',
        '--payload=tls_client_hello'
    )

    if ($Fooling -eq 'none') {
        $argumentList += "--lua-desync=$SplitMode`:pos=$SplitPositions"
    } else {
        $tlsMod = if ([string]::IsNullOrWhiteSpace($FakeSni)) {
            'rnd,rndsni,dupsid'
        } else {
            "rnd,sni=$FakeSni,dupsid"
        }
        if ($Fooling -eq 'ttl') {
            $argumentList = @("--wf-tcp-in=$Port") + $argumentList
            $argumentList += "--lua-desync=fake:blob=fake_default_tls:ip_autottl=-$AutoTtlDelta,$AutoTtlMin-$AutoTtlMax`:ip6_autottl=-$AutoTtlDelta,$AutoTtlMin-$AutoTtlMax`:tls_mod=$tlsMod`:repeats=$Repeats"
        } else {
            $luaFooling = switch ($Fooling) {
                'badseq' { "tcp_seq=$BadSequence" }
                'badsum' { 'badsum' }
                'md5sig' { 'tcp_md5' }
            }
            $argumentList += "--lua-desync=fake:blob=fake_default_tls:$luaFooling`:tls_mod=$tlsMod`:repeats=$Repeats"
        }
        $argumentList += "--lua-desync=$SplitMode`:pos=$SplitPositions"
    }
    return $argumentList
}

function Join-CommandPreview {
    param([Parameter(Mandatory)][string[]]$Arguments)
    return ($Arguments | ForEach-Object {
        if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
}

Export-ModuleMember -Function @(
    'ConvertFrom-VlessUri',
    'ConvertFrom-XrayInput',
    'Get-ConfigMetadata',
    'Set-GrayAddress',
    'Test-GrayAddress',
    'Ensure-LocalInbounds',
    'Disable-XrayMux',
    'Get-DesyncProfiles',
    'New-Winws2ArgumentList',
    'Join-CommandPreview'
)
