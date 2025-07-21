#!/bin/bash

# --- Configurações Iniciais e Cores ---
LOG_FILE="/var/log/xubuntu_snapd_repair_final_pinning.log" # Novo log para esta versão final
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logar mensagens (tanto no console quanto no arquivo)
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
    echo -e "$1" # Exibe no console
}

# Função para verificar e tratar erros
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}[ERRO] Processo falhou: $1${NC}"
        log "${RED}O script será abortado. Por favor, revise as mensagens de erro acima e o log em ${LOG_FILE}.${NC}"
        # Tentar desmontar recursivamente em caso de erro para limpeza
        if [ -d "$MOUNT_POINT" ] && mountpoint -q "$MOUNT_POINT"; then
            log "${YELLOW}Tentando desmontar diretório de montagem recursivamente antes de sair...${NC}"
            sudo umount -lR "$MOUNT_POINT" 2>/dev/null
        fi
        # Tentar remover o diretório de montagem em caso de erro
        if [ -d "$MOUNT_POINT" ]; then
            log "${YELLOW}Tentando remover o diretório de montagem '$MOUNT_POINT' em caso de erro...${NC}"
            sudo rm -rf "$MOUNT_POINT" 2>/dev/null
        fi
        exit 1
    fi
}

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}  INÍCIO DO SCRIPT DE REPARO FINAL (REMOVENDO APT PINNING)     ${NC}"
echo -e "${BLUE}  Xubuntu Minimal 24.04 - Executando do Live USB               ${NC}"
echo -e "${BLUE}===============================================================${NC}"
echo ""

# --- ETAPA 1: Verificação de Permissões ---
echo -e "${YELLOW}[1/9] Verificando permissões...${NC}" # Etapas numeradas novamente
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Este script deve ser executado como root. Por favor, use 'sudo bash $0'.${NC}"
    exit 1
fi
log "${GREEN}Permissões root verificadas.${NC}"
echo ""

# --- ETAPA 2: Identificação e Confirmação da Partição Raiz do HD ---
echo -e "${YELLOW}[2/9] Identificando a partição raiz do seu Xubuntu no HD...${NC}"
echo -e "${BLUE}Saída do 'lsblk' para análise:${NC}"
lsblk

POSSIBLE_ROOT_PARTITIONS=$(lsblk -no NAME,SIZE,TYPE,MOUNTPOINTS,RM | grep "disk\|part" | \
    grep -E "mmcblk0p[0-9]+" | \
    awk '{if ($4 != "1" && $2 ~ /G|M/) print "/dev/"$1 " ("$2 " - "$5")"}')

if [ -z "$POSSIBLE_ROOT_PARTITIONS" ]; then
    log "${RED}Nenhuma partição de HD provável encontrada. Verifique sua instalação.${NC}"
    exit 1
fi

echo -e "${BLUE}Partições prováveis para a raiz do seu Xubuntu no HD:${NC}"
echo -e "${GREEN}${POSSIBLE_ROOT_PARTITIONS}${NC}"
echo -e "${YELLOW}Confirmado: ${GREEN}/dev/mmcblk0p2${YELLOW} é a partição raiz que você usou anteriormente.${NC}"

read -p "Digite o nome COMPLETO da partição raiz do seu Xubuntu no HD (ex: /dev/mmcblk0p2): " TARGET_PARTITION

if [ -z "$TARGET_PARTITION" ]; then
    log "${RED}Nome da partição não pode ser vazio. Abortando.${NC}"
    exit 1
fi

if ! [[ -b "$TARGET_PARTITION" ]]; then
    log "${RED}A partição '$TARGET_PARTITION' não parece ser um dispositivo de bloco válido. Abortando.${NC}"
    exit 1
fi

log "${GREEN}Partição raiz do HD identificada: $TARGET_PARTITION${NC}"
echo ""

# --- ETAPA 3: Preparação e Montagem do Sistema de Arquivos Alvo ---
echo -e "${YELLOW}[3/9] Preparando e montando o sistema de arquivos do HD...${NC}"
MOUNT_POINT="/mnt/xubuntu_repair"

log "${BLUE}Garantindo que o ponto de montagem '${MOUNT_POINT}' esteja completamente limpo e desocupado...${NC}"
if mountpoint -q "$MOUNT_POINT"; then
    log "${YELLOW}O diretório '${MOUNT_POINT}' já está montado. Tentando desmontar recursivamente...${NC}"
    sudo umount -lR "$MOUNT_POINT" 2>/dev/null
    log "${GREEN}Desmontado com sucesso (se estava montado).${NC}"
