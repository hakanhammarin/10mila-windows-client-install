# edge.ps1 - Edge that starts without questions (also after "Rensa profil"), on a local start page with the event's graphics
# and buttons for the sites the crew needs. All as machine policy, so a cleared profile gets it again.
Step 'Edge: no first-run questions, local start page'
$start = "$Data\start"; New-Item -ItemType Directory -Force $start | Out-Null
$links = @(@('Google', 'https://www.google.se', 'general'), @('Eventor', 'https://eventor.orientering.se', 'general'))
if ($Setup -eq 'oringen') {
  $links += @(@('Gmail', 'https://mail.google.com'), @('O-Ringen', 'https://www.oringen.se'), @('Resultat', 'https://resultat.oringen.se'))
  if (Test-Path 'C:\bgi\o_ringen_cover.jpg') { Copy-Item -Force 'C:\bgi\o_ringen_cover.jpg' "$start\bg.jpg" }
  $v = @{ TITLE = 'O-Ringen'; BG = '#f5f4f2'; IMAGE = 'bg.jpg'; IMGPOS = '35%'; IMGSIZE = '100% auto'; ACCENT = '#d4145a' }
} else {
  $links += @(@('10MILA', 'https://10mila.se'), @('10MILA online', 'https://online.10mila.se'))
  Get-File "$BaseUrl/files/10mila-logo.png" "$start\bg.png" | Out-Null
  $v = @{ TITLE = '10MILA'; BG = '#bebebe'; IMAGE = 'bg.png'; IMGPOS = '30%'; IMGSIZE = 'auto 45vh'; ACCENT = '#008a4b' }
}
$v.COMPUTER = $env:COMPUTERNAME
$v.LINKS = ($links | ForEach-Object { $cls = if ($_[2]) { ' class="general"' } else { '' }; '    <a href="{0}"{1}>{2}</a>' -f $_[1], $cls, $_[0] }) -join "`n"
$html = (Get-Content -Raw (Get-File "$BaseUrl/files/start.html" "$Tmp\start.html") -Encoding UTF8)
foreach ($k in $v.Keys) { $html = $html.Replace("@$k@", $v[$k]) }
[IO.File]::WriteAllText("$start\index.html", $html)
$url = 'file:///' + ("$start\index.html" -replace '\\', '/')
$e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
foreach ($p in @(@('HideFirstRunExperience', 1), @('AutoImportAtFirstRun', 4), @('ImportOnEachLaunch', 0), @('BrowserSignin', 0), @('SyncDisabled', 1),
                 @('DefaultBrowserSettingEnabled', 0), @('PromotionalTabsEnabled', 0), @('ShowRecommendationsEnabled', 0), @('SpotlightExperiencesAndRecommendationsEnabled', 0),
                 @('PersonalizationReportingEnabled', 0), @('EdgeShoppingAssistantEnabled', 0), @('ShowMicrosoftRewards', 0), @('HubsSidebarEnabled', 0),
                 @('Microsoft365CopilotChatIconEnabled', 0), @('CopilotPageContext', 0), @('EdgeFollowEnabled', 0), @('StartupBoostEnabled', 0), @('BackgroundModeEnabled', 0),
                 @('NewTabPageContentEnabled', 0), @('NewTabPageQuickLinksEnabled', 0), @('NewTabPageHideDefaultTopSites', 1), @('NewTabPageAllowedBackgroundTypes', 3),
                 @('UserFeedbackAllowed', 0), @('DiagnosticData', 0), @('ConfigureDoNotTrack', 1), @('PasswordManagerEnabled', 0), @('AutofillAddressEnabled', 0), @('AutofillCreditCardEnabled', 0),
                 @('ShowHomeButton', 1), @('RestoreOnStartup', 4))) {
  Set-Value $e $p[0] $p[1]
}
Set-Value $e HomepageLocation $url 'String'
Set-Value $e NewTabPageLocation $url 'String'
Set-Value "$e\RestoreOnStartupURLs" '1' $url 'String'
# Edge updates put "Microsoft Edge" back on the desktop: not on these desktops (Edge is on the start page and the taskbar).
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'CreateDesktopShortcutDefault' 0
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'CreateDesktopShortcut{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' 0
Remove-Item "$env:PUBLIC\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
Add-Check { @("Edge starts on $url without questions", ((Test-Path "$start\index.html") -and (Get-ItemProperty $e -ErrorAction SilentlyContinue).HideFirstRunExperience -eq 1)) }
