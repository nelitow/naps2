# Captures and drives only the WPF dev build's own windows. Never touches other windows or the installed NAPS2.
# Set DEVWIN_EXE to target another copy of the app (e.g. an unpacked release build) instead of the Debug build.
#
#   devwin.ps1 launch [file]     Start the app with an isolated data folder, optionally importing a file
#   devwin.ps1 stop              Close the app and clear its throwaway recovery data
#   devwin.ps1 shot <name>       Save its windows to dev/shots/<name>.png, <name>-1.png, ... (topmost first)
#   devwin.ps1 tree [depth]      List the UI Automation elements of its windows
#   devwin.ps1 invoke <name>     Invoke the element with that automation name, looking in the topmost window first
#   devwin.ps1 backdrop          Report the main window's DWM system backdrop type (2 = Mica)
#   devwin.ps1 select <i,j,...>  Select the list items at those zero-based positions
param(
    [Parameter(Position = 0, Mandatory = $true)][ValidateSet('launch', 'stop', 'shot', 'tree', 'invoke', 'backdrop', 'select')][string]$Action,
    [Parameter(Position = 1)][string]$Arg
)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
$exe = if ($env:DEVWIN_EXE) { $env:DEVWIN_EXE } else { Join-Path $repo 'NAPS2.App.Wpf\bin\Debug\net10.0-windows\win-x64\NAPS2.exe' }

Add-Type -AssemblyName System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DevWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int value, int size);
}
'@
# DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2, so captures are at real pixel size
[void][DevWin]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))

$AE = [System.Windows.Automation.AutomationElement]
$Scope = [System.Windows.Automation.TreeScope]

