# Usage (PowerShell as administrator): .\sandbox\write-usb.ps1 -Iso <path to kestrel-*.iso> [-ExpectName "<USB stick name from Get-Disk>"]
# Writes the Kestrel ISO to the USB stick in 256 MB pieces. Each piece is written, flushed,
# read back and compared before the next one; between pieces there is a short pause. If the
# stick drops off the USB bus (this one resets after long writes), the script waits for it
# to come back and redoes that piece. Runs elevated; only touches the disk named $ExpectName.
param(
    [Parameter(Mandatory)] [string] $Iso,
    [string] $ExpectName = 'Intenso Slim Line',
    [string] $Log = "$env:TEMP\kestrel-usb2.log"
)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public static class RawDisk2 {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
    public static FileStream Open(int disk, bool write) {
        var h = CreateFile(@"\\.\PhysicalDrive" + disk, write ? 0xC0000000u : 0x80000000u, 3u, IntPtr.Zero, 3u,
                           write ? 0x80000000u : 0u, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("cannot open disk " + disk + ", error " + Marshal.GetLastWin32Error());
        return new FileStream(h, write ? FileAccess.ReadWrite : FileAccess.Read, 4 * 1024 * 1024);
    }
    public static bool Same(byte[] a, byte[] b, int n) {
        for (int i = 0; i < n; i++) if (a[i] != b[i]) return false;
        return true;
    }
}
'@
function Log($m) {
    $line = "$(Get-Date -Format HH:mm:ss) $m"; Write-Output $line
    # Someone reading the log (a progress monitor) can hold it for a moment: retry, never abort.
    for ($i = 0; $i -lt 20; $i++) { try { Add-Content -Path $Log -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 250 } }
}

function Find-Stick {
    # A running PowerShell keeps its old disk list; refresh it, or a replugged stick is never seen.
    Update-HostStorageCache -ErrorAction SilentlyContinue
    $d = Get-Disk | Where-Object { $_.FriendlyName -eq $ExpectName -and $_.BusType -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem }
    if (@($d).Count -eq 1) { return $d.Number }
    return $null
}
function Wait-Stick {
    for ($i = 0; $i -lt 120; $i++) {
        $n = Find-Stick
        if ($null -ne $n) { return $n }
        if ($i -eq 0) { Log "stick is gone, waiting for it to come back (unplug and replug it if it doesn't)" }
        Start-Sleep -Seconds 5
    }
    throw "stick did not come back within 10 minutes"
}

Set-Content -Path $Log -Value "start $(Get-Date)"
try {
    $disk = Wait-Stick
    [long]$size = (Get-Item $Iso).Length
    if ($size -gt (Get-Disk -Number $disk).Size) { throw "ISO is larger than the stick" }
    Log "writing $Iso ($([math]::Round($size/1GB,2)) GB) to disk $disk ($ExpectName)"
    Clear-Disk -Number $disk -RemoveData -RemoveOEM -Confirm:$false
    Start-Sleep -Seconds 2

    [long]$piece = 256MB
    $buf = New-Object byte[] $piece
    $back = New-Object byte[] $piece
    $isoFile = [IO.File]::OpenRead($Iso)
    [long]$offset = 0
    $pieces = [math]::Ceiling($size / $piece)
    $k = 0
    while ($offset -lt $size) {
        $k++
        $isoFile.Position = $offset
        $n = $isoFile.Read($buf, 0, $piece)
        $len = $n
        if ($len % 512 -ne 0) { $len += 512 - ($len % 512); [Array]::Clear($buf, $n, $len - $n) }
        $tries = 0
        while ($true) {
            try {
                $disk = Wait-Stick
                $w = [RawDisk2]::Open($disk, $true)
                $w.Position = $offset
                $w.Write($buf, 0, $len)
                $w.Flush($true)
                $w.Close()
                Start-Sleep -Milliseconds 500
                $r = [RawDisk2]::Open($disk, $false)
                $r.Position = $offset
                $got = 0
                while ($got -lt $len) {
                    $m = $r.Read($back, $got, $len - $got)
                    if ($m -le 0) { throw "short read" }
                    $got += $m
                }
                $r.Close()
                if (-not [RawDisk2]::Same($buf, $back, $n)) { throw "read-back differs" }
                break
            } catch {
                $tries++
                Log "piece $k of $pieces failed ($($_.Exception.Message)), retry $tries"
                if ($tries -ge 6) { throw "piece $k failed 6 times" }
                Start-Sleep -Seconds 10
            }
        }
        $offset += $n
        Log "piece $k of $pieces ok"
        Start-Sleep -Seconds 2
    }
    $isoFile.Close()
    Update-Disk -Number $disk
    Log "USB-OK all $pieces pieces written and checked"
} catch {
    Log "USB-FAILED: $_"
}
