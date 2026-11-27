# Widget chấm công nhỏ ở góc dưới phải màn hình + icon khay hệ thống
# Chạy: wscript ChamCongTray.vbs  (ẩn console)
# Xem trước ra ảnh (không hiện cửa sổ): powershell -STA -File ChamCongTray.ps1 -Preview out.png [-At "14:06"]
param([string]$Preview, [string]$At)

# ===== Cấu hình =====
$Url            = 'https://hxp.f88.vn/hrm/nhan-vien/cham-cong'
$PlaceName      = 'Văn phòng'
$ShiftStart     = '08:30'
$ShiftEnd       = '17:30'
$RemindIn       = '08:50'  # giờ tự hiện widget nhắc chấm công vào
$RemindOut      = '17:20'  # giờ tự hiện widget nhắc chấm công ra
$WorkDays       = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
$WinWidth       = 430      # kích thước cửa sổ trang chấm công
$WinHeight      = 780
# ====================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CcNative {
    [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int l, int t, int r, int b, int w, int h);
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);
}
'@

if (-not $Preview) {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\ChamCongTray')
    if (-not $mutex.WaitOne(0)) { exit }
}

# ----- Tiện ích -----
function Get-Now { if ($At) { (Get-Date).Date + [timespan]::Parse($At) } else { Get-Date } }
function Get-TimeToday([string]$hm) { (Get-Now).Date + [timespan]::Parse($hm) }
function Format-Dur([timespan]$ts) { '{0}:{1:00}' -f [int][Math]::Floor($ts.TotalHours), $ts.Minutes }
function New-Color($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
function New-Font($size, [switch]$Bold) {
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font('Segoe UI', $size, $style)
}

# Tông màu nền xanh teal (kiểu Hàn Quốc), đặc, không mờ
$cBg       = New-Color 15 107 117   # nền teal #0F6B75
$cHeaderBg = New-Color 11 84 92     # dải tiêu đề đậm hơn
$cFg       = New-Color 255 255 255  # chữ chính: trắng
$cMuted    = New-Color 176 219 223  # chữ phụ: teal nhạt
$cTrack    = New-Color 9 72 79      # nền thanh tiến độ
$cOrange   = New-Color 255 196 84   # nhấn vàng (ca ra)
$cGreen    = New-Color 120 232 205  # nhấn xanh sáng (ca vào)
$cBtn      = New-Color 255 255 255  # nút trắng
$cBtnText  = New-Color 13 92 100    # chữ nút: teal đậm

function Get-BrowserPath {
    @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
$Browser = Get-BrowserPath

# Mở trang chấm công thật (Chrome chế độ app) cạnh widget; chưa đăng nhập thì trang tự chuyển SSO
function Open-ChamCong {
    if (-not $Browser) { Start-Process $Url; return }
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = if ($form.Visible) { $form.Left - $WinWidth - 10 } else { $wa.Right - $WinWidth - 10 }
    $x = [Math]::Max(0, $x)
    $y = [Math]::Max(0, $wa.Bottom - $WinHeight - 10)
    Start-Process $Browser -ArgumentList @("--app=$Url", "--window-size=$WinWidth,$WinHeight", "--window-position=$x,$y")
}

# ----- Widget -----
$W = 300; $H = 272
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.StartPosition = 'Manual'
$form.BackColor = $cBg
$form.ClientSize = New-Object System.Drawing.Size($W, $H)
$form.Region = [System.Drawing.Region]::FromHrgn([CcNative]::CreateRoundRectRgn(0, 0, $W + 1, $H + 1, 14, 14))

function Add-Label($x, $y, $w, $h, $font, $color, $text = '') {
    $l = New-Object System.Windows.Forms.Label
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Text = $text
    $form.Controls.Add($l)
    $l
}
function Add-IconButton($x, $text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Location = New-Object System.Drawing.Point($x, 6)
    $b.Size = New-Object System.Drawing.Size(26, 24)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $cTrack
    $b.ForeColor = $cMuted; $b.Font = New-Font 10; $b.Text = $text
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $form.Controls.Add($b)
    $b
}

$headerBg = New-Object System.Windows.Forms.Panel
$headerBg.Location = New-Object System.Drawing.Point(0, 0)
$headerBg.Size = New-Object System.Drawing.Size($W, 40)
$headerBg.BackColor = $cHeaderBg
$form.Controls.Add($headerBg)

$accent = New-Object System.Windows.Forms.Panel
$accent.Location = New-Object System.Drawing.Point(0, 40)
$accent.Size = New-Object System.Drawing.Size($W, 3)
$accent.BackColor = $cOrange
$form.Controls.Add($accent)

$lblHeader = Add-Label 18 11 210 18 (New-Font 8.5) $cMuted "$PlaceName · $($ShiftStart)–$($ShiftEnd)"
$lblHeader.Parent = $headerBg
$lblHeader.Location = New-Object System.Drawing.Point(18, 11)
$btnRefresh = Add-IconButton 232 ([string][char]0x21BB)
$btnHide    = Add-IconButton 262 ([string][char]0x02C4)
$lblTitle   = Add-Label 15 50 270 34 (New-Font 16 -Bold) $cOrange

$bar = New-Object System.Windows.Forms.Panel
$bar.Location = New-Object System.Drawing.Point(18, 88)
$bar.Size = New-Object System.Drawing.Size(264, 6)
$form.Controls.Add($bar)
$script:progress = 0.0
$script:accentColor = $cOrange
$bar.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.Clear($cTrack)
    $fill = [int]($bar.Width * $script:progress)
    if ($fill -gt 0) { $g.FillRectangle((New-Object System.Drawing.SolidBrush $script:accentColor), 0, 0, $fill, $bar.Height) }
})

