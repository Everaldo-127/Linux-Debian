#!/bin/bash
set -euo pipefail

DATA=$(date +%Y%m%d-%H%M%S)
LOG="/var/log/kde_migration_${DATA}.log"
BACKUP="/root/rollback_xfce_${DATA}.tar.gz"
SDDM_CONF_DIR="/etc/sddm.conf.d"
SDDM_CONF_FILE="${SDDM_CONF_DIR}/00-disable-virtual-keyboard.conf"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

rollback() {
  local err_code=$?
  log "Rollback iniciado devido a erro. Código: $err_code"
  if [[ -f "$BACKUP" ]]; then
    log "Restaurando backup $BACKUP"
    tar -xzf "$BACKUP" -C /
    log "Rollback executado. Reinicie o sistema."
  else
    log "Backup não encontrado. Rollback não pôde ser executado."
  fi
  exit $err_code
}

trap 'rollback' ERR

log "Iniciando migração para KDE no Xubuntu Minimal 24.04."

# Verifica se está rodando como root
if [[ "$EUID" -ne 0 ]]; then
  log "ERRO: Execute este script como root."
  exit 1
fi

# Verifica se é Ubuntu 24.04
if ! command -v lsb_release &>/dev/null; then
  apt update -y >> "$LOG"
  apt install -y lsb-release >> "$LOG"
fi

DISTRO=$(lsb_release -is)
VERSION=$(lsb_release -rs)

if [[ "$DISTRO" != "Ubuntu" || "$VERSION" != "24.04" ]]; then
  log "ERRO: Este script é específico para Ubuntu 24.04 (Xubuntu Minimal)."
  exit 1
fi

# Detecta gerenciador gráfico atual
CURRENT_DM=""
if [[ -f /etc/X11/default-display-manager ]]; then
  CURRENT_DM=$(cat /etc/X11/default-display-manager)
fi
log "Gerenciador de display atual: $CURRENT_DM"

PACOTES=("kubuntu-desktop" "plasma-desktop" "sddm")

# Se já estiver usando SDDM (KDE), só ajusta ambiente
if [[ "$CURRENT_DM" == "/usr/bin/sddm" ]]; then
  log "Sistema já usa SDDM (KDE). Ajustando configurações do ambiente..."

  # Cria backup mesmo que não vá reinstalar
  DIRS=(
    "/etc/apt"
    "/etc/X11"
    "/etc/sddm.conf.d"
    "/etc/lightdm"
    "/etc/default"
    "/etc/environment"
    "/var/log/apt"
  )
  DIRS_EXISTENTES=()
  for d in "${DIRS[@]}"; do
    [[ -e "$d" ]] && DIRS_EXISTENTES+=("$d") || log "Aviso: $d não encontrado no sistema, ignorando."
  done
  log "Criando backup para rollback..."
  tar -czpf "$BACKUP" "${DIRS_EXISTENTES[@]}" >> "$LOG" 2>&1 || { log "ERRO: falha ao criar backup."; exit 1; }
  log "Backup salvo em $BACKUP."

  # Verifica se pacotes essenciais estão instalados
  for p in "${PACOTES[@]}"; do
    if ! dpkg -l "$p" &>/dev/null; then
      log "ERRO: Pacote $p não está instalado. Abortando para instalação."
      exit 1
    fi
  done

else
  # Não usa SDDM, faz instalação completa

  # Verifica quais pacotes estão faltando
  PACOTES_FALTANDO=()
  for p in "${PACOTES[@]}"; do
    if ! dpkg -l "$p" &>/dev/null; then
      PACOTES_FALTANDO+=("$p")
    fi
  done

  if [[ ${#PACOTES_FALTANDO[@]} -gt 0 ]]; then
    log "Pacotes faltando: ${PACOTES_FALTANDO[*]}"
    apt update -y >> "$LOG" 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y "${PACOTES_FALTANDO[@]}" >> "$LOG" 2>&1
  else
    log "Todos pacotes necessários já estão instalados."
  fi

  # Confirma instalação
  for p in "${PACOTES[@]}"; do
    if ! dpkg -l "$p" &>/dev/null; then
      log "ERRO: Pacote $p não instalado corretamente."
      rollback
    fi
  done
  log "Pacotes essenciais instalados com sucesso."

  # Cria backup para rollback
  DIRS=(
    "/etc/apt"
    "/etc/X11"
    "/etc/sddm.conf.d"
    "/etc/lightdm"
    "/etc/default"
    "/etc/environment"
    "/var/log/apt"
  )
  DIRS_EXISTENTES=()
  for d in "${DIRS[@]}"; do
    [[ -e "$d" ]] && DIRS_EXISTENTES+=("$d") || log "Aviso: $d não encontrado no sistema, ignorando."
  done
  log "Criando backup para rollback..."
  tar -czpf "$BACKUP" "${DIRS_EXISTENTES[@]}" >> "$LOG" 2>&1 || { log "ERRO: falha ao criar backup."; rollback; }

  # Define SDDM como gerenciador padrão
  log "Configurando SDDM como gerenciador padrão..."
  echo "/usr/bin/sddm" > /etc/X11/default-display-manager
  dpkg-reconfigure sddm --frontend=noninteractive >> "$LOG" 2>&1

fi

# Configura SDDM para desativar teclado virtual
log "Configurando SDDM para desabilitar teclado virtual..."
mkdir -p "$SDDM_CONF_DIR"
cat > "$SDDM_CONF_FILE" << EOF
[General]
InputMethod=

[Users]
MaximumUid=65000
EOF

# Verificação de erros no journal e apt logs (ignorando erros irrelevantes)
log "Verificando logs do sistema por erros..."
JOURNAL_ERRORS=$(journalctl -p err -b --no-pager | grep -vE "ufw|apport|audit|systemd-coredump|kernel" || true)
if [[ -n "$JOURNAL_ERRORS" ]]; then
  log "ERRO: Erros detectados no journalctl (filtros aplicados):"
  log "$JOURNAL_ERRORS"
  rollback
fi

APT_ERRORS=$(grep -i "error" /var/log/apt/history.log /var/log/apt/term.log 2>/dev/null || true)
if [[ -n "$APT_ERRORS" ]]; then
  log "ERRO: Erros detectados nos logs do apt:"
  log "$APT_ERRORS"
  rollback
fi

# Remover XFCE e LightDM se não for KDE ativo
if [[ "$CURRENT_DM" != "/usr/bin/sddm" ]]; then
  log "Removendo XFCE e LightDM (ignorando ausência)..."
  set +e
  apt purge -y xubuntu-desktop xfce4* lightdm* >> "$LOG" 2>&1
  apt autoremove -y --purge >> "$LOG" 2>&1
  set -e
else
  log "Sistema já usa SDDM, remoção do XFCE não necessária."
fi

# Atualiza initramfs e grub
log "Atualizando initramfs e grub..."
update-initramfs -u >> "$LOG" 2>&1
update-grub >> "$LOG" 2>&1

log "Migração para KDE concluída com sucesso. Reinicie o sistema para aplicar as alterações."
exit 0

