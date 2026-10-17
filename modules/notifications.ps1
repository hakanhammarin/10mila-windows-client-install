# notifications.ps1 - no Windows notifications on the event laptops: no toasts or banners from apps, no notification
# center, no tips, suggestions or "finish setting up" nags, no Windows Security or Windows Update pop-ups.
# The tray icons stay as they are.
Step 'Notifications off'
$pn = 'Software\Microsoft\Windows\CurrentVersion\PushNotifications'
Set-UserValue $pn ToastEnabled 0                                                                   # Settings > Notifications off
Set-UserValue 'Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' NoToastApplicationNotification 1
Set-UserValue 'Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' NoTileApplicationNotification 1
Set-UserValue 'Software\Policies\Microsoft\Windows\Explorer' DisableNotificationCenter 1
$cdm = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'                      # tips and suggestions
foreach ($n in 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-310093Enabled',
               'SubscribedContent-338388Enabled', 'SubscribedContent-353698Enabled') { Set-UserValue $cdm $n 0 }
Set-UserValue 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0   # "finish setting up your device"
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' DisableSoftLanding 1
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' DisableWindowsConsumerFeatures 1
$wsc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'
Set-Value $wsc DisableNotifications 1; Set-Value $wsc DisableEnhancedNotifications 1
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' SetUpdateNotificationLevel 2   # no update pop-ups
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' UpdateNotificationLevel 2
Add-Check { @('Windows notifications off', ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' -ErrorAction SilentlyContinue).DisableNotifications -eq 1 -and
  (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -ErrorAction SilentlyContinue).ToastEnabled -eq 0)) }
