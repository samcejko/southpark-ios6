# Generates all iOS icon sizes from tools/icon.png into Resources/ and cydia-repo/site/icons/
param(
    [string]$Source = "$PSScriptRoot\icon.png",
    [string]$ResourcesDir = "$PSScriptRoot\..\Resources",
    [string]$CydiaRepoDir = "$PSScriptRoot\..\..\cydia-repo"
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $Source)) {
    Write-Error "Source icon not found: $Source"
    exit 1
}

if (-not (Test-Path $ResourcesDir)) {
    New-Item -ItemType Directory -Path $ResourcesDir -Force | Out-Null
}

$rawImg = [System.Drawing.Bitmap]::FromFile($Source)
$w = $rawImg.Width
$h = $rawImg.Height

# 1. Prepare full-bleed master: fill any white corner pixels with the background color
$masterBmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$mg = [System.Drawing.Graphics]::FromImage($masterBmp)
$mg.DrawImage($rawImg, 0, 0, $w, $h)
$mg.Dispose()
$rawImg.Dispose()

$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$data = $masterBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($w * $h * 4)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

$cornerLimit = 220
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if (($x -lt $cornerLimit -or $x -ge ($w - $cornerLimit)) -and ($y -lt $cornerLimit -or $y -ge ($h - $cornerLimit))) {
            $idx = ($y * $w + $x) * 4
            $b = $bytes[$idx]
            $g = $bytes[$idx + 1]
            $r = $bytes[$idx + 2]
            $lum = ($r * 0.299 + $g * 0.587 + $b * 0.114)
            if ($lum -gt 70) {
                $bytes[$idx] = 53      # B
                $bytes[$idx + 1] = 41  # G
                $bytes[$idx + 2] = 38  # R
                $bytes[$idx + 3] = 255 # A
            }
        }
    }
}
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
$masterBmp.UnlockBits($data)

$sizes = @{
    "Icon.png"             = 57
    "Icon@2x.png"          = 114
    "Icon-72.png"          = 72
    "Icon-72@2x.png"       = 144
    "Icon-Small.png"       = 29
    "Icon-Small@2x.png"    = 58
    "Icon-Small-50.png"    = 50
    "Icon-Small-50@2x.png" = 100
    "Icon-60@2x.png"       = 120
    "Icon-60@3x.png"       = 180
    "Icon-76.png"          = 76
    "Icon-76@2x.png"       = 152
    "Icon-83.5@2x.png"     = 167
}

function Make-RoundedIcon([System.Drawing.Bitmap]$master, [int]$size, [string]$outPath) {
    $scale = 4
    $bigSize = $size * $scale
    $bigBmp = New-Object System.Drawing.Bitmap($bigSize, $bigSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bg = [System.Drawing.Graphics]::FromImage($bigBmp)
    $bg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $bg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $bg.Clear([System.Drawing.Color]::Transparent)

    $radius = $bigSize * 0.1757
    $d = $radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($bigSize - $d, 0, $d, $d, 270, 90)
    $path.AddArc($bigSize - $d, $bigSize - $d, $d, $d, 0, 90)
    $path.AddArc(0, $bigSize - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    $bg.SetClip($path)
    $bg.DrawImage($master, 0, 0, $bigSize, $bigSize)
    $bg.Dispose()

    $finalBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $fg = [System.Drawing.Graphics]::FromImage($finalBmp)
    $fg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $fg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $fg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $fg.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $fg.Clear([System.Drawing.Color]::Transparent)
    $fg.DrawImage($bigBmp, 0, 0, $size, $size)
    $fg.Dispose()
    $bigBmp.Dispose()

    $finalBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $finalBmp.Dispose()
}

Write-Host "Exporting rounded icon sizes to $ResourcesDir ..."
foreach ($name in $sizes.Keys) {
    $sz = $sizes[$name]
    $dest = Join-Path $ResourcesDir $name
    Make-RoundedIcon $masterBmp $sz $dest
    Write-Host "  -> $name ($sz x $sz)"
}

# Also export to cydia-repo if present
$cydiaIconDir = Join-Path $CydiaRepoDir "site\icons"
if (Test-Path $cydiaIconDir) {
    $cydiaIcon = Join-Path $cydiaIconDir "com.samcejko.cityvod.png"
    Make-RoundedIcon $masterBmp 144 $cydiaIcon
    Write-Host "  -> Exported rounded cydia repo icon: $cydiaIcon (144x144)"
}

$masterBmp.Dispose()
Write-Host "Done! All rounded icons generated successfully."
