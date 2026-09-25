' ============================================================
'  workbuddy2api-panel  -  Startup folder autostart shim
'
'  Installed into your Startup folder by autostart.cmd
'  (option 3). Runs silently at every logon, no admin needed.
'
'  To disable autostart: delete this file from
'    %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
'
'  If you ever move the project folder, update PANEL_DIR below.
' ============================================================

Option Explicit

Dim PANEL_DIR
PANEL_DIR = "D:\CodeData\workbuddy2api-panel"

Dim sh, fso, exe
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

exe = PANEL_DIR & "\wb2api.exe"

' Nothing to start - bail out quietly rather than showing an error
' at logon.
If Not fso.FileExists(exe) Then
    WScript.Quit 0
End If

' Already listening (e.g. started manually) -> do not start a
' second instance, it would only fail to bind the port.
If PortListening() Then
    WScript.Quit 0
End If

sh.CurrentDirectory = PANEL_DIR
sh.Run """" & PANEL_DIR & "\run-wb2api.cmd""", 0, False

WScript.Quit 0


' --- is something LISTENING on 7863? -------------------------------
Function PortListening()
    Dim e, out
    PortListening = False
    On Error Resume Next
    Set e = sh.Exec("%comspec% /c netstat -ano | findstr LISTENING | findstr 7863")
    out = e.StdOut.ReadAll()
    If InStr(1, out, "LISTENING", vbTextCompare) > 0 Then PortListening = True
    On Error GoTo 0
End Function
