<#
Merge Google Takeout JSON sidecars into media files with exiftool.

Fills gaps only: a field is written when the file has no value for it.
If the file's own date and the JSON date differ by more than a day, the file is
flagged in the report and its date is left alone.

Dry run by default. -Apply writes to COPIES in -Dest, never to -Src.

  .\merge_json.ps1 -Src "D:\Google Photos\Photos from 2014" -Dest D:\merge-test -Apply
#>
param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dest,
    [switch]$Apply,
    [string]$Report = "merge-report.csv"
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$media = '.jpg','.jpeg','.heic','.png','.gif','.mp4','.mov','.m4v','.3gp','.mod','.bmp'
$video = '.mp4','.mov','.m4v','.3gp','.mod'
$conflictSeconds = 86400

function Find-Sidecar([string]$path) {
    # Takeout truncates long names, so try the full name and then prefixes.
    $dir = Split-Path $path; $name = Split-Path $path -Leaf
    $stem = [IO.Path]::GetFileNameWithoutExtension($name); $ext = [IO.Path]::GetExtension($name)
    $cands = @("$name.supplemental-metadata.json", "$name.json")
    if ($stem -match '^(.*)\((\d+)\)$') {   # IMG(1).jpg -> IMG.jpg.supplemental-metadata(1).json
        $cands += "$($Matches[1])$ext.supplemental-metadata($($Matches[2])).json"
        $cands += "$($Matches[1])$ext($($Matches[2])).json"
    }
    foreach ($c in $cands) { $p = Join-Path $dir $c; if (Test-Path -LiteralPath $p) { return $p } }
    $full = ".supplemental-metadata"
    for ($cut = $full.Length; $cut -gt 3; $cut--) {
        $p = Join-Path $dir ("$name" + $full.Substring(0, $cut) + ".json")
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Parse-ExifDate($s) {
    if (-not $s -or "$s".StartsWith("0000")) { return $null }
    try { return [datetime]::ParseExact("$s".Substring(0, 19), "yyyy:MM:dd HH:mm:ss", $null) } catch { return $null }
}

$files = Get-ChildItem -LiteralPath $Src -File | Where-Object { $media -contains $_.Extension.ToLower() } | Sort-Object Name
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# one exiftool call reads existing values for the whole folder (via arg/out files to keep UTF-8 intact)
$tmp = Join-Path $Dest "_read"; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$listFile = Join-Path $tmp "list.txt"; $outFile = Join-Path $tmp "exif.json"
[IO.File]::WriteAllLines($listFile, [string[]]($files.FullName), $utf8)
cmd /c "exiftool -json -n -charset filename=utf8 -DateTimeOriginal -CreateDate -MediaCreateDate -GPSLatitude -ImageDescription -@ `"$listFile`" > `"$outFile`" 2>nul"
$exif = @{}
if ((Test-Path $outFile) -and (Get-Item $outFile).Length -gt 0) {
    foreach ($e in ([IO.File]::ReadAllText($outFile, $utf8) | ConvertFrom-Json)) {
        $exif[[IO.Path]::GetFileName($e.SourceFile)] = $e
    }
}

$rows = New-Object System.Collections.Generic.List[object]
$argLines = New-Object System.Collections.Generic.List[string]

foreach ($f in $files) {
    $info = $exif[$f.Name]
    $row = [ordered]@{ file = $f.Name; sidecar = $false; action = ""; note = ""; people = "" }
    $sc = Find-Sidecar $f.FullName
    if (-not $sc) { $row.action = "skip"; $row.note = "no JSON sidecar"; $rows.Add([pscustomobject]$row); continue }
    $row.sidecar = $true
    $j = [IO.File]::ReadAllText($sc, $utf8) | ConvertFrom-Json
    $taken = [DateTimeOffset]::FromUnixTimeSeconds([int64]$j.photoTakenTime.timestamp).UtcDateTime
    $ext = $f.Extension.ToLower()
    $have = $null
    if ($info) { $have = Parse-ExifDate ($(if ($info.DateTimeOriginal) { $info.DateTimeOriginal } elseif ($info.CreateDate) { $info.CreateDate } else { $info.MediaCreateDate })) }
    $a = New-Object System.Collections.Generic.List[string]; $notes = @()

    if ($null -eq $have) {
        $ts = $taken.ToString("yyyy:MM:dd HH:mm:ss")
        if ($video -contains $ext) { $a.Add("-QuickTime:CreateDate=$ts"); $a.Add("-QuickTime:MediaCreateDate=$ts"); $a.Add("-QuickTime:TrackCreateDate=$ts") }
        else { $a.Add("-DateTimeOriginal=$ts"); $a.Add("-CreateDate=$ts"); $a.Add("-XMP-photoshop:DateCreated=$ts") }
        $notes += "date filled from JSON ($ts UTC)"
    } elseif ([math]::Abs(($have - $taken).TotalSeconds) -gt $conflictSeconds) {
        $notes += "DATE CONFLICT file=$($have.ToString('yyyy-MM-dd')) json=$($taken.ToString('yyyy-MM-dd')), left alone"
    }

    $lat = [double]$j.geoData.latitude; $lon = [double]$j.geoData.longitude
    if (($lat -ne 0 -or $lon -ne 0) -and ($null -eq $info -or -not $info.GPSLatitude)) {
        $a.Add("-GPSLatitude=$lat"); $a.Add("-GPSLongitude=$lon")
        $a.Add("-GPSLatitudeRef=$(if ($lat -ge 0) {'N'} else {'S'})"); $a.Add("-GPSLongitudeRef=$(if ($lon -ge 0) {'E'} else {'W'})")
        if ([double]$j.geoData.altitude -ne 0) { $a.Add("-GPSAltitude=$($j.geoData.altitude)") }
        $notes += "GPS filled from JSON"
    }

    $desc = ("$($j.description)" -split '\s+' | Where-Object { $_ }) -join ' '
    if ($desc -and ($null -eq $info -or -not $info.ImageDescription)) {
        $a.Add("-ImageDescription=$desc"); $a.Add("-XMP-dc:Description=$desc"); $notes += "description filled from JSON"
    }

    $row.people = (@($j.people | ForEach-Object { $_.name } | Where-Object { $_ })) -join '; '
    $row.action = if ($a.Count) { "write" } else { "none" }
    $row.note = $notes -join ' | '
    $rows.Add([pscustomobject]$row)

    if ($a.Count -and $Apply) {
        $dst = Join-Path $Dest $f.Name
        Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
        foreach ($l in @("-charset","filename=utf8","-charset","exif=utf8","-overwrite_original") + $a + @($dst, "-execute")) { $argLines.Add($l) }
    }
}

if ($argLines.Count) {
    $af = Join-Path $tmp "args.txt"
    [IO.File]::WriteAllLines($af, $argLines.ToArray(), $utf8)
    & exiftool -@ $af | Out-Null
}
Remove-Item -LiteralPath $tmp -Recurse -Force

$rows | Export-Csv -Path $Report -NoTypeInformation -Encoding UTF8
$tally = ($rows | Group-Object action | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
$conf = ($rows | Where-Object { $_.note -like '*CONFLICT*' }).Count
"$($rows.Count) media files | $tally | date conflicts: $conf | report: $Report"
if ($Apply) { "APPLIED to copies in $Dest" } else { "DRY RUN: nothing written" }
