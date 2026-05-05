#!/bin/bash

# ==========================================================================
# 🚀 SHIFT - INFRAESTRUTURA - SUSTENTAÇÃO - v2
# ==========================================================================
# Desenvolvedor: Miguel Parra Ribeiro (Analista de Infraestrutura - Estagiário)
# Atualizado em: 05/05/2025
# ==========================================================================

# --- CONFIGURAÇÕES E TRAPS ---
trap ctrl_c INT
function ctrl_c() {
    tput cnorm
    echo -e "\n\n${C_RED}✖ Interrupção forçada pelo usuário.${C_RESET}\n"
    exit 1
}

# --- VARIÁVEIS GLOBAIS ---
LOG_FILE="/opt/scripts/cronbinario.log"
REQ_SPACE_GB=5
SAFETY_MARGIN_GB=5
MAPA_CAMINHOS=()
MAPA_LABELS=()
SELECTED_INDEX=0

# --- PALETA DE CORES (256 Colors - OCEAN BLUE THEME) ---
C_RESET='\033[0m'
C_BOLD='\033[1m'

C_PRIMARY='\033[38;5;33m'
C_SECONDARY='\033[38;5;51m'
C_ACCENT='\033[38;5;39m'

C_SUCCESS='\033[38;5;46m'
C_WARNING='\033[38;5;226m'
C_RED='\033[38;5;196m'

C_GRAY='\033[38;5;245m'
C_DARK_GRAY='\033[38;5;238m'
C_WHITE='\033[38;5;255m'
C_DIM='\033[2m'

# --- FUNÇÕES GRÁFICAS ---

draw_line() {
    printf "${C_DARK_GRAY}────────────────────────────────────────────────────────────────────────────────${C_RESET}\n"
}

draw_double_line() {
    printf "${C_PRIMARY}════════════════════════════════════════════════════════════════════════════════${C_RESET}\n"
}

draw_usage_bar() {
    local percent=$1
    local width=15
    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))

    printf "${C_DARK_GRAY}["
    if [ "$percent" -gt 90 ]; then printf "${C_RED}";
    elif [ "$percent" -gt 70 ]; then printf "${C_WARNING}";
    else printf "${C_SECONDARY}"; fi

    for ((i=0; i<filled; i++)); do printf "❚"; done
    printf "${C_DARK_GRAY}"
    for ((i=0; i<empty; i++)); do printf "·"; done
    printf "]${C_RESET}"
}

header() {
    clear
    local _USER
    local _HOST
    local _DATE
    _USER=$(whoami)
    _HOST=$(hostname)
    _DATE=$(date +'%H:%M')

    local _DISK_USE
    local _MEM_TOTAL
    local _MEM_USED
    local _MEM_PERC
    _DISK_USE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    _MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    _MEM_USED=$(free -m | awk 'NR==2{print $3}')
    _MEM_PERC=$(( _MEM_USED * 100 / _MEM_TOTAL ))

    echo -e "${C_PRIMARY}"
    cat << "EOF"
   ███████╗██╗  ██╗██╗███████╗████████╗  v2
   ██╔════╝██║  ██║██║██╔════╝╚══██╔══╝  INFRA
   ███████╗███████║██║█████╗     ██║     SUSTENTAÇÃO
   ╚════██║██╔══██║██║██╔══╝     ██║     
   ███████║██║  ██║██║██║        ██║     
   ╚══════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝     
EOF
    echo -e "${C_RESET}"

    printf "   %-20s %-20s %20s\n" "👤 $_USER" "💻 $_HOST" "🕒 $_DATE"
    draw_line
    printf "   DISK: %-3s%% " "$_DISK_USE"
    draw_usage_bar "$_DISK_USE"
    printf "    RAM: %-3s%% " "$_MEM_PERC"
    draw_usage_bar "$_MEM_PERC"
    echo ""
    draw_line
    echo ""
}

spinner_bar() {
    local pid=$1
    local text=$2
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0

    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 8 ))
        printf "\r   ${C_SECONDARY}${spin:$i:1}${C_RESET}  ${text}..."
        sleep 0.1
    done
    printf "\r   ${C_SUCCESS}✔${C_RESET}  ${text}... Concluído!   \n"
    tput cnorm
}