fi

if [ -d "$MOUNT_POINT" ]; then
    log "${YELLOW}Removendo diretório '${MOUNT_POINT}' e recriando para garantir limpeza...${NC}"
    sudo rm -rf "$MOUNT_POINT"
    check_error "Falha ao remover o diretório '$MOUNT_POINT'."
fi

sudo mkdir -p "$MOUNT_POINT"
check_error "Falha ao criar o diretório de montagem $MOUNT_POINT."
log "${GREEN}Ponto de montagem '${MOUNT_POINT}' preparado e limpo.${NC}"

log "${BLUE}Montando $TARGET_PARTITION em $MOUNT_POINT...${NC}"
sudo mount "$TARGET_PARTITION" "$MOUNT_POINT"
check_error "Falha ao montar a partição $TARGET_PARTITION. Verifique se ela não está corrompida ou já montada."

log "${BLUE}Montando diretórios essenciais (proc, sys, dev, dev/pts, run)...${NC}"
sudo mount --bind /proc "$MOUNT_POINT/proc"
check_error "Falha ao montar /proc."
sudo mount --bind /sys "$MOUNT_POINT/sys"
check_error "Falha ao montar /sys."
sudo mount --bind /dev "$MOUNT_POINT/dev"
check_error "Falha ao montar /dev."
sudo mount --bind /dev/pts "$MOUNT_POINT/dev/pts"
check_error "Falha ao montar /dev/pts."
sudo mount --bind /run "$MOUNT_POINT/run"
check_error "Falha ao montar /run."

if [ -d "$MOUNT_POINT/boot/efi" ] && ! mountpoint -q "$MOUNT_POINT/boot/efi"; then
    log "${BLUE}Tentando montar /boot/efi (se existir)...${NC}"
    EFI_PARTITION="/dev/mmcblk0p1"
    if [[ -b "$EFI_PARTITION" ]]; then
        sudo mount "$EFI_PARTITION" "$MOUNT_POINT/boot/efi"
        log "${GREEN}/boot/efi montado com sucesso.${NC}" || log "${YELLOW}Não foi possível montar /boot/efi. Prosseguindo.${NC}"
    else
        log "${YELLOW}Partição EFI ($EFI_PARTITION) não encontrada ou não é um dispositivo de bloco. Pulando a montagem.${NC}"
    fi
else
    log "${YELLOW}/boot/efi não existe ou já está montado dentro do alvo. Pulando a montagem.${NC}"
fi

log "${GREEN}Sistema de arquivos do HD montado com sucesso em $MOUNT_POINT.${NC}"
echo ""

# --- ETAPA 4: Configuração do Ambiente chroot ---
echo -e "${YELLOW}[4/9] Configurando o ambiente chroot...${NC}"
log "${BLUE}Removendo qualquer resolv.conf existente no alvo para uma cópia limpa...${NC}"
sudo rm -f "$MOUNT_POINT/etc/resolv.conf"
check_error "Falha ao remover resolv.conf existente no alvo."

log "${BLUE}Copiando resolv.conf do sistema live para garantir conectividade dentro do chroot...${NC}"
sudo cp /etc/resolv.conf "$MOUNT_POINT/etc/"
check_error "Falha ao copiar resolv.conf."

log "${GREEN}Ambiente chroot preparado. Entrando no chroot para reparo...${NC}"
echo ""

