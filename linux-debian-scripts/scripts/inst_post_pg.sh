#!/bin/bash

# ====================================================================
# INSTALAÇÃO DO POSTGRESQL + PGADMIN 4 - OTIMIZADO E RESILIENTE
# Compatível com Xubuntu Minimal 24.04 (kernel 6.8.0-60-generic)
#
# Funcionalidades:
# - Validação e saneamento de repositórios oficiais.
# - Limpeza de cache e resolução proativa de dependências quebradas.
# - Verificação e instalação de pré-requisitos essenciais.
# - Instalação segura do PostgreSQL e pgAdmin 4 de seus repositórios oficiais.
# - Tratamento de erros robusto.
# ====================================================================

# --- Cores para melhor feedback visual ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar e tratar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERRO] Processo falhou: $1${NC}" >&2
        echo -e "${RED}Por favor, analise a saída acima para mais detalhes e tente corrigir o problema.${NC}" >&2
        exit 1
    fi
}

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}  INÍCIO DA INSTALAÇÃO ROBUSTA DE POSTGRESQL E PGADMIN 4            ${NC}"
echo -e "${BLUE}  Xubuntu Minimal 24.04                                             ${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""

# --- ETAPA 1: VALIDAÇÃO E SANEAMENTO DOS REPOSITÓRIOS OFICIAIS DO SISTEMA ---
echo -e "${YELLOW}[1/8] Validando e saneando os repositórios oficiais do sistema...${NC}"
# Cria um backup do arquivo sources.list original
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
check_error "Falha ao criar backup do sources.list."

# Limpa o conteúdo do sources.list e adiciona as fontes padrão do Xubuntu 24.04
# Usamos `ubuntu` como base para os repositórios, pois o Xubuntu usa os mesmos repositórios.
# Se precisar de um minimalista, pode-se ajustar para main restricted.
echo "deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse" | sudo tee /etc/apt/sources.list > /dev/null
echo "deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list > /dev/null
echo "deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list > /dev/null
echo "deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list > /dev/null

