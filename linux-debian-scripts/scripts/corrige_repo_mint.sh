#!/bin/bash

echo "🔎 Diagnóstico visual dos repositórios APT..."

# 1. Backup completo
BACKUP_DIR="/etc/apt/backup-final-$(date +%F-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
sudo cp -r /etc/apt/sources.list* "$BACKUP_DIR"
sudo cp -r /etc/apt/sources.list.d "$BACKUP_DIR"
echo "📦 Backup salvo em: $BACKUP_DIR"

# 2. Listar todos os arquivos com conteúdo
echo "📄 Arquivos de repositório ativos:"
find /etc/apt/sources.list.d/ -type f -name "*.list" -exec echo "--- {} ---" \; -exec cat {} \;

# 3. Detectar e remover arquivos com conteúdo duplicado
echo "🧹 Removendo arquivos com conteúdo duplicado..."
declare -A hash_map
for file in /etc/apt/sources.list.d/*.list; do
  if [ -f "$file" ]; then
    hash=$(md5sum "$file" | awk '{print $1}')
    if [[ -n "${hash_map[$hash]}" ]]; then
      echo "❌ Arquivo duplicado: $file (igual a ${hash_map[$hash]})"
      sudo rm -f "$file"
    else
      hash_map[$hash]="$file"
    fi
  fi
done

# 4. Recriar repositório oficial do Mint
echo "🛠️ Recriando repositório oficial do Mint..."
sudo tee /etc/apt/sources.list.d/official-package-repositories.list > /dev/null <<EOF
deb http://packages.linuxmint.com xia main upstream import backport
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

# 5. Atualizar pacotes
echo "🔄 Atualizando pacotes..."
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt update
sudo apt --fix-broken install -y
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y
sudo apt autoclean

echo "✅ Repositórios limpos, duplicações eliminadas e sistema atualizado com sucesso!"

