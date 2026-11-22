# ADR-0075: fetches the license notices of the PDFium binary that pdfrx uses
# (downloaded at build time by pdfium_dart's build hook) into the app's assets.
# The archives are the ones pdfium_dart pins (bblanchon/pdfium-binaries); each
# is checked against pdfium_dart's own SHA-256 before its licenses/ folder is
# read. The notice files are copied unchanged (the licenses ask for it).
#
# The app ships the Windows x64 and the Android arm, arm64 and x64 archives.
# They do not carry the same set of notices (Android adds a few), so the
# notices of all four are kept. A notice with the same name must have the same
# text in every archive (line endings aside), or the script stops.
#
# SOURCE records the pdfium_dart version, the release and, for each notice,
# the SHA-256 of its text with LF line endings; FF-ARCH-07 checks them.
#
# Run from the repository root:  powershell -File tools/licenses/fetch_pdfium_notices.ps1
# Re-run (and update $pdfiumDart, $release and the hashes after reading the
# licenses again, ADR-0075) when the locked version of pdfium_dart changes.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$pdfiumDart = '0.4.3'
$release = 'chromium/8125'
# From pdfium_dart 0.4.3 lib/src/pdfium_archive_integrity.dart.
$archives = [ordered]@{
  'pdfium-win-x64.tgz'       = '9a964261760cff52570aabf038ab346d3a5034dd8b30d0d5fe8861235d356b8b'
  'pdfium-android-arm.tgz'   = 'ac4ac5319ded88ba5d885747a6b2641e7f712c9797de0770465104abe4dbf7da'
  'pdfium-android-arm64.tgz' = '0495e57163429937caaee1bdd9b07924a7098dbd51d1b97645d124e349f097b4'
  'pdfium-android-x64.tgz'   = 'bd68707f29f2316c20f9d5c793b8731796a4a65408ac4d3c30bc606390354e41'
}
$dest = 'apps/lifeflow_app/assets/licenses/pdfium'
$work = Join-Path ([System.IO.Path]::GetTempPath()) 'lifeflow-pdfium-notices'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force -Path $work | Out-Null

function TextHash([string] $path) {
  $text = [System.IO.File]::ReadAllText($path) -replace "`r`n", "`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

$notices = @{}  # file name -> @{ hash; path; from }
foreach ($name in @($archives.Keys)) {
  $url = "https://github.com/bblanchon/pdfium-binaries/releases/download/$([uri]::EscapeDataString($release))/$name"
  $tgz = Join-Path $work $name
  Invoke-WebRequest -Uri $url -OutFile $tgz -UseBasicParsing
  $hash = (Get-FileHash -Algorithm SHA256 $tgz).Hash.ToLower()
  if ($hash -ne $archives[$name]) { throw "$name changed: $hash (expected $($archives[$name]))" }
  $out = Join-Path $work ($name -replace '\.tgz$', '')
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  tar -xzf $tgz -C $out
  if ($LASTEXITCODE -ne 0) { throw "could not unpack $name" }
  $files = @(Get-ChildItem (Join-Path $out 'licenses') -File)
  if ($files.Count -eq 0) { throw "$name has no licenses/ folder" }
  foreach ($f in $files) {
    $h = TextHash $f.FullName
    $seen = $notices[$f.Name]
    if ($null -eq $seen) {
      $notices[$f.Name] = @{ hash = $h; path = $f.FullName; from = $name }
    } elseif ($seen.hash -ne $h) {
      throw "$($f.Name) differs between $($seen.from) and ${name}: read both (ADR-0075)"
    }
  }
  "$name $hash, $($files.Count) notices"
}

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$names = @($notices.Keys | Sort-Object)
foreach ($n in $names) { Copy-Item $notices[$n].path (Join-Path $dest $n) }
$lines = @(
  "pdfium_dart $pdfiumDart",
  "release $release",
  "https://github.com/bblanchon/pdfium-binaries/releases/tag/$release"
) + @($names | ForEach-Object { "notice $_ $($notices[$_].hash)" })
[System.IO.File]::WriteAllText((Join-Path (Resolve-Path $dest) 'SOURCE'), (($lines -join "`n") + "`n"))
Remove-Item -Recurse -Force $work
"$($names.Count) notices in $dest"
