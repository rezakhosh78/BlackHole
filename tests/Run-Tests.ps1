Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module (Join-Path $root 'BlackHole.Core.psm1') -Force

$passed = 0
$failed = 0

function Assert-Equal {
    param($Actual, $Expected, [string]$Name)
    if ($Actual -ne $Expected) {
        $script:failed++
        Write-Host "FAIL: $Name`n  expected: $Expected`n  actual:   $Actual" -ForegroundColor Red
    } else {
        $script:passed++
        Write-Host "PASS: $Name" -ForegroundColor Green
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    Assert-Equal $Condition $true $Name
}

Assert-True (Test-Path -LiteralPath (Join-Path $root 'core\desync\cygwin1.dll') -PathType Leaf) `
    'Native runtime DLL is bundled'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'assets\blackhole-loop.mp4') -PathType Leaf) `
    'Animated black-hole background video is bundled'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'README.md') -PathType Leaf) `
    'Bilingual README entrypoint is bundled'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'README_FA.md') -PathType Leaf) `
    'Persian README is bundled'
Assert-True (Test-Path -LiteralPath (Join-Path $root 'README_EN.md') -PathType Leaf) `
    'English README is bundled'

$link = 'vless://11111111-2222-3333-4444-555555555555@old.example.com:443?encryption=none&security=tls&type=ws&host=edge.example.com&sni=edge.example.com&path=%2Fws&fp=chrome#Test'
$config = ConvertFrom-VlessUri -Uri $link
$before = Get-ConfigMetadata $config

Assert-Equal $before.Address 'old.example.com' 'VLESS address parsed'
Assert-Equal $before.Port 443 'VLESS port parsed'
Assert-Equal $before.Sni 'edge.example.com' 'SNI parsed'
Assert-Equal $before.Host 'edge.example.com' 'WS Host parsed'
Assert-Equal $before.Network 'ws' 'Network parsed'
Assert-Equal $config.inbounds[0].listen '0.0.0.0' 'Default SOCKS listener binds to all interfaces'
Assert-Equal $config.inbounds[0].port 1819 'Default SOCKS port is 1819'
Assert-Equal $config.inbounds[1].listen '0.0.0.0' 'Default HTTP listener binds to all interfaces'
Assert-Equal $config.inbounds[1].port 1920 'Default HTTP port is 1920'

$config = Set-GrayAddress -Config $config -Address '104.18.10.10'
$after = Get-ConfigMetadata $config
Assert-Equal $after.Address '104.18.10.10' 'Gray IP replaces address'
Assert-Equal $after.Sni $before.Sni 'Gray IP does not change SNI'
Assert-Equal $after.Host $before.Host 'Gray IP does not change Host'

Assert-True (Test-GrayAddress '104.18.10.10') 'IPv4 accepted'
Assert-True (Test-GrayAddress '2606:4700::6812:a0a') 'IPv6 accepted'
Assert-Equal (Test-GrayAddress 'cloudflare.com') $false 'Hostname rejected as Gray IP'

$existingJson = @'
{
  "inbounds": [
    {"tag":"socks-in","listen":"127.0.0.1","port":9000,"protocol":"socks","settings":{"udp":true}},
    {"tag":"http-in","listen":"127.0.0.1","port":9001,"protocol":"http","settings":{}}
  ],
  "outbounds": [{
    "protocol":"vless",
    "settings":{"vnext":[{"address":"old.example.com","port":443,"users":[{"id":"11111111-2222-3333-4444-555555555555","encryption":"none"}]}]},
    "streamSettings":{"network":"ws","security":"tls","tlsSettings":{"serverName":"edge.example.com"},"wsSettings":{"path":"/ws","headers":{"Host":"edge.example.com"}}},
    "mux":{"enabled":true}
  }]
}
'@
$existing = ConvertFrom-XrayInput $existingJson
$existing = Ensure-LocalInbounds -Config $existing -SocksPort 1819 -HttpPort 1920
$existing = Disable-XrayMux -Config $existing
$socks = @($existing.inbounds | Where-Object { $_.tag -eq 'socks-in' })[0]
$http = @($existing.inbounds | Where-Object { $_.tag -eq 'http-in' })[0]
Assert-Equal $socks.listen '0.0.0.0' 'Existing SOCKS listener updated'
Assert-Equal $socks.port 1819 'Existing SOCKS inbound port updated'
Assert-Equal $http.listen '0.0.0.0' 'Existing HTTP listener updated'
Assert-Equal $http.port 1920 'Existing HTTP inbound port updated'
Assert-Equal $existing.outbounds[0].mux.enabled $false 'Mux disabled'

$profiles = Get-DesyncProfiles
Assert-Equal $profiles['Speed - Light split'].Advanced.SplitMode 'multisplit' 'Speed UI method mapped'
Assert-Equal $profiles['Speed - Light split'].Advanced.SplitPositions 'midsld' 'Speed split position mapped'
Assert-Equal $profiles['Speed - Light split'].Advanced.Fooling 'none' 'Speed disables Fake'
Assert-Equal $profiles['Balanced - BadSeq'].Advanced.Fooling 'badseq' 'Balanced BadSeq mapped'
Assert-Equal $profiles['Balanced - BadSeq'].Advanced.BadSequence -10000 'Balanced BadSeq value mapped'
Assert-Equal $profiles['Severe filtering - BadSeq'].Advanced.SplitMode 'multidisorder' 'Severe BadSeq method mapped'
Assert-Equal $profiles['Severe filtering - BadSeq'].Advanced.SplitPositions '1,sniext+1,midsld' 'Severe BadSeq positions mapped'
Assert-Equal $profiles['Severe filtering - BadSeq'].Advanced.Repeats 2 'Severe BadSeq repeats mapped'
Assert-Equal $profiles['SNI spoof - WrongSeq'].Advanced.Fooling 'badseq' 'SNI spoof uses BadSeq'
Assert-Equal $profiles['SNI spoof - WrongSeq'].Advanced.BadSequence -100000 'SNI spoof uses stronger wrong sequence'
Assert-Equal $profiles['Balanced - BadSeq'].Advanced.FakeSni '' 'Default Fake SNI stays empty'
Assert-Equal $profiles['SNI spoof - WrongSeq'].Advanced.FakeSni 'hcaptcha.com' 'SNI spoof Fake SNI preset mapped'
Assert-Equal $profiles['Severe filtering - AutoTTL'].Advanced.SplitMode 'multidisorder' 'AutoTTL UI method mapped'
Assert-Equal $profiles['Severe filtering - AutoTTL'].Advanced.Fooling 'ttl' 'AutoTTL UI fooling mapped'
Assert-Equal $profiles['Severe filtering - AutoTTL'].Advanced.AutoTtlDelta 2 'AutoTTL UI delta mapped'
Assert-Equal $profiles['Custom'].Advanced $null 'Custom profile preserves UI values'

$badSeqArgs = New-Winws2ArgumentList -Profile badseq `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua'
$badSeqText = Join-CommandPreview $badSeqArgs
Assert-True ($badSeqText.Contains('--wf-tcp-out=443')) 'Outgoing TLS interception enabled'
Assert-True ($badSeqText.Contains('--ipset=ips.txt')) 'Gray IP scope emitted'
Assert-True ($badSeqText.Contains('--out-range=-d10')) 'Desync limited to initial packets'
Assert-True ($badSeqText.Contains('tcp_seq=-10000')) 'BadSeq emitted'
Assert-True ($badSeqText.Contains('multisplit:pos=1,midsld')) 'Multisplit emitted'

