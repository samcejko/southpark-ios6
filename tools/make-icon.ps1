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

$srcImg = [System.Drawing.Image]::FromFile($Source)

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

function Resize-Image([System.Drawing.Image]$img, [int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    $g.DrawImage($img, 0, 0, $size, $size)
    $g.Dispose()
    
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Write-Host "Exporting icon sizes to $ResourcesDir ..."
foreach ($name in $sizes.Keys) {
    $sz = $sizes[$name]
    $dest = Join-Path $ResourcesDir $name
    Resize-Image $srcImg $sz $dest
    Write-Host "  -> $name ($sz x $sz)"
}

# Also export to cydia-repo if present
$cydiaIconDir = Join-Path $CydiaRepoDir "site\icons"
if (Test-Path $cydiaIconDir) {
    $cydiaIcon = Join-Path $cydiaIconDir "com.samcejko.cityvod.png"
    Resize-Image $srcImg 144 $cydiaIcon
    Write-Host "  -> Exported cydia repo icon: $cydiaIcon (144x144)"
}

$srcImg.Dispose()
Write-Host "Done! All icons generated."
