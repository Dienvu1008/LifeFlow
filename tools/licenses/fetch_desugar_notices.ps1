# ADR-0035: fetches the license notices of desugar_jdk_libs (Android core
# library desugaring) from its official repository, at a pinned commit, into
# the app's assets, and checks their SHA-256. The files are copied unchanged:
# the license requires its notices to travel with the app.
#
# Run from the repository root:  powershell -File tools/licenses/fetch_desugar_notices.ps1
# Re-run (and update $commit and the hashes after review) when the pinned
# version of desugar_jdk_libs changes.
$ErrorActionPreference = 'Stop'
$commit = 'ec1741f99ecc2c6595cd91e8f2c0f8298af03eed'  # google/desugar_jdk_libs master, 2026-11-02
$files = [ordered]@{
  'LICENSE'                 = '4b9abebc4338048a7c2dc184e9f800deb349366bdf28eb23c2677a77b4c87726'
  'ASSEMBLY_EXCEPTION'      = 'a44eb7b5caf5534c6ef536b21edb40b4d6babf91bf97d9d45596868618b2c6fb'
  'ADDITIONAL_LICENSE_INFO' = 'a69bce275ba7a3570af6579cb0f55682cd75fedfcd49e0e8e9022270c447c916'
}
$dest = 'apps/lifeflow_app/assets/licenses/desugar_jdk_libs'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($name in @($files.Keys)) {
  $url = "https://raw.githubusercontent.com/google/desugar_jdk_libs/$commit/$name"
  $out = Join-Path $dest $name
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
  $hash = (Get-FileHash -Algorithm SHA256 $out).Hash.ToLower()
  $expected = $files[$name]
  if ($expected -and $expected -ne $hash) { throw "$name changed: $hash (expected $expected)" }
  "$name $hash"
}
"Source: https://github.com/google/desugar_jdk_libs/tree/$commit" | Set-Content -Encoding utf8 (Join-Path $dest 'SOURCE')
