#!/bin/bash
# TITLE: PostgreSQL Manager (v7.8)
# DESCRIPTION: Script completo para gerenciamento de usuários e bancos de dados PostgreSQL
# FUNCIONALIDADES:
#   1. Listar usuários
#   2. Listar bancos de dados
#   3. Criar usuário
#   4. Criar banco para usuário existente (apenas nome e dono)
#   5. Criar usuário + banco
#   6. Remover usuário
#   7. Remover banco de dados
# USO: sudo ./pg_manager.sh

# ===== CONSTANTES =====
LOG_FILE="/var/log/pg_manager_$(date +%Y%m%d_%H%M%S).log"
VERSION="7.8"

# ===== FUNÇÕES =====
show_header() {
    clear
    echo -e "\n\e[1;46m ========= PostgreSQL Manager v$VERSION ========= \e[0m\n"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_menu() {
    echo -e "\e[1;37m► MENU PRINCIPAL ◄\e[0m"
    echo -e "┌─────────────────────────────────────┐"
    echo -e "│ \e[33m1.\e[0m Listar usuários                     │"
    echo -e "│ \e[33m2.\e[0m Listar bancos de dados              │"
    echo -e "│ \e[33m3.\e[0m Criar usuário                       │"
    echo -e "│ \e[33m4.\e[0m Criar banco para usuário existente  │"
    echo -e "│ \e[33m5.\e[0m Criar usuário + banco               │"
    echo -e "│ \e[33m6.\e[0m Remover usuário                     │"
    echo -e "│ \e[33m7.\e[0m Remover banco de dados              │"
    echo -e "│ \e[33m8.\e[0m Sair                                │"
    echo -e "└─────────────────────────────────────┘"
    echo -ne "\e[33m► Escolha uma opção:\e[0m "
}

list_users() {
    echo -e "\e[1;37m► LISTA DE USUÁRIOS ◄\e[0m"
    
    result=$(sudo -u postgres psql -XqAt -c "
        SELECT 
            r.rolname || '|' ||
            CASE WHEN r.rolsuper THEN 'Sim' ELSE 'Não' END || '|' ||
            CASE WHEN r.rolcreatedb THEN 'Sim' ELSE 'Não' END || '|' ||
            CASE WHEN r.rolcreaterole THEN 'Sim' ELSE 'Não' END || '|' ||
            COALESCE(r.rolvaliduntil::text, 'Nunca')
        FROM pg_roles r
        WHERE r.rolname !~ '^pg_' AND r.rolname <> 'postgres'
        ORDER BY 1")

    if [ -z "$result" ]; then
        echo -e "\e[33mNenhum usuário encontrado.\e[0m"
    else
        echo -e "┌──────────────────────┬────────────┬──────────┬───────────┬──────────────────┐"
        echo -e "│ \e[1;36mUsuário\e[0m             │ \e[1;36mSuperuser\e[0m │ \e[1;36mCriar DB\e[0m │ \e[1;36mCriar Role\e[0m │ \e[1;36mValidade\e[0m        │"
        echo -e "├──────────────────────┼────────────┼──────────┼───────────┼──────────────────┤"
        
        while IFS='|' read -r username superuser createdb createrole validuntil; do
            printf "│ %-20s │ %-10s │ %-8s │ %-9s │ %-16s │\n" \
                   "$username" "$superuser" "$createdb" "$createrole" "$validuntil"
        done <<< "$result"
        
        echo -e "└──────────────────────┴────────────┴──────────┴───────────┴──────────────────┘"
    fi
}

list_databases() {
    echo -e "\e[1;37m► BANCOS DE DADOS ◄\e[0m"
    
    result=$(sudo -u postgres psql -XqAt -c "
        SELECT 
            d.datname || '|' ||
            pg_catalog.pg_get_userbyid(d.datdba) || '|' ||
            pg_catalog.pg_size_pretty(pg_database_size(d.datname)) || '|' ||
            (SELECT count(*) FROM pg_stat_activity WHERE datname = d.datname)::text
        FROM pg_database d
        WHERE d.datname NOT LIKE 'template%'
        ORDER BY 1")

    if [ -z "$result" ]; then
        echo -e "\e[33mNenhum banco de dados encontrado.\e[0m"
    else
        echo -e "┌──────────────────────┬─────────────────┬──────────┬──────────────┐"
        echo -e "│ \e[1;36mNome\e[0m                │ \e[1;36mDono\e[0m           │ \e[1;36mTamanho\e[0m │ \e[1;36mConexões\e[0m │"
        echo -e "├──────────────────────┼─────────────────┼──────────┼──────────────┤"
        
        while IFS='|' read -r dbname owner size connections; do
            printf "│ %-20s │ %-15s │ %-8s │ %-12s │\n" \
                   "$dbname" "$owner" "$size" "$connections"
        done <<< "$result"
        
        echo -e "└──────────────────────┴─────────────────┴──────────┴──────────────┘"
    fi
}

create_user() {
    show_header
    echo -e "\e[1;37m► CRIAR USUÁRIO ◄\e[0m"
    
    read -p "Nome do novo usuário: " username
    if [ -z "$username" ]; then
        echo -e "\e[31mNome de usuário não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    read -s -p "Senha para o usuário: " password
    echo
    if [ -z "$password" ]; then
        echo -e "\e[31mSenha não pode ser vazia!\e[0m"
        sleep 1
        return
    fi
    
    read -p "Deseja conceder permissão para criar bancos de dados? (s/n): " createdb
    read -p "Deseja conceder permissão para criar roles? (s/n): " createrole
    read -p "Deseja tornar este usuário superuser? (s/n): " superuser
    read -p "Definir data de expiração (YYYY-MM-DD ou vazio para nunca): " validuntil
    
    # Construir comando SQL
    sql="CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password'"
    
    [ "$createdb" = "s" ] && sql+=" CREATEDB"
    [ "$createrole" = "s" ] && sql+=" CREATEROLE"
    [ "$superuser" = "s" ] && sql+=" SUPERUSER"
    [ -n "$validuntil" ] && sql+=" VALID UNTIL '$validuntil'"
    
    if sudo -u postgres psql -c "$sql"; then
        log "Usuário $username criado com sucesso"
        echo -e "\n\e[32m✔ Usuário $username criado com sucesso!\e[0m"
    else
        log "Falha ao criar usuário $username"
        echo -e "\n\e[31m✖ Erro ao criar usuário!\e[0m"
    fi
    sleep 2
}

create_db() {
    show_header
    echo -e "\e[1;37m► CRIAR BANCO DE DADOS ◄\e[0m"
    
    read -p "Nome do banco de dados: " dbname
    if [ -z "$dbname" ]; then
        echo -e "\e[31mNome do banco não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    read -p "Dono do banco de dados: " owner
    if [ -z "$owner" ]; then
        echo -e "\e[31mDono do banco não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    # Verificar se usuário existe
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$owner'" | grep -q 1; then
        echo -e "\e[31mUsuário $owner não existe!\e[0m"
        sleep 1
        return
    fi
    
    if sudo -u postgres psql -c "CREATE DATABASE \"$dbname\" WITH OWNER = \"$owner\" ENCODING = 'UTF8' TEMPLATE = template0"; then
        log "Banco $dbname criado com sucesso para o usuário $owner"
        echo -e "\n\e[32m✔ Banco $dbname criado com sucesso para $owner!\e[0m"
    else
        log "Falha ao criar banco $dbname"
        echo -e "\n\e[31m✖ Erro ao criar banco de dados!\e[0m"
    fi
    sleep 2
}

create_user_and_db() {
    show_header
    echo -e "\e[1;37m► CRIAR USUÁRIO E BANCO DE DADOS ◄\e[0m"
    
    read -p "Nome do novo usuário: " username
    if [ -z "$username" ]; then
        echo -e "\e[31mNome de usuário não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    read -s -p "Senha para o usuário: " password
    echo
    if [ -z "$password" ]; then
        echo -e "\e[31mSenha não pode ser vazia!\e[0m"
        sleep 1
        return
    fi
    
    read -p "Nome do banco de dados: " dbname
    if [ -z "$dbname" ]; then
        echo -e "\e[31mNome do banco não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    # Criar usuário
    if sudo -u postgres psql -c "CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password'"; then
        log "Usuário $username criado com sucesso"
        # Criar banco
        if sudo -u postgres psql -c "CREATE DATABASE \"$dbname\" WITH OWNER = \"$username\" ENCODING = 'UTF8' TEMPLATE = template0"; then
            log "Banco $dbname criado com sucesso para o usuário $username"
            echo -e "\n\e[32m✔ Usuário e banco criados com sucesso!\e[0m"
            echo -e "\e[32m✔ Usuário: $username\e[0m"
            echo -e "\e[32m✔ Banco: $dbname\e[0m"
        else
            log "Falha ao criar banco $dbname"
            echo -e "\n\e[31m✖ Usuário criado, mas falha ao criar banco!\e[0m"
        fi
    else
        log "Falha ao criar usuário $username"
        echo -e "\n\e[31m✖ Erro ao criar usuário!\e[0m"
    fi
    sleep 2
}

delete_user() {
    show_header
    echo -e "\e[1;37m► REMOVER USUÁRIO ◄\e[0m"
    
    read -p "Nome do usuário a ser removido: " username
    if [ -z "$username" ]; then
        echo -e "\e[31mNome de usuário não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    # Verificar se usuário existe
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'" | grep -q 1; then
        echo -e "\e[31mUsuário $username não existe!\e[0m"
        sleep 1
        return
    fi
    
    read -p "Remover também todos os objetos do usuário? (s/n): " drop_objects
    
    if [ "$drop_objects" = "s" ]; then
        sql="DROP OWNED BY \"$username\"; DROP ROLE \"$username\""
    else
        sql="DROP ROLE \"$username\""
    fi
    
    if sudo -u postgres psql -c "$sql"; then
        log "Usuário $username removido com sucesso"
        echo -e "\n\e[32m✔ Usuário $username removido com sucesso!\e[0m"
    else
        log "Falha ao remover usuário $username"
        echo -e "\n\e[31m✖ Erro ao remover usuário!\e[0m"
    fi
    sleep 2
}

delete_db() {
    show_header
    echo -e "\e[1;37m► REMOVER BANCO DE DADOS ◄\e[0m"
    
    read -p "Nome do banco de dados a ser removido: " dbname
    if [ -z "$dbname" ]; then
        echo -e "\e[31mNome do banco não pode ser vazio!\e[0m"
        sleep 1
        return
    fi
    
    # Verificar se banco existe
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'" | grep -q 1; then
        echo -e "\e[31mBanco $dbname não existe!\e[0m"
        sleep 1
        return
    fi
    
    read -p "Tem certeza que deseja remover o banco $dbname? (s/n): " confirm
    if [ "$confirm" != "s" ]; then
        echo -e "\e[33mOperação cancelada!\e[0m"
        sleep 1
        return
    fi
    
    # Encerrar todas as conexões ao banco
    sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$dbname'"
    
    if sudo -u postgres psql -c "DROP DATABASE \"$dbname\""; then
        log "Banco $dbname removido com sucesso"
        echo -e "\n\e[32m✔ Banco $dbname removido com sucesso!\e[0m"
    else
        log "Falha ao remover banco $dbname"
        echo -e "\n\e[31m✖ Erro ao remover banco de dados!\e[0m"
    fi
    sleep 2
}

# ===== EXECUÇÃO PRINCIPAL =====
main() {
    # Verificações iniciais
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\e[31mERRO: Execute como root!\e[0m\nUse: sudo ./pg_manager.sh"
        exit 1
    fi

    if ! command -v psql &> /dev/null; then
        echo -e "\e[31mPostgreSQL não está instalado!\e[0m\nExecute: sudo apt-get install postgresql"
        exit 1
    fi

    # Menu principal
    while true; do
        show_header
        show_menu
        read -r OPTION
        
        case $OPTION in
            1) 
                show_header
                list_users
                read -p "Pressione Enter para continuar..."
                ;;
            2) 
                show_header
                list_databases
                read -p "Pressione Enter para continuar..."
                ;;
            3) create_user ;;
            4) create_db ;;
            5) create_user_and_db ;;
            6) delete_user ;;
            7) delete_db ;;
            8) echo -e "\n\e[1;42m ► SESSÃO ENCERRADA ◄ \e[0m\n"; exit 0 ;;
            *) echo -e "\n\e[31mOpção inválida!\e[0m"; sleep 1 ;;
        esac
    done
}

main