# Limpar /etc/apt/sources.list.d/ para evitar conflitos de PPA antigos
echo -e "${YELLOW}  Limpando arquivos em /etc/apt/sources.list.d/...${NC}"
sudo rm -f /etc/apt/sources.list.d/*.list
check_error "Falha ao limpar arquivos em /etc/apt/sources.list.d/."

echo -e "${YELLOW}  Atualizando a lista de pacotes após saneamento dos repositórios...${NC}"
sudo apt update
check_error "Falha ao atualizar a lista de pacotes após saneamento dos repositórios. Verifique sua conexão com a internet ou os espelhos de repositório."

echo -e "${GREEN}  Repositórios oficiais validados e atualizados com sucesso.${NC}"
echo ""

# --- ETAPA 2: LIMPEZA DE CACHE E RESOLUÇÃO PROATIVA DE DEPENDÊNCIAS ---
echo -e "${YELLOW}[2/8] Limpando cache de pacotes e resolvendo dependências...${NC}"
echo -e "${YELLOW}  Limpando o cache de pacotes APT...${NC}"
sudo apt clean
check_error "Falha ao limpar o cache de pacotes APT."

echo -e "${YELLOW}  Removendo pacotes órfãos e não utilizados...${NC}"
sudo apt autoremove --purge -y
check_error "Falha ao remover pacotes órfãos."

echo -e "${YELLOW}  Tentando corrigir pacotes quebrados e dependências...${NC}"
sudo apt --fix-broken install -y
check_error "Falha ao tentar corrigir pacotes quebrados."

sudo dpkg --configure -a
check_error "Falha ao reconfigurar pacotes dpkg."

sudo apt-get install -f -y # Força a resolução de dependências
check_error "Falha ao forçar a resolução de dependências."

# Tratamento específico para o erro perlapi-5.34.0 (se persistir após as tentativas acima)
# Esta etapa só deve ser considerada se o erro persistir.
# Um "hold" pode ser removido, ou o pacote pode ser reinstalado.
echo -e "${YELLOW}  Verificando e tratando possíveis problemas com 'perlapi-5.34.0' e 'libio-pty-perl'...${NC}"
# Primeiro, tentar remover o hold se houver
if dpkg --get-selections | grep -q "libio-pty-perl hold"; then
    echo -e "${YELLOW}  Pacote 'libio-pty-perl' em status 'hold' detectado. Removendo o hold...${NC}"
    echo "libio-pty-perl install" | sudo dpkg --set-selections
    sudo apt update
    sudo apt --fix-broken install -y
fi

# Se o problema ainda não resolver, podemos tentar reinstalar/atualizar o perl-base
# ou os pacotes que dependem de perlapi.
# Para Xubuntu 24.04 (Noble Numbat), o perlapi esperado seria 5.38.x
# Tentativa de forçar atualização de perl-base ou perl-modules
sudo apt install --reinstall -y perl-base perl-modules-5.38.2
sudo apt install -y libio-pty-perl # Tenta reinstalar agora
check_error "Ainda existem problemas de dependência relacionados a perlapi/libio-pty-perl. Pode ser necessário intervenção manual."

echo -e "${GREEN}  Limpeza e resolução de dependências concluídas. Sistema preparado.${NC}"
echo ""

# --- ETAPA 3: VERIFICAÇÃO E INSTALAÇÃO PROATIVA DE PRÉ-REQUISITOS ---
echo -e "${YELLOW}[3/8] Verificando e instalando pré-requisitos essenciais...${NC}"
# Pacotes essenciais para adição de repositórios e outras operações
REQUIRED_PKGS="curl gpg software-properties-common apt-transport-https ca-certificates dirmngr"
sudo apt install -y ${REQUIRED_PKGS}
check_error "Falha ao instalar pré-requisitos essenciais."
echo -e "${GREEN}  Pré-requisitos instalados com sucesso.${NC}"
echo ""

# --- ETAPA 4: ADICIONAR REPOSITÓRIO DO POSTGRESQL ---
echo -e "${YELLOW}[4/8] Configurando repositório do PostgreSQL...${NC}"
# Garante que o arquivo do repositório não exista antes de adicionar
sudo rm -f /etc/apt/sources.list.d/pgdg.list

# Adiciona o repositório do PostgreSQL
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
check_error "Falha ao adicionar a entrada do repositório do PostgreSQL."

# Adiciona a chave GPG do PostgreSQL
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
check_error "Falha ao adicionar a chave GPG do PostgreSQL."

echo -e "${YELLOW}  Atualizando a lista de pacotes após adicionar repositório do PostgreSQL...${NC}"
sudo apt update
check_error "Falha ao atualizar pacotes após configurar repositório do PostgreSQL."
echo -e "${GREEN}  Repositório do PostgreSQL configurado com sucesso.${NC}"
echo ""

# --- ETAPA 5: INSTALAR POSTGRESQL ---
echo -e "${YELLOW}[5/8] Instalando PostgreSQL e postgresql-contrib...${NC}"
sudo apt install -y postgresql postgresql-contrib
check_error "Falha ao instalar PostgreSQL e postgresql-contrib."
echo -e "${GREEN}  PostgreSQL instalado com sucesso.${NC}"
echo ""

# --- ETAPA 6: CONFIGURAR E INICIAR SERVIÇO POSTGRESQL ---
echo -e "${YELLOW}[6/8] Habilitando e iniciando o serviço PostgreSQL...${NC}"
sudo systemctl enable postgresql
check_error "Falha ao habilitar o serviço PostgreSQL."
sudo systemctl start postgresql
check_error "Falha ao iniciar o serviço PostgreSQL."

# Verifica o status do serviço
echo -e "${YELLOW}  Verificando o status do serviço PostgreSQL...${NC}"
sudo systemctl is-active --quiet postgresql && echo -e "${GREEN}  Serviço PostgreSQL está ativo e rodando.${NC}" || echo -e "${RED}  Serviço PostgreSQL não está ativo. Verifique os logs.${NC}"
sudo systemctl is-enabled --quiet postgresql && echo -e "${GREEN}  Serviço PostgreSQL está habilitado para iniciar no boot.${NC}" || echo -e "${RED}  Serviço PostgreSQL não está habilitado para iniciar no boot.${NC}"
echo -e "${GREEN}  Configuração do serviço PostgreSQL concluída.${NC}"
echo ""

# --- ETAPA 7: INSTALAR PGADMIN 4 ---
echo -e "${YELLOW}[7/8] Instalando pgAdmin 4 (versão Desktop)...${NC}"
# Garante que o arquivo do repositório do pgAdmin 4 não exista antes de adicionar
sudo rm -f /etc/apt/sources.list.d/pgadmin4.list

# Adiciona a chave GPG do pgAdmin 4
sudo curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin-keyring.gpg
check_error "Falha ao adicionar a chave GPG do pgAdmin 4."

# Adiciona o repositório do pgAdmin 4
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
check_error "Falha ao adicionar a entrada do repositório do pgAdmin 4."

echo -e "${YELLOW}  Atualizando a lista de pacotes após adicionar repositório do pgAdmin 4...${NC}"
sudo apt update
check_error "Falha ao atualizar pacotes após configurar repositório do pgAdmin 4."

sudo apt install -y pgadmin4-desktop
check_error "Falha ao instalar pgAdmin 4."
echo -e "${GREEN}  pgAdmin 4 instalado com sucesso.${NC}"
echo ""

# --- ETAPA 8: RESUMO E PRÓXIMOS PASSOS ---
echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                              ${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}POSTGRESQL:${NC}"
echo -e "${BLUE}- Para verificar o status do serviço: ${GREEN}sudo systemctl status postgresql${NC}"
echo -e "${BLUE}- Para acessar o console do PostgreSQL: ${GREEN}sudo -u postgres psql${NC}"
echo -e "${BLUE}  ${YELLOW}Sugestão: Crie um superusuário para administração: ${NC}"
echo -e "${GREEN}    sudo -u postgres createuser --superuser --pwprompt seu_usuario${NC}"
echo -e "${BLUE}PGADMIN 4:${NC}"
echo -e "${BLUE}- Para executar o pgAdmin 4: ${GREEN}pgadmin4${NC} (via terminal ou menu de aplicativos)${NC}"
echo -e "${BLUE}  ${YELLOW}Ao iniciar o pgAdmin 4 pela primeira vez, você será solicitado a criar uma senha mestra.${NC}"
echo -e "${BLUE}  ${YELLOW}Para conectar ao PostgreSQL, adicione um novo servidor com os detalhes do seu banco de dados local (host: localhost).${NC}"
echo -e "${BLUE}--------------------------------------------------------------------${NC}"
echo -e "${GREEN}Tudo pronto para você usar PostgreSQL e pgAdmin 4 no seu Xubuntu!${NC}"
echo -e "${BLUE}====================================================================${NC}"
