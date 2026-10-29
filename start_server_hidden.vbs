' รัน server แบบซ่อนหน้าต่าง (ใช้กับโฟลเดอร์ Startup ของ Windows)
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
sh.Run "cmd /c node server.js >> server.log 2>&1", 0, False
