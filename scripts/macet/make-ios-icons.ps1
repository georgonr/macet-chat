# Generates the iOS app icons and in-app logos from the master logo.
#
# Nothing here is resampled from a finished bitmap - every asset is redrawn from the geometry of
# assets/macet-logo.svg at its own resolution, the same way scripts/macet/make-desktop-icons.ps1
# does it, so even a 20 px icon stays crisp:
#
#   background     : #0F172A, full square
#   white polyline : 135,348 -> 135,164 -> 256,308 -> 377,164 -> 377,348
#   accent segment : 256,308 -> 377,164 in #38BDF8, drawn over the white one
#   stroke width   : 46, round caps and joins, all in a 512 viewBox
#
# Written into apps/ios/Shared/Assets.xcassets:
#   AppIcon.appiconset       19 sizes, opaque, no alpha, square (iOS rounds the corners itself)
#   DarkAppIcon.appiconset   19 sizes, the near-black alternate offered in the icon picker
#   icon-light.imageset      100/200/300  preview of AppIcon in the picker, QR code overlay
#   icon-dark.imageset       60/120/180   preview of DarkAppIcon in the picker
#   icon-transparent.imageset 60/120/180  CallKit template - white mark on transparency
#   logo.imageset            wordmark for the light colour scheme
#   logo-light.imageset      wordmark for the dark colour scheme
#   vertical_logo.imageset   8/16/24 tile used as the texture that masks hidden text
#
# Run:  powershell -ExecutionPolicy Bypass -File scripts/macet/make-ios-icons.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$assets = Join-Path $PSScriptRoot '..\..\apps\ios\Shared\Assets.xcassets'
$assets = (Resolve-Path $assets).Path

$background = [System.Drawing.ColorTranslator]::FromHtml('#0F172A')
$darkAlt    = [System.Drawing.ColorTranslator]::FromHtml('#020617')
$accent     = [System.Drawing.ColorTranslator]::FromHtml('#38BDF8')
$white      = [System.Drawing.Color]::White

# The mark, in the coordinates of the 512 viewBox of assets/macet-logo.svg.
$markPoints = @(
  (New-Object System.Drawing.PointF(135, 348)),
  (New-Object System.Drawing.PointF(135, 164)),
  (New-Object System.Drawing.PointF(256, 308)),
  (New-Object System.Drawing.PointF(377, 164)),
  (New-Object System.Drawing.PointF(377, 348))
)

