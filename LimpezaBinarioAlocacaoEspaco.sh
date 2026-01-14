#!/bin/bash

# ==========================================================================
# 🚀 SHIFT - INFRAESTRUTURA - SUSTENTAÇÃO - v3.0 (ULTIMATE TUI)
# ==========================================================================
# Desenvolvedor: Miguel Parra Ribeiro
# Atualizado em: 2026-01-13
# Descrição: Interface TUI avançada para gestão de Cache/IRIS
# ==========================================================================

# --- TRATAMENTO DE SINAIS (Trap CTRL+C) ---
trap ctrl_c INT
function ctrl_c() {
    echo -e "\n${C_ERROR} ✖ Interrompido pelo usuário.${C_RESET}"
    tput cnorm # Restaura cursor
    exit 1
}

# --- VARIÁVEIS GLOBAIS ---
LOG_FILE="/opt/scripts/cronbinario.log"
REQ_SPACE_GB=5
SAFETY_MARGIN_GB=5
MAPA_CAMINHOS=()
SELECTED_INDEX=0

# --- CORES E ESTILOS (True Color / 256) ---
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'

# Tema: "Neon City"
C_PRIMARY='\033[38;5;63m'    # Azul Royal
C_ACCENT='\033[38;5;87m'     # Ciano Água
C_HIGHLIGHT='\033[38;5;201m' # Rosa Choque
C_SUCCESS='\033[38;5;48m'    # Verde Neon
C_WARNING='\033[38;5;220m'   # Ouro
C_ERROR='\033[38;5;196m'     # Vermelho
C_GRAY='\033[38;5;238m'      # Cinza Fundo
C_WHITE='\033[38;5;255m'     # Branco Puro
BG_SELECTED='\033[48;5;63m'  # Fundo da seleção

# --- FUNÇÕES DE UI (User Interface) ---

# Desenha uma linha separadora
draw_line() {
    printf "${C_GRAY}────────────────────────────────────────────────────────────────────────────────${C_RESET}\n"
}

# Cabeçalho com Dashboard de Recursos
draw_header() {
    clear
    local _USER=$(whoami)
    local _HOST=$(hostname)
    local _DATE=$(date +'%d/%m %H:%M')
    
    # Métricas
    local _DISK=$(df -h / | awk 'NR==2 {print $5}')
    local _MEM=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')
    local _LOAD=$(cut -d . -f 1 /proc/loadavg)

    echo -e "${C_PRIMARY}"
    cat << "EOF"
   ███████╗██╗  ██╗██╗███████╗████████╗   
   ██╔════╝██║  ██║██║██╔════╝╚══██╔══╝   
   ███████╗███████║██║█████╗     ██║      
   ╚════██║██╔══██║██║██╔══╝     ██║      
   ███████║██║  ██║██║██║        ██║      
   ╚══════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝      
EOF
    echo -e "   ${C_ACCENT}INFRAESTRUTURA & SUSTENTAÇÃO ${C_DIM}| v3.0${C_RESET}"
    
    draw_line
    printf "   👤 ${C_WHITE}%-10s${C_RESET} 💻 ${C_WHITE}%-10s${C_RESET} 🕒 ${C_WHITE}%-10s${C_RESET}\n" "$_USER" "$_HOST" "$_DATE"
    printf "   💾 Disk: ${C_SUCCESS}%-6s${C_RESET} 🧠 RAM: ${C_SUCCESS}%-6s${C_RESET} ⚙️  Load: ${C_SUCCESS}%-6s${C_RESET}\n" "$_DISK" "$_MEM" "${_LOAD}"
    draw_line
    echo ""
}

# Barra de Progresso
progress_bar() {
    local duration=${1}
    local prefix=${2}
    local block="█"
    local empty="░"
    local width=40

    tput civis # Esconde cursor
    for (( i=0; i<=100; i+=2 )); do
        local num_blocks=$(( (i * width) / 100 ))
        local num_empty=$(( width - num_blocks ))
        
        local bar=""
        for (( j=0; j<num_blocks; j++ )); do bar+="$block"; done
        for (( j=0; j<num_empty; j++ )); do bar+="$empty"; done

        printf "\r   ${prefix} ${C_ACCENT}[${bar}]${C_RESET} ${i}%%"
        sleep "$duration"
    done
    echo ""
    tput cnorm # Volta cursor
}

