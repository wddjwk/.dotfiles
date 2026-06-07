# ==============================================
#  PowerShell 主配置
# ==============================================

# ========== 编辑器 ==========
$env:EDITOR = 'subl.exe'

function Invoke-Editor {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$args)
    & $env:EDITOR @args
}

# ========== 配置文件编辑 ==========

function Edit-MainProfile { Invoke-Editor $PROFILE }
function Edit-LocalProfile { Invoke-Editor (Join-Path (Split-Path $PROFILE) 'local_profile.ps1') }
function Edit-EnvProfile { Invoke-Editor (Join-Path (Split-Path $PROFILE) 'env_profile.ps1') }

Set-Alias -Name vimb  -Value Edit-MainProfile
Set-Alias -Name vima  -Value Edit-MainProfile
Set-Alias -Name vimal -Value Edit-LocalProfile
Set-Alias -Name vime  -Value Edit-EnvProfile
Set-Alias -Name sb    -Value $PROFILE

# ==============================================
#  快捷键映射
# ==============================================

Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function ForwardDeleteLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine

# ==============================================
#  常用别名
# ==============================================

# ========== Remove PowerShell built-in aliases conflicting with coreutils ==========
# ========== scoop installuutils-coreutils ==========
foreach ($cmd in @('cat', 'cp', 'dir', 'echo', 'ls', 'mv', 'pwd', 'rm', 'rmdir', 'sleep', 'sort', 'tee')) {
    Remove-Alias -Name $cmd -Force -ErrorAction SilentlyContinue
}

Set-Alias -Name ls -Value lsd.exe
Set-Alias -Name cd -Value Set-Location-Unix -Option AllScope
Set-Alias -Name du -Value dust.exe
Set-Alias -Name df -Value duf.exe
Set-Alias -Name y -Value yazi

function ll { ls -alhF }

Set-Alias -Name vim  -Value Invoke-Editor
Set-Alias -Name fvim -Value fedit
Set-Alias -Name rvim -Value redit


# ==============================================
#  常用函数
# ==============================================

function Set-Location-Unix {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$args)

    $target = if ($args.Count -eq 0) { $HOME }
    elseif ($args.Count -eq 1 -and $args[0] -eq '-') {
        if ($env:OLDPWD) { $env:OLDPWD } else { Write-Error "cd: OLDPWD not set"; return 1 }
    }
    else { $args[0] }

    $oldPwd = (Get-Location).Path

    try {
        if ((Test-Path -LiteralPath $target -PathType Leaf) -and -not (Test-Path -LiteralPath $target -PathType Container)) {
            $fullPath = (Resolve-Path -LiteralPath $target).Path
            $parent = Split-Path -Parent $fullPath
            if (-not $parent) { $parent = (Get-Location).Path }
            Set-Location -LiteralPath $parent -ErrorAction Stop
        }
        else {
            Set-Location -LiteralPath $target -ErrorAction Stop
        }
    }
    catch {
        Write-Error "cd: ${target}: $_"; return 1
    }

    $env:OLDPWD = $oldPwd

    $searchDir = (Get-Location).Path
    $venvPath = $null
    while ($searchDir) {
        $root = [IO.Path]::GetPathRoot($searchDir)
        $dockerVenv = Join-Path $searchDir '.venv-docker'
        $stdVenv = Join-Path $searchDir '.venv'
        if ($env:USERNAME -eq 'user' -and
            ((Test-Path (Join-Path $dockerVenv 'bin/activate')) -or
            (Test-Path (Join-Path $dockerVenv 'Scripts/Activate.ps1')))) {
            $venvPath = $dockerVenv; break
        }
        if ((Test-Path (Join-Path $stdVenv 'bin/activate')) -or
            (Test-Path (Join-Path $stdVenv 'Scripts/Activate.ps1'))) {
            $venvPath = $stdVenv; break
        }
        if ($searchDir -eq $root) { break }
        $searchDir = Split-Path -Parent $searchDir
    }

    if ($venvPath) {
        if (-not $env:VIRTUAL_ENV -or $env:VIRTUAL_ENV -ne $venvPath) {
            $activate = Join-Path $venvPath 'Scripts/Activate.ps1'
            if (-not (Test-Path $activate)) {
                $activate = Join-Path $venvPath 'bin/activate.ps1'
            }
            if (Test-Path $activate) { . $activate }
        }
    }
    elseif ($env:VIRTUAL_ENV -and (Get-Command deactivate -ErrorAction SilentlyContinue)) {
        deactivate
    }
}

function fcd {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$args
    )
    $selected = fd @args -uu --exclude "software" | fzf +m
    if (-not $selected) {
        Write-Host "${ANSI_RGB_SUNSET}No selection made.$ANSI_RGB_EMERALD"
        return
    }
    if (Test-Path -Path $selected -PathType Container) {
        Set-Location $selected
    }
    else {
        Set-Location (Split-Path -Parent $selected)
    }
}

function fedit {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$args
    )
    $selected = fd @args -uu --exclude "software" | fzf +m
    if (-not $selected) {
        Write-Host "${ANSI_RGB_SUNSET}No selection made.$ANSI_RGB_EMERALD"
        return
    }
    Invoke-Editor $selected
}

function redit {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$args
    )
    $selected = rg -l @args | fzf +m
    if (-not $selected) {
        Write-Host "${ANSI_RGB_SUNSET}No selection made.$ANSI_RGB_EMERALD"
        return
    }
    Invoke-Editor $selected
}

# ==============================================
#  命令提示符主题
# ==============================================

function global:prompt {
    $userColor = $ANSI_BRIGHT_YELLOW
    $atColor = $ANSI_RGB_SUNSET
    $hostColor = $ANSI_BRIGHT_YELLOW
    $pathColor = $ANSI_BRIGHT_CYAN
    $bracketColor = $ANSI_BRIGHT_GREEN
    $promptColor = $ANSI_BRIGHT_BLUE

    $user = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    $currentPath = (Get-Location).Path.Replace($HOME, '~')

    "$bracketColor[$userColor$user$atColor@$hostColor$hostname " +
    "$pathColor$currentPath$bracketColor]$promptColor`$$ANSI_RESET "
}

# ==============================================
#  加载本地配置 (路径相关的别名与函数)
# ==============================================

$envProfile = Join-Path (Split-Path $PROFILE) "env_profile.ps1"
if (Test-Path $envProfile) { . $envProfile }

$localProfile = Join-Path (Split-Path $PROFILE) "local_profile.ps1"
if (Test-Path $localProfile) { . $localProfile }
