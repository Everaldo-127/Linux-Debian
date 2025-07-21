#!/bin/bash

echo "[1/10] Removendo repositórios de versão anterior (jammy)..."
sudo rm -f /etc/apt/sources.list.d/*jammy*
sudo sed -i '/jammy/d' /etc/apt/sources.list

echo "[2/10] Corrigindo fontes de repositório principais para versão correta (noble)..."
sudo sed -i 's/jammy/noble/g' /etc/apt/sources.list

echo "[3/10] Atualizando lista de pacotes..."
sudo apt update

echo "[4/10] Limpando cache de pacotes obsoletos..."
sudo apt clean
sudo apt autoclean

echo "[5/10] Corrigindo pacotes quebrados automaticamente..."
sudo dpkg --configure -a
sudo apt --fix-broken install -y

echo "[6/10] Forçando reinstalação de pacotes com dependências corrompidas..."
sudo apt install --reinstall fonts-liberation2 libcurl4 libgs-common libgtk2.0-0 libcups2 libtirpc3 libparted2 ubuntu-advantage-tools -y

echo "[7/10] Removendo pacotes conflitantes legados (se ainda presentes)..."
sudo apt remove fonts-liberation libgs9-common libgail18 libext2fs2 libcurl4 libtirpc3 libgtk2.0-0 libparted2 libcups2 ubuntu-advantage-tools -y || true

echo "[8/10] Atualizando o sistema com base limpa e coerente..."
sudo apt update && sudo apt full-upgrade -y

echo "[9/10] Limpando pacotes órfãos e dependências residuais..."
sudo apt autoremove -y
sudo apt autoclean

echo "[10/10] Finalizado. Reinicie o sistema se necessário para aplicar mudanças."

