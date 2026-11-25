# ADR-0084: fetches the license notices of the llama.cpp runtime that
# llamadart's build hook downloads (leehack/llamadart-native, pinned by
# llamadart) into the app's assets. The runtime is built from llama.cpp and
# the code it vendors; each text is taken from the source at the exact commit
# the release was built from, and copied unchanged (the licenses ask for it).
# For code that carries its license inside a header (stb_image, miniaudio,
# subprocess.h), the license block of that header is taken as it is.
#
# SOURCE records the llamadart version, the release and, for each notice, the
# SHA-256 of its text with LF line endings; FF-ARCH-07 checks them.
#
# Run from the repository root:  powershell -File tools/licenses/fetch_llamacpp_notices.ps1
# Re-run (and update the pins after reading the licenses again, ADR-0084)
# when the locked version of llamadart changes.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$llamadart = '0.20.6'
$release = 'v1.0.0-4'                                      # leehack/llamadart-native, pinned by llamadart 0.20.6
$llamacpp = 'b1b770d90d94cad9e9ea5b993bdbc383a522fb28'     # its third_party/llama.cpp
$vulkan = '49f1a381e2aec33ef32adf4a377b5a39ec016ec4'       # its third_party/Vulkan-Headers
$spirv = 'ad9184e76a66b1001c29db9b0a3e87f646c64de0'        # its third_party/SPIRV-Headers
$dest = 'apps/lifeflow_app/assets/licenses/llamacpp'

function Raw([string] $repo, [string] $ref, [string] $path) {
  (Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/$repo/$ref/$path").Content
}
function Block([string] $text, [string] $from, [string] $to, [string] $after = '') {
  $text = $text -replace "`r`n", "`n"
  $a = $text.IndexOf($from)
  if ($a -lt 0) { throw "not found: $from" }
  $s = if ($after) { $text.IndexOf($after, $a) } else { $a }
  if ($s -lt 0) { throw "not found: $after" }
  $b = $text.IndexOf($to, $s)
  if ($b -lt 0) { throw "not found: $to" }
  $text.Substring($a, $b + $to.Length - $a)
}

$notices = [ordered]@{
  'llama.cpp.txt'          = Raw 'ggml-org/llama.cpp' $llamacpp 'LICENSE'
  'llamadart-native.txt'   = Raw 'leehack/llamadart-native' $release 'LICENSE'
  'cpp-httplib.txt'        = Raw 'ggml-org/llama.cpp' $llamacpp 'vendor/cpp-httplib/LICENSE'
  'nlohmann-json.txt'      = Raw 'ggml-org/llama.cpp' $llamacpp 'licenses/LICENSE-jsonhpp'
  'stb_image.txt'          = Block (Raw 'ggml-org/llama.cpp' $llamacpp 'vendor/stb/stb_image.h') 'This software is available under 2 licenses' 'SOFTWARE.' 'ALTERNATIVE B'
  'miniaudio.txt'          = Block (Raw 'ggml-org/llama.cpp' $llamacpp 'vendor/miniaudio/miniaudio.h') 'This software is available as a choice of the following licenses' 'SOFTWARE.' 'ALTERNATIVE 2'
  'subprocess.h.txt'       = Block (Raw 'ggml-org/llama.cpp' $llamacpp 'vendor/sheredom/subprocess.h') 'This is free and unencumbered software released into the public domain.' 'http://unlicense.org/>'
  'vulkan-headers.md'      = Raw 'KhronosGroup/Vulkan-Headers' $vulkan 'LICENSE.md'
  'vulkan-headers-Apache-2.0.txt' = Raw 'KhronosGroup/Vulkan-Headers' $vulkan 'LICENSES/Apache-2.0.txt'
  'spirv-headers.txt'      = Raw 'KhronosGroup/SPIRV-Headers' $spirv 'LICENSE'
}

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$sha = [System.Security.Cryptography.SHA256]::Create()
$lines = @("llamadart $llamadart", "release $release", "https://github.com/leehack/llamadart-native/releases/tag/$release", "llama.cpp $llamacpp")
foreach ($name in $notices.Keys) {
  $text = ($notices[$name] -replace "`r`n", "`n").TrimEnd() + "`n"
  $path = Join-Path $dest $name
  [System.IO.File]::WriteAllText((Join-Path (Resolve-Path $dest) $name), $text, [System.Text.UTF8Encoding]::new($false))
  $hash = ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString('x2') }) -join ''
  $lines += "notice $name $hash"
}
[System.IO.File]::WriteAllText((Join-Path (Resolve-Path $dest) 'SOURCE'), (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Output "wrote $($notices.Count) notices to $dest"
