#!/usr/bin/env bash
# =============================================================================
# Script de configuração e manutenção (menu interativo)
# =============================================================================

set -euo pipefail

# Cores para facilitar leitura
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear

echo -e "${YELLOW}===================================================="
echo "       Configuração e Manutenção do Ambiente        "
echo "===================================================${NC}"
echo

# Função para rodar comandos como root
as_root() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# =============================================
#  FUNÇÕES DAS AÇÕES
# =============================================

action_criar_usuario() {
    echo -e "${GREEN}→ Criando usuário vinicius (se não existir)${NC}"
    id vinicius 2>/dev/null && { echo "Usuário vinicius já existe."; return; }
    
    as_root useradd -m -s /bin/bash vinicius
    echo "vinicius:35479867@Vn" | as_root chpasswd
    as_root usermod -aG sudo vinicius
    echo -e "${GREEN}Usuário criado e adicionado ao grupo sudo${NC}"
}

action_sudo_sem_senha() {
    echo -e "${GREEN}→ Configurando sudo sem senha para vinicius${NC}"
    local file="/etc/sudoers.d/vinicius-nopasswd"
    
    if [ -f "$file" ]; then
        echo "Já existe arquivo de sudo sem senha."
        return
    fi
    
    echo "vinicius ALL=(ALL) NOPASSWD:ALL" | as_root tee "$file" >/dev/null
    as_root chmod 0440 "$file"
    echo -e "${GREEN}Sudo sem senha configurado${NC}"
}

action_instalar_pacotes_base() {
    echo -e "${GREEN}→ Atualizando sistema e instalando pacotes básicos${NC}"
    as_root apt update -y
    as_root apt install -y \
        curl ca-certificates \
        python3 python3-pip python3-venv
    echo -e "${GREEN}Pacotes base instalados${NC}"
}

action_instalar_git_gh() {
    echo -e "${GREEN}→ Instalando git e GitHub CLI (gh)${NC}"

    # git
    if ! command -v git >/dev/null; then
        as_root apt install -y git
    else
        echo "git já instalado ($(git --version))"
    fi

    # gh CLI
    if ! command -v gh >/dev/null; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | as_root dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        as_root chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        as_root apt update -y
        as_root apt install -y gh
    else
        echo "gh já instalado ($(gh --version | head -1))"
    fi

    # Autenticação como vinicius via browser (headless)
    echo
    echo -e "${YELLOW}Iniciando autenticação do GitHub CLI como usuário vinicius...${NC}"
    echo -e "${YELLOW}Será exibido um código e uma URL — acesse a URL no seu browser local e insira o código.${NC}"
    echo
    su - vinicius -c 'gh auth login --hostname github.com --git-protocol https --web'
}

action_instalar_nodejs() {
    echo -e "${GREEN}→ Instalando Node.js LTS${NC}"
    if command -v node >/dev/null && node -v | grep -q "v[0-9][0-9]\."; then
        echo "Node.js já está instalado ($(node -v))"
        return
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_lts.x | as_root bash -
    as_root apt install -y nodejs
    echo -e "${GREEN}Node.js instalado$(node -v 2>/dev/null || echo ' (verificação falhou)') ${NC}"
}