$ttlArgs = New-Winws2ArgumentList -Profile autottl `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua'
$ttlText = Join-CommandPreview $ttlArgs
Assert-True ($ttlText.Contains('--wf-tcp-in=443')) 'Incoming packets included for AutoTTL'
Assert-True ($ttlText.Contains('ip_autottl=-2,3-20')) 'IPv4 AutoTTL syntax emitted'
Assert-True ($ttlText.Contains('ip6_autottl=-2,3-20')) 'IPv6 AutoTTL syntax emitted'
Assert-True ($ttlText.Contains('multidisorder:pos=1,midsld')) 'Multi-disorder emitted'

$sniSpoofArgs = New-Winws2ArgumentList -Profile sni_spoof_badseq `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua'
$sniSpoofText = Join-CommandPreview $sniSpoofArgs
Assert-True ($sniSpoofText.Contains('tcp_seq=-100000')) 'SNI spoof WrongSeq emitted'
Assert-True ($sniSpoofText.Contains('tls_mod=rnd,sni=hcaptcha.com,dupsid')) 'SNI spoof Fake SNI emitted'
Assert-True ($sniSpoofText.Contains('multidisorder:pos=1,sniext+1,midsld')) 'SNI spoof split positions emitted'

$customArgs = New-Winws2ArgumentList -Profile custom `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua' `
    -Fooling badsum -SplitMode multidisorder -FakeSni 'cover.example.com'