$lblK1 = Add-Label 18 102 120 16 (New-Font 8.5) $cMuted 'Bắt đầu ca'
$lblK2 = Add-Label 150 102 130 16 (New-Font 8.5) $cMuted 'Kết thúc ca'
$lblV1 = Add-Label 18 118 120 22 (New-Font 12 -Bold) $cFg
$lblV2 = Add-Label 150 118 130 22 (New-Font 12 -Bold) $cFg
$lblK3 = Add-Label 18 144 120 16 (New-Font 8.5) $cMuted
$lblK4 = Add-Label 150 144 130 16 (New-Font 8.5) $cMuted 'Còn lại'
$lblV3 = Add-Label 18 160 120 22 (New-Font 12 -Bold) $cFg
$lblV4 = Add-Label 150 160 130 22 (New-Font 12 -Bold) $cFg
$lblStatus = Add-Label 18 186 264 18 (New-Font 9) $cFg

$btnMain = New-Object System.Windows.Forms.Button
$btnMain.Location = New-Object System.Drawing.Point(18, 208)
$btnMain.Size = New-Object System.Drawing.Size(264, 38)
$btnMain.FlatStyle = 'Flat'; $btnMain.FlatAppearance.BorderSize = 0
$btnMain.FlatAppearance.MouseOverBackColor = New-Color 214 234 222
$btnMain.BackColor = $cBtn; $btnMain.ForeColor = $cBtnText
$btnMain.Font = New-Font 11 -Bold
$btnMain.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnMain.Region = [System.Drawing.Region]::FromHrgn([CcNative]::CreateRoundRectRgn(0, 0, 265, 39, 20, 20))
$form.Controls.Add($btnMain)

$lblFooter = Add-Label 18 250 264 16 (New-Font 7.5) $cMuted

function Update-Widget {
    $now   = Get-Now
    $start = Get-TimeToday $ShiftStart
    $end   = Get-TimeToday $ShiftEnd
    $total = $end - $start
    $elapsed = $now - $start
    if ($elapsed -lt [timespan]::Zero) { $elapsed = [timespan]::Zero }
    if ($elapsed -gt $total) { $elapsed = $total }
    $remain = $total - $elapsed
    $isIn = $now -lt $start.AddTicks([long]($total.Ticks / 2))
    $isWorkDay = $WorkDays -contains $now.DayOfWeek.ToString()

    $color = if ($isIn) { $cGreen } else { $cOrange }
    $accent.BackColor = $color
    $lblTitle.ForeColor = if ($isIn) { $cFg } else { $cOrange }
    $lblTitle.Text = if ($isIn) { "Vào lúc $ShiftStart" } else { "Ra lúc $ShiftEnd" }
    $script:accentColor = $color
    $script:progress = if ($total.Ticks -gt 0) { $elapsed.Ticks / $total.Ticks } else { 0 }
    $bar.Invalidate()

    $lblV1.Text = $ShiftStart
    $lblV2.Text = $ShiftEnd
    $lblK3.Text = "Đã qua / $(Format-Dur $total)"
    $lblV3.Text = Format-Dur $elapsed
    $lblV4.Text = Format-Dur $remain

    $lblStatus.Text =
        if (-not $isWorkDay)                 { 'Hôm nay không phải ngày làm việc.' }
        elseif ($now -lt $start.AddMinutes(-15)) { 'Chưa đến giờ vào ca.' }
        elseif ($now -lt $start)             { 'Sắp đến giờ vào ca.' }
        elseif ($isIn)                       { 'Đã vào ca, nhớ chấm công vào.' }
        elseif ($now -lt $end.AddMinutes(-30)) { 'Đang trong ca.' }
        elseif ($now -lt $end)               { 'Sắp đến giờ ra.' }
        else                                 { 'Đã hết ca, nhớ chấm công ra.' }

    $btnMain.Text = if ($isIn) { 'Chấm công VÀO' } else { 'Chấm công RA' }
    $lblFooter.Text = "Cập nhật $($now.ToString('HH:mm')) · bấm icon khay để ẩn/hiện"
}