action_instalar_rclone() {
    echo -e "${GREEN}→ Instalando e configurando rclone com Google Drive${NC}"

    # Instala rclone se não existir
    if ! command -v rclone >/dev/null; then
        curl -fsSL https://rclone.org/install.sh | as_root bash
    else
        echo "rclone já instalado ($(rclone --version | head -1))"
    fi

    # Dependência para mount via FUSE
    as_root apt install -y fuse3 2>/dev/null || as_root apt install -y fuse 2>/dev/null || true

    # Habilita user_allow_other no fuse
    if ! grep -q "^user_allow_other" /etc/fuse.conf 2>/dev/null; then
        echo "user_allow_other" | as_root tee -a /etc/fuse.conf >/dev/null
    fi

    # Verifica se o remote gdrive já existe
    if rclone listremotes | grep -q "^gdrive:"; then
        echo -e "${YELLOW}Remote 'gdrive' já existe. Pulando configuração OAuth.${NC}"
    else
        echo
        echo -e "${YELLOW}============================================================${NC}"
        echo -e "${YELLOW} AUTENTICAÇÃO GOOGLE DRIVE — FLUXO HEADLESS (VPS)${NC}"
        echo -e "${YELLOW}============================================================${NC}"
        echo
        echo "Na sua MÁQUINA LOCAL (com browser), rode:"
        echo
        echo -e "  ${GREEN}rclone authorize \"drive\" \"\" \"\" --auth-no-open-browser${NC}"
        echo
        echo "Ou, se não tiver rclone localmente, use:"
        echo -e "  ${GREEN}npx --yes @rclone/rclone authorize drive${NC}"
        echo
        echo "Cole abaixo o token JSON gerado (começa com {\"access_token\":...)"
        echo -e "${YELLOW}------------------------------------------------------------${NC}"
        read -rp "Token: " RCLONE_TOKEN </dev/tty

        if [ -z "$RCLONE_TOKEN" ]; then
            echo -e "${RED}Token não informado. Abortando configuração do rclone.${NC}"
            return 1
        fi

        # Cria configuração do remote gdrive
        as_root mkdir -p /root/.config/rclone
        local RCLONE_CONF="/root/.config/rclone/rclone.conf"

        cat | as_root tee -a "$RCLONE_CONF" >/dev/null <<EOF

[gdrive]
type = drive
scope = drive
token = ${RCLONE_TOKEN}
EOF

        echo -e "${GREEN}Remote 'gdrive' configurado com sucesso.${NC}"
    fi

    # Pede folder ID do Drive
    echo
    echo "Informe o ID da pasta do Google Drive que deseja montar."
    echo "(Abra a pasta no browser — o ID é a parte final da URL)"
    echo -e "Exemplo: https://drive.google.com/drive/folders/${GREEN}1AbCdEfGhIjKlMnOpQr${NC}"
    echo "(Deixe em branco para montar o Drive inteiro)"
    read -rp "Folder ID: " GDRIVE_FOLDER_ID </dev/tty

    # Pede ponto de montagem
    echo
    read -rp "Caminho de montagem na VPS [padrão: /mnt/gdrive]: " MOUNT_POINT </dev/tty
    MOUNT_POINT="${MOUNT_POINT:-/mnt/gdrive}"

    # Monta em subpasta /drive para não sobrescrever arquivos locais existentes
    local ACTUAL_MOUNT="${MOUNT_POINT}/drive"
    as_root mkdir -p "$ACTUAL_MOUNT"

    # Monta service systemd
    local SERVICE_FILE="/etc/systemd/system/rclone-gdrive.service"

    # Constrói argumento de root folder se informado
    local ROOT_FOLDER_ARG=""
    if [ -n "$GDRIVE_FOLDER_ID" ]; then
        ROOT_FOLDER_ARG="--drive-root-folder-id=${GDRIVE_FOLDER_ID} "
    fi

    as_root tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=rclone mount Google Drive (gdrive)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStartPre=/bin/mkdir -p ${ACTUAL_MOUNT}
ExecStart=/usr/bin/rclone mount gdrive: ${ACTUAL_MOUNT} \\
    ${ROOT_FOLDER_ARG}--allow-other \\
    --vfs-cache-mode full \\
    --vfs-cache-max-size 10G \\
    --vfs-read-chunk-size 128M \\
    --vfs-read-chunk-size-limit off \\
    --transfers 16 \\
    --checkers 16 \\
    --drive-chunk-size 256M \\
    --buffer-size 256M \\
    --use-mmap \\
    --log-level INFO \\
    --log-file /var/log/rclone-gdrive.log
ExecStop=/bin/fusermount -uz ${ACTUAL_MOUNT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    as_root systemctl daemon-reload
    as_root systemctl enable rclone-gdrive.service
    as_root systemctl start rclone-gdrive.service

    echo
    sleep 2
    if systemctl is-active --quiet rclone-gdrive.service; then
        echo -e "${GREEN}✔ Google Drive montado com sucesso em: ${ACTUAL_MOUNT}${NC}"
        echo -e "${GREEN}  Arquivos locais em ${MOUNT_POINT} preservados${NC}"
        echo -e "${GREEN}  Serviço systemd ativado (inicia automático no boot)${NC}"
    else
        echo -e "${RED}✘ Serviço não iniciou. Verifique: journalctl -u rclone-gdrive.service${NC}"
    fi
}

action_configurar_aliases() {
    local target_bashrc="$HOME/.bashrc"
    echo -e "${GREEN}→ Configurando aliases personalizados em: $target_bashrc${NC}"

    # Função auxiliar: adiciona linha ao bashrc se ainda não existir
    add_line() {
        grep -qxF "$1" "$target_bashrc" || echo "$1" >> "$target_bashrc"
    }

    # Bloco de aliases personalizados
    add_line ""
    add_line "# ── Aliases personalizados (instalador) ──"
    add_line "alias claude='claude --dangerously-skip-permissions'"
    add_line "alias variaveis='nano ~/.bashrc'"
    add_line "alias carregar='source ~/.bashrc'"
    add_line "alias desativar='deactivate'"
    add_line "alias rodar='bash ./rodar.sh'"
    add_line "alias orion='bash <(curl -sSL setup.oriondesign.art.br)'"
    add_line "alias venv='if [ -d \".venv\" ]; then echo \"Ativando ambiente virtual existente...\"; source .venv/bin/activate; else echo \"Criando e ativando novo ambiente virtual...\"; python3 -m venv .venv && source .venv/bin/activate; fi'"
    add_line "alias install='source .venv/bin/activate 2>/dev/null || (python3 -m venv .venv && source .venv/bin/activate); pip install -r requirements.txt'"

    # Função _show_alias + alias 'a'
    if ! grep -q "_show_alias()" "$target_bashrc"; then
        cat >> "$target_bashrc" <<'ALIASES_EOF'

# Menu interativo de aliases
_show_alias() {
    local aliases=(
        "claude" "variaveis" "carregar" "desativar"
        "rodar" "orion" "venv" "install"
        "ll" "la" "l"
    )
    local list=()
    local i=1
    for name in "${aliases[@]}"; do
        local def
        def=$(alias "$name" 2>/dev/null)
        if [ -n "$def" ]; then
            printf "%6d\t%s\n" "$i" "$def"
            list+=("$name")
            ((i++))
        fi
    done
    read -p "Digite o número do alias (ou Enter para cancelar): " num </dev/tty
    if [[ -n "$num" && "$num" =~ ^[0-9]+$ && "$num" -ge 1 && "$num" -le "${#list[@]}" ]]; then
        local chosen="${list[$((num-1))]}"
        eval "$(alias "$chosen" | cut -d= -f2- | tr -d "'")"
    fi
}
alias a='_show_alias'
ALIASES_EOF
    fi

    echo -e "${GREEN}Aliases configurados. Execute: source ~/.bashrc${NC}"
}

action_configurar_vinicius() {
    echo -e "${YELLOW}Executando configurações como usuário vinicius...${NC}\n"
    
    su - vinicius -c '
        set -euo pipefail
        
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        
        # Adiciona ao .bashrc se ainda não existir
        grep -qxF "export PATH=\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH" ~/.bashrc || \
        echo "export PATH=\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH" >> ~/.bashrc
        
        grep -qxF "alias rodar=\"bash ./rodar.sh\"" ~/.bashrc || \
        echo "alias rodar=\"bash ./rodar.sh\"" >> ~/.bashrc
        
        # pip + pipx
        python3 -m pip install --user --upgrade pip pipx
        python3 -m pipx ensurepath
        
        # uv
        if ! command -v uv >/dev/null; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        
        echo
        echo "Status final (como vinicius):"
        echo "----------------------------------------"
        whoami
        node -v 2>/dev/null || echo "node não encontrado"
        npm -v  2>/dev/null || echo "npm não encontrado"
        python3 --version
        uv --version 2>/dev/null || echo "uv não encontrado"
        claude --version 2>/dev/null || echo "claude não encontrado"
        echo "----------------------------------------"
    '
}

action_instalar_claude() {
    echo -e "${GREEN}→ Instalando Claude Code para o usuário vinicius${NC}"
    su - vinicius -c '
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        if command -v claude >/dev/null; then
            echo "Claude Code já instalado ($(claude --version 2>/dev/null))"
        else
            curl -fsSL https://claude.ai/install.sh | bash || echo "Instalação do claude falhou"
        fi
    '
}

# =============================================
#                MENU PRINCIPAL
# =============================================

executar_opcao() {
    case $1 in
        1) action_criar_usuario ;;
        2) action_sudo_sem_senha ;;
        3) action_instalar_pacotes_base ;;
        4) action_instalar_git_gh ;;
        5) action_instalar_nodejs ;;
        6) action_configurar_vinicius ;;
        7) action_instalar_claude ;;
        8) action_instalar_rclone ;;
        9) action_configurar_aliases ;;
        10)
            echo -e "\n${YELLOW}Executando TODAS as etapas na ordem...${NC}\n"
            action_criar_usuario
            action_sudo_sem_senha
            action_instalar_pacotes_base
            action_instalar_git_gh
            action_instalar_nodejs
            action_configurar_vinicius
            action_instalar_claude
            action_instalar_rclone
            action_configurar_aliases
            ;;
        0) echo -e "\n${GREEN}Saindo...${NC}"; exit 0 ;;
        *) echo -e "${RED}Opção inválida: $1${NC}" ;;
    esac
}