$customText = Join-CommandPreview $customArgs
Assert-True ($customText.Contains('badsum')) 'Custom badsum emitted'
Assert-True ($customText.Contains('tls_mod=rnd,sni=cover.example.com,dupsid')) 'Custom Fake SNI emitted'
Assert-True ($customText.Contains('multidisorder:pos=1,midsld')) 'Custom split mode emitted'

$profileOverrideArgs = New-Winws2ArgumentList -Profile badseq `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua' `
    -Fooling none -SplitMode multidisorder -SplitPositions '2,midsld'
$profileOverrideText = Join-CommandPreview $profileOverrideArgs
Assert-Equal ($profileOverrideText.Contains('tcp_seq=')) $false `
    'Visible Advanced fooling overrides a named profile command'
Assert-True ($profileOverrideText.Contains('multidisorder:pos=2,midsld')) `
    'Visible Advanced split values reach a named profile command'

$noFakeArgs = New-Winws2ArgumentList -Profile custom `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua' `
    -Fooling none -BadSequence 1 -AutoTtlDelta 0 -AutoTtlMin 255 -AutoTtlMax 1 `
    -Repeats 0 -FakeSni 'not a hostname'
$noFakeText = Join-CommandPreview $noFakeArgs
Assert-Equal ($noFakeText.Contains('fake:blob=')) $false 'Fooling none emits no Fake packet'
Assert-Equal ($noFakeText.Contains('tcp_seq=')) $false 'Bad Sequence ignored outside badseq'
Assert-Equal ($noFakeText.Contains('autottl=')) $false 'AutoTTL values ignored outside ttl'
Assert-Equal ($noFakeText.Contains('not a hostname')) $false 'Fake SNI ignored when Fake is disabled'
Assert-Equal ($noFakeText.Contains('repeats=')) $false 'Repeats ignored when Fake is disabled'

$badSumArgs = New-Winws2ArgumentList -Profile custom `
    -HostListPath 'hosts.txt' -IpSetPath 'ips.txt' `
    -LuaLibraryPath 'engine-lib.lua' -LuaAntiDpiPath 'engine-antidpi.lua' `
    -Fooling badsum -BadSequence 1 -AutoTtlDelta 0 -AutoTtlMin 255 -AutoTtlMax 1
$badSumText = Join-CommandPreview $badSumArgs
Assert-True ($badSumText.Contains(':badsum:')) 'Bad Sequence and AutoTTL validation skipped for badsum'
Assert-Equal ($badSumText.Contains('tcp_seq=')) $false 'Bad Sequence not emitted for badsum'
Assert-Equal ($badSumText.Contains('autottl=')) $false 'AutoTTL not emitted for badsum'

