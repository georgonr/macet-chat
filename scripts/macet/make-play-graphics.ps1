# Generates the Google Play store graphics from the master logo.
#
# Drawn from the geometry of assets/macet-logo.svg, like the desktop and iOS icons - nothing is
# resampled from a finished bitmap. See scripts/macet/make-desktop-icons.ps1 for the same approach.
#
# Outputs into play-listing/:
#   icon-512.png            512x512  app icon, opaque, square (Play rounds it itself)
#   feature-graphic.png    1024x500  the banner shown at the top of the listing
#
# Run:  powershell -ExecutionPolicy Bypass -File scripts/macet/make-play-graphics.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot '..\..\play-listing'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force $out | Out-Null }
$out = (Resolve-Path $out).Path

$background = [System.Drawing.ColorTranslator]::FromHtml('#0F172A')
$deep       = [System.Drawing.ColorTranslator]::FromHtml('#020617')
$accent     = [System.Drawing.ColorTranslator]::FromHtml('#38BDF8')
$white      = [System.Drawing.Color]::White

$markPoints = @(
  (New-Object System.Drawing.PointF(135, 348)),
  (New-Object System.Drawing.PointF(135, 164)),
  (New-Object System.Drawing.PointF(256, 308)),
  (New-Object System.Drawing.PointF(377, 164)),
  (New-Object System.Drawing.PointF(377, 348))
)

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  return @{ Bitmap = $bmp; Graphics = $g }
}

function Draw-Mark($g, [float]$strokeWidth) {
  $pen = New-Object System.Drawing.Pen($white, $strokeWidth)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawLines($pen, [System.Drawing.PointF[]]$markPoints)
  $accentPen = New-Object System.Drawing.Pen($accent, $strokeWidth)
  $accentPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $accentPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawLine($accentPen, 256.0, 308.0, 377.0, 164.0)
  $pen.Dispose(); $accentPen.Dispose()
}

function Get-Font([float]$size, [System.Drawing.FontStyle]$style) {
  foreach ($name in @('Segoe UI Semibold', 'Segoe UI', 'Arial')) {
    $f = New-Object System.Drawing.Font($name, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    if ($f.Name -eq $name -or $name -eq 'Arial') { return $f }
    $f.Dispose()
  }
  return New-Object System.Drawing.Font('Arial', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

# 512x512 listing icon
$c = New-Canvas 512 512
$c.Graphics.Clear($background)
Draw-Mark $c.Graphics 46
$c.Graphics.Dispose()
$c.Bitmap.Save((Join-Path $out 'icon-512.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$c.Bitmap.Dispose()

# 1024x500 feature graphic: mark on the left, name and one line of description on the right.
# Play crops this on some surfaces, so nothing important goes near the edges.
$w = 1024; $h = 500
$c = New-Canvas $w $h
$g = $c.Graphics
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.Point(0, 0)),
  (New-Object System.Drawing.Point($w, $h)), $deep, $background)
$g.FillRectangle($brush, 0, 0, $w, $h)
$brush.Dispose()

$markSide = 240.0
$markX = 96.0
$markY = ($h - $markSide) / 2.0
$state = $g.Save()
$g.TranslateTransform($markX, $markY)
$g.ScaleTransform($markSide / 512.0, $markSide / 512.0)
Draw-Mark $g 46
$g.Restore($state)

$textLeft = $markX + $markSide + 72.0
$title = 'Macet Secure Chat'
$sub = 'End-to-end encrypted messaging'
# shrink until both lines clear the right edge
$available = $w - $textLeft - 72.0
$titleSize = 76.0
$titleFont = Get-Font $titleSize ([System.Drawing.FontStyle]::Bold)
while (($g.MeasureString($title, $titleFont)).Width -gt $available -and $titleSize -gt 20) {
  $titleFont.Dispose(); $titleSize -= 2.0
  $titleFont = Get-Font $titleSize ([System.Drawing.FontStyle]::Bold)
}
$subSize = [Math]::Round($titleSize * 0.45)
$subFont = Get-Font $subSize ([System.Drawing.FontStyle]::Regular)
while (($g.MeasureString($sub, $subFont)).Width -gt $available -and $subSize -gt 12) {
  $subFont.Dispose(); $subSize -= 1.0
  $subFont = Get-Font $subSize ([System.Drawing.FontStyle]::Regular)
}
$titleBrush = New-Object System.Drawing.SolidBrush($white)
$subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#94A3B8'))
$tm = $g.MeasureString($title, $titleFont)
$sm = $g.MeasureString($sub, $subFont)
$block = $tm.Height + 18 + $sm.Height
$top = ($h - $block) / 2.0
$g.DrawString($title, $titleFont, $titleBrush, [float]$textLeft, [float]$top)
$g.DrawString($sub, $subFont, $subBrush, [float]$textLeft, [float]($top + $tm.Height + 18))
$titleFont.Dispose(); $subFont.Dispose(); $titleBrush.Dispose(); $subBrush.Dispose()
$g.Dispose()
$c.Bitmap.Save((Join-Path $out 'feature-graphic.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$c.Bitmap.Dispose()

Get-ChildItem $out -Filter *.png | ForEach-Object {
  $i = [System.Drawing.Image]::FromFile($_.FullName)
  "{0,-24} {1}x{2}" -f $_.Name, $i.Width, $i.Height
  $i.Dispose()
}
