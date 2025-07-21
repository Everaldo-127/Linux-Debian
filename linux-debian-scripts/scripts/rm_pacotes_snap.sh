#!/bin/bash

LOGFILE="$HOME/remover_snap_log.txt"

echo "=== Remoção completa do Snap iniciada em $(date) ===" | tee "$LOGFILE"

# Verifica se o script está sendo executado com sudo/root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script com sudo ou como root." | tee -a "$LOGFILE"
  exit 1
fi

echo "ATENÇÃO: Este script removerá TODOS os snaps instalados e o snapd do sistema."
read -p "Deseja continuar? (s/N): " confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
  echo "Operação cancelada pelo usuário." | tee -a "$LOGFILE"
  exit 0
fi

echo "Passo 1: Listando snaps instalados..." | tee -a "$LOGFILE"
SNAPS=$(snap list | awk 'NR>1 {print $1}')
if [ -z "$SNAPS" ]; then
  echo "Nenhum snap instalado encontrado." | tee -a "$LOGFILE"
else
  echo "Removendo snaps instalados..." | tee -a "$LOGFILE"
  for snap in $SNAPS; do
    echo "Removendo snap: $snap" | tee -a "$LOGFILE"
    snap remove --purge "$snap" >> "$LOGFILE" 2>&1
  done
fi

echo "Passo 2: Parando e desabilitando o serviço snapd..." | tee -a "$LOGFILE"
systemctl stop snapd >> "$LOGFILE" 2>&1
systemctl disable snapd >> "$LOGFILE" 2>&1

echo "Passo 3: Removendo pacote snapd..." | tee -a "$LOGFILE"
apt purge snapd -y >> "$LOGFILE" 2>&1

echo "Passo 4: Removendo diretórios relacionados ao snap..." | tee -a "$LOGFILE"
rm -rf ~/snap /snap /var/snap /var/lib/snapd >> "$LOGFILE" 2>&1

echo "Passo 5: Bloqueando futuras instalações do snapd via apt..." | tee -a "$LOGFILE"
echo -e "Package: snapd\nPin: release a=*\nPin-Priority: -10" > /etc/apt/preferences.d/nosnap.pref

echo "Passo 6: Limpando pacotes órfãos e atualizando o sistema..." | tee -a "$LOGFILE"
apt autoremove --purge -y >> "$LOGFILE" 2>&1
apt update >> "$LOGFILE" 2>&1

echo "=== Remoção do Snap concluída em $(date) ===" | tee -a "$LOGFILE"
echo "Logs completos em $LOGFILE"

