# instalador

Script interativo de configuração de ambiente Linux para VPS.

## O que faz

Automatiza a instalação e configuração de:
- Usuário Linux (`vinicius`)
- Sudo sem senha
- Pacotes base (curl, git, Python)
- Node.js LTS
- Ferramentas para desenvolvimento (pip, pipx, uv, Claude Code)
- **rclone** com Google Drive montado automaticamente
- **Aliases personalizados** no `.bashrc` (venv, claude, rodar, orion...)

## Como usar

```bash
bash instalador.sh
```

Requer acesso a `sudo` (ou rodar como root).

## Menu de opções

| Opção | Descrição |
|-------|-----------|
| 1 | Criar usuário vinicius + senha + sudo |
| 2 | Configurar sudo sem senha |
| 3 | Instalar pacotes base |
| 4 | Instalar Node.js LTS |
| 5 | Configurar ambiente do usuário vinicius |
| 6 | Instalar e configurar rclone + Google Drive |
| 7 | Configurar aliases personalizados no `.bashrc` |
| 8 | Executar tudo (1→7) |

## Configuração do rclone (opção 6)

### Pré-requisitos

Na **máquina local** (com browser), execute:
```bash
rclone authorize "drive" "" "" --auth-no-open-browser
```

Copie o token JSON gerado.

### No script

1. Cole o token quando solicitado
2. Informe o **Folder ID** do Google Drive (opcional — deixe em branco para montar tudo)
3. Defina o **ponto de montagem** (padrão: `/mnt/gdrive`)

### Resultado

- ✅ Remote `gdrive` configurado
- ✅ Serviço systemd criado (`rclone-gdrive.service`)
- ✅ Auto-inicia no boot
- ✅ Log em `/var/log/rclone-gdrive.log`
- ✅ Performance otimizada (transfers, cache, chunk size máximos)

## Características

- **Idempotente**: cada opção verifica se já foi executada
- **Cores**: saída formatada com cores para fácil leitura
- **Menu interativo**: escolha o que configurar
- **Otimizado para VPS**: sem dependências gráficas
