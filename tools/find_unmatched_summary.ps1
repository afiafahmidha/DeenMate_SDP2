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
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '{') { $stack.RemoveAt($stack.Count-1) }
      }
      ')' {
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '(') { $stack.RemoveAt($stack.Count-1) }
      }
      ']' {
        if ($stack.Count -gt 0 -and $stack[-1].char -eq '[') { $stack.RemoveAt($stack.Count-1) }
      }
    }
  }
}
$openCount = $stack | Group-Object -Property char | ForEach-Object { [PSCustomObject]@{char=$_.Name;count=$_.Count} }
Write-Host "Unmatched counts:"
$openCount | ForEach-Object { Write-Host "$($_.char): $($_.count)" }
Write-Host "Top unmatched (last 20):"
$stack[-20..-1] | ForEach-Object { Write-Host "$($_.char) opened at $($_.line):$($_.col)" }