function Get-DevProcesses {
    @(Get-Process -Name NAPS2 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
}

# The app's top-level windows, topmost first
function Get-DevWindows {
    $windows = @()
    foreach ($p in Get-DevProcesses) {
        $cond = New-Object System.Windows.Automation.PropertyCondition ($AE::ProcessIdProperty), $p.Id
        $found = $AE::RootElement.FindAll($Scope::Children, $cond)
        foreach ($w in $found) {
            # Dialogs show up as children of the window that owns them
            $dialogCond = New-Object System.Windows.Automation.PropertyCondition ($AE::ControlTypeProperty), ([System.Windows.Automation.ControlType]::Window)
            foreach ($dialog in $w.FindAll($Scope::Descendants, $dialogCond)) { $windows += $dialog }
            $windows += $w
        }
    }
    if ($windows.Count -eq 0) { throw 'App has no windows open. Use: devwin.ps1 launch' }
    $windows
}

switch ($Action) {
    'launch' {
        if (Get-DevProcesses | Where-Object { $_.MainWindowHandle -ne 0 }) { Write-Output 'already running'; return }
        $env:NAPS2_TEST_DATA = Join-Path $env:TEMP 'naps2-dev-data'
        New-Item -ItemType Directory -Force $env:NAPS2_TEST_DATA | Out-Null
        if ($Arg) { Start-Process -FilePath $exe -ArgumentList "`"$Arg`"" | Out-Null }
        else { Start-Process -FilePath $exe | Out-Null }
        foreach ($i in 1..40) {
            Start-Sleep -Milliseconds 500
            $p = Get-DevProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
            if ($p) { Write-Output "running pid=$($p.Id)"; return }
        }
        throw 'App window did not appear'
    }
    'stop' {
        # Force-closed, since closing with pages would otherwise prompt. Only the throwaway data is affected.
        $running = Get-DevProcesses
        $running | Stop-Process -Force
        $running | ForEach-Object { [void]$_.WaitForExit(5000) }
        $recovery = Join-Path $env:TEMP 'naps2-dev-data\recovery'
        if (Test-Path $recovery) { Get-ChildItem $recovery | Remove-Item -Recurse -Force }
        Write-Output "stopped $($running.Count)"
    }
    'shot' {
        if (-not $Arg) { throw 'shot needs a name' }
        $dir = Join-Path $PSScriptRoot 'shots'
        New-Item -ItemType Directory -Force $dir | Out-Null
        $n = 0
        foreach ($win in Get-DevWindows) {
            $hwnd = [IntPtr]$win.Current.NativeWindowHandle
            $r = New-Object DevWin+RECT
            [void][DevWin]::GetWindowRect($hwnd, [ref]$r)
            $w = $r.R - $r.L; $h = $r.B - $r.T
            if ($w -le 0 -or $h -le 0) { continue }
            $bmp = New-Object System.Drawing.Bitmap $w, $h
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $hdc = $g.GetHdc()
            # PW_RENDERFULLCONTENT (2) is needed for WPF's DirectComposition content
            $ok = [DevWin]::PrintWindow($hwnd, $hdc, 2)
            $g.ReleaseHdc($hdc); $g.Dispose()
            if (-not $ok) { throw 'PrintWindow failed' }
            $file = if ($n -eq 0) { "$Arg.png" } else { "$Arg-$n.png" }
            $out = Join-Path $dir $file
            $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
            Write-Output "$out (${w}x${h}) '$($win.Current.Name)'"
            $n++
        }
    }
    'select' {
        if (-not $Arg) { throw 'select needs item positions' }
        $cond = New-Object System.Windows.Automation.PropertyCondition ($AE::ControlTypeProperty), ([System.Windows.Automation.ControlType]::ListItem)
        foreach ($win in Get-DevWindows) {
            $items = $win.FindAll($Scope::Descendants, $cond)
            if ($items.Count -eq 0) { continue }
            $first = $true
            foreach ($i in $Arg -split ',') {
                $pat = $items[[int]$i].GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
                if ($first) { $pat.Select(); $first = $false } else { $pat.AddToSelection() }
            }
            $names = ($items | ForEach-Object { $_.Current.Name }) -join ', '
            Write-Output "selected $Arg of $($items.Count): $names"
            return
        }
        throw 'No list items found'
    }
    'backdrop' {
        $p = Get-DevProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $p) { throw 'App is not running' }
        $value = 0
        # DWMWA_SYSTEMBACKDROP_TYPE
        $hr = [DevWin]::DwmGetWindowAttribute($p.MainWindowHandle, 38, [ref]$value, 4)
        Write-Output "hresult=$hr backdrop=$value"
    }
    'tree' {
        $max = if ($Arg) { [int]$Arg } else { 6 }
        $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
        function Walk($el, $depth) {
            if ($depth -gt $max) { return }
            $c = $el.Current
            $type = $c.ControlType.ProgrammaticName -replace 'ControlType\.', ''
            Write-Output (('  ' * $depth) + "$type '$($c.Name)' enabled=$($c.IsEnabled)")
            $child = $walker.GetFirstChild($el)
            while ($child) { Walk $child ($depth + 1); $child = $walker.GetNextSibling($child) }
        }
        foreach ($win in Get-DevWindows) { Walk $win 0 }
    }
    'invoke' {
        if (-not $Arg) { throw 'invoke needs an element name' }
        # "Name#2" picks the third element with that name
        $name, $index = $Arg -split '#'
        $index = if ($index) { [int]$index } else { 0 }
        $cond = New-Object System.Windows.Automation.PropertyCondition ($AE::NameProperty), $name
        foreach ($win in Get-DevWindows) {
            $found = $win.FindAll($Scope::Descendants, $cond)
            if ($found.Count -le $index) { continue }
            $el = $found[$index]
            $pat = $null
            if ($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pat)) { $pat.Invoke() }
            elseif ($el.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$pat)) { $pat.Toggle() }
            elseif ($el.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$pat)) { $pat.Expand() }
            elseif ($el.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pat)) { $pat.Select() }
            else { throw "'$Arg' cannot be invoked" }
            Write-Output "invoked '$Arg' in '$($win.Current.Name)'"
            return
        }
        throw "No element named '$Arg'"
    }
}