# Caixas de Mensagem Estilizadas
msg_box() {
    local type=$1
    local msg=$2
    case $type in
        "info")    echo -e "   ${C_ACCENT}ℹ️  INFO:${C_RESET}    $msg" ;;
        "success") echo -e "   ${C_SUCCESS}✅ SUCESSO:${C_RESET} $msg" ;;
        "error")   echo -e "   ${C_ERROR}❌ ERRO:${C_RESET}    $msg" ;;
        "warn")    echo -e "   ${C_WARNING}⚠️  ATENÇÃO:${C_RESET} $msg" ;;
        "input")   echo -ne "   ${C_HIGHLIGHT}➤  ${C_BOLD}$msg${C_RESET} " ;;
    esac
}

# Função para Navegação por Setas (MENU)
select_option() {
    # Recebe array de opções como argumentos
    local options=("$@")
    local cur_selection=0
    local key

    # Loop de renderização do menu
    while true; do
        # Redesenha apenas a área do menu (poderia ser otimizado, mas clear é mais seguro visualmente)
        draw_header
        echo -e "   ${C_BOLD}SELECIONE UMA OPERAÇÃO:${C_RESET}"
        echo ""

        for i in "${!options[@]}"; do
            if [ $i -eq $cur_selection ]; then
                # Item selecionado
                echo -e "   ${C_HIGHLIGHT}➤ ${BG_SELECTED}${C_WHITE} ${options[$i]} ${C_RESET}"
            else
                # Item normal
                echo -e "     ${C_GRAY}${options[$i]}${C_RESET}"
            fi
        done
        
        echo ""
        draw_line
        echo -e "   ${C_DIM}Use ↑/↓ para navegar e ENTER para confirmar${C_RESET}"

        # Captura input (Setas e Enter)
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ $key == '[A' ]]; then # Cima
                ((cur_selection--))
                [[ $cur_selection -lt 0 ]] && cur_selection=$((${#options[@]} - 1))
            elif [[ $key == '[B' ]]; then # Baixo
                ((cur_selection++))
                [[ $cur_selection -ge ${#options[@]} ]] && cur_selection=0
            fi
        elif [[ $key == "" ]]; then # Enter
            break
        fi
    done
    
    return $cur_selection
}

# Função para Seleção de Pastas (Estilo Menu)
select_folder() {
    local paths=("${!1}") # Recebe array por referência
    local labels=("${!2}")
    local title="$3"
    
    local cur=0
    local key

    while true; do
        draw_header
        echo -e "   ${C_BOLD}$title${C_RESET}"
        echo ""

        if [ ${#paths[@]} -eq 0 ]; then
            msg_box "warn" "Nenhum diretório encontrado."
            read -p "   ENTER para voltar..."
            return 255
        fi

        for i in "${!labels[@]}"; do
            if [ $i -eq $cur ]; then
                echo -e "   ${C_ACCENT}●${C_RESET} ${BG_SELECTED}${C_WHITE} ${labels[$i]} ${C_RESET}"
                echo -e "      ${C_HIGHLIGHT}↳ ${paths[$i]}${C_RESET}"
            else
                echo -e "     ${C_DIM}${labels[$i]}${C_RESET}"
            fi
        done

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            [[ $key == '[A' ]] && ((cur--))
            [[ $key == '[B' ]] && ((cur++))
            [[ $cur -lt 0 ]] && cur=$((${#labels[@]} - 1))
            [[ $cur -ge ${#labels[@]} ]] && cur=0
        elif [[ $key == "" ]]; then
            SELECTED_INDEX=$cur
            return 0
        fi
    done
}

# --- LÓGICA DE NEGÓCIO ---

scan_folders() {
    # Popula arrays globais
    MAPA_CAMINHOS=()
    MAPA_LABELS=()
    
    local sistemas=("cache" "irishealth")
    
    # Animação fake de scan
    echo -ne "   ${C_ACCENT}Mapeando sistema de arquivos...${C_RESET}"
    for i in {1..3}; do sleep 0.2; echo -ne "."; done
    
    for sistema in "${sistemas[@]}"; do
        local base_path="/binario/$sistema/csp"
        if [ -d "$base_path" ]; then
            for cliente_dir in "$base_path"/*/; do
                if [ -d "${cliente_dir}tmp" ]; then
                    local tmp_folder="${cliente_dir}tmp"
                    local client_name=$(basename "$cliente_dir")
                    
                    MAPA_CAMINHOS+=("$tmp_folder")
                    MAPA_LABELS+=("[$sistema] CLIENTE: ${client_name^^}")
                fi
            done
        fi
    done
}

func_limpeza_tmp() {
    scan_folders
    select_folder MAPA_CAMINHOS[@] MAPA_LABELS[@] "SELECIONE O ALVO PARA AGENDAMENTO (CRON):"
    [[ $? -eq 255 ]] && return

    local target=${MAPA_CAMINHOS[$SELECTED_INDEX]}
    [[ "$target" == *"cache"* ]] && USER_CRON="cacheusr" || USER_CRON="irisusr"

    if ! id "$USER_CRON" &>/dev/null; then
        msg_box "error" "Usuário $USER_CRON não existe no sistema."
        read -r; return
    fi

    echo ""
    msg_box "info" "Adicionando ao Crontab do usuário ${C_BOLD}$USER_CRON${C_RESET}..."
    progress_bar 0.02 "Processando"
    
    local cmd="00 02 * * * echo  \"\\n[\$(date \"+\%F \%T\")]\\n\$(find $target -type f -mtime +10 -exec rm -v {} \;)\" >> $LOG_FILE"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Crontab magic
    ( ( crontab -u "$USER_CRON" -l 2>/dev/null | grep -v "$target" ; echo "$cmd" ) | crontab -u "$USER_CRON" - )
    
    msg_box "success" "Agendamento configurado com sucesso!"
    read -rsn1 -p "   Pressione qualquer tecla..."
}

func_limpeza_manual() {
    scan_folders
    select_folder MAPA_CAMINHOS[@] MAPA_LABELS[@] "SELECIONE O ALVO PARA LIMPEZA IMEDIATA:"
    [[ $? -eq 255 ]] && return

    local target=${MAPA_CAMINHOS[$SELECTED_INDEX]}

    echo ""
    msg_box "input" "Manter arquivos de quantos dias? (Padrão: 10):"
    read -r dias
    [[ -z "$dias" ]] && dias=10
    
    if ! [[ "$dias" =~ ^[0-9]+$ ]]; then
        msg_box "error" "Número inválido."
        read -r; return
    fi

    echo ""
    msg_box "info" "Calculando arquivos afetados..."
    local count=$(find "$target" -type f -mtime +$dias | wc -l)
    
    if [ "$count" -eq 0 ]; then
        msg_box "warn" "Nenhum arquivo encontrado com mais de $dias dias."
        read -r; return
    fi

    echo -e "   ${C_ERROR}╔══════════════════════════════════════════╗${C_RESET}"
    echo -e "   ${C_ERROR}║ 🧨 ZONA DE PERIGO                        ║${C_RESET}"
    echo -e "   ${C_ERROR}╠══════════════════════════════════════════╣${C_RESET}"
    echo -e "   ${C_ERROR}║${C_RESET} Arquivos a apagar: ${C_BOLD}$count${C_RESET}"
    echo -e "   ${C_ERROR}║${C_RESET} Retenção:          ${C_BOLD}$dias dias${C_RESET}"
    echo -e "   ${C_ERROR}║${C_RESET} Pasta:             ${C_DIM}$(basename $target)${C_RESET}"
    echo -e "   ${C_ERROR}╚══════════════════════════════════════════╝${C_RESET}"
    
    msg_box "input" "Digite 'SIM' para confirmar:"
    read -r confirm

    if [[ "$confirm" == "SIM" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo -e "\n[$(date "+%F %T")] MANUAL EXECUTION (Days: $dias)" >> $LOG_FILE
        
        # Executa em background para mostrar progresso fake (find pode ser lento)
        (find "$target" -type f -mtime +$dias -exec rm -v {} \; >> $LOG_FILE 2>&1) &
        local pid=$!
        
        progress_bar 0.05 "Deletando"
        wait $pid
        
        msg_box "success" "Limpeza concluída."
    else
        msg_box "info" "Operação cancelada."
    fi
    read -rsn1 -p "   Pressione qualquer tecla..."
}

func_storage() {
    draw_header
    echo -e "   ${C_BOLD}GESTOR DE ALOCAÇÃO DE DISCO${C_RESET}"
    echo ""
    
    local paths=("/dados" "/binario")
    
    for p in "${paths[@]}"; do
        if [ ! -d "$p" ]; then
            echo -e "   ${C_ERROR}✖${C_RESET} $p não encontrado."
            continue
        fi

        local avail=$(df -BG "$p" | awk 'NR==2 {print $4}' | sed 's/G//')
        local needed=$((REQ_SPACE_GB + SAFETY_MARGIN_GB))
        local file_path="$p/controle_armazenamento.img"

        echo -e "   ${C_ACCENT}📂 Analisando: $p${C_RESET}"
        echo -e "      Livre: ${avail}GB (Necessário: ${needed}GB)"

        if [ -f "$file_path" ]; then
             echo -e "      ${C_SUCCESS}✔ Arquivo de controle já existe.${C_RESET}"
        elif [ "$avail" -lt "$needed" ]; then
             echo -e "      ${C_WARNING}⚠ Espaço insuficiente.${C_RESET}"
        else
             progress_bar 0.02 "      Alocando ${REQ_SPACE_GB}GB"
             fallocate -l ${REQ_SPACE_GB}G "$file_path" 2>/dev/null
             if [ $? -eq 0 ]; then
                echo -e "      ${C_SUCCESS}✔ Criado com sucesso!${C_RESET}"
             else
                echo -e "      ${C_ERROR}✖ Erro na criação.${C_RESET}"
             fi
        fi
        echo ""
    done
    read -rsn1 -p "   Pressione qualquer tecla..."
}

func_wizard() {
    # O Script Definitivo - Orquestração
    local steps=("Limpeza Manual" "Configuração Crontab" "Arquivos de Controle")
    
    draw_header
    echo -e "   ${C_HIGHLIGHT}🚀 WIZARD DE EXECUÇÃO TOTAL${C_RESET}"
    echo -e "   ${C_DIM}Seguiremos os seguintes passos:${C_RESET}"
    echo ""
    for i in "${!steps[@]}"; do
        echo -e "   $((i+1)). ${steps[$i]}"
    done
    echo ""
    msg_box "input" "Pressione ENTER para iniciar a jornada..."
    read -r

    # Passo 1
    func_limpeza_manual
    
    # Passo 2
    func_limpeza_tmp

    # Passo 3
    func_storage

    draw_header
    echo ""
    echo -e "   ${C_SUCCESS}✨✨ PROCESSAMENTO COMPLETO FINALIZADO ✨✨${C_RESET}"
    echo ""
    read -rsn1 -p "   Pressione qualquer tecla para voltar ao menu..."
}

# --- MENU PRINCIPAL LOOP ---

while true; do
    options=(
        "Executar Limpeza Manual (Imediata)"
        "Configurar Limpeza Automática (Cron)"
        "Gerar Arquivos de Controle (Storage)"
        "Instalação Padrão (Cron + Storage)"
        "WIZARD COMPLETO (Limpeza + Cron + Storage)"
        "Sair do Sistema"
    )

    select_option "${options[@]}"
    choice=$?

    case $choice in
        0) func_limpeza_manual ;;
        1) func_limpeza_tmp ;;
        2) func_storage ;;
        3) func_limpeza_tmp; func_storage ;;
        4) func_wizard ;;
        5) 
           echo -e "\n   ${C_PRIMARY}Até logo! 👋${C_RESET}\n"
           exit 0 ;;
    esac
done