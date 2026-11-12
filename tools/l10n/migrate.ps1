# P03 UX U1: moves the strings of the given UI files to the ARB file, then
# repairs const / context errors until `flutter analyze` is clean (or
# stops changing). Run from the repository root:
#   powershell -File tools/l10n/migrate.ps1 packages/ui/lib/src/screens/x.dart ...
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
$ErrorActionPreference = 'Continue'
dart run tools/l10n/migrate_strings.dart extract @Files
Push-Location packages/ui
flutter gen-l10n 2>&1 | Out-Null
$out = Join-Path $env:TEMP 'l10n_analyze.txt'
for ($i = 0; $i -lt 8; $i++) {
  flutter analyze --no-pub 2>&1 | Out-File -Encoding utf8 $out
  $errors = (Select-String -Path $out -Pattern '^\s*error - ').Count
  "round $i : $errors errors"
  if ($errors -eq 0) { break }
  Pop-Location
  $r = dart run tools/l10n/migrate_strings.dart fix $out
  $r
  Push-Location packages/ui
  if ($r -match 'fixes: 0') { break }
}
Select-String -Path $out -Pattern '^\s*error - ' | Select-Object -First 15 | ForEach-Object { $_.Line.Trim() }
Pop-Location
