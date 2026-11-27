# Cài tự chạy khi đăng nhập Windows:  .\install.ps1
# Gỡ:                                .\install.ps1 -Uninstall
param([switch]$Uninstall)

$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'ChamCongTray.lnk'
if ($Uninstall) {
    if (Test-Path $lnk) { Remove-Item $lnk -Confirm:$false }
    Write-Output 'Đã gỡ khỏi Startup. Thoát tool bằng menu chuột phải ở khay hệ thống.'
    return
}

$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = 'wscript.exe'
$sc.Arguments = '"' + (Join-Path $PSScriptRoot 'ChamCongTray.vbs') + '"'
$sc.WorkingDirectory = $PSScriptRoot
$sc.Save()
Write-Output "Đã thêm vào Startup: $lnk"
Start-Process wscript.exe -ArgumentList ('"' + (Join-Path $PSScriptRoot 'ChamCongTray.vbs') + '"')
Write-Output 'Tool đã chạy - xem icon đồng hồ xanh ở khay hệ thống (góc phải taskbar).'