function Show-Widget {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point(($wa.Right - $W - 12), ($wa.Bottom - $H - 12))
    Update-Widget
    $form.Show()
}

$btnMain.Add_Click({ Open-ChamCong })
$btnRefresh.Add_Click({ Update-Widget })
$btnHide.Add_Click({ $form.Hide() })

# Kéo thả widget bằng chuột (vùng nền / tiêu đề)
$dragHandler = {
    if ($_.Button -eq 'Left') {
        [CcNative]::ReleaseCapture() | Out-Null
        [CcNative]::SendMessage($form.Handle, 0xA1, 2, 0) | Out-Null
    }
}
$form.Add_MouseDown($dragHandler)
$lblHeader.Add_MouseDown($dragHandler)
$lblTitle.Add_MouseDown($dragHandler)

# ----- Chế độ xem trước: vẽ ra ảnh rồi thoát -----
if ($Preview) {
    $form.Location = New-Object System.Drawing.Point(-5000, -5000)
    $form.Show()
    Update-Widget
    [System.Windows.Forms.Application]::DoEvents()
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $W, $H)))
    $bmp.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose(); $form.Dispose()
    return
}

$script:exiting = $false
$form.Add_FormClosing({
    param($s, $e)
    if (-not $script:exiting) { $e.Cancel = $true; $form.Hide() }
})

# ----- Tray icon -----
function New-ClockIcon {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 0 96 47)), 1, 1, 30, 30)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 3
    $g.DrawLine($pen, 16, 16, 16, 7)
    $g.DrawLine($pen, 16, 16, 23, 16)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = New-ClockIcon
$tray.Text = "Chấm công ($ShiftStart - $ShiftEnd)"
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Items.Add('Hiện widget').Add_Click({ Show-Widget }) | Out-Null
$menu.Items.Add('Mở trang chấm công').Add_Click({ Open-ChamCong }) | Out-Null
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('Thoát').Add_Click({
    $script:exiting = $true
    $tray.Visible = $false
    $tray.Dispose()
    $form.Close()
    [System.Windows.Forms.Application]::Exit()
}) | Out-Null
$tray.ContextMenuStrip = $menu
$tray.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq 'Left') { if ($form.Visible) { $form.Hide() } else { Show-Widget } }
})

# ----- Hẹn giờ: cập nhật mỗi 10s, tự hiện widget gần giờ vào/ra -----
$script:shown = @{ in = $null; out = $null }
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 10000
$timer.Add_Tick({
    if ($form.Visible) { Update-Widget }
    $now = Get-Date
    if ($WorkDays -notcontains $now.DayOfWeek.ToString()) { return }
    $today = $now.Date
    $due = @{ in = (Get-TimeToday $RemindIn); out = (Get-TimeToday $RemindOut) }
    foreach ($k in 'in', 'out') {
        if ($script:shown[$k] -ne $today -and $now -ge $due[$k] -and $now -lt $due[$k].AddMinutes(60)) {
            $script:shown[$k] = $today
            [System.Media.SystemSounds]::Exclamation.Play()
            Show-Widget
        }
    }
})
$timer.Start()

Show-Widget
[System.Windows.Forms.Application]::Run()
$mutex.ReleaseMutex()