$guiSource = Get-Content (Join-Path $root 'BlackHole.ps1') -Raw
$readmeFa = Get-Content (Join-Path $root 'README_FA.md') -Raw
$readmeEn = Get-Content (Join-Path $root 'README_EN.md') -Raw
$readmeMain = Get-Content (Join-Path $root 'README.md') -Raw
Assert-True ($readmeFa.Contains('🕳️ Black Hole 0.3.3')) `
    'Persian README has emoji title and current version'
Assert-True ($readmeFa.Contains('توضیح گزینه‌های Advanced settings')) `
    'Persian README explains Advanced settings'
Assert-True ($readmeFa.Contains('روش اجرای سریع')) `
    'Persian README explains how to run'
Assert-Equal ($readmeFa.Contains('Powered By ReZa Kh')) $false `
    'Persian README does not document visual footer details'
Assert-Equal ($readmeFa.Contains('پس‌زمینه')) $false `
    'Persian README does not document visual background details'
Assert-True ($readmeEn.Contains('🕳️ Black Hole 0.3.3')) `
    'English README has emoji title and current version'
Assert-True ($readmeEn.Contains('Advanced Settings')) `
    'English README explains Advanced settings'
Assert-True ($readmeEn.Contains('Quick Start')) `
    'English README explains how to run'
Assert-Equal ($readmeEn.Contains('Powered By ReZa Kh')) $false `
    'English README does not document visual footer details'
Assert-Equal ($readmeEn.Contains('background')) $false `
    'English README does not document visual background details'
Assert-True ($readmeMain.Contains('README_FA.md')) `
    'Main README links Persian README'
Assert-True ($readmeMain.Contains('README_EN.md')) `
    'Main README links English README'
Assert-True ($guiSource.Contains('ControlTemplate TargetType="{x:Type ComboBox}"')) `
    'ComboBox uses a complete dark control template'
Assert-True ($guiSource.Contains('Background="#090C18"')) `
    'Dropdown popup has an explicit dark background'
Assert-True ($guiSource.Contains('Text="Black Hole"')) `
    'GUI uses Black Hole branding'
Assert-True ($guiSource.Contains('Text="Powered By ReZa Kh"')) `
    'GUI shows the powered-by footer'
Assert-True ($guiSource.Contains('Foreground="#FFD36A"')) `
    'Powered-by footer uses a gold color'
Assert-True ($guiSource.Contains('RadialGradientBrush')) `
    'GUI uses the black-hole space background'
Assert-True ($guiSource.Contains('AccretionRingOuter')) `
    'GUI includes an animated black-hole accretion ring'
Assert-True ($guiSource.Contains('DoubleAnimation')) `
    'GUI background uses WPF animation instead of a static image'
Assert-True ($guiSource.Contains('x:Name="BlackHoleVideo"')) `
    'GUI contains a black-hole video background layer'
Assert-True ($guiSource.Contains('assets\blackhole-loop.mp4')) `
    'GUI loads the bundled black-hole video'
Assert-True ($guiSource.Contains('Add_MediaEnded')) `
    'Background video loops continuously'
Assert-True ($guiSource.Contains('Opacity="0.58"')) `
    'Background video layer is more visible'
Assert-True ($guiSource.Contains('Opacity="0.62"')) `
    'Dark video overlay is reduced for better visibility'
Assert-True ($guiSource.Contains('<Setter Property="Background" Value="#7310162A"/>')) `
    'Cards use a more transparent glass background'
Assert-True ($guiSource.Contains('Background="#73060814"')) `
    'Main tab card is more transparent'
Assert-True ($guiSource.Contains('Enable-ComboBoxFullClickDropdown')) `
    'ComboBoxes register full-field click-to-open behavior'
Assert-True ($guiSource.Contains('Add_PreviewMouseLeftButtonDown')) `
    'ComboBox clicks are handled across the whole field'
Assert-True ($guiSource.Contains('Test-ClickInsideComboToggle')) `
    'ComboBox arrow clicks are detected separately'
