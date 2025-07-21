#!/bin/bash

# Gestor de Swap Melhorado
# Versão: 2.0
# Autor: Script melhorado

set -euo pipefail  # Modo rigoroso: sair em erro, variáveis não definidas e falhas em pipes

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configurações
readonly SWAPFILE_PATH="/swapfile"
readonly MIN_SWAP_SIZE=1
readonly MAX_SWAP_SIZE=32

# Função para logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC} ${timestamp}: $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} ${timestamp}: $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} ${timestamp}: $message" >&2 ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} ${timestamp}: $message" ;;
    esac
}

# Verificar se o script está sendo executado como root ou com sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script precisa ser executado com privilégios de root (sudo)."
        exit 1
    fi
}

# Verificar espaço livre em disco
check_disk_space() {
    local required_size_gb="$1"
    local available_space_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $available_space_gb -lt $((required_size_gb + 1)) ]]; then
        log "ERROR" "Espaço insuficiente. Necessário: ${required_size_gb}GB + 1GB livre. Disponível: ${available_space_gb}GB"
        return 1
    fi
    return 0
}

# Função para mostrar o status atual da swap com informações detalhadas
show_swap_status() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}           STATUS DA SWAP ATUAL          ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    if swapon --show=NAME,SIZE,USED,PRIO,TYPE --noheadings 2>/dev/null | grep -q .; then
        echo -e "\n${GREEN}Dispositivos de swap ativos:${NC}"
        swapon --show=NAME,SIZE,USED,PRIO,TYPE 2>/dev/null
        
        # Mostrar uso da memória
        echo -e "\n${BLUE}Uso da memória:${NC}"
        free -h | grep -E "^(Mem|Swap):"
        
        # Informações sobre swappiness
        local swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "N/A")
        echo -e "\nSwappiness atual: ${swappiness}"
        
    else
        echo -e "\n${YELLOW}Nenhuma swap ativa no momento.${NC}"
        echo -e "\n${BLUE}Uso da memória:${NC}"
        free -h | grep "^Mem:"
    fi
    
    # Verificar se existe arquivo de swap
    if [[ -f "$SWAPFILE_PATH" ]]; then
        local swap_size=$(du -h "$SWAPFILE_PATH" 2>/dev/null | cut -f1)
        echo -e "\nArquivo de swap encontrado: $SWAPFILE_PATH (${swap_size})"
    fi
    
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

# Função para validar entrada de confirmação
confirm_action() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt (s/N): " response
        case "${response,,}" in
            s|sim|y|yes) return 0 ;;
            n|não|nao|no|"") return 1 ;;
            *) echo "Por favor, responda 's' para sim ou 'n' para não." ;;
        esac
    done
}

# Função para limpar a swap com verificações de segurança
clear_swap() {
    log "INFO" "Iniciando processo de limpeza da swap..."
    
    if ! swapon --show --noheadings | grep -q .; then
        log "WARN" "Nenhuma swap ativa para limpar."
        return 0
    fi
    
    echo -e "\n${YELLOW}⚠️  ATENÇÃO: Esta operação irá temporariamente desativar toda a swap.${NC}"
    echo "Certifique-se de que há memória RAM suficiente disponível."
    
    if ! confirm_action "Deseja continuar com a limpeza da swap?"; then
        log "INFO" "Operação cancelada pelo usuário."
        return 0
    fi
    
    log "INFO" "Desativando swap..."
    if swapoff -a; then
        log "SUCCESS" "Swap desativada com sucesso."
        
        log "INFO" "Reativando swap..."
        if swapon -a; then
            log "SUCCESS" "Swap reativada e limpa com sucesso."
        else
            log "ERROR" "Erro ao reativar a swap. Sistema pode estar instável!"
            return 1
        fi
    else
        log "ERROR" "Erro ao desativar a swap. Operação abortada."
        return 1
    fi
}

