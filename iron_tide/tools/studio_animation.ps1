# Build the studio's 12-frame assembly and projector overlays from its own canvas.
Add-Type -AssemblyName System.Drawing
$dir = Join-Path $PSScriptRoot '../assets/ra2/shp'
$body = [Drawing.Bitmap]::new((Join-Path $dir 'NEUTRALSTUDIO.png'))
foreach ($id in 'STUDIOMK','STUDIOREEL') {
    $atlas = [Drawing.Bitmap]::new(1500,296)
    $g = [Drawing.Graphics]::FromImage($atlas)
    $frames = @()
    foreach ($i in 0..11) {
        $x = ($i % 6)*250; $y = [math]::Floor($i/6)*148
        $frames += @{x=$x;y=$y;w=250;h=148}
        $g.ResetTransform(); $g.TranslateTransform($x,$y)
        if ($id -eq 'STUDIOMK') {
            $height = 14 + [math]::Round(134*$i/11)
            $g.DrawImage($body,[Drawing.Rectangle]::new(0,148-$height,250,$height))
        } else {
            foreach ($reel in @(@(102,43,3,5),@(111,49,3,4))) {
                $g.FillEllipse([Drawing.Brushes]::DarkGoldenrod,$reel[0]-$reel[2],$reel[1]-$reel[3],2*$reel[2],2*$reel[3])
                foreach ($hole in 0..2) {
                    $a=2*[math]::PI*($i/36+$hole/3)
                    $px=$reel[0]+[math]::Cos($a)*1.8; $py=$reel[1]+[math]::Sin($a)*3
                    $g.FillEllipse([Drawing.Brushes]::Black,[single]($px-1),[single]($py-1),[single]2,[single]2)
                }
            }
            $brush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb([int](64+45*[math]::Sin(2*[math]::PI*$i/12)),255,195,80))
            $g.FillPolygon($brush,[Drawing.Point[]]@([Drawing.Point]::new(95,77),[Drawing.Point]::new(118,88),[Drawing.Point]::new(118,108),[Drawing.Point]::new(95,96)))
            $brush.Dispose()
        }
    }
    $atlas.Save((Join-Path $dir "$id.png"),[Drawing.Imaging.ImageFormat]::Png)
    @{id=$id;cell=@(250,148);count=12;dmg=1;rects=$frames}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $dir "$id.json") -Encoding utf8
    $g.Dispose();$atlas.Dispose()
}
$body.Dispose()
