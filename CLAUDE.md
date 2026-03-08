# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Importante
- Sempre mantenha o readm.me atualizado

## Visão Geral

Script Bash interativo de configuração de ambiente Linux. Automatiza a criação de usuário, configuração de sudo, instalação de dependências (Node.js, Python, uv, Claude Code) e clone de repositório via menu numerado.

## Arquivo principal

- `instalador.sh` — único arquivo do projeto. Script de menu interativo com 7 opções.

## Como executar

```bash
bash instalador.sh
# ou com permissão de execução:
chmod +x instalador.sh && ./instalador.sh
```

Requer execução com usuário que tenha acesso a `sudo` (ou como root diretamente).

## Estrutura do script

O script segue um padrão de funções prefixadas com `action_*`, cada uma correspondendo a uma opção do menu:

| Opção | Função | O que faz |
|-------|--------|-----------|
| 1 | `action_criar_usuario` | Cria usuário `vinicius` com senha e grupo sudo |
| 2 | `action_sudo_sem_senha` | Adiciona arquivo em `/etc/sudoers.d/` |
| 3 | `action_instalar_pacotes_base` | `apt update` + instalação de curl, ca-certificates, python3 |
| 4 | `action_instalar_git_gh` | Instala git + GitHub CLI (`gh`) via repositório oficial; autentica como vinicius via `gh auth login --web` (headless) |
| 5 | `action_instalar_nodejs` | Instala Node.js LTS via nodesource |
| 6 | `action_configurar_vinicius` | Configura pip, pipx, uv como usuário vinicius |
| 7 | `action_instalar_claude` | Instala Claude Code como usuário vinicius |
| 8 | `action_instalar_rclone` | Instala rclone, configura remote `gdrive` (Google Drive, escopo total), pede folder ID e ponto de montagem, cria serviço systemd com velocidade máxima |
| 9 | `action_configurar_aliases` | Adiciona aliases personalizados no `~/.bashrc` do usuário atual (claude, venv, install, rodar, orion, carregar, variaveis, desativar, menu `a`) |
| 10 | — | Executa opções 1→2→3→4→5→6→7→8→9 em sequência |

O menu aceita **seleção múltipla**: digite opções separadas por vírgula ou espaço (ex: `1,3,5` ou `1 3 5`).

## Fluxo OAuth do rclone (headless / VPS)

A opção 6 usa fluxo sem browser na VPS. O usuário deve rodar **na máquina local**:
```bash
rclone authorize "drive" "" "" --auth-no-open-browser
```
Colar o token JSON gerado quando solicitado pelo script.

## Serviço systemd do rclone

- Arquivo: `/etc/systemd/system/rclone-gdrive.service`
- Montagem: `/mnt/gdrive` (padrão, configurável)
- Log: `/var/log/rclone-gdrive.log`
- Flags de performance: `--transfers 16 --checkers 16 --drive-chunk-size 256M --buffer-size 256M --vfs-cache-mode full`

## Padrões do código

- Usa `as_root()` para elevar privilégios via `sudo` quando não é root
- Idempotente: cada função verifica se a ação já foi realizada antes de executar
- Usa `set -euo pipefail` — qualquer erro aborta a execução
- Cores definidas no topo: `RED`, `GREEN`, `YELLOW`, `NC`
- O subshell `su - vinicius -c '...'` na opção 5 executa configurações no contexto do usuário alvo

## PROJECT_INDEX.md

Consulte `PROJECT_INDEX.md` para uma visão completa do projeto (estrutura, funções, dependências, configurações).

**Quando usar**:
- Na primeira sessão ou após entender a arquitetura
- Para referência rápida de funções, entrada e saída
- Economiza ~94% de tokens comparado a ler `instalador.sh` completo

**Informação incluída**:
- Estrutura de diretórios
- Tabela resumida de funções
- Variáveis de ambiente e configuração
- Dependências externas
- Quick start e checklist de manutenção
