#!/bin/bash

# Função para detectar automaticamente o servidor SMTP via DNS ou definir manualmente
detect_smtp_server() {
    DOMAIN=$(echo "$EMAIL" | cut -d '@' -f 2)
    AUTOCONFIG=$(dig +short "_submission._tcp.$DOMAIN" SRV | awk '{print $4}')

    if [ -n "$AUTOCONFIG" ]; then
        SMTP_SERVER="$AUTOCONFIG"
        SMTP_PORT="587"
    else
        case "$DOMAIN" in
            "gmail.com")
                SMTP_SERVER="smtp.gmail.com"
                SMTP_PORT="587"
                ;;
            "outlook.com"|"hotmail.com")
                SMTP_SERVER="smtp-mail.outlook.com"
                SMTP_PORT="587"
                ;;
            "yahoo.com"|"yahoo.com.br")
                SMTP_SERVER="smtp.mail.yahoo.com"
                SMTP_PORT="587"
                ;;
            *)
                echo "Servidor SMTP não configurado para o domínio $DOMAIN."
                exit 1
                ;;
        esac
    fi
}

# Função para validar credenciais via SMTP
validate_credentials() {
    echo "Validando credenciais..."
    VALIDACAO=$(swaks --to "$EMAIL" --from "$EMAIL" \
              --server "$SMTP_SERVER" --port "$SMTP_PORT" \
              --auth LOGIN --auth-user "$EMAIL" --auth-password "$SENHA" \
              --tls --quit-after RCPT 2>&1)

    if echo "$VALIDACAO" | grep -q "250"; then
        echo "Autenticação bem-sucedida!"
    else
        echo "Falha na autenticação. Verifique sua conta, senha e servidor SMTP."
        exit 1
    fi
}

# Função para coletar informações do usuário para o e-mail
collect_email_data() {
    echo "Insira os dados para o envio do e-mail:"
    read -p "Destinatário(s) (separados por vírgula): " DESTINATARIOS
    read -p "Assunto: " ASSUNTO
    read -p "Cópia (CC) (separados por vírgula, se houver): " CC
    read -p "Com cópia oculta (BCC) (separados por vírgula, se houver): " BCC

    echo "Digite a mensagem (termine com uma linha contendo somente 'EOF'):"
    MSG=""
    while IFS= read -r LINE; do
        [ "$LINE" == "EOF" ] && break
        MSG+="${LINE}\n"
    done
    MSG=$(printf "%b" "$MSG")  # Converte corretamente as quebras de linha
}

# Função para enviar o e-mail via swaks
send_email() {
    echo "Enviando e-mail..."
    swaks --to "$DESTINATARIOS" \
          --from "$EMAIL" \
          --server "$SMTP_SERVER" --port "$SMTP_PORT" \
          --auth LOGIN --auth-user "$EMAIL" --auth-password "$SENHA" \
          --tls \
          --h-Subject "$ASSUNTO" \
          ${CC:+--h-Cc "$CC"} \
          ${BCC:+--h-Bcc "$BCC"} \
          --body "$MSG"

    if [ $? -eq 0 ]; then
        echo "E-mail enviado com sucesso!"
    else
        echo "Falha ao enviar o e-mail."
        exit 1
    fi
}

# Função principal
main() {
    read -p "Digite sua conta de e-mail: " EMAIL
    read -s -p "Digite sua senha: " SENHA
    echo ""

    detect_smtp_server
    validate_credentials
    collect_email_data
    send_email
}

# Executa o script
main

