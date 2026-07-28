# Generates the desktop application icons from the master logo.
#
# The mark is not rasterised from assets/macet-logo.svg - it is redrawn here from exactly the same
# geometry, so every density is rendered at its own resolution instead of being downsampled from a
# large bitmap, and the 16 px icon stays crisp:
#
#   background     : #0F172A, full square
#   white polyline : 135,348 -> 135,164 -> 256,308 -> 377,164 -> 377,348
#   accent segment : 256,308 -> 377,164 in #38BDF8, drawn over the white one
#   stroke width   : 46, round caps and joins, all in a 512 viewBox
#
# Outputs, next to the Compose distribution config:
#   macet.ico   16/32/48/64/128/256   Windows launcher, installer and shortcut
#   macet.png   512                   Linux .desktop icon
#   macet.icns  16..1024 (@1x, @2x)   macOS bundle
#
# Run:  powershell -ExecutionPolicy Bypass -File scripts/macet/make-desktop-icons.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot '..\..\apps\multiplatform\desktop\src\jvmMain\resources\distribute'
$outDir = (Resolve-Path $outDir).Path

$background = [System.Drawing.ColorTranslator]::FromHtml('#0F172A')
$accent     = [System.Drawing.ColorTranslator]::FromHtml('#38BDF8')
$white      = [System.Drawing.Color]::White

function New-Icon([int]$size) {
  $scale = $size / 512.0
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear($background)
    $g.ScaleTransform($scale, $scale)

    $pen = New-Object System.Drawing.Pen($white, 46.0)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $points = @(
      (New-Object System.Drawing.PointF(135, 348)),
      (New-Object System.Drawing.PointF(135, 164)),
      (New-Object System.Drawing.PointF(256, 308)),
      (New-Object System.Drawing.PointF(377, 164)),
      (New-Object System.Drawing.PointF(377, 348))
    )
    $g.DrawLines($pen, [System.Drawing.PointF[]]$points)

    $accentPen = New-Object System.Drawing.Pen($accent, 46.0)
    $accentPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $accentPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($accentPen, 256.0, 308.0, 377.0, 164.0)

    $pen.Dispose(); $accentPen.Dispose()
  } finally {
    $g.Dispose()
  }
  return $bmp
}

function Get-PngBytes([System.Drawing.Bitmap]$bmp) {
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bytes = $ms.ToArray()
  $ms.Dispose()
  return ,$bytes
}

# A classic ICO entry: BITMAPINFOHEADER with a doubled height, bottom-up BGRA rows, then the 1 bpp
# AND mask. The mark is fully opaque, so the mask is all zeros.
function Get-DibBytes([System.Drawing.Bitmap]$bmp) {
  $size = $bmp.Width
  $ms = New-Object System.IO.MemoryStream
  $w = New-Object System.IO.BinaryWriter($ms)
  $w.Write([int]40); $w.Write([int]$size); $w.Write([int]($size * 2))
  $w.Write([int16]1); $w.Write([int16]32)
  $w.Write([int]0); $w.Write([int]0)
  $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0)
  for ($y = $size - 1; $y -ge 0; $y--) {
    for ($x = 0; $x -lt $size; $x++) {
      $c = $bmp.GetPixel($x, $y)
      $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A)
    }
  }
  $maskRow = [Math]::Floor(($size + 31) / 32) * 4
  $w.Write((New-Object byte[] ($maskRow * $size)))
  $w.Flush()
  $bytes = $ms.ToArray()
  $w.Dispose()
  return ,$bytes
}

function Write-Ico([int[]]$sizes, [string]$path) {
  $images = @()
  foreach ($size in $sizes) {
    $bmp = New-Icon $size
    # Every density is stored as an uncompressed DIB. PNG-compressed entries are smaller and are
    # what modern icon editors emit for 256, but GDI+ cannot read them back, so a plain ICO keeps
    # the file readable by every consumer.
    $data = Get-DibBytes $bmp
    $images += ,@{ Size = $size; Data = $data }
    $bmp.Dispose()
  }
  $fs = [System.IO.File]::Create($path)
  $w = New-Object System.IO.BinaryWriter($fs)
  $w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$images.Count)
  $offset = 6 + 16 * $images.Count
  foreach ($image in $images) {
    $dim = $image.Size
    if ($dim -ge 256) { $dim = 0 }
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([int16]1); $w.Write([int16]32)
    $w.Write([int]$image.Data.Length); $w.Write([int]$offset)
    $offset += $image.Data.Length
  }
  foreach ($image in $images) { $w.Write($image.Data) }
  $w.Dispose(); $fs.Dispose()
}

function Write-Png([int]$size, [string]$path) {
  $bmp = New-Icon $size
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# icns is a flat list of PNG-carrying entries; the type code says which density it is.
function Write-Icns([string]$path) {
  $types = [ordered]@{ 'ic07' = 128; 'ic08' = 256; 'ic09' = 512; 'ic10' = 1024;
                       'ic11' = 32;  'ic12' = 64;  'ic13' = 256; 'ic14' = 512 }
  $body = New-Object System.IO.MemoryStream
  foreach ($type in $types.Keys) {
    $bmp = New-Icon $types[$type]
    $png = Get-PngBytes $bmp
    $bmp.Dispose()
    $body.Write([System.Text.Encoding]::ASCII.GetBytes($type), 0, 4)
    $len = [System.BitConverter]::GetBytes([int]($png.Length + 8))
    [Array]::Reverse($len)
    $body.Write($len, 0, 4)
    $body.Write($png, 0, $png.Length)
  }
  $fs = [System.IO.File]::Create($path)
  $fs.Write([System.Text.Encoding]::ASCII.GetBytes('icns'), 0, 4)
  $total = [System.BitConverter]::GetBytes([int]($body.Length + 8))
  [Array]::Reverse($total)
  $fs.Write($total, 0, 4)
  $body.WriteTo($fs)
  $fs.Dispose(); $body.Dispose()
}

Write-Ico @(16, 32, 48, 64, 128, 256) (Join-Path $outDir 'macet.ico')
Write-Png 512 (Join-Path $outDir 'macet.png')
Write-Icns (Join-Path $outDir 'macet.icns')
Get-ChildItem (Join-Path $outDir 'macet.*') | Select-Object Name, Length