msg() {
    local type=$1
    local text=$2
    case $type in
        "info")    echo -e "   ${C_SECONDARY}ℹ  INFO${C_RESET}    $text" ;;
        "success") echo -e "   ${C_SUCCESS}✔  SUCESSO${C_RESET} $text" ;;
        "warn")    echo -e "   ${C_WARNING}⚠  ATENÇÃO${C_RESET} $text" ;;
        "error")   echo -e "   ${C_RED}✖  ERRO${C_RESET}    $text" ;;
        "input")   echo -ne "   ${C_ACCENT}➤  ${C_BOLD}$text${C_RESET} " ;;
    esac
}

# --- LIVE LOG DISPLAY ---
# Exibe em tempo real os arquivos sendo deletados com contador e tamanho total liberado

live_clean_display() {
    local target=$1
    local dias=$2
    local log_tmp
    log_tmp=$(mktemp)

    local term_width
    term_width=$(tput cols 2>/dev/null || echo 120)
    # Layout: "   " (3) + num (4) + "  " (2) + path + "  " (2) + tamanho (8) = term_width
    local path_max=$(( term_width - 19 ))
    [[ $path_max -lt 40 ]] && path_max=40

    echo ""
    draw_double_line
    echo -e "   ${C_ACCENT}${C_BOLD}📡 LOG EM TEMPO REAL${C_RESET}  ${C_GRAY}(arquivos com mais de ${dias} dias)${C_RESET}"
    draw_double_line

    # Cabeçalho da tabela
    printf "   ${C_DARK_GRAY}%-4s  %-${path_max}s  %8s${C_RESET}\n" "Nº" "CAMINHO COMPLETO" "TAMANHO"
    draw_line

    local count=0
    local total_bytes=0

    tput civis

    # Processa arquivo por arquivo e exibe ao vivo
    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue

        # Captura tamanho ANTES de deletar
        local fsize
        fsize=$(stat --printf="%s" "$filepath" 2>/dev/null || echo 0)

        # Deleta
        rm -f "$filepath" 2>/dev/null
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            (( count++ ))
            (( total_bytes += fsize ))

            local fpath="$filepath"

            # Se o path for maior que o espaço disponível, trunca pelo INÍCIO
            # mostrando sempre o final (mais importante: nome do arquivo e pasta imediata)
            # ex: "...alth/csp/servius/tmp/teste01" em vez de "/binario/irishea..."
            if [[ ${#fpath} -gt $path_max ]]; then
                fpath="...${fpath:$(( ${#fpath} - path_max + 3 ))}"
            fi

            # Formata tamanho
            local fsize_fmt
            if [[ $fsize -ge 1073741824 ]]; then
                fsize_fmt="$(echo "scale=1; $fsize/1073741824" | bc)G"
            elif [[ $fsize -ge 1048576 ]]; then
                fsize_fmt="$(echo "scale=1; $fsize/1048576" | bc)M"
            elif [[ $fsize -ge 1024 ]]; then
                fsize_fmt="$(echo "scale=1; $fsize/1024" | bc)K"
            else
                fsize_fmt="${fsize}B"
            fi

            # Cor alternada por linha para legibilidade
            if (( count % 2 == 0 )); then
                printf "   ${C_DARK_GRAY}%-4s${C_RESET}  ${C_GRAY}%-${path_max}s${C_RESET}  ${C_WARNING}%8s${C_RESET}\n" \
                    "$count" "$fpath" "$fsize_fmt"
            else
                printf "   ${C_DARK_GRAY}%-4s${C_RESET}  ${C_WHITE}%-${path_max}s${C_RESET}  ${C_WARNING}%8s${C_RESET}\n" \
                    "$count" "$fpath" "$fsize_fmt"
            fi

            # Log no arquivo
            echo "[$(date "+%F %T")] DELETED: $filepath ($fsize_fmt)" >> "$LOG_FILE"
        fi

    done < <(find "$target" -type f -mtime +"$dias" 2>/dev/null)

    # Formata total liberado
    local total_fmt
    if [[ $total_bytes -ge 1073741824 ]]; then
        total_fmt="$(echo "scale=2; $total_bytes/1073741824" | bc) GB"
    elif [[ $total_bytes -ge 1048576 ]]; then
        total_fmt="$(echo "scale=2; $total_bytes/1048576" | bc) MB"
    elif [[ $total_bytes -ge 1024 ]]; then
        total_fmt="$(echo "scale=2; $total_bytes/1024" | bc) KB"
    else
        total_fmt="${total_bytes} B"
    fi

    draw_double_line
    echo -e "   ${C_SUCCESS}${C_BOLD}✔ LIMPEZA CONCLUÍDA${C_RESET}"
    printf "   ${C_GRAY}Arquivos removidos : ${C_WHITE}${C_BOLD}%s${C_RESET}\n" "$count"
    printf "   ${C_GRAY}Espaço liberado    : ${C_SUCCESS}${C_BOLD}%s${C_RESET}\n" "$total_fmt"
    draw_double_line
    echo ""

    tput cnorm
    rm -f "$log_tmp"

    echo "[$(date "+%F %T")] SUMMARY: $count files removed, $total_fmt freed from $target (mtime +${dias}d)" >> "$LOG_FILE"
}

# --- FUNÇÕES LÓGICAS ---

scan_folders() {
    MAPA_CAMINHOS=()
    MAPA_LABELS=()
    local sistemas=("cache" "irishealth")

    sleep 0.5 & spinner_bar $! "Mapeando diretórios"

    for sistema in "${sistemas[@]}"; do
        local base_path="/binario/$sistema/csp"
        if [ -d "$base_path" ]; then
            for cliente_dir in "$base_path"/*/; do
                if [ -d "${cliente_dir}tmp" ]; then
                    local tmp_folder="${cliente_dir}tmp"
                    local client_name
                    client_name=$(basename "$cliente_dir")
                    MAPA_CAMINHOS+=("$tmp_folder")
                    MAPA_LABELS+=("${sistema^^} │ CLIENTE: ${client_name^^}")
                fi
            done
        fi
    done
}

select_target_folder() {
    local title=$1
    header
    echo -e "   ${C_ACCENT}${C_BOLD}${title}${C_RESET}\n"

    if [ ${#MAPA_CAMINHOS[@]} -eq 0 ]; then
        msg "warn" "Nenhum diretório encontrado."
        read -rsn1 -p "   Pressione qualquer tecla..."
        return 255
    fi

    local i=0
    for label in "${MAPA_LABELS[@]}"; do
        echo -e "   ${C_DARK_GRAY}[${C_SECONDARY}$((i+1))${C_DARK_GRAY}]${C_RESET} ${C_WHITE}${label}${C_RESET}"
        echo -e "       ${C_GRAY}↳ ${MAPA_CAMINHOS[$i]}${C_RESET}"
        (( i++ ))
    done
    echo ""

    msg "input" "Digite o número da opção (0 para Voltar):"
    read -r selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -eq 0 ] || [ "$selection" -gt "${#MAPA_CAMINHOS[@]}" ]; then
        return 255
    fi

    SELECTED_INDEX=$(( selection - 1 ))
    return 0
}

# 1. Limpeza Manual com Live Log
action_manual_clean() {
    scan_folders
    select_target_folder "LIMPEZA MANUAL DE ARQUIVOS"
    [[ $? -eq 255 ]] && return

    local target="${MAPA_CAMINHOS[$SELECTED_INDEX]}"

    echo ""
    msg "input" "Manter arquivos de quantos dias? (Padrão: 10):"
    read -r dias
    [[ -z "$dias" ]] && dias=10

    # Validação: deve ser número positivo
    if [[ ! "$dias" =~ ^[0-9]+$ ]] || [[ "$dias" -lt 1 ]]; then
        msg "error" "Valor inválido. Use um número inteiro positivo."
        read -rsn1 -p "   Pressione qualquer tecla..."
        return
    fi

    local count
    count=$(find "$target" -type f -mtime +"$dias" 2>/dev/null | wc -l)

    if [ "$count" -eq 0 ]; then
        msg "warn" "Nenhum arquivo encontrado com mais de $dias dias em:"
        echo -e "       ${C_GRAY}↳ $target${C_RESET}"
        read -rsn1 -p "   Pressione qualquer tecla..."
        return
    fi

    echo ""
    echo -e "   ${C_ACCENT}┌──────────────────────────────────────────────┐${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET} ${C_RED}${C_BOLD}🛑 CONFIRMAÇÃO DE EXCLUSÃO${C_RESET}                  ${C_ACCENT}│${C_RESET}"
    echo -e "   ${C_ACCENT}├──────────────────────────────────────────────┤${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET}  Arquivos encontrados : ${C_WHITE}${C_BOLD}$count${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET}  Retenção             : ${C_WHITE}${C_BOLD}$dias dias${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET}  Destino              : ${C_GRAY}$target${C_RESET}"
    echo -e "   ${C_ACCENT}└──────────────────────────────────────────────┘${C_RESET}"
    echo ""
    msg "input" "Digite 'SIM' para confirmar e exibir log ao vivo:"
    read -r confirm

    if [[ "$confirm" == "SIM" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "" >> "$LOG_FILE"
        echo "[$(date "+%F %T")] ===== MANUAL EXECUTION START (target: $target, days: $dias) =====" >> "$LOG_FILE"

        live_clean_display "$target" "$dias"

        msg "success" "Log salvo em: ${C_GRAY}$LOG_FILE${C_RESET}"
    else
        msg "info" "Operação cancelada pelo usuário."
    fi
    echo ""
    read -rsn1 -p "   Pressione qualquer tecla para voltar ao menu..."
}

# 2. Configurar Cron
action_cron_setup() {
    scan_folders
    select_target_folder "AGENDAMENTO AUTOMÁTICO (CRON)"
    [[ $? -eq 255 ]] && return

    local target="${MAPA_CAMINHOS[$SELECTED_INDEX]}"
    local USER_CRON
    [[ "$target" == *"cache"* ]] && USER_CRON="cacheusr" || USER_CRON="irisusr"

    if ! id "$USER_CRON" &>/dev/null; then
        msg "error" "Usuário '$USER_CRON' não existe no sistema."
        read -rsn1 -p "   Pressione qualquer tecla..."
        return
    fi

    echo ""
    local cmd="00 02 * * * find \"$target\" -type f -mtime +10 -delete >> $LOG_FILE 2>&1"

    msg "info" "Configurando Crontab para o usuário: ${C_WHITE}${C_BOLD}$USER_CRON${C_RESET}"
    msg "info" "Agendamento: ${C_GRAY}todos os dias às 02:00 AM${C_RESET}"
    echo ""
    mkdir -p "$(dirname "$LOG_FILE")"

    # Remove entrada anterior do mesmo target, adiciona nova
    ( (crontab -u "$USER_CRON" -l 2>/dev/null | grep -v "$target") ; echo "$cmd" ) \
        | crontab -u "$USER_CRON" - &
    spinner_bar $! "Atualizando tabela de agendamento"

    msg "success" "Agendamento criado. Rodará às 02:00 AM diariamente."
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 3. Storage Allocation
action_storage() {
    header
    echo -e "   ${C_ACCENT}${C_BOLD}ALOCAÇÃO DE ESPAÇO EM DISCO${C_RESET}\n"

    local paths=("/dados" "/binario")

    for p in "${paths[@]}"; do
        echo -e "   ${C_SECONDARY}📂 Verificando: ${C_WHITE}${C_BOLD}$p${C_RESET}"

        if [ ! -d "$p" ]; then
            msg "error" "Diretório '$p' não encontrado no sistema."
            echo ""
            continue
        fi

        local file_path="$p/controle_armazenamento.img"

        if [ -f "$file_path" ]; then
            msg "success" "Arquivo de controle já existe: ${C_GRAY}$file_path${C_RESET}"
        else
            local avail
            avail=$(df -BG "$p" | awk 'NR==2 {print $4}' | sed 's/G//')
            local needed=$(( REQ_SPACE_GB + SAFETY_MARGIN_GB ))

            if [ "$avail" -lt "$needed" ]; then
                msg "warn" "Espaço livre insuficiente (${avail}GB disponível, mínimo ${needed}GB necessário)."
            else
                msg "info" "Espaço disponível: ${avail}GB. Alocando ${REQ_SPACE_GB}GB..."
                fallocate -l "${REQ_SPACE_GB}G" "$file_path" 2>/dev/null
                if [ $? -eq 0 ]; then
                    msg "success" "Arquivo de controle alocado com sucesso."
                else
                    msg "error" "Falha ao alocar arquivo em '$p'. Verifique permissões."
                fi
            fi
        fi
        echo ""
    done
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 4. Visualizar Log Histórico
action_view_log() {
    header
    echo -e "   ${C_ACCENT}${C_BOLD}📋 HISTÓRICO DE EXECUÇÕES${C_RESET}\n"

    if [ ! -f "$LOG_FILE" ]; then
        msg "warn" "Nenhum log encontrado em: ${C_GRAY}$LOG_FILE${C_RESET}"
        read -rsn1 -p "   Pressione qualquer tecla..."
        return
    fi

    local total_lines
    total_lines=$(wc -l < "$LOG_FILE")
    msg "info" "Arquivo: ${C_GRAY}$LOG_FILE${C_RESET} (${total_lines} linhas)"
    echo ""
    draw_line

    # Exibe as últimas 30 linhas com colorização
    tail -n 30 "$LOG_FILE" | while IFS= read -r line; do
        if [[ "$line" == *"====="* ]]; then
            echo -e "   ${C_PRIMARY}${C_BOLD}$line${C_RESET}"
        elif [[ "$line" == *"DELETED"* ]]; then
            echo -e "   ${C_GRAY}$line${C_RESET}"
        elif [[ "$line" == *"SUMMARY"* ]]; then
            echo -e "   ${C_SUCCESS}${C_BOLD}$line${C_RESET}"
        elif [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"FAIL"* ]]; then
            echo -e "   ${C_RED}$line${C_RESET}"
        else
            echo -e "   ${C_WHITE}$line${C_RESET}"
        fi
    done

    draw_line
    echo ""
    msg "info" "Exibindo últimas 30 linhas do log."
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 5. Wizard Completo
action_wizard() {
    header
    echo -e "   ${C_ACCENT}🧙 WIZARD DE AUTOMAÇÃO COMPLETA${C_RESET}\n"
    echo -e "   Este processo irá executar sequencialmente:"
    echo -e "   ${C_SECONDARY}1.${C_RESET} Limpeza Manual (com log ao vivo)"
    echo -e "   ${C_SECONDARY}2.${C_RESET} Configuração de Cron"
    echo -e "   ${C_SECONDARY}3.${C_RESET} Alocação de Storage"
    echo ""

    msg "input" "Pressione ENTER para iniciar o wizard..."
    read -r

    action_manual_clean
    action_cron_setup
    action_storage

    header
    draw_double_line
    echo -e "   ${C_SUCCESS}${C_BOLD}  ✔ WIZARD FINALIZADO COM SUCESSO!${C_RESET}"
    draw_double_line
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# --- MENU PRINCIPAL ---

show_menu() {
    header
    echo -e "   ${C_WHITE}${C_BOLD}SELECIONE UMA OPERAÇÃO:${C_RESET}\n"

    echo -e "   ${C_SECONDARY}[1]${C_RESET} ${C_BOLD}Executar Limpeza Manual${C_RESET}      ${C_GRAY}(com log em tempo real)${C_RESET}"
    echo -e "   ${C_SECONDARY}[2]${C_RESET} ${C_BOLD}Configurar Agendamento${C_RESET}       ${C_GRAY}(Crontab)${C_RESET}"
    echo -e "   ${C_SECONDARY}[3]${C_RESET} ${C_BOLD}Gerar Arquivos de Controle${C_RESET}   ${C_GRAY}(Storage)${C_RESET}"
    echo -e "   ${C_SECONDARY}[4]${C_RESET} ${C_BOLD}Visualizar Log Histórico${C_RESET}     ${C_GRAY}(últimas 30 linhas)${C_RESET}"
    echo -e "   ${C_SECONDARY}[5]${C_RESET} ${C_BOLD}Instalação Padrão${C_RESET}            ${C_GRAY}(Cron + Storage)${C_RESET}"
    echo -e "   ${C_SECONDARY}[6]${C_RESET} ${C_BOLD}WIZARD COMPLETO${C_RESET}              ${C_GRAY}(Tudo em sequência)${C_RESET}"
    echo ""
    echo -e "   ${C_RED}[0]${C_RESET} ${C_GRAY}Sair do Sistema${C_RESET}"
    echo ""
    draw_line
}

# --- LOOP PRINCIPAL ---

while true; do
    show_menu
    echo ""
    msg "input" "Digite o número da opção:"
    read -r opt

    case $opt in
        1) action_manual_clean ;;
        2) action_cron_setup ;;
        3) action_storage ;;
        4) action_view_log ;;
        5) action_cron_setup; action_storage ;;
        6) action_wizard ;;
        0)
            echo -e "\n   ${C_PRIMARY}Encerrando sistema... Até logo! 👋${C_RESET}\n"
            exit 0 ;;
        *)
            msg "error" "Opção inválida. Tente novamente."
            sleep 1 ;;
    esac
done
