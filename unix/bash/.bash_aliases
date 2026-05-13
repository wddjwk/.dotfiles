# tools
alias ll='ls -alhF --color=auto'
alias la='ls -aF --color=auto'
alias l='ls -ahF --color=none'
alias gdb='gdb -q'

# git
alias gitc='git checkout'
alias gitl='git log'
alias gitlg='git log --graph'
alias gitlo='git log --oneline'
alias gitlog='git log --oneline --graph'
alias gitloga='git log --oneline --graph --all'
alias gitrebase='git rebase --interactive --autostash --keep-empty --no-autosquash --rebase-merges'
alias gitpullorigin='git pull origin $(git branch --show-current)'
function gitcheckoutremote() {
    git checkout --track origin/"$1"
}

# convinence
alias PATH='echo $PATH | xargs -d: -n1'
alias cman='man -M /usr/share/man/zh_CN'
alias sb='source ~/.bashrc'
alias sz='source ~/.zshrc'
alias sv='source ~/.vimrc > /dev/null 2>&1'
alias vimb='vim ~/.bashrc'
alias vimz='vim ~/.zshrc'
alias vimv='vim ~/.vimrc'
alias vima='vim ~/.bash_aliases'
alias vimal='vim ~/.bash_aliases_local'
alias vime='vim ~/.bash_env'

alias fzf='fzf --ansi --smart-case'
alias fzf-view="fzf --preview-window=up --preview='bat --color always {}'"
alias today='date "+%Y%m%d"'
alias now='date "+%Y-%m-%d %H:%M:%S"'
alias timestamp='date +%s'


# 彩色的less（彩色man手册）
export LESS_TERMCAP_mb=$'\e[01;31m'    # 开始加粗（红色）
export LESS_TERMCAP_md=$'\e[01;31m'    # 加粗（红色）
export LESS_TERMCAP_me=$'\e[0m'        # 结束加粗
export LESS_TERMCAP_so=$'\e[01;44;33m' # 高亮背景（黄色文字，蓝色背景）
export LESS_TERMCAP_se=$'\e[0m'        # 结束高亮
export LESS_TERMCAP_us=$'\e[01;32m'    # 下划线（绿色）
export LESS_TERMCAP_ue=$'\e[0m'        # 结束下划线
export LESS_TERMCAP_mr=$'\e[01;31m'    # 反显（红色）
export LESS_TERMCAP_mh=$'\e[01;34m'    # 半高亮（蓝色）

# ANSI 颜色
ANSI_RESET="\e[0m"
ANSI_BOLD="\e[1m"
ANSI_DIM="\e[2m"
ANSI_ITALIC="\e[3m"
ANSI_UNDERLINE="\e[4m"
ANSI_BLINK="\e[5m"

ANSI_BG_BLACK="\e[40m"
ANSI_BG_BLUE="\e[44m"
ANSI_BG_CYAN="\e[46m"
ANSI_BG_GREEN="\e[42m"
ANSI_BG_MAGENTA="\e[45m"
ANSI_BG_RED="\e[41m"
ANSI_BG_WHITE="\e[47m"
ANSI_BG_YELLOW="\e[43m"
ANSI_FG_BLACK="\e[30m"
ANSI_FG_BLUE="\e[34m"
ANSI_FG_BRIGHT_BLACK="\e[90m"
ANSI_FG_BRIGHT_BLUE="\e[94m"
ANSI_FG_BRIGHT_CYAN="\e[96m"
ANSI_FG_BRIGHT_GREEN="\e[92m"
ANSI_FG_BRIGHT_MAGENTA="\e[95m"
ANSI_FG_BRIGHT_RED="\e[91m"
ANSI_FG_BRIGHT_WHITE="\e[97m"
ANSI_FG_BRIGHT_YELLOW="\e[93m"
ANSI_FG_CYAN="\e[36m"
ANSI_FG_GRAY="\e[38;5;245m"
ANSI_FG_GREEN="\e[32m"
ANSI_FG_LIME="\e[38;5;154m"
ANSI_FG_MAGENTA="\e[35m"
ANSI_FG_ORANGE="\e[38;5;208m"
ANSI_FG_PINK="\e[38;5;205m"
ANSI_FG_PURPLE="\e[38;5;93m"
ANSI_FG_RED="\e[31m"
ANSI_FG_RGB_EMERALD="\e[38;2;80;200;120m"
ANSI_FG_RGB_OCEAN="\e[38;2;0;155;255m"
ANSI_FG_RGB_SUNSET="\e[38;2;255;94;77m"
ANSI_FG_WHITE="\e[37m"
ANSI_FG_YELLOW="\e[33m"

