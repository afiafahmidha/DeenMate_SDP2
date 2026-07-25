$path = 'd:\GitHub\DeenMate_SDP2\lib\screens\prayer_tab.dart'
$content = [System.IO.File]::ReadAllText($path)

# We need to close the _DarkModeScope which wraps the Column.
# The Column closes with:   ],\r\n    );\r\n  }\r\n}
# We need to add  ),\r\n    before the final );
$old = "      ],`r`n    );`r`n  }`r`n}`r`n`r`n/// Consistent"
$new = "      ],`r`n    ),`r`n    );`r`n  }`r`n}`r`n`r`n/// Consistent"

if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    [System.IO.File]::WriteAllText($path, $content)
    Write-Host "Done - scope closed successfully"
} else {
    Write-Host "Pattern not found - checking content around line 993..."
    $lines = $content -split "`r`n"
    for ($i = 990; $i -lt 998; $i++) {
        Write-Host "Line $($i+1): [$($lines[$i])]"
    }
}
