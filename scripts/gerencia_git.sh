#!/bin/bash

LOG_FILE="/var/log/LOG_GITHUB.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

if [[ $EUID -ne 0 ]]; then
    echo "Por favor, execute como root para que o script possa escrever no arquivo de log em /var/log."
    exit 1
fi

check_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo "Git não está instalado. Instalando..."
        log "Git não está instalado. Instalando..."
        sudo apt-get update && sudo apt-get install -y git
    fi
    echo "Git está instalado."
    log "Git está instalado."

    if ! git config --global user.email >/dev/null 2>&1 || [ -z "$(git config --global user.email)" ]; then
        read -p "Digite o e-mail para configuração do Git: " GIT_EMAIL
        git config --global user.email "$GIT_EMAIL"
        log "user.email configurado como $GIT_EMAIL"
    fi
    if ! git config --global user.name >/dev/null 2>&1 || [ -z "$(git config --global user.name)" ]; then
        read -p "Digite o nome de usuário para configuração do Git: " GIT_NAME
        git config --global user.name "$GIT_NAME"
        log "user.name configurado como $GIT_NAME"
    fi
}

check_dependencies() {
    local dependencies=("curl" "jq" "rsync")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Dependência $dep não está instalada. Instalando..."
            sudo apt-get install -y "$dep"
            log "Dependência $dep instalada."
        fi
    done
    echo "Todas as dependências estão instaladas."
    log "Todas as dependências estão instaladas."
}

get_credentials() {
    read -p "Digite seu nome de usuário do GitHub: " GITHUB_USER
    read -sp "Digite seu token de acesso pessoal do GitHub (com permissão repo): " GITHUB_TOKEN
    echo
    if [[ -z "$GITHUB_USER" || -z "$GITHUB_TOKEN" ]]; then
        echo "Credenciais incompletas. Abortando."
        log "Credenciais incompletas. Abortando."
        exit 1
    fi
}

check_response() {
    local http_code=$1
    local operation=$2
    if [[ "$operation" == "delete" && "$http_code" == "204" ]]; then
        return 0
    elif [[ "$operation" == "rename" && "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

create_repository() {
    get_credentials
    read -p "Digite o nome do novo repositório: " REPO_NAME
    if [[ -z "$REPO_NAME" ]]; then
        echo "Nome do repositório não pode ser vazio."
        return
    fi
    read -p "Digite uma descrição para o repositório (opcional): " REPO_DESC
    read -p "O repositório será privado? (y/n): " IS_PRIVATE
    PRIVATE_FLAG=false
    [[ "$IS_PRIVATE" =~ ^[Yy]$ ]] && PRIVATE_FLAG=true
    local URL="https://api.github.com/user/repos"
    local DATA="{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESC}\",\"private\":${PRIVATE_FLAG}}"
    echo "Criando repositório '$REPO_NAME'..."
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u "${GITHUB_USER}:${GITHUB_TOKEN}" \
        -H "Content-Type: application/json" -d "$DATA" "$URL")
    if [[ "$HTTP_RESPONSE" == "201" ]]; then
        echo "Repositório '$REPO_NAME' criado com sucesso."
        log "Repositório '$REPO_NAME' criado com sucesso pelo usuário $GITHUB_USER."
    else
        echo "Falha ao criar o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao criar o repositório '$REPO_NAME'. Código HTTP: $HTTP_RESPONSE"
    fi
}

rename_repository() {
    read -p "Digite o nome atual do repositório: " OLD_NAME
    read -p "Digite o novo nome do repositório: " NEW_NAME
    read -p "Confirma a renomeação de '$OLD_NAME' para '$NEW_NAME'? (y/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || return
    get_credentials
    local URL="https://api.github.com/repos/${GITHUB_USER}/${OLD_NAME}"
    local DATA="{\"name\":\"${NEW_NAME}\"}"
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -u "${GITHUB_USER}:${GITHUB_TOKEN}" \
        -H "Content-Type: application/json" -d "$DATA" "$URL")
    if check_response "$HTTP_RESPONSE" "rename"; then
        echo "Repositório renomeado com sucesso para '$NEW_NAME'."
        log "Repositório '$OLD_NAME' renomeado para '$NEW_NAME'."
    else
        echo "Falha ao renomear repositório. HTTP $HTTP_RESPONSE"
    fi
}

delete_repository() {
    read -p "Digite o nome do repositório a ser excluído: " REPO_NAME
    read -p "Confirma exclusão de '$REPO_NAME'? (y/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || return
    get_credentials
    local URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}"
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "${GITHUB_USER}:${GITHUB_TOKEN}" "$URL")
    if check_response "$HTTP_RESPONSE" "delete"; then
        echo "Repositório '$REPO_NAME' excluído com sucesso."
        log "Repositório '$REPO_NAME' excluído."
    else
        echo "Falha ao excluir repositório. HTTP $HTTP_RESPONSE"
    fi
}

