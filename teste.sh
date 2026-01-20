#!/bin/bash

# ==========================================================================
# 🚀 SHIFT - INFRAESTRUTURA - SUSTENTAÇÃO - v1
# ==========================================================================
# Desenvolvedor: Miguel Parra Ribeiro(Analista de infraestutura(Estagiario))
# Atualizado em: 12/01/2025
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

# Tema Azul Tecnológico
C_PRIMARY='\033[38;5;33m'     # Azul Dodger (Logo Principal)
C_SECONDARY='\033[38;5;51m'   # Ciano Brilhante (Destaques, Menus, Info)
C_ACCENT='\033[38;5;39m'      # Azul Deep Sky (Inputs, Títulos de Seção)

# Cores Funcionais (Mantidas para alto contraste)
C_SUCCESS='\033[38;5;46m'    # Verde Neon (Sucesso)
C_WARNING='\033[38;5;226m'   # Amarelo Puro (Atenção)
C_RED='\033[38;5;196m'       # Vermelho Laser (Erro/Perigo)

# Base e Neutros
C_GRAY='\033[38;5;245m'      # Cinza Claro (Subtítulos, linhas)
C_DARK_GRAY='\033[38;5;238m' # Cinza Escuro (Elementos de fundo)
C_WHITE='\033[38;5;255m'     # Branco Puro (Texto Principal)

# --- FUNÇÕES GRÁFICAS ---

# Desenha uma linha horizontal
draw_line() {
    printf "${C_DARK_GRAY}────────────────────────────────────────────────────────────────────────────────${C_RESET}\n"
}

# Barra de uso visual (ex: [|||||.....])
draw_usage_bar() {
    local percent=$1
    local width=15
    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))
    
    printf "${C_DARK_GRAY}["
    if [ $percent -gt 90 ]; then printf "${C_RED}";
    elif [ $percent -gt 70 ]; then printf "${C_WARNING}";
    else printf "${C_SECONDARY}"; fi # Usando azul/ciano para "OK"
    
    for ((i=0; i<filled; i++)); do printf "❚"; done
    printf "${C_DARK_GRAY}"
    for ((i=0; i<empty; i++)); do printf "·"; done
    printf "]${C_RESET}"
}

# Cabeçalho Principal
header() {
    clear
    local _USER=$(whoami)
    local _HOST=$(hostname)
    local _DATE=$(date +'%H:%M')
    
    # Coletar Métricas
    local _DISK_USE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    local _MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    local _MEM_USED=$(free -m | awk 'NR==2{print $3}')
    local _MEM_PERC=$(( _MEM_USED * 100 / _MEM_TOTAL ))
    
    echo -e "${C_PRIMARY}"
    cat << "EOF"
   ███████╗██╗  ██╗██╗███████╗████████╗  v1
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
    draw_usage_bar $_DISK_USE
    printf "    RAM: %-3s%% " "$_MEM_PERC"
    draw_usage_bar $_MEM_PERC
    echo ""
    draw_line
    echo ""
}

# Barra de Progresso Lisa
spinner_bar() {
    local pid=$1
    local text=$2
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0
    
    tput civis
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 8 ))
        printf "\r   ${C_SECONDARY}${spin:$i:1}${C_RESET}  ${text}..."
        sleep 0.1
    done
    printf "\r   ${C_SUCCESS}✔${C_RESET}  ${text}... Concluído!   \n"
    tput cnorm
}

# Box de Mensagem
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

# --- FUNÇÕES LÓGICAS ---