# --- ETAPA 5: Reparação Agressiva do APT e Diagnóstico do snapd dentro do chroot ---
echo -e "${YELLOW}[5/9] Realizando reparação agressiva do APT e diagnóstico do snapd dentro do chroot...${NC}"
sudo chroot "$MOUNT_POINT" bash -c "
    echo \"${BLUE}Executando dentro do chroot...${NC}\"
    
    echo \"${YELLOW}Removendo arquivos de lista de pacotes antigos/corrompidos...${NC}\"
    rm -rf /var/lib/apt/lists/*
    rm -rf /var/lib/apt/lists/partial/*
    
    echo \"${YELLOW}Garantindo que o sources.list aponte para repositórios oficiais do Noble (24.04) com universe...${NC}\"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak_advanced_repair_$(date +%Y%m%d%H%M%S) # Backup

    echo 'deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse' > /etc/apt/sources.list
    echo 'deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse' >> /etc/apt/sources.list
    echo 'deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse' >> /etc/apt/sources.list
    echo 'deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse' >> /etc/apt/sources.list

    rm -f /etc/apt/sources.list.d/*.list

    echo \"${YELLOW}Atualizando lista de pacotes no sistema do HD (forçado)...${NC}\"
    apt update --allow-releaseinfo-change -y
    
    echo \"${BLUE}--- DIAGNÓSTICO DETALHADO DO SNAPD (PRÉ-REPARO DE PINNING) ---${NC}\"
    echo \"${BLUE}Saída de 'apt policy snapd':${NC}\"
    apt policy snapd
    
    echo \"${BLUE}Verificando se 'snapd' está em hold (retido):${NC}\"
    HOLD_STATUS=\$(apt-mark showhold snapd)
    if [ -n \"\$HOLD_STATUS\" ]; then
        echo \"${YELLOW}ATENÇÃO: 'snapd' está em hold. Tentando remover o hold...${NC}\"
        apt-mark unhold snapd
        echo \"${GREEN}'snapd' removido do hold (se aplicável).${NC}\"
    else
        echo \"${GREEN}'snapd' não está em hold.${NC}\"
    fi
    
    echo \"${BLUE}Dependências do 'snapd' ('apt-cache depends snapd'):${NC}\"
    apt-cache depends snapd

    echo \"${BLUE}Política de APT geral ('apt-cache policy'):${NC}\"
    apt-cache policy
    echo \"${BLUE}--- FIM DO DIAGNÓSTICO DETALHADO DO SNAPD ---${NC}\"

    echo \"${YELLOW}Limpando cache do apt e removendo pacotes órfãos...${NC}\"
    apt clean
    apt autoremove --purge -y

    echo \"${YELLOW}Tentando corrigir pacotes quebrados e pendentes (novamente)...${NC}\"
    apt --fix-broken install -y
    dpkg --configure -a
    apt-get install -f -y # Força resolução de dependências

    echo \"${GREEN}Reparo agressivo do APT concluído dentro do chroot.${NC}\"
"
check_error "Falha durante a reparação agressiva do APT e diagnóstico dentro do chroot."
log "${GREEN}Reparo agressivo do APT e diagnóstico do snapd concluídos no sistema do HD.${NC}"
echo ""

# --- ETAPA 6: Removendo o APT Pinning do snapd dentro do chroot ---
echo -e "${YELLOW}[6/9] Removendo regras de APT pinning para 'snapd' dentro do chroot...${NC}"
sudo chroot "$MOUNT_POINT" bash -c "
    echo \"${BLUE}Executando dentro do chroot...${NC}\"
    echo \"${YELLOW}Procurando e removendo arquivos de preferências do APT que despriorizam 'snapd' (${RED}ESTA É A ETAPA CRÍTICA!${NC})...${NC}\"
    
    # Lista arquivos .pref que contêm 'snapd' e são relevantes
    FIND_PINNING_FILES=\$(grep -r -l -E 'Package: snapd|Pin: -10' /etc/apt/preferences.d/ 2>/dev/null)
    
    if [ -n \"\$FIND_PINNING_FILES\" ]; then
        echo \"${YELLOW}Arquivos de pinning encontrados:${NC}\"
        echo \"\$FIND_PINNING_FILES\"
        for file in \$FIND_PINNING_FILES; do
            log \"${YELLOW}Fazendo backup de \$file para \$file.bak_pinning_$(date +%Y%m%d%H%M%S)...${NC}\"
            cp \"\$file\" \"\$file.bak_pinning_$(date +%Y%m%d%H%M%S)\"
            
            log \"${YELLOW}Removendo \$file...${NC}\"
            rm -f \"\$file\"
            echo \"${GREEN}Arquivo \$file removido.${NC}\"
        done
        echo \"${GREEN}Regras de APT pinning para 'snapd' removidas.${NC}\"
    else
        echo \"${GREEN}Nenhum arquivo de APT pinning para 'snapd' encontrado (ou já removido).${NC}\"
    fi

    echo \"${YELLOW}Atualizando a lista de pacotes novamente após a remoção do pinning...${NC}\"
    apt update --allow-releaseinfo-change -y

    echo \"${BLUE}--- DIAGNÓSTICO PÓS-REPARO DE PINNING ---${NC}\"
    echo \"${BLUE}Saída de 'apt policy snapd' APÓS a remoção do pinning:${NC}\"
    apt policy snapd
    echo \"${BLUE}--- FIM DO DIAGNÓSTICO PÓS-REPARO DE PINNING ---${NC}\"

    echo \"${GREEN}Remoção do APT pinning para 'snapd' concluída dentro do chroot.${NC}\"
"
check_error "Falha durante a remoção do APT pinning para 'snapd'."
log "${GREEN}APT pinning para 'snapd' removido com sucesso no sistema do HD.${NC}"
echo ""

# --- ETAPA 7: Reinstalação Completa do snapd dentro do chroot ---
echo -e "${YELLOW}[7/9] Reinstalando snapd dentro do ambiente chroot (tentativa final após pinning)...${NC}"
sudo chroot "$MOUNT_POINT" bash -c "
    echo \"${YELLOW}Removendo quaisquer remanescentes do snapd (limpeza final)...${NC}\"
    apt purge snapd -y 2>/dev/null || true
    apt autoremove --purge -y
    rm -rf /var/lib/snapd /snap
    
    echo \"${YELLOW}Reinstalando snapd...${NC}\"
    apt install snapd -y
    
    echo \"${YELLOW}Verificando o status e versão do snapd após reinstalação (dentro do chroot)...\${NC}\"
    systemctl status snapd --no-pager || true
    snap version || true
    
    echo \"${GREEN}Reinstalação do snapd concluída dentro do chroot.${NC}\"
"
check_error "Falha durante a reinstalação do snapd."
log "${GREEN}Snapd reinstalado (ou tentativa finalizada) com sucesso no sistema do HD.${NC}"
echo ""

# --- ETAPA 8: Reinstalação de Meta-Pacotes Essenciais e Verificação Final (Firefox) ---
echo -e "${YELLOW}[8/9] Reinstalando meta-pacotes essenciais e verificando funcionalidade do APT (instalando Firefox)...${NC}"
sudo chroot "$MOUNT_POINT" bash -c "
    echo \"${YELLOW}Reinstalando meta-pacote xubuntu-core para garantir a integridade do sistema base...${NC}\"
    apt install xubuntu-core -y || apt install ubuntu-minimal -y
    
    echo \"${YELLOW}Tentando instalar Firefox via apt (verificação final)...\${NC}\"
    apt install firefox -y
    if [ \$? -eq 0 ]; then
        echo \"${GREEN}Firefox instalado com sucesso via APT! O APT e o snapd estão funcionando!${NC}\"
    else
        echo \"${RED}Falha ao instalar Firefox via APT. O problema pode persistir. Por favor, verifique o log para detalhes.${NC}\"
        echo \"${YELLOW}Para investigar mais a fundo, tente 'sudo apt install firefox' e 'sudo apt policy snapd' após reiniciar no HD.${NC}\"
    fi
"
check_error "Falha na verificação da funcionalidade do APT (instalação do Firefox ou meta-pacotes)."
log "${GREEN}Verificação da funcionalidade do APT (instalação do Firefox) concluída.${NC}"
echo ""

# --- ETAPA 9: Limpeza e Saída do Ambiente chroot ---
echo -e "${YELLOW}[9/9] Limpando e saindo do ambiente de reparo...${NC}"
log "${BLUE}Saindo do chroot...${NC}"

log "${BLUE}Desmontando partições...${NC}"
sudo umount -lR "$MOUNT_POINT"
check_error "Falha ao desmontar partições."

log "${BLUE}Removendo diretório temporário de montagem...${NC}"
sudo rm -rf "$MOUNT_POINT"
check_error "Falha ao remover diretório de montagem."

log "${GREEN}Limpeza concluída. O processo de reparo foi finalizado.${NC}"
echo ""

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}  REPARO CONCLUÍDO!                                            ${NC}"
echo -e "${BLUE}===============================================================${NC}"
echo -e "${GREEN}Seu Xubuntu Minimal no HD passou por uma reparação intensiva e diagnóstico aprofundado.${NC}"
echo -e "${GREEN}Acreditamos que o problema de pinning do snapd foi resolvido.${NC}"
echo -e "${GREEN}Agora, por favor, ${YELLOW}reinicie o seu notebook${GREEN} e inicialize pelo HD.${NC}"
echo -e "${YELLOW}Verifique se o Firefox e outros programas podem ser instalados normalmente via APT ou Snap.${NC}"
echo -e "${RED}CASO O PROBLEMA PERSISTA, ANALISE CUIDADOSAMENTE O LOG COMPLETO EM:${NC} ${GREEN}$LOG_FILE${NC}"
echo -e "${BLUE}===============================================================${NC}"
