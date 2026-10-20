# ADF (Atlassian Document Format) -> Markdown converter. Dot-source this file.
# Extracted unchanged from the original .jira/fetch-ticket.ps1.

# Helper function to convert ADF (Atlassian Document Format) to Markdown
function Convert-AdfToMarkdown($node, $indent = "") {
    if ($null -eq $node) { return "" }
    if ($node -is [string]) { return $node }
    
    # In PowerShell, checking if object has property "type"
    if ($null -eq $node.type) {
        return ""
    }
    
    $type = $node.type
    $result = ""
    
    switch ($type) {
        "doc" {
            if ($node.content) {
                foreach ($child in $node.content) {
                    $result += $(Convert-AdfToMarkdown $child $indent) + "`n`n"
                }
            }
        }
        "paragraph" {
            $pText = ""
            if ($node.content) {
                foreach ($child in $node.content) {
                    $pText += $(Convert-AdfToMarkdown $child $indent)
                }
            }
            $result = $pText
        }
        "heading" {
            $level = 1
            if ($null -ne $node.attrs -and $null -ne $node.attrs.level) {
                $level = $node.attrs.level
            }
            $hashes = "#" * $level
            $text = ""
            if ($node.content) {
                foreach ($child in $node.content) {
                    $text += $(Convert-AdfToMarkdown $child $indent)
                }
            }
            $result = "$hashes $text"
        }
        "text" {
            $text = $node.text
            if ($null -ne $node.marks) {
                foreach ($mark in $node.marks) {
                    if ($mark.type -eq "strong") { $text = "**$text**" }
                    elseif ($mark.type -eq "em") { $text = "*$text*" }
                    elseif ($mark.type -eq "strike") { $text = "~~$text~~" }
                    elseif ($mark.type -eq "code") { $text = '`' + $text + '`' }
                    elseif ($mark.type -eq "link" -and $null -ne $mark.attrs -and $null -ne $mark.attrs.href) { 
                        $text = "[$text]($($mark.attrs.href))" 
                    }
                }
            }
            $result = $text
        }
        "bulletList" {
            if ($node.content) {
                foreach ($child in $node.content) {
                    $result += $(Convert-AdfToMarkdown $child $indent) + "`n"
                }
            }
        }
        "orderedList" {
            $i = 1
            if ($node.content) {
                foreach ($child in $node.content) {
                    $result += $(Convert-ListItemToMarkdown $child $indent "$i. ") + "`n"
                    $i++
                }
            }
        }
        "listItem" {
            $result = Convert-ListItemToMarkdown $node $indent "- "
        }
        "codeBlock" {
            $lang = ""
            if ($null -ne $node.attrs -and $null -ne $node.attrs.language) {
                $lang = $node.attrs.language
            }
            $code = ""
            if ($node.content) {
                foreach ($child in $node.content) {
                    if ($null -ne $child.text) {
                        $code += $child.text
                    }
                }
            }
            $result = "````$lang`n$code`n````"
        }
        "blockquote" {
            $quote = ""
            if ($node.content) {
                foreach ($child in $node.content) {
                    $quote += $(Convert-AdfToMarkdown $child $indent)
                }
            }
            $lines = $quote -split "`n"
            $quoteLines = @()
            foreach ($line in $lines) {
                $quoteLines += "> $line"
            }
            $result = $quoteLines -join "`n"
        }
        "rule" {
            $result = "---"
        }
        "hardBreak" {
            $result = "`n"
        }
        "inlineCard" {
            if ($null -ne $node.attrs -and $null -ne $node.attrs.url) {
                $result = "[$($node.attrs.url)]($($node.attrs.url))"
            }
        }
        "blockCard" {
            if ($null -ne $node.attrs -and $null -ne $node.attrs.url) {
                $result = "[$($node.attrs.url)]($($node.attrs.url))"
            }
        }
        "table" {
            if (-not $node.content) { return "" }
            $rows = $node.content
            $mdTable = ""
            $headersDone = $false
            
            foreach ($row in $rows) {
                if (-not $row.content) { continue }
                $cellStrings = @()
                $isHeaderRow = $true
                foreach ($cell in $row.content) {
                    if ($cell.type -ne "tableHeader") {
                        $isHeaderRow = $false
                    }
                    $cellText = ""
                    if ($cell.content) {
                        foreach ($child in $cell.content) {
                            $cellText += $(Convert-AdfToMarkdown $child $indent)
                        }
                    }
                    $cellText = $cellText.Replace("`r`n", "<br>").Replace("`n", "<br>")
                    $cellStrings += $cellText
                }
                
                $mdTable += "| " + ($cellStrings -join " | ") + " |`n"
                
                if ($isHeaderRow -and -not $headersDone) {
                    $separators = @()
                    for ($i = 0; $i -lt $cellStrings.Count; $i++) {
                        $separators += "---"
                    }
                    $mdTable += "| " + ($separators -join " | ") + " |`n"
                    $headersDone = $true
                }
            }
            
            # Fallback separator if headers were not explicitly marked
            if (-not $headersDone -and $rows.Count -gt 0 -and $rows[0].content) {
                $firstRowCols = $rows[0].content.Count
                $separators = @()
                for ($i = 0; $i -lt $firstRowCols; $i++) {
                    $separators += "---"
                }
                $lines = $mdTable -split "`n"
                if ($lines.Count -gt 0) {
                    $firstRowText = $lines[0]
                    $mdTable = $firstRowText + "`n| " + ($separators -join " | ") + " |`n"
                    for ($i = 1; $i -lt $rows.Count; $i++) {
                        if (-not $rows[$i].content) { continue }
                        $cellStrings = @()
                        foreach ($cell in $rows[$i].content) {
                            $cellText = ""
                            if ($cell.content) {
                                foreach ($child in $cell.content) {
                                    $cellText += $(Convert-AdfToMarkdown $child $indent)
                                }
                            }
                            $cellText = $cellText.Replace("`r`n", "<br>").Replace("`n", "<br>")
                            $cellStrings += $cellText
                        }
                        $mdTable += "| " + ($cellStrings -join " | ") + " |`n"
                    }
                }
            }
            $result = $mdTable
        }
        default {
            if ($node.content) {
                foreach ($child in $node.content) {
                    $result += $(Convert-AdfToMarkdown $child $indent)
                }
            }
        }
    }
    return $result
}

function Convert-ListItemToMarkdown($listItem, $indent, $prefix) {
    $output = ""
    $first = $true
    if ($listItem.content) {
        foreach ($block in $listItem.content) {
            $blockText = Convert-AdfToMarkdown $block "$indent    "
            if ($first) {
                $output += "$indent$prefix$blockText"
                $first = $false
            } else {
                if ($block.type -eq "bulletList" -or $block.type -eq "orderedList") {
                    $output += "`n$blockText"
                } else {
                    $output += "`n$indent    $blockText"
                }
            }
        }
    }
    return $output
}