clonar_repository() {
    get_credentials
    read -p "Digite o nome do repositório do seu usuário para clonar: " REPO_NAME
    local DEST_DIR="$REPO_NAME"
    local REPO_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
    echo "Clonando repositório próprio '$REPO_NAME'..."
    if git clone "$REPO_URL" "$DEST_DIR"; then
        echo "Repositório '$REPO_NAME' clonado com sucesso."
        log "Clonado repositório próprio: $REPO_NAME"
    else
        echo "Falha ao clonar repositório '$REPO_NAME'."
        log "Falha ao clonar repositório próprio: $REPO_NAME"
    fi
}

clonar_terceiros() {
    read -p "Digite a URL do repositório público para clonar: " URL
    echo "Clonando repositório público de terceiros..."
    if git clone "$URL"; then
        echo "Repositório público clonado com sucesso."
        log "Clonado repositório público de terceiros: $URL"
    else
        echo "Falha ao clonar repositório público."
        log "Falha ao clonar repositório público: $URL"
    fi
}

enviar_para_github() {
    DIR_ATUAL=$(pwd)
    get_credentials
    read -p "Digite os nomes dos repositórios do seu usuário (separados por espaço): " REPOSITORIOS
    read -p "Mensagem base do commit: " MENSAGEM_COMMIT
    for REPO in $REPOSITORIOS; do
        log "📂 Processando repositório: $REPO"
        TMP_DIR=$(mktemp -d)
        git clone --depth=1 "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO}.git" "$TMP_DIR" || {
            log "❌ Falha ao clonar repositório remoto $REPO"
            rm -rf "$TMP_DIR"
            continue
        }
        cd "$TMP_DIR" || continue
        git checkout main || git checkout -b main
        cd "$DIR_ATUAL" || continue
        rsync -a --exclude='.git' "$DIR_ATUAL"/ "$TMP_DIR"/
        cd "$TMP_DIR" || continue
        git add .
        if git diff --cached --quiet; then
            log "⚠️ Sem alterações para commit no repositório $REPO."
        else
            git commit -m "$MENSAGEM_COMMIT [$(date '+%Y-%m-%d %H:%M:%S')]"
            git push origin main && log "✅ Push realizado com sucesso no repositório $REPO" || log "❌ Falha no push no repositório $REPO"
        fi
        cd "$DIR_ATUAL" || continue
        rm -rf "$TMP_DIR"
    done
    log "=== ENVIO FINALIZADO ==="
}

main_menu() {
    while true; do
        echo
        echo "=========== Menu GitHub ==========="
        echo "1) Criar repositório"
        echo "2) Renomear repositório"
        echo "3) Excluir repositório"
        echo "4) Clonar repositório próprio"
        echo "5) Clonar repositório público de terceiros"
        echo "6) Enviar arquivos para repositórios"
        echo "7) Sair"
        read -p "Escolha uma opção [1-7]: " OPTION
        case "$OPTION" in
            1) create_repository ;;
            2) rename_repository ;;
            3) delete_repository ;;
            4) clonar_repository ;;
            5) clonar_terceiros ;;
            6) enviar_para_github ;;
            7) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida. Tente novamente." ;;
        esac
    done
}

check_git
check_dependencies
main_menu

