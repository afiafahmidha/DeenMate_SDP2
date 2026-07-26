$path = 'd:\GitHub\DeenMate_SDP2\lib\screens\calendar_tab.dart'
$lines = Get-Content $path
$stack = New-Object System.Collections.ArrayList
for ($ln=0;$ln -lt $lines.Count; $ln++) {
  $line = $lines[$ln]
  for ($i=0; $i -lt $line.Length; $i++) {
    $c = $line[$i]
    switch ($c) {
      '{' { $stack.Add(@{char='{'; line=$ln+1; col=$i+1}) | Out-Null }
      '(' { $stack.Add(@{char='('; line=$ln+1; col=$i+1}) | Out-Null }
      '[' { $stack.Add(@{char='['; line=$ln+1; col=$i+1}) | Out-Null }
      '}' {
        if ($stack.Count -gt 0 -and $stack[$stack.Count-1].char -eq '{') { $stack.RemoveAt($stack.Count-1) }
      }
      ')' {
        if ($stack.Count -gt 0 -and $stack[$stack.Count-1].char -eq '(') { $stack.RemoveAt($stack.Count-1) }
      }
      ']' {
        if ($stack.Count -gt 0 -and $stack[$stack.Count-1].char -eq '[') { $stack.RemoveAt($stack.Count-1) }
      }
    }
  }
}
$group = @{}
foreach ($item in $stack) { $group[$item.char] = ($group[$item.char] + 1) }
Write-Host "Unmatched counts:"
$group.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }
Write-Host "Top unmatched (last 20):"
$start = [Math]::Max(0, $stack.Count-20)
for ($i=$start; $i -lt $stack.Count; $i++) { $item = $stack[$i]; Write-Host "$($item.char) opened at $($item.line):$($item.col)" }
