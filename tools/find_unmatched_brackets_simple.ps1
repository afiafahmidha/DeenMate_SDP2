$path = 'd:\GitHub\DeenMate_SDP2\lib\screens\calendar_tab.dart'
$lines = Get-Content $path
$stack = @()
for ($ln=0;$ln -lt $lines.Count; $ln++) {
  $line = $lines[$ln]
  for ($i=0; $i -lt $line.Length; $i++) {
    $c = $line[$i]
    switch ($c) {
      '{' { $stack += @{char='{'; line=$ln+1; col=$i+1} }
      '(' { $stack += @{char='('; line=$ln+1; col=$i+1} }
      '[' { $stack += @{char='['; line=$ln+1; col=$i+1} }
      '}' {
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '{') { $stack.RemoveAt($stack.Count-1) } else { }
      }
      ')' {
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '(') { $stack.RemoveAt($stack.Count-1) } else { }
      }
      ']' {
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '[') { $stack.RemoveAt($stack.Count-1) } else { }
      }
    }
  }
}
if ($stack.Count -eq 0) { Write-Host "All matched." }
else {
  Write-Host "Unmatched openings (top last):"
  foreach ($item in $stack) { Write-Host "$($item.char) opened at $($item.line):$($item.col)" }
}