while true; do
    echo
    echo -e "${YELLOW}O que deseja fazer?${NC}"
    echo "  1) Criar usuário vinicius + senha + sudo"
    echo "  2) Configurar sudo sem senha para vinicius"
    echo "  3) Instalar pacotes base (curl, python...)"
    echo "  4) Instalar git + GitHub CLI (gh) + autenticação"
    echo "  5) Instalar Node.js LTS"
    echo "  6) Configurar ambiente do usuário vinicius (pip, pipx, uv)"
    echo "  7) Instalar Claude Code"
    echo "  8) Instalar e configurar rclone + Google Drive"
    echo "  9) Configurar aliases personalizados"
    echo " 10) Executar TUDO (1→2→3→4→5→6→7→8→9)"
    echo "  0) Sair"
    echo
    echo -e "${YELLOW}Dica: você pode escolher múltiplas opções separadas por vírgula ou espaço (ex: 1,3,5 ou 1 3 5)${NC}"
    echo
    read -p "Escolha [0-10]: " entrada </dev/tty

    # Normaliza separadores (vírgula e espaço) e itera
    IFS=', ' read -ra opcoes <<< "$entrada"
    for opcao in "${opcoes[@]}"; do
        [[ -z "$opcao" ]] && continue
        executar_opcao "$opcao"
    done

    echo -e "\nPressione Enter para voltar ao menu..."
    read -r </dev/tty
    clear
done
