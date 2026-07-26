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
        if ($stack.Count -eq 0) { Write-Host "Unmatched closing } at $($ln+1):$($i+1)" }
        else {
          $top = $stack[-1]
          if ($top.char -ne '{') { Write-Host "Mismatched closing } at $($ln+1):$($i+1), expected closing for $($top.char) opened at $($top.line):$($top.col)"; $stack.RemoveAt($stack.Count-1) }
          else { $stack.RemoveAt($stack.Count-1) }
        }
      }
      ')' {
        if ($stack.Count -eq 0) { Write-Host "Unmatched closing ) at $($ln+1):$($i+1)" }
        else {
          $top = $stack[-1]
          if ($top.char -ne '(') { Write-Host "Mismatched closing ) at $($ln+1):$($i+1), expected closing for $($top.char) opened at $($top.line):$($top.col)"; $stack.RemoveAt($stack.Count-1) }
          else { $stack.RemoveAt($stack.Count-1) }
        }
      }
      ']' {
        if ($stack.Count -eq 0) { Write-Host "Unmatched closing ] at $($ln+1):$($i+1)" }
        else {
          $top = $stack[-1]
          if ($top.char -ne '[') { Write-Host "Mismatched closing ] at $($ln+1):$($i+1), expected closing for $($top.char) opened at $($top.line):$($top.col)"; $stack.RemoveAt($stack.Count-1) }
          else { $stack.RemoveAt($stack.Count-1) }
        }
      }
    }
  }
}
if ($stack.Count -eq 0) { Write-Host "All matched." }
else {
  Write-Host "Unmatched openings (top last):"
  foreach ($item in $stack) { Write-Host "$($item.char) opened at $($item.line):$($item.col)" }
}