Assert-True ($guiSource.Contains('System.Windows.Controls.Primitives.ToggleButton')) `
    'ComboBox arrow detection checks the ToggleButton ancestor'
Assert-True ($guiSource.Contains('$sender.IsDropDownOpen = $true')) `
    'ComboBox full-field click opens the dropdown'
Assert-True ($guiSource.Contains('ComboBoxItem Content="hcaptcha.com"')) `
    'Fake SNI preset includes hcaptcha.com'
Assert-True ($guiSource.Contains('param($sender, $eventArgs)')) `
    'Profile change handler receives the changed control directly'
Assert-True ($guiSource.Contains('Apply-ProfileToAdvancedSettings -ProfileKey $profileKey')) `
    'Profile change explicitly applies its Advanced values'
Assert-True ($guiSource.Contains('x:Name="SplitPositionsCombo" IsEditable="True"')) `
    'Split positions provides selectable presets and custom input'
Assert-True ($guiSource.Contains('x:Name="FakeSni" IsEditable="True"')) `
    'Fake SNI provides selectable presets and custom input'
Assert-True ($guiSource.Contains('x:Name="PART_EditableTextBox"')) `
    'Editable ComboBox template contains the required editable text part'
Assert-True ($guiSource.Contains('TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"')) `
    'Editable ComboBox displays its selected or typed text'
Assert-True ($guiSource.Contains('Text="{Binding Text, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"')) `
    'Editable ComboBox text stays synchronized with its selected value'
Assert-True ($guiSource.Contains('$ComboBox.Text = $Text')) `
    'Programmatic profile changes explicitly refresh editable ComboBox text'
Assert-True ($guiSource.Contains('Width="36"')) `
    'Dropdown toggle is limited to the arrow area so custom text remains editable'
Assert-True ($guiSource.Contains('Update-AdvancedDependencyState')) `
    'Advanced dependency state is refreshed'
Assert-True ($guiSource.Contains("-Enabled (`$fooling -eq 'badseq')")) `
    'Bad Sequence UI depends on badseq'
Assert-True ($guiSource.Contains("-Enabled (`$fooling -eq 'ttl')")) `
    'AutoTTL UI depends on ttl'
Assert-True ($guiSource.Contains('-Enabled $fakeEnabled')) `
    'Fake SNI and repeats UI depend on Fake'
Assert-True ($guiSource.Contains('Range: -2000000000 to -1')) `
    'Bad Sequence range is shown'
Assert-True ($guiSource.Contains('Range: 1 to 65535')) `
    'Port range is shown'
Assert-True ($guiSource.Contains('$SavedWorkspacePath = Join-Path $RuntimeRoot ''saved-workspace.json''')) `
    'Persistent workspace path is defined'
Assert-True ($guiSource.Contains('function Save-PersistentWorkspace')) `
    'Configuration and settings persistence is implemented'
Assert-True ($guiSource.Contains('function Load-PersistentWorkspace')) `
    'Saved configuration restore is implemented'
Assert-True ($guiSource.Contains('Request-AutoSave')) `
    'Settings changes request automatic save'
Assert-True ($guiSource.Contains('Saved configuration and Gray IP restored.')) `
    'Startup restore completes configuration and Gray IP'
Assert-True ($guiSource.Contains('Read-Utf8Text $SavedWorkspacePath')) `
    'Saved configuration is restored with explicit UTF-8 decoding'

$stopSource = Get-Content (Join-Path $root 'Stop-BlackHole.ps1') -Raw
Assert-Equal ($stopSource.Contains('saved-workspace.json')) $false `
    'Emergency stop preserves the saved configuration'
Assert-Equal ($stopSource.Contains('user-settings.json')) $false `
    'Emergency stop preserves saved UI settings'

Write-Host ""
Write-Host "Passed: $passed  Failed: $failed"
if ($failed -gt 0) { exit 1 }
exit 0