# Função para validar tamanho da swap
validate_swap_size() {
    local size_input="$1"
    local size_num
    local size_unit
    
    # Extrair número e unidade
    if [[ $size_input =~ ^([0-9]+)([GgMm]?)$ ]]; then
        size_num="${BASH_REMATCH[1]}"
        size_unit="${BASH_REMATCH[2],,}"
    else
        log "ERROR" "Formato inválido. Use apenas números seguidos de G ou M (ex: 4G, 512M)"
        return 1
    fi
    
    # Converter para GB para validação
    case "$size_unit" in
        "g"|"") size_gb=$size_num ;;
        "m") size_gb=$((size_num / 1024)) ;;
        *) log "ERROR" "Unidade inválida. Use G para Gigabytes ou M para Megabytes"; return 1 ;;
    esac
    
    # Validar limites
    if [[ $size_gb -lt $MIN_SWAP_SIZE ]]; then
        log "ERROR" "Tamanho mínimo: ${MIN_SWAP_SIZE}G"
        return 1
    fi
    
    if [[ $size_gb -gt $MAX_SWAP_SIZE ]]; then
        log "ERROR" "Tamanho máximo: ${MAX_SWAP_SIZE}G"
        return 1
    fi
    
    return 0
}

# Função para criar backup da configuração atual
backup_swap_config() {
    local backup_file="/tmp/swap_backup_$(date +%Y%m%d_%H%M%S)"
    
    echo "# Backup da configuração de swap - $(date)" > "$backup_file"
    swapon --show >> "$backup_file" 2>/dev/null || true
    grep swap /etc/fstab >> "$backup_file" 2>/dev/null || true
    
    log "INFO" "Backup da configuração salvo em: $backup_file"
}

# Função para redimensionar a swap com melhorias
resize_swap() {
    log "INFO" "Iniciando processo de redimensionamento da swap..."
    
    echo -e "\n${BLUE}Redimensionamento da Swap${NC}"
    echo "Tamanhos recomendados:"
    echo "  • Até 2GB RAM: swap = 2x RAM"
    echo "  • 2-8GB RAM: swap = igual à RAM"
    echo "  • Mais de 8GB RAM: swap = 4-8GB"
    echo ""
    
    local new_size
    while true; do
        read -p "Digite o novo tamanho da swap (ex: 4G, 512M): " new_size
        if validate_swap_size "$new_size"; then
            break
        fi
    done
    
    # Verificar espaço em disco
    local size_gb
    if [[ $new_size =~ ^([0-9]+)[Gg]?$ ]]; then
        size_gb="${BASH_REMATCH[1]}"
    elif [[ $new_size =~ ^([0-9]+)[Mm]$ ]]; then
        size_gb=$((${BASH_REMATCH[1]} / 1024 + 1))
    fi
    
    if ! check_disk_space "$size_gb"; then
        return 1
    fi
    
    echo -e "\n${YELLOW}⚠️  Esta operação irá:${NC}"
    echo "  1. Desativar a swap atual"
    echo "  2. Remover o arquivo de swap existente (se houver)"
    echo "  3. Criar um novo arquivo de swap de $new_size"
    echo "  4. Ativar a nova swap"
    
    if ! confirm_action "Confirma o redimensionamento da swap para $new_size?"; then
        log "INFO" "Operação cancelada pelo usuário."
        return 0
    fi
    
    # Fazer backup
    backup_swap_config
    
    # Desativar swap atual
    log "INFO" "Desativando swap atual..."
    swapoff -a 2>/dev/null || true
    
    # Remover arquivo antigo se existir
    if [[ -f "$SWAPFILE_PATH" ]]; then
        log "INFO" "Removendo arquivo de swap antigo..."
        rm -f "$SWAPFILE_PATH"
    fi
    
    # Criar novo arquivo de swap
    log "INFO" "Criando novo arquivo de swap de $new_size..."
    
    # Usar fallocate se disponível (mais rápido), senão dd
    if command -v fallocate >/dev/null 2>&1; then
        if fallocate -l "$new_size" "$SWAPFILE_PATH"; then
            log "SUCCESS" "Arquivo de swap criado com fallocate."
        else
            log "WARN" "fallocate falhou, usando dd..."
            create_swap_with_dd "$new_size"
        fi
    else
        create_swap_with_dd "$new_size"
    fi
    
    # Configurar permissões e formato
    log "INFO" "Configurando permissões e formato..."
    chmod 600 "$SWAPFILE_PATH"
    
    if mkswap "$SWAPFILE_PATH"; then
        log "SUCCESS" "Formato de swap aplicado."
    else
        log "ERROR" "Erro ao formatar o arquivo de swap."
        rm -f "$SWAPFILE_PATH"
        return 1
    fi
    
    # Ativar nova swap
    log "INFO" "Ativando nova swap..."
    if swapon "$SWAPFILE_PATH"; then
        log "SUCCESS" "Swap de $new_size criada e ativada com sucesso!"
        
        # Adicionar ao fstab para tornar permanente
        if ! grep -q "$SWAPFILE_PATH" /etc/fstab 2>/dev/null; then
            echo -e "\n${YELLOW}💡 Dica: Para tornar a swap permanente, adicione ao /etc/fstab:${NC}"
            echo "$SWAPFILE_PATH none swap sw 0 0" | sudo tee -a /etc/fstab
            log "SUCCESS" "Adicionado ao /etc/fstab."
        else
            log "INFO" "Swap já está configurada em /etc/fstab."
        fi
    else
        log "ERROR" "Erro ao ativar a nova swap."
        rm -f "$SWAPFILE_PATH"
        return 1
    fi
}

