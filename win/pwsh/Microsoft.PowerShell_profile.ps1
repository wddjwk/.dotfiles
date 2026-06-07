# ==============================================
#  PowerShell 主配置
# ==============================================

# Set-Variable PROXY_URL "http://192.168.31.102:7890"

# $env:HTTP_PROXY = $PROXY_URL
# $env:HTTPS_PROXY = $PROXY_URL
$env:EDITOR = 'subl.exe'
$env:SHELL = 'pwsh.exe'

# ========== 配置文件编辑 ==========

function Invoke-Editor {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$args)
    & $env:EDITOR @args
}

function Edit-MainProfile { Invoke-Editor $PROFILE }
function Edit-LocalProfile { Invoke-Editor (Join-Path (Split-Path $PROFILE) 'local_profile.ps1') }
function Edit-EnvProfile { Invoke-Editor (Join-Path (Split-Path $PROFILE) 'env_profile.ps1') }

Set-Alias -Name vimb  -Value Edit-MainProfile
Set-Alias -Name vima  -Value Edit-MainProfile
Set-Alias -Name vimal -Value Edit-LocalProfile
Set-Alias -Name vime  -Value Edit-EnvProfile
Set-Alias -Name sb    -Value $PROFILE

# ==============================================
#  常用别名
# ==============================================

# ========== Remove PowerShell built-in aliases conflicting with coreutils ==========
# ========== [NEED] scoop installuutils-coreutils ==========
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
#  快捷键映射
# ==============================================

Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function ForwardDeleteLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine

# ==============================================
#  常用函数
# ==============================================

function proxy {
    $env:HTTP_PROXY = $PROXY_URL
    $env:HTTPS_PROXY = $PROXY_URL
    if ($args.Count -gt 0) {
        $cmd = $args[0]
        $rest = $args[1..($args.Count - 1)]
        & $cmd @rest
    }
}

function noproxy {
    $old = @{
        HTTP_PROXY  = $env:HTTP_PROXY
        HTTPS_PROXY = $env:HTTPS_PROXY
        ALL_PROXY   = $env:ALL_PROXY
    }
    Remove-Item Env:\HTTP_PROXY, Env:\HTTPS_PROXY, Env:\http_proxy, Env:\https_proxy, Env:\ALL_PROXY, Env:\all_proxy -ErrorAction SilentlyContinue
    if ($args.Count -gt 0) {
        $cmd = $args[0]
        $rest = $args[1..($args.Count - 1)]
        & $cmd @rest
    }
    foreach ($k in $old.Keys) {
        if ($null -ne $old[$k]) { Set-Item "Env:\$k" $old[$k] }
    }
}

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

# ========== 基础变量 ==========
Set-Variable ESC "$([char]27)"
Set-Variable ANSI_RESET "$ESC[0m"

# ========== 基础颜色 ==========
Set-Variable ANSI_BLACK "$ESC[30m"
Set-Variable ANSI_RED "$ESC[31m"
Set-Variable ANSI_GREEN "$ESC[32m"
Set-Variable ANSI_YELLOW "$ESC[33m"
Set-Variable ANSI_BLUE "$ESC[34m"
Set-Variable ANSI_MAGENTA "$ESC[35m"
Set-Variable ANSI_CYAN "$ESC[36m"
Set-Variable ANSI_WHITE "$ESC[37m"

# ========== 亮色模式 ==========
Set-Variable ANSI_BRIGHT_BLACK "$ESC[90m"
Set-Variable ANSI_BRIGHT_RED "$ESC[91m"
Set-Variable ANSI_BRIGHT_GREEN "$ESC[92m"
Set-Variable ANSI_BRIGHT_YELLOW "$ESC[93m"
Set-Variable ANSI_BRIGHT_BLUE "$ESC[94m"
Set-Variable ANSI_BRIGHT_MAGENTA "$ESC[95m"
Set-Variable ANSI_BRIGHT_CYAN "$ESC[96m"
Set-Variable ANSI_BRIGHT_WHITE "$ESC[97m"

# ========== 背景颜色 ==========
Set-Variable ANSI_BG_BLACK "$ESC[40m"
Set-Variable ANSI_BG_RED "$ESC[41m"
Set-Variable ANSI_BG_GREEN "$ESC[42m"
Set-Variable ANSI_BG_YELLOW "$ESC[43m"
Set-Variable ANSI_BG_BLUE "$ESC[44m"
Set-Variable ANSI_BG_MAGENTA "$ESC[45m"
Set-Variable ANSI_BG_CYAN "$ESC[46m"
Set-Variable ANSI_BG_WHITE "$ESC[47m"

# ========== 256色扩展 ==========
Set-Variable ANSI_ORANGE "$ESC[38;5;208m"
Set-Variable ANSI_PURPLE "$ESC[38;5;93m"
Set-Variable ANSI_PINK "$ESC[38;5;205m"
Set-Variable ANSI_LIME "$ESC[38;5;154m"
Set-Variable ANSI_GRAY "$ESC[38;5;245m"

# ========== RGB自定义颜色 ==========
Set-Variable ANSI_RGB_EMERALD "$ESC[38;2;80;200;120m"
Set-Variable ANSI_RGB_SUNSET "$ESC[38;2;255;94;77m"
Set-Variable ANSI_RGB_OCEAN "$ESC[38;2;0;155;255m"

# ========== 格式样式 ==========
Set-Variable ANSI_BOLD "$ESC[1m"
Set-Variable ANSI_DIM "$ESC[2m"
Set-Variable ANSI_ITALIC "$ESC[3m"
Set-Variable ANSI_UNDERLINE "$ESC[4m"
Set-Variable ANSI_BLINK "$ESC[5m"

# ==============================================
#  加载本地配置 (路径相关的别名与函数)
# ==============================================

$envProfile = Join-Path (Split-Path $PROFILE) "env_profile.ps1"
if (Test-Path $envProfile) { . $envProfile }

$localProfile = Join-Path (Split-Path $PROFILE) "local_profile.ps1"
if (Test-Path $localProfile) { . $localProfile }
