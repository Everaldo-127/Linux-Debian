#!/bin/bash

LOGFILE="$HOME/programas_mais_pesados.txt"

echo "Listando os programas que mais ocupam espaço no seu sistema..." | tee "$LOGFILE"
echo "Sistema: Xubuntu 24.04 - Data: $(date)" | tee -a "$LOGFILE"
echo "==============================================" | tee -a "$LOGFILE"

# Pacotes dpkg/apt
echo -e "\n📦 Pacotes APT (dpkg):" | tee -a "$LOGFILE"
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | \
    sort -nr | \
    head -n 20 | \
    awk '{printf "%.2f MB\t%s\n", $1/1024, $2}' | tee -a "$LOGFILE"

# Tamanho real dos arquivos Snap
echo -e "\n📦 Tamanho real dos arquivos Snap:" | tee -a "$LOGFILE"
if [ -d /var/lib/snapd/snaps ]; then
    du -h /var/lib/snapd/snaps/*.snap 2>/dev/null | \
    sort -hr | tee -a "$LOGFILE"
else
    echo "Snap não encontrado ou não instalado neste sistema." | tee -a "$LOGFILE"
fi

# Flatpak
if command -v flatpak &> /dev/null; then
    echo -e "\n📦 Pacotes Flatpak:" | tee -a "$LOGFILE"
    flatpak list --app --columns=application,size | \
        sort -k2 -h -r | \
        awk -F'\t' '{print $2 "\t" $1}' | tee -a "$LOGFILE"
fi

echo -e "\n✅ Análise concluída. Lista salva em: $LOGFILE"

