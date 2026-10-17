' hidden.vbs - start a PowerShell script in the user's session without any window (a console window, even one that
' hides itself, takes the focus from the program the user is working in). Used by the logon and redraw tasks.
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & WScript.Arguments(0) & """", 0, False
