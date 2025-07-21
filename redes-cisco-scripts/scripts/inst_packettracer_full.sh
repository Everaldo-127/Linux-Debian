#!/bin/bash

################################################################################
# INSTALADOR CISCO PACKET TRACER - BLACKOPS DEFINITIVO                        #
#                                                                              #
# 💻 Este script automatiza o processo de instalação do Cisco Packet Tracer   #
# em sistemas baseados no Ubuntu. Ele lida com locks, dependências,           #
# repositórios temporários, e permite instalar um .deb baixado manualmente.   #
#                                                                              #
# ✅ Limpeza de locks e pacotes em hold                                        #
# ✅ Atualização e correção automática de pacotes                              #
# ✅ Gerenciamento de repositório Jammy temporário                             #
# ✅ Exibição de links para download do Packet Tracer                          #
# ✅ Instalação direta via arquivo .deb local                                  #
################################################################################

LOGFILE="/home/$USER/logs/packettracer_install.log"
mkdir -p "/home/$USER/logs"
exec > >(tee -a "$LOGFILE") 2>&1

log() {
  echo -e "[$(date +%H:%M:%S)] $1"
}

limpa_locks_holds() {
  log "🧹 LIMPANDO LOCKS E HOLDS"
  rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
  dpkg --configure -a
  log "🔓 Removendo pacotes em hold (se existirem)"
  for pkg in $(apt-mark showhold); do
    log "🔓 Removendo hold de: $pkg"
    apt-mark unhold "$pkg"
  done
}

atualiza_apt() {
  log "🔄 ATUALIZANDO APT"
  apt update -y || return 1
}

corrige_dependencias() {
  log "🧺 CORRIGINDO DEPENDÊNCIAS COM APTITUDE"
  if ! command -v aptitude &>/dev/null; then
    log "🚫 aptitude não encontrado. Instalando..."
    apt install -y aptitude || return 1
  else
    log "✅ aptitude já instalado"
  fi

  for tentativa in {1..3}; do
    log "🔁 Tentativa $tentativa de correção automática"
    aptitude -f -y install && return 0
    sleep 2
  done
  return 1
}

adiciona_repo_jammy() {
  log "🧩 ADICIONANDO REPO JAMMY TEMPORÁRIO"
  echo -e "deb http://archive.ubuntu.com/ubuntu jammy main universe multiverse" >/etc/apt/sources.list.d/jammy-temp.list
  echo -e "Package: *\nPin: release a=jammy\nPin-Priority: 1001" >/etc/apt/preferences.d/jammy-pin
  apt update || return 1
  return 0
}

remove_repo_jammy() {
  log "🧽 REMOVENDO JAMMY TEMPORÁRIO"
  rm -f /etc/apt/sources.list.d/jammy-temp.list /etc/apt/preferences.d/jammy-pin
  apt update
}

exibir_link_gzip() {
  echo -e "\n\033[1;36m🔗 Link para download do pacote gzipado:\033[0m"

  echo -e "\n\033[1;37mLINK : https://drive.google.com/file/d/1y-mLAzwKHjbtLqJYRBaZq11Vf1Vjppra/view?usp=drive_link\033[0m"

  echo -e "\n\033[0;36m• Após o download, descompacte com o comando:\033[0m \033[1;33mgunzip nome_do_pacote.deb.gz\033[0m"
  echo -e "\033[0;36m• Após download, use a opção 3 para instalar com o arquivo .deb baixado.\033[0m"

  read -rp $'\nPressione ENTER para retornar ao menu...'
}

exibir_link_cisco() {
  echo -e "\n\033[1;36m🔗 Link para download oficial da Cisco NetAcad:\033[0m"

  echo -e "\n\033[1;37mLINK: https://www.netacad.com/resources/lab-downloads?courseLang=en-US\033[0m"

  echo -e "\n\033[0;36m• Após download, use a opção 3 para instalar com o arquivo .deb baixado.\033[0m"

  read -rp $'\nPressione ENTER para retornar ao menu...'
}

menu_final() {
  clear
  echo -e "\n\033[1;32m====== MENU de INSTALAÇÃO do Cisco PACKET TRACER ======\033[0m\n"

  echo -e "\033[1;34m1)\033[0m Baixar pacote gzipado do Packet Tracer (Google Drive) - \033[1;33mEXIBIR LINK\033[0m"
  echo -e "   \033[0;36m• Após download, descompacte com gunzip e use a opção 3 para instalar\033[0m\n"

  echo -e "\033[1;34m2)\033[0m Baixar .deb oficial no site Cisco NetAcad (login necessário) - \033[1;33mEXIBIR LINK\033[0m"
  echo -e "   \033[0;36m• Após download, use a opção 3 para instalar com o arquivo .deb baixado\033[0m\n"

  echo -e "\033[1;34m3)\033[0m Instalar Packet Tracer (.deb local):"
  echo -e "   \033[0;36m• Aponte o caminho completo do arquivo .deb já baixado\033[0m\n"

  echo -e "\033[1;34m4)\033[0m Sair / finalizar a instalação.\n"

  read -rp "Escolha uma opção [1-4]: " opcao
  case $opcao in
    1)
      exibir_link_gzip
      menu_final
      ;;
    2)
      exibir_link_cisco
      menu_final
      ;;
    3)
      read -rp "Informe o caminho completo do arquivo .deb já extraído: " deb
      if [[ -f "$deb" ]]; then
        dpkg -i "$deb" || apt install -f -y
        log "🚀 Packet Tracer instalado com sucesso."
      else
        log "❌ Arquivo .deb não encontrado."
      fi
      read -rp $'\nPressione ENTER para retornar ao menu...'
      menu_final
      ;;
    4)
      echo -e "\n🚪 Finalizando instalador. Até logo!\n"
      exit 0
      ;;
    *)
      echo -e "\033[1;31mOpção inválida.\033[0m"
      read -rp $'\nPressione ENTER para retornar ao menu...'
      menu_final
      ;;
  esac
}

### INÍCIO DO SCRIPT ###
log "🚀 INICIANDO INSTALADOR CISCO PACKET TRACER"
limpa_locks_holds
atualiza_apt || log "❌ Falha ao atualizar APT"
corrige_dependencias || log "❌ Falha ao corrigir dependências"
adiciona_repo_jammy || { log "❌ [ERRO FATAL] Falha ao atualizar apt após adicionar jammy"; remove_repo_jammy; exit 1; }
menu_final
remove_repo_jammy

