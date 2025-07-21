#!/bin/bash

LOGFILE="$HOME/aplicativos_usuario_espaco.txt"
TEMPFILE=$(mktemp)

echo "🔍 Iniciando varredura de aplicativos do usuário (não nativos)..." | tee "$LOGFILE"
echo "Sistema: $(hostname) | Data: $(date)" | tee -a "$LOGFILE"
echo "===============================================================" | tee -a "$LOGFILE"

# Diretórios típicos de apps instalados pelo usuário
DIRS=(
  "/opt"
  "/usr/local"
  "$HOME/.local/share"
  "/var/lib/snapd/snaps"
  "/var/lib/flatpak"
)

# Varrer diretórios de instalação não nativos
for DIR in "${DIRS[@]}"; do
    echo -e "\n📁 Diretório: $DIR" | tee -a "$LOGFILE"
    if [ -d "$DIR" ]; then
        sudo du -h --max-depth=1 "$DIR" 2>/dev/null | sort -hr | tee -a "$LOGFILE" >> "$TEMPFILE"
    else
        echo "❌ Diretório não encontrado: $DIR" | tee -a "$LOGFILE"
    fi
done

# RESUMO FINAL filtrado e limpo
echo -e "\n📋 RESUMO FINAL - Aplicativos instalados pelo usuário:" | tee -a "$LOGFILE"
echo "============================================================" | tee -a "$LOGFILE"
sort -hr "$TEMPFILE" | head -n 15 | while read tamanho caminho; do
    app=$(basename "$caminho")
    echo "Aplicativo: $app  |  Tamanho: $tamanho" | tee -a "$LOGFILE"
done

rm -f "$TEMPFILE"
echo -e "\n✅ Varredura concluída. Resultado completo salvo em: $LOGFILE"