# functions
function cd() {
    if [[ -f "$1" ]]; then
        builtin cd "$(dirname "$1")" || return
    else
        builtin cd "$@" || return
    fi
    local search_dir=$(pwd -P)
    local venv_path=""
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/.venv-docker/bin/activate" && $(whoami) == "user" ]]; then
            venv_path="$search_dir/.venv-docker"
            break
        fi
        if [[ -f "$search_dir/.venv/bin/activate" ]]; then
            venv_path="$search_dir/.venv"
            break
        fi
        search_dir=$(dirname "$search_dir")
    done
    if [[ -n "$venv_path" ]]; then
        if [[ -z "$VIRTUAL_ENV" || "$VIRTUAL_ENV" != "$venv_path" ]]; then
            source "$venv_path/bin/activate"
        fi
    elif [[ -n "$VIRTUAL_ENV" ]] && declare -f deactivate >/dev/null; then
        deactivate
    fi
}

function ghdown() {
    local url="$1"
    local output_dir="${2:-$(pwd)}"
    local output_file="$output_dir/$(basename "$1")"

    if [[ "$url" == *"github.com"* ]]; then
        local proxy_url
        proxy_url=$(python3 -c "import urllib.parse; print(f'https://ghfast.top/?q={urllib.parse.quote(input())}')" <<<"$url")
        curl -# --fail --show-error -L "$proxy_url" --output "$output_file"
    else
        curl -# --fail --show-error -L "$url" --output "$output_file"
    fi

    echo "save to ${output_file}"
}

function sep() {
    local term_width=$(tput cols)
    local separator_line=$(printf "${ANSI_FG_PINK}%*s${ANSI_RESET}" "$term_width" | tr ' ' '=')
    local current_time=$(now)
    local time_length=${#current_time}
    local stars_length=$(((term_width - time_length - 2) / 2))
    local stars_left=$(printf "${ANSI_FG_PINK}%*s${ANSI_RESET}" "$stars_length" | tr ' ' '>')
    local stars_right=$(printf "${ANSI_FG_PINK}%*s${ANSI_RESET}" "$stars_length" | tr ' ' '<')
    echo "$separator_line"
    echo "${stars_left} ${current_time} ${stars_right}"
    echo "$separator_line"
}

ipshow() {
    echo -en '[IPV4]: '
    curl 4.ipw.cn
    echo -en '\n[IPV6]: '
    curl 6.ipw.cn
    echo -en '\n[PREFERRED]: '
    curl test.ipw.cn
    echo ''
}

bak() {
    for file in "$@"; do
        if [ -d ${file} ]; then
            cp -r "${file}" "${file}.bak"
        else
            cp "${file}" "${file}.bak"
        fi
    done
}

color() {
    local colors=({30..37} {40..47})
    for code in "${colors[@]}"; do
        echo -en "\e[${code}m"'\\e['"$code"'m'"\e[0m"
        echo -en "\e[$code;1m"'\\e['"$code"';1m'"\e[0m"
        echo -en "\e[$code;3m"'\\e['"$code"';3m'"\e[0m"
        echo -en "\e[$code;4m"'\\e['"$code"';4m'"\e[0m"
        echo -e "\e[$((code + 60))m"'\\e['"$((code + 60))"'m'"\e[0m"
    done
}

install() {
    sudo mv "$@" /usr/local/bin/
}

# 编译运行
mk() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: mk <filename>"
        return 1
    fi

    local file="$1"
    local extension="${file##*.}"
    local base="${file%.*}"

    if [ ! -f "$file" ]; then
        echo "File '$file' does not exist."
        return 1
    fi

    case "$extension" in
    cpp | cc | cxx)
        echo "Compiling C++ file '$file'..."
        g++ "$file" -o "$base" -std=c++20 -g
        if [ $? -eq 0 ]; then
            echo "Running executable '$base'..."
            ./"$base"
        else
            echo "Compilation failed."
        fi
        ;;
    c)
        echo "Compiling C file '$file'..."
        gcc "$file" -o "$base" -g
        if [ $? -eq 0 ]; then
            echo "Running executable '$base'..."
            ./"$base"
        else
            echo "Compilation failed."
        fi
        ;;
    py)
        echo "Running Python file '$file'..."
        python3 "$file"
        ;;
    sh)
        echo "Running shell script '$file'..."
        bash "$file"
        ;;
    lua)
        echo "Running Lua script '$file'..."
        lua "$file"
        ;;
    go)
        echo "Compiling Go file '$file'..."
        go build -o "$base" "$file"
        if [ $? -eq 0 ]; then
            echo "Running executable '$base'..."
            ./"$base"
        else
            echo "Compilation failed."
        fi
        ;;
    *)
        echo "Unsupported file type: .$extension"
        return 1
        ;;
    esac
}

