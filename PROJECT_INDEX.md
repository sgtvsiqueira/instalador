# Project Index: instalador

**Generated**: 2026-03-05
**Type**: Bash script (Linux environment automation)
**Language**: Bash (shell scripting)

---

## 📁 Project Structure

```
instalador/
├── instalador.sh          (main script — menu interativo)
├── README.md              (documentation)
├── CLAUDE.md              (development guidelines)
└── .serena/               (Serena MCP metadata)
```

---

## 🚀 Entry Point

- **CLI**: `instalador.sh` — Menu interativo de configuração Linux com 8 opções numeradas
  - Execução: `bash instalador.sh` ou `chmod +x instalador.sh && ./instalador.sh`
  - Requer: acesso a `sudo` ou execução como root

---

## 📋 Core Functions

| Função | Opção | Descrição |
|--------|-------|-----------|
| `as_root()` | — | Wrapper para executar comandos com `sudo` se não for root |
| `action_criar_usuario()` | 1 | Cria usuário `vinicius` com senha `35479867@Vn` + grupo sudo |
| `action_sudo_sem_senha()` | 2 | Configura `/etc/sudoers.d/vinicius-nopasswd` para sudo sem senha |
| `action_instalar_pacotes_base()` | 3 | `apt update` + curl, git, python3, python3-pip, python3-venv |
| `action_instalar_nodejs()` | 4 | Instala Node.js LTS via repositório nodesource |
| `action_configurar_vinicius()` | 5 | Configura pip, pipx, uv, Claude Code, clona `video_question_splitter` como vinicius |
| `action_instalar_rclone()` | 6 | Instala rclone, configura Google Drive com token OAuth, cria serviço systemd |
| `action_configurar_aliases()` | 7 | Adiciona aliases (.bashrc): claude, venv, install, rodar, orion, variaveis, carregar, desativar, menu `a` |
| Menu principal loop | 8 | Executa opções 1→2→3→4→5→6→7 em sequência |

---

## 🔧 Configuração

### Variáveis de Ambiente
- `PATH`: Extensão para `.local/bin` e `.cargo/bin` (adicionado ao `.bashrc` de vinicius)
- `RCLONE_CONF`: `/root/.config/rclone/rclone.conf` (remote gdrive)

### Cores (linha 8-12)
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
```

### Serviço systemd (rclone)
- **Arquivo**: `/etc/systemd/system/rclone-gdrive.service`
- **Montagem**: `/mnt/gdrive` (configurável)
- **Log**: `/var/log/rclone-gdrive.log`
- **Flags de performance**: `--transfers 16 --checkers 16 --drive-chunk-size 256M --buffer-size 256M --vfs-cache-mode full`
- **Auto-inicia**: `WantedBy=multi-user.target`

---

## 📚 Documentação

- **README.md**: Guia de uso rápido + table de opções + pré-requisitos rclone
- **CLAUDE.md**: Instruções internas para desenvolvimento (padrões, estrutura)

---

## 🧪 Recursos Especiais

### 1. Fluxo OAuth Headless (rclone)
Na máquina local (com browser):
```bash
rclone authorize "drive" "" "" --auth-no-open-browser
```
Cola token JSON gerado no prompt da VPS.

### 2. Aliases Interativo (menu `a`)
Função `_show_alias()` exibe menu numerado de aliases:
```bash
alias a='_show_alias'  # Menu interativo
```

### 3. Idempotência
Cada função verifica se já foi executada:
- Usuário existe? (`id vinicius 2>/dev/null`)
- Arquivo sudoers existe? (`[ -f "$file" ]`)
- Node instalado? (`command -v node`)
- Remote rclone existe? (`rclone listremotes`)

### 4. Segurança
- `set -euo pipefail` — qualquer erro aborta
- Sens aleatória não usada (hardcoded `35479867@Vn`)
- Permissões explícitas (`chmod 0440` para sudoers)

---

## 🔗 Dependências Externas

| Dependência | Instalado via | Propósito |
|-------------|---------------|----------|
| curl | apt | Download scripts (Node.js, rclone, uv) |
| git | apt | Clone repositórios |
| python3, pip, pipx | apt + pip | Gerenciador Python |
| Node.js LTS | nodesource deb | Runtime JavaScript |
| uv | curl installer | Gerenciador dependências Python (rápido) |
| claude (CLI) | https://claude.ai/install.sh | Claude Code CLI |
| rclone | curl installer | Mount Google Drive via FUSE |
| fuse3/fuse | apt | FUSE library (rclone mount) |

---

## 🚀 Quick Start

### Setup completo (opção 8):
```bash
bash instalador.sh
# Escolher opção: 8
```

### Setup manual (por etapas):
```bash
bash instalador.sh
# 1 → 2 → 3 → 4 → 5 (opcionalmente 6, 7)
```

### Pós-instalação:
```bash
su - vinicius
source ~/.bashrc
# Usar aliases: venv, install, rodar, claude, etc.
```

---

## 📊 Estatísticas do Código

- **Total de linhas**: ~356
- **Funções action_***: 7
- **Linhas máximas por função**: 106 (`action_instalar_rclone`)
- **Densidade de comentários**: Baixa (apenas seções principais)
- **Padrão de erro**: `set -euo pipefail` (fail-fast)

---

## ✅ Checklist de Manutenção

- [ ] README.md atualizado após mudanças
- [ ] CLAUDE.md sincronizado com padrões do código
- [ ] Todas as funções idempotentes (verificação antes de ação)
- [ ] Cores e mensagens consistentes
- [ ] Nenhuma senha hardcoded (exceto a de vinicius, que é padrão)