function New-Canvas([int]$w, [int]$h, [bool]$opaque) {
  $format = if ($opaque) { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
            else { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
  $bmp = New-Object System.Drawing.Bitmap($w, $h, $format)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  return @{ Bitmap = $bmp; Graphics = $g }
}

# Draws the mark into the current transform of $g. $strokeWidth is in viewBox units.
# $mono draws the whole mark in $bodyColor, which is what a template image needs.
function Draw-Mark($g, $bodyColor, $strokeWidth, [bool]$mono) {
  $pen = New-Object System.Drawing.Pen($bodyColor, [float]$strokeWidth)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawLines($pen, [System.Drawing.PointF[]]$markPoints)
  if (-not $mono) {
    $accentPen = New-Object System.Drawing.Pen($accent, [float]$strokeWidth)
    $accentPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $accentPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($accentPen, 256.0, 308.0, 377.0, 164.0)
    $accentPen.Dispose()
  }
  $pen.Dispose()
}

function Save-Png($bmp, [string]$path) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# A full-bleed square icon: solid background, mark on top, no transparency and no rounding -
# iOS masks the corners itself and the App Store rejects an icon with an alpha channel.
function New-AppIcon([int]$size, $bg) {
  $c = New-Canvas $size $size $true
  $c.Graphics.Clear($bg)
  $c.Graphics.ScaleTransform($size / 512.0, $size / 512.0)
  Draw-Mark $c.Graphics $white 46 $false
  $c.Graphics.Dispose()
  return $c.Bitmap
}

# The mark alone on transparency, used as the CallKit template.
function New-TemplateIcon([int]$size) {
  $c = New-Canvas $size $size $false
  $c.Graphics.Clear([System.Drawing.Color]::Transparent)
  $c.Graphics.ScaleTransform($size / 512.0, $size / 512.0)
  Draw-Mark $c.Graphics $white 46 $true
  $c.Graphics.Dispose()
  return $c.Bitmap
}

# Rounded brand tile, drawn into $g at ($x,$y) with side $side.
function Draw-Tile($g, [float]$x, [float]$y, [float]$side, $bg) {
  $r = $side * 0.22
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90)
  $path.AddArc($x + $side - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90)
  $path.AddArc($x + $side - 2 * $r, $y + $side - 2 * $r, 2 * $r, 2 * $r, 0, 90)
  $path.AddArc($x, $y + $side - 2 * $r, 2 * $r, 2 * $r, 90, 90)
  $path.CloseFigure()
  $brush = New-Object System.Drawing.SolidBrush($bg)
  $g.FillPath($brush, $path)
  $brush.Dispose(); $path.Dispose()
}

function Get-Font([float]$size) {
  foreach ($name in @('Segoe UI Semibold', 'Segoe UI', 'Arial')) {
    $f = New-Object System.Drawing.Font($name, $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    if ($f.Name -eq $name -or $name -eq 'Arial') { return $f }
    $f.Dispose()
  }
  return New-Object System.Drawing.Font('Arial', $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
}

# The wordmark: brand tile with the mark, then "Macet Secure Chat".
# On the light colour scheme the tile is dark and the text is dark; on the dark scheme there is no
# tile - the mark and the text are both white, matching the Android and desktop wordmarks.
function New-Wordmark([int]$w, [int]$h, [bool]$forDarkScheme) {
  $c = New-Canvas $w $h $false
  $g = $c.Graphics
  $g.Clear([System.Drawing.Color]::Transparent)

  $side = $h * 0.82
  $x = $h * 0.09
  $y = ($h - $side) / 2.0

  if ($forDarkScheme) {
    # no tile - the mark is drawn white, directly on the dark background of the app
    $state = $g.Save()
    $g.TranslateTransform($x, $y)
    $g.ScaleTransform($side / 512.0, $side / 512.0)
    Draw-Mark $g $white 46 $false
    $g.Restore($state)
  } else {
    Draw-Tile $g $x $y $side $background
    $inset = $side * 0.06
    $state = $g.Save()
    $g.TranslateTransform($x + $inset, $y + $inset)
    $g.ScaleTransform(($side - 2 * $inset) / 512.0, ($side - 2 * $inset) / 512.0)
    Draw-Mark $g $white 46 $false
    $g.Restore($state)
  }

  $text = 'Macet Secure Chat'
  $textLeft = $x + $side + $h * 0.20
  $available = $w - $textLeft - $h * 0.10
  $fontSize = $h * 0.46
  $font = Get-Font $fontSize
  # shrink until the wordmark fits the canvas width
  while (($g.MeasureString($text, $font)).Width -gt $available -and $fontSize -gt 6) {
    $font.Dispose()
    $fontSize = $fontSize - ($h * 0.01)
    $font = Get-Font $fontSize
  }
  $textColor = if ($forDarkScheme) { $white } else { $background }
  $brush = New-Object System.Drawing.SolidBrush($textColor)
  $measured = $g.MeasureString($text, $font)
  $g.DrawString($text, $font, $brush, [float]$textLeft, [float](($h - $measured.Height) / 2.0))
  $brush.Dispose(); $font.Dispose()

  $g.Dispose()
  return $c.Bitmap
}

# Small tileable texture used to mask hidden text. It is drawn thicker than the master geometry
# because at 8 px the 46-unit stroke would disappear.
function New-TileTexture([int]$size) {
  $c = New-Canvas $size $size $false
  $c.Graphics.Clear([System.Drawing.Color]::Transparent)
  # fit the mark, which spans x 112..400 and y 141..371 of the viewBox, into the tile
  $scale = $size / 300.0
  $c.Graphics.ScaleTransform($scale, $scale)
  $c.Graphics.TranslateTransform(-106.0, -128.0)
  Draw-Mark $c.Graphics $accent 78 $true
  $c.Graphics.Dispose()
  return $c.Bitmap
}

$appIconSizes = @(20, 29, 40, 50, 57, 58, 60, 72, 76, 80, 87, 100, 114, 120, 144, 152, 167, 180, 1024)

Write-Output 'AppIcon.appiconset'
foreach ($s in $appIconSizes) {
  $bmp = New-AppIcon $s $background
  Save-Png $bmp (Join-Path $assets "AppIcon.appiconset\$s.png")
  $bmp.Dispose()
}

Write-Output 'DarkAppIcon.appiconset'
foreach ($s in $appIconSizes) {
  $bmp = New-AppIcon $s $darkAlt
  Save-Png $bmp (Join-Path $assets "DarkAppIcon.appiconset\$s.png")
  $bmp.Dispose()
}

Write-Output 'icon-light.imageset'
foreach ($p in @(@{n='icon-light.png'; s=100}, @{n='icon-light@2x.png'; s=200}, @{n='icon-light@3x.png'; s=300})) {
  $bmp = New-AppIcon $p.s $background
  Save-Png $bmp (Join-Path $assets "icon-light.imageset\$($p.n)")
  $bmp.Dispose()
}

Write-Output 'icon-dark.imageset'
foreach ($s in @(60, 120, 180)) {
  $bmp = New-AppIcon $s $darkAlt
  Save-Png $bmp (Join-Path $assets "icon-dark.imageset\$s.png")
  $bmp.Dispose()
}

Write-Output 'icon-transparent.imageset'
foreach ($s in @(60, 120, 180)) {
  $bmp = New-TemplateIcon $s
  Save-Png $bmp (Join-Path $assets "icon-transparent.imageset\$s.png")
  $bmp.Dispose()
}

Write-Output 'logo.imageset / logo-light.imageset'
foreach ($p in @(@{n='logo.png'; w=256; h=63}, @{n='logo@2x.png'; w=512; h=126}, @{n='logo@3x.png'; w=768; h=189})) {
  $bmp = New-Wordmark $p.w $p.h $false
  Save-Png $bmp (Join-Path $assets "logo.imageset\$($p.n)")
  $bmp.Dispose()
}
foreach ($p in @(@{n='logo-light.png'; w=256; h=63}, @{n='logo-light@2x.png'; w=512; h=126}, @{n='logo-light@3x.png'; w=768; h=189})) {
  $bmp = New-Wordmark $p.w $p.h $true
  Save-Png $bmp (Join-Path $assets "logo-light.imageset\$($p.n)")
  $bmp.Dispose()
}

Write-Output 'vertical_logo.imageset'
foreach ($p in @(@{n='vertical_logo_x1.png'; s=8}, @{n='vertical_logo_x2.png'; s=16}, @{n='vertical_logo_x3.png'; s=24})) {
  $bmp = New-TileTexture $p.s
  Save-Png $bmp (Join-Path $assets "vertical_logo.imageset\$($p.n)")
  $bmp.Dispose()
}

Write-Output 'done'
