# Themed prompt with zero external dependencies -- no starship, no
# oh-my-posh, just a function override. Source this from $PROFILE.
function prompt {
    $esc = [char]27
    $accent = "$esc[38;2;128;0;0m"    # SYN_ACCENT #800000
    $dim    = "$esc[38;2;64;1;1m"     # SYN_PANEL_HOVER #400101
    $urgent = "$esc[38;2;255;85;85m"  # SYN_URGENT #ff5555
    $reset  = "$esc[0m"

    $lastSucceeded = $?
    $path = (Get-Location).Path
    if ($path.StartsWith($HOME)) {
        $path = "~" + $path.Substring($HOME.Length)
    }

    Write-Host "$dim[$accent$env:USERNAME$dim@$accent$env:COMPUTERNAME$dim]$reset " -NoNewline
    Write-Host "$accent$path$reset" -NoNewline

    $marker = if ($lastSucceeded) { "$accent>" } else { "$urgent>" }
    return " $marker$reset "
}