# Função auxiliar para criar swap com dd
create_swap_with_dd() {
    local size="$1"
    if dd if=/dev/zero of="$SWAPFILE_PATH" bs=1M count="$(convert_to_mb "$size")" status=progress; then
        log "SUCCESS" "Arquivo de swap criado com dd."
    else
        log "ERROR" "Erro ao criar arquivo de swap com dd."
        return 1
    fi
}

# Converter tamanho para MB
convert_to_mb() {
    local size="$1"
    if [[ $size =~ ^([0-9]+)[Gg]?$ ]]; then
        echo $((${BASH_REMATCH[1]} * 1024))
    elif [[ $size =~ ^([0-9]+)[Mm]$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# Função para ajustar swappiness
adjust_swappiness() {
    local current_swappiness=$(cat /proc/sys/vm/swappiness)
    
    echo -e "\n${BLUE}Ajuste do Swappiness${NC}"
    echo "Swappiness atual: $current_swappiness"
    echo ""
    echo "Valores recomendados:"
    echo "  • 0-10: Uso mínimo da swap (servidores)"
    echo "  • 30-50: Uso moderado (workstations)"
    echo "  • 60-100: Uso agressivo da swap"
    echo ""
    
    local new_swappiness
    while true; do
        read -p "Digite o novo valor de swappiness (0-100) ou Enter para manter atual: " new_swappiness
        
        if [[ -z "$new_swappiness" ]]; then
            log "INFO" "Mantendo swappiness atual: $current_swappiness"
            return 0
        fi
        
        if [[ "$new_swappiness" =~ ^[0-9]+$ ]] && [[ $new_swappiness -ge 0 ]] && [[ $new_swappiness -le 100 ]]; then
            break
        else
            echo "Por favor, digite um número entre 0 e 100."
        fi
    done
    
    if confirm_action "Alterar swappiness de $current_swappiness para $new_swappiness?"; then
        echo "$new_swappiness" > /proc/sys/vm/swappiness
        log "SUCCESS" "Swappiness alterado para $new_swappiness"
        
        echo -e "\n${YELLOW}💡 Para tornar permanente, adicione ao /etc/sysctl.conf:${NC}"
        echo "vm.swappiness = $new_swappiness"
    else
        log "INFO" "Operação cancelada."
    fi
}

# Menu principal melhorado
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║           GESTOR DE SWAP v2.0          ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    show_swap_status
    
    echo -e "${BLUE}Opções disponíveis:${NC}"
    echo "  1. 🧹 Limpar a Swap"
    echo "  2. 📏 Redimensionar a Swap"
    echo "  3. ⚙️  Ajustar Swappiness"
    echo "  4. 🔄 Atualizar Status"
    echo "  5. ❌ Sair"
    echo ""
}

# Função principal
main() {
    # Verificar privilégios
    check_privileges
    
    log "INFO" "Iniciando Gestor de Swap v2.0"
    
    while true; do
        show_menu
        
        local option
        read -p "Escolha uma opção (1-5): " option
        
        case "$option" in
            1)
                clear_swap
                read -p "Pressione Enter para continuar..." -r
                ;;
            2)
                resize_swap
                read -p "Pressione Enter para continuar..." -r
                ;;
            3)
                adjust_swappiness
                read -p "Pressione Enter para continuar..." -r
                ;;
            4)
                log "INFO" "Atualizando status..."
                ;;
            5)
                log "INFO" "Encerrando Gestor de Swap. Até logo!"
                exit 0
                ;;
            *)
                log "WARN" "Opção inválida: $option. Escolha uma opção entre 1-5."
                sleep 2
                ;;
        esac
    done
}

# Tratamento de sinais
trap 'log "WARN" "Script interrompido pelo usuário."; exit 130' INT TERM

# Executar função principal
main "$@"