## quick tmux

alias tmuxkillall='tmux kill-server'
# alias tmuxkillall="tmux list-sessions | awk -F: '{print $1}' | xargs -n 1 tmux kill-session -t"

tmuxn() {
    local a c="" cmds=() sn n i=0
    for a in "$@"; do [[ "$a" == "+" ]] && { cmds+=("$c"); c=""; } || c="${c:+$c }$a"; done
    [[ -n "$c" ]] && cmds+=("$c")
    (( ${#cmds[@]} )) || { echo "Usage: tmuxn cmd1 + cmd2 ..."; return 1; }

    sn="cs_$(basename "${cmds[0]%% *}")"
    n=${#cmds[@]}

    for c in "${cmds[@]}"; do
        if (( i++ == 0 )); then
            tmux kill-session -t "$sn" 2>/dev/null
            tmux new-session -d -s "$sn"
        else
            (( n==2 )) && tmux split-window -h -t "$sn" || { tmux split-window -t "$sn"; tmux select-layout -t "$sn" tiled > /dev/null; }
        fi
        tmux send-keys -t "$sn" "$c" C-m
        sleep 0.5
    done

    tmux select-pane -t "$sn.0"
    tmux attach-session -t "$sn"
}

## rg + fzf
rvim() {
    local file
    file=$(rg "$@" -l | fzf) && vim "$file"
}

rnvim() {
    local file
    file=$(rg "$@" -l | fzf) && nvim "$file"
}

## locate + fzf
lnvim() {
    local file
    file=$(locate "$@" | fzf) && nvim $file
}

## fd + fzf
ftmux2() {
    local server client
    server=$(fd -t f -uu -L . "$@" | fzf)
    client=$(fd -t f -uu -L . "$@" | fzf)
    tmuxn ${server} ${client}
}

ftmux3() {
    local server client1 client2
    server=$(fd -t f -uu -L . "$@" | fzf)
    client1=$(fd -t f -uu -L . "$@" | fzf)
    client2=$(fd -t f -uu -L . "$@" | fzf)
    tmuxn ${server} ${client1} ${client2}
}

alias flog='fzf --tac --no-sort --border --ansi --multi'

fcd() {
    local dir
    dir=$(fd . "$@" | fzf)
    if [ -z $dir ]; then
        return
    fi
    if [ -d $dir ]; then
        cd $dir
    else
        cd $(dirname "$dir")
    fi
}

fcdd() {
    local dir
    dir=$(fd . -t d "$@" | fzf)
    if [ -z $dir ]; then
        return
    fi
    cd $dir
}

fpwd() {
    local dir
    dir=$(fd . "$@" | fzf) && echo $(realpath "$dir")
}

fvi() {
    local file
    file=$(fd . "$@" | fzf) && vim "$file"
}

fvim() {
    local file
    file=$(fd . "$@" | fzf) && nvim "$file"
}

fnvim() {
    local file
    file=$(fd . "$@" | fzf) && nvim $file
}

fbat() {
    local file
    file=$(fd . "$@" | fzf) && bat $file
}

fcat() {
    local file
    file=$(fd . "$@" | fzf) && cat $file
}

fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

    if [ "x$pid" != "x" ]; then
        echo $pid | xargs kill -${1:-9}
    fi
}

ftmuxkill() {
    local items target type id
    items=$(tmux list-sessions -F "S:#{session_name}|  [Session] #{session_name} (#{session_windows} windows)" 2>/dev/null;
            tmux list-windows -a -F "W:#{session_name}:#{window_index}|   [Window] #{session_name}:#{window_index} \"#{window_name}\"" 2>/dev/null;
            tmux list-panes -a -F "P:#{session_name}:#{window_index}.#{pane_index}|    [Pane] #{session_name}:#{window_index}.#{pane_index} [#{pane_current_command}]" 2>/dev/null)

    [[ -z "$items" ]] && echo "No tmux sessions found." && return

    target=$(echo "$items" | fzf -m --delimiter="|" --with-nth=2.. | cut -d'|' -f1)

    [[ -z "$target" ]] && return

    echo "$target" | while read t; do
        type=${t%%:*}
        id=${t#*:}
        case "$type" in
            S) tmux kill-session -t "$id" 2>/dev/null ;;
            W) tmux kill-window -t "$id" 2>/dev/null ;;
            P) tmux kill-pane -t "$id" 2>/dev/null ;;
        esac
    done
}

fgit() {
    local hashid
    hashid=$(git lng |
        fzf --preview-window=up,36% \
            --preview="git show --color=always \$(echo {} | choose -f '-' 0)" |
        choose -f ' ' 1 | choose -f '-' 0)
    git show ${hashid} | delta -s
}

fhistory() {
    local file
    file=$(fd . "$@" -E "*\.git\/*" | fzf --exit-0)
    if [[ -n "$file" ]]; then
        git lng -- "$file" | fzf --preview-window=up,70% \
            --preview="git show --color=always --format=fuller \$(echo {} | awk -F '-' '{print \$1}') -- '$file' | delta -w 140"
    fi
}

## Complete
_ibash() {
    local cur=${COMP_WORDS[1]}
    if [[ $COMP_CWORD == 1 ]]; then
        COMPREPLY=($(compgen -c -- "$cur"))
    else
        local cmd=${COMP_WORDS[1]}
        if [[ -n $cmd && $(type -t _command_offset 2>/dev/null) == function ]]; then
            COMP_WORDS=("${COMP_WORDS[@]:1}")
            COMP_CWORD=$((COMP_CWORD - 1))
            _command_offset 0 "$cmd"
        else
            COMPREPLY=($(compgen -f -- "${COMP_WORDS[COMP_CWORD]}"))
        fi
    fi
}
complete -F _ibash ibash

## specific wrapper
subl() {
    local win_path
    for p in "$@"; do
        win_path=$(wslpath -w "$p")
        set -- "$@" "$win_path"
        shift
    done
    subl.exe "$@"
}

### software manage (only for linux)
update-nvim() {
    wget -O /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar xf /tmp/nvim.tar.gz -C /opt
    rm /tmp/nvim.tar.gz
    echo "DONE!"
}

### perf
#（1） perf report：一步到位
perf_report() {
    sudo perf record -g -- $1 && sudo perf report
}

#（2） 生成火焰图，并可通过浏览器进行访问（主要针对虚拟机，没在正常平台上试验过）
#       $1:命令, $2:svg文件无后缀名称, $3:port, $4:网卡名，如ens33
perf_flame() {
    local SvgPath=$(pwd)
    local FlameGraphSvgPath=/opt/FlameGraph
    local filename=${2:-perf-flamegraph}.svg
    local vm_ip=$(ip address show ${4:-eth0} | /usr/bin/grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | awk 'NR==1{print $1}')
    local vm_port=${3:-8000}
    local svg_link="http://${vm_ip}:${vm_port}/${filename}"

    sudo perf record -F 1000 -g -- $1
    sudo perf script >perf.out

    perl ${FlameGraphSvgPath}/stackcollapse-perf.pl ${SvgPath}/perf.out | grep -v '^#' | perl ${FlameGraphSvgPath}/flamegraph.pl >${SvgPath}/${filename}

    echo -e "\n-----------------------------= PERF FLAME GRAPH =-----------------------------\n"
    echo -e "\e[1;33m Now you can view the SVG file by clicking \e[4;34m${svg_link}\e[0m"
    echo -e "\n------------------------------------------------------------------------------\n"

    python3 -m http.server --directory ${SvgPath} --bind ${vm_ip} ${vm_port}
}

########################################
# DEPRECATED
########################################

### redis : redisc [host] [port]  &  redisrun  &  redisstop
AUTH=shuaikaisredis
alias redisrun='redis-server /home/shuaikai/.redis/redis.conf'
alias redisstop='redis-cli -a shuaikaisredis SHUTDOWN'
alias redisc='redis-cli -h localhost -p 6379 -a $AUTH'

### aliyun-oss : ossup ossupdate ossupdateall ossdowndate ossdowndateall osslsv osslsb ossls ossmkdir ossrm osscat ossdu
BUCKET=oss://shuaikai-bucket0001
ossup() {
    ossutil cp -r $1 $BUCKET/$2 -u
}
ossdown() {
    ossutil cp -r $BUCKET/$1 $2 -u
}
ossls() {
    ossutil ls $BUCKET/$1 -s $2 $3 | sed 's#^oss://shuaikai-bucket0001#https://shuaikai-bucket0001.oss-cn-shanghai.aliyuncs.com#'
}
ossla() {
    ossutil ls $BUCKET -d | sed 's#^oss://shuaikai-bucket0001#https://shuaikai-bucket0001.oss-cn-shanghai.aliyuncs.com#'
}
ossmkdir() {
    ossutil mkdir $BUCKET/$1
}
ossrm() {
    # 兼容下面的 grep
    ossutil rm $BUCKET/$1 $2 $3 $4
}
ossrm-grep() {
    # 删除所有满足 $2 条件的对象
    ossutil rm $BUCKET/$1 --include "$2" -r
}
osscat() {
    ossutil cat $BUCKET/$1
}
ossdu() {
    ossutil du $BUCKET/$1 --block-size MB
}