scan_folders() {
    MAPA_CAMINHOS=()
    MAPA_LABELS=()
    local sistemas=("cache" "irishealth")
    
    # Simulando scan rápido com spinner
    sleep 0.5 & spinner_bar $! "Mapeando diretórios" 
    
    for sistema in "${sistemas[@]}"; do
        local base_path="/binario/$sistema/csp"
        if [ -d "$base_path" ]; then
            for cliente_dir in "$base_path"/*/; do
                if [ -d "${cliente_dir}tmp" ]; then
                    local tmp_folder="${cliente_dir}tmp"
                    local client_name=$(basename "$cliente_dir")
                    MAPA_CAMINHOS+=("$tmp_folder")
                    MAPA_LABELS+=("${sistema^^} │ CLIENTE: ${client_name^^}")
                fi
            done
        fi
    done
}

# Seletor de Pastas (Estilo Lista Numerada)
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
        # Número em Ciano, Label em Branco
        echo -e "   ${C_DARK_GRAY}[${C_SECONDARY}$((i+1))${C_DARK_GRAY}]${C_RESET} ${C_WHITE}${label}${C_RESET}"
        # Caminho sutil em cinza
        echo -e "       ${C_GRAY}↳ ${MAPA_CAMINHOS[$i]}${C_RESET}"
        ((i++))
    done
    echo ""
    
    msg "input" "Digite o número da opção (0 para Voltar):"
    read -r selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -eq 0 ] || [ "$selection" -gt "${#MAPA_CAMINHOS[@]}" ]; then
        return 255
    fi

    SELECTED_INDEX=$((selection-1))
    return 0
}

# 1. Limpeza Manual
action_manual_clean() {
    scan_folders
    select_target_folder "LIMPEZA MANUAL DE ARQUIVOS"
    [[ $? -eq 255 ]] && return

    local target=${MAPA_CAMINHOS[$SELECTED_INDEX]}
    
    echo ""
    msg "input" "Manter arquivos de quantos dias? (Padrão: 10):"
    read -r dias
    [[ -z "$dias" ]] && dias=10

    # Contagem prévia
    local count=$(find "$target" -type f -mtime +$dias | wc -l)
    
    if [ "$count" -eq 0 ]; then
        msg "warn" "Nada para limpar com mais de $dias dias."
        read -r; return
    fi

    echo ""
    # Usando Azul Accent para a borda da caixa de confirmação, mas mantendo o texto vermelho para alerta
    echo -e "   ${C_ACCENT}┌──────────────────────────────────────────────┐${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET} ${C_RED}🛑 CONFIRMAÇÃO DE EXCLUSÃO${C_RESET}                  ${C_ACCENT}│${C_RESET}"
    echo -e "   ${C_ACCENT}├──────────────────────────────────────────────┤${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET} Arquivos: ${C_WHITE}${C_BOLD}$count${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET} Retenção: ${C_WHITE}${C_BOLD}$dias dias${C_RESET}"
    echo -e "   ${C_ACCENT}│${C_RESET} Destino:  ${C_GRAY}$(basename $target)${C_RESET}"
    echo -e "   ${C_ACCENT}└──────────────────────────────────────────────┘${C_RESET}"
    
    msg "input" "Digite 'SIM' para apagar:"
    read -r confirm

    if [[ "$confirm" == "SIM" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo -e "\n[$(date "+%F %T")] MANUAL EXECUTION (Days: $dias)" >> $LOG_FILE
        
        # Execução com spinner
        (find "$target" -type f -mtime +$dias -exec rm -v {} \; >> $LOG_FILE 2>&1) &
        spinner_bar $! "Removendo arquivos antigos"
        
        msg "success" "Limpeza finalizada."
    else
        msg "info" "Operação cancelada."
    fi
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 2. Configurar Cron
action_cron_setup() {
    scan_folders
    select_target_folder "AGENDAMENTO AUTOMÁTICO (CRON)"
    [[ $? -eq 255 ]] && return

    local target=${MAPA_CAMINHOS[$SELECTED_INDEX]}
    [[ "$target" == *"cache"* ]] && USER_CRON="cacheusr" || USER_CRON="irisusr"

    if ! id "$USER_CRON" &>/dev/null; then
        msg "error" "Usuário $USER_CRON não existe."
        read -r; return
    fi

    echo ""
    local cmd="00 02 * * * echo \"\\n[\$(date \"+\%F \%T\")]\\n\$(find $target -type f -mtime +10 -exec rm -v {} \;)\" >> $LOG_FILE"
    
    msg "info" "Configurando Crontab para: ${C_WHITE}${C_BOLD}$USER_CRON${C_RESET}"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    ( ( crontab -u "$USER_CRON" -l 2>/dev/null | grep -v "$target" ; echo "$cmd" ) | crontab -u "$USER_CRON" - ) &
    spinner_bar $! "Atualizando tabelas de agendamento"
    
    msg "success" "Agendamento criado para rodar às 02:00 AM."
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 3. Storage Allocation
action_storage() {
    header
    echo -e "   ${C_ACCENT}${C_BOLD}ALOCAÇÃO DE ESPAÇO EM DISCO${C_RESET}\n"
    
    local paths=("/dados" "/binario")
    
    for p in "${paths[@]}"; do
        echo -e "   ${C_SECONDARY}📂 Verificando: $p${C_RESET}"
        
        if [ ! -d "$p" ]; then
            msg "error" "Diretório não encontrado."
            echo ""
            continue
        fi

        local file_path="$p/controle_armazenamento.img"
        
        if [ -f "$file_path" ]; then
             msg "success" "Arquivo de controle já existe."
        else
             local avail=$(df -BG "$p" | awk 'NR==2 {print $4}' | sed 's/G//')
             local needed=$((REQ_SPACE_GB + SAFETY_MARGIN_GB))
             
             if [ "$avail" -lt "$needed" ]; then
                 msg "warn" "Espaço livre insuficiente ($avail GB)."
             else
                 msg "info" "Alocando ${REQ_SPACE_GB}GB..."
                 fallocate -l ${REQ_SPACE_GB}G "$file_path" 2>/dev/null
                 if [ $? -eq 0 ]; then
                    msg "success" "Alocado com sucesso."
                 else
                    msg "error" "Falha na alocação."
                 fi
             fi
        fi
        echo ""
    done
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# 4. Wizard Completo
action_wizard() {
    header
    echo -e "   ${C_ACCENT}🧙 WIZARD DE AUTOMAÇÃO COMPLETA${C_RESET}\n"
    echo -e "   Este processo irá executar sequencialmente:"
    echo -e "   ${C_SECONDARY}1.${C_RESET} Limpeza Manual"
    echo -e "   ${C_SECONDARY}2.${C_RESET} Configuração de Cron"
    echo -e "   ${C_SECONDARY}3.${C_RESET} Alocação de Storage\n"
    
    msg "input" "Pressione ENTER para iniciar..."
    read -r
    
    action_manual_clean
    action_cron_setup
    action_storage
    
    header
    msg "success" "Processamento em lote finalizado!"
    read -rsn1 -p "   Pressione qualquer tecla..."
}

# --- MENU PRINCIPAL ---

show_menu() {
    header
    echo -e "   ${C_WHITE}SELECIONE UMA OPERAÇÃO:${C_RESET}\n"
    
    # Opções Formatadas com o novo esquema Azul
    # Número em Ciano (Secondary), Texto em Branco, Descrição em Cinza
    echo -e "   ${C_SECONDARY}[1]${C_RESET} ${C_BOLD}Executar Limpeza Manual${C_RESET}      ${C_GRAY}(Imediata)${C_RESET}"
    echo -e "   ${C_SECONDARY}[2]${C_RESET} ${C_BOLD}Configurar Agendamento${C_RESET}       ${C_GRAY}(Crontab)${C_RESET}"
    echo -e "   ${C_SECONDARY}[3]${C_RESET} ${C_BOLD}Gerar Arquivos de Controle${C_RESET}   ${C_GRAY}(Storage)${C_RESET}"
    echo -e "   ${C_SECONDARY}[4]${C_RESET} ${C_BOLD}Instalação Padrão${C_RESET}            ${C_GRAY}(Cron + Storage)${C_RESET}"
    echo -e "   ${C_SECONDARY}[5]${C_RESET} ${C_BOLD}WIZARD COMPLETO${C_RESET}              ${C_GRAY}(Tudo em sequência)${C_RESET}"
    echo -e ""
    # Sair em vermelho sutil para diferenciar
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
        4) action_cron_setup; action_storage ;;
        5) action_wizard ;;
        0) 
           echo -e "\n   ${C_PRIMARY}Encerrando sistema... Até logo! 👋${C_RESET}\n"
           exit 0 ;;
        *) 
           msg "error" "Opção inválida."
           sleep 1 ;;
    esac
done
