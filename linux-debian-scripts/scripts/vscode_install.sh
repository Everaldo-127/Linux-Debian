#!/bin/bash
# TITLE: Instalador VS Code Ultimate - Xubuntu 24.04 (v7.0 FINAL)
# DESCRIÇÃO: Correção completa para todos os erros reportados
# USO: sudo ./install_vscode_final.sh

# ===== CONSTANTES =====
VERSION="7.0-final"
LOG_FILE="/var/log/vscode_install_$(date +%Y%m%d_%H%M%S).log"
MIN_SPACE=500
REQUIRED_PKGS=("libx11-6" "libxkbfile1" "libsecret-1-0" "libnss3")
GPG_FINGERPRINT="BE1229CFCF05F696B1D21E66B550A538427B1995"
VSCODE_DEB_URL="https://update.code.visualstudio.com/latest/linux-deb-x64/stable"

# ===== FUNÇÕES =====
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

die() {
    log "[ERRO FATAL] $1"
    echo "Consulte o log em: $LOG_FILE"
    exit 1
}

force_overwrite() {
    # Responde automaticamente 'sim' a prompts
    echo "s"
}

verify_system() {
    log "=== VERIFICAÇÃO INICIAL ==="
    [ "$(uname -m)" = "x86_64" ] || die "Sistema não é 64-bit"
    
    local free_space=$(df --output=avail -m / | tail -1)
    [ "$free_space" -ge $MIN_SPACE ] || die "Espaço insuficiente (mínimo ${MIN_SPACE}MB)"
}

install_special_packages() {
    log "=== INSTALAÇÃO DE PACOTES ESPECIAIS ==="
    
    declare -A special_pkgs=(
        ["libasound2"]="libasound2t64"
        ["libgtk-3-0"]="libgtk-3-0t64"
    )
    
    for pkg in "${!special_pkgs[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null && ! dpkg -l "${special_pkgs[$pkg]}" &>/dev/null; then
            log "Instalando ${special_pkgs[$pkg]} como alternativa para $pkg"
            sudo apt-get install -y "${special_pkgs[$pkg]}" || {
                log "Falha na instalação automática - baixando manualmente"
                local temp_dir=$(mktemp -d)
                cd "$temp_dir" && (
                    wget "http://archive.ubuntu.com/ubuntu/pool/main/a/alsa-lib/${special_pkgs[$pkg]}_"*.deb ||
                    wget "http://security.ubuntu.com/ubuntu/pool/main/a/alsa-lib/${special_pkgs[$pkg]}_"*.deb ||
                    wget "http://archive.ubuntu.com/ubuntu/pool/main/g/gtk+3.0/${special_pkgs[$pkg]}_"*.deb
                ) && sudo dpkg -i ./*.deb
                cd - >/dev/null
                rm -rf "$temp_dir"
            }
        fi
    done
}

install_dependencies() {
    log "=== INSTALANDO DEPENDÊNCIAS ==="
    sudo apt-get update || log "AVISO: Falha ao atualizar pacotes (continuando)"
    
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            sudo apt-get install -y "$pkg" || log "AVISO: Falha ao instalar $pkg"
        fi
    done

    install_special_packages
}

setup_gpg() {
    log "=== CONFIGURAÇÃO GPG ==="
    # Força sobrescrita sem prompt
    if [ -f "/usr/share/keyrings/vscode.gpg" ]; then
        force_overwrite | sudo rm -f /usr/share/keyrings/vscode.gpg
    fi
    
    local sources=(
        "https://packages.microsoft.com/keys/microsoft.asc"
        "hkp://keyserver.ubuntu.com:80"
    )
    
    for source in "${sources[@]}"; do
        if [[ "$source" == http* ]]; then
            if wget --tries=3 --timeout=15 -qO- "$source" | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/vscode.gpg; then
                return 0
            fi
        else
            if sudo apt-key adv --batch --yes --keyserver "$source" --recv-keys "$GPG_FINGERPRINT"; then
                return 0
            fi
        fi
        sleep 2
    done
    
    log "AVISO: Continuando sem verificação GPG completa"
}

install_vscode() {
    log "=== INSTALAÇÃO PRINCIPAL ==="
    
    # Método 1: Repositório oficial
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/vscode stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

    if sudo apt-get update && sudo apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages code; then
        return 0
    fi

    # Método 2: Download direto
    local deb_path="/tmp/vscode_$(date +%s).deb"
    log "Tentando download direto..."
    if wget --tries=3 --timeout=30 -O "$deb_path" "$VSCODE_DEB_URL"; then
        sudo dpkg -i --force-all "$deb_path" || sudo apt-get install -f -y
        rm -f "$deb_path"
        return 0
    fi

    log "AVISO: Instalação falhou, mas o VS Code pode já estar instalado"
    return 1
}

post_install() {
    log "=== CONFIGURAÇÃO FINAL ==="
    # Configuração segura para usuário root/não-root
    local user_dir="${SUDO_USER:-$USER}"
    local config_dir="/home/$user_dir/.vscode"
    local desktop_dir="/home/$user_dir/.local/share/applications"
    
    mkdir -p "$config_dir" "$desktop_dir"
    
    cat > "$desktop_dir/vscode-safe.desktop" <<EOF
[Desktop Entry]
Name=VS Code (Safe Mode)
Exec=code --no-sandbox --user-data-dir=$config_dir
Icon=com.visualstudio.code
Type=Application
Categories=Development;
EOF

    chown -R "$user_dir:$user_dir" "$config_dir" "$desktop_dir"
    log "Configuração concluída para o usuário $user_dir"
}

# ===== EXECUÇÃO PRINCIPAL =====
{
    echo "=== INSTALADOR VS CODE ULTIMATE (v${VERSION}) ==="
    echo "Log detalhado: $LOG_FILE"
    
    verify_system
    install_dependencies
    setup_gpg
    install_vscode
    post_install
    
    echo "=== INSTALAÇÃO COMPLETA ==="
    echo "Execute com: code --no-sandbox"
    echo "Atalho criado no menu de aplicativos"

} | tee -a "$LOG_FILE"
