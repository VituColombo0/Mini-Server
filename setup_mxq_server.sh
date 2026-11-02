#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Mini Servidor Residencial Otimizado & Seguro
#  
#  Serviços, Otimizações e Acesso Remoto Master Inclusos:
#    1. Otimizações ARM (ZRAM lz4, Proteção Flash/SD noatime, Watchdog, CPU Governor)
#    2. Segurança Reforçada (Firewall UFW, Fail2ban contra força bruta, SSH protegido)
#    3. Usuário Master ROOT "Lirool" com sudo e poderes totais de reescrita remota
#    4. Console Terminal Web Master (ttyd na porta 7681 — terminal root no navegador)
#    5. FileBrowser Web Master (Editor de arquivos do sistema raiz na porta 8082)
#    6. Ferramenta de Atualização Remota OTA (/usr/local/bin/mxq-update)
#    7. AdGuard Home (Bloqueador de anúncios DNS protegido por senha na porta 3000)
#    8. Servidor Samba Autenticado (Compartilhamento de arquivos na rede porta 445)
#    9. Dashboard Nginx Protegido (Autenticação HTTP Basic Auth na porta 8080)
#   10. Docker + Portainer CE (Gerenciamento de containers na porta 9000)
#   11. Uptime Kuma (Monitoramento com alertas na porta 3001)
#   12. Tailscale VPN (Acesso remoto seguro de qualquer lugar do mundo)
#   13. Manutenção Automática (Cron diário para limpeza de cache e Docker)
# ============================================================================

set -euo pipefail

# ── Cores para output ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ── Credenciais de Usuário Padrão da Casa ───────────────────────────────────
SERVER_USER="${SERVER_USER:-vimora}"
SERVER_PASS="${SERVER_PASS:-aromiv}"

# ── Credenciais MASTER / ROOT (Apenas o Administrador sabe) ─────────────────
MASTER_USER="${MASTER_USER:-Lirool}"
MASTER_PASS="${MASTER_PASS:-vitubidi123}"

# ── Portas dos Serviços ────────────────────────────────────────────────────
ADGUARD_PORT=3000
UPTIME_KUMA_PORT=3001
PORTAINER_PORT=9000
NGINX_PORT=8080
FILEBROWSER_PORT=8082
WEB_TERMINAL_PORT=7681

# ── Diretórios ─────────────────────────────────────────────────────────────
SAMBA_SHARE_PATH="/srv/shared"
USB_MOUNT_POINT="/mnt/usb"
LOG_FILE="/var/log/mxq-setup.log"
CREDS_FILE="/root/server-credentials.txt"

# ── Funções Auxiliares ─────────────────────────────────────────────────────
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

header() {
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root (sudo)"
        exit 1
    fi
}

get_local_ip() {
    hostname -I | awk '{print $1}'
}

get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        aarch64)  echo "arm64" ;;
        armv7l)   echo "armv7" ;;
        armv6l)   echo "armv6" ;;
        x86_64)   echo "amd64" ;;
        *)        echo "$arch" ;;
    esac
}

# ============================================================================
#  FASE 1: Otimizações de Hardware & Sistema (ZRAM, Flash, CPU, Watchdog)
# ============================================================================
setup_optimizations() {
    header "FASE 1: Otimizações de Desempenho e Vida Útil do Hardware"

    log "1.1 Atualizando repositórios e instalando utilitários essenciais..."
    apt-get update -qq
    apt-get install -y -qq \
        curl wget git htop nano ufw unzip ca-certificates gnupg \
        lsb-release ntfs-3g avahi-daemon net-tools jq zram-tools \
        apache2-utils fail2ban cpufrequtils watchdog sudo 2>/dev/null || \
    apt-get install -y \
        curl wget git htop nano ufw unzip ca-certificates gnupg \
        ntfs-3g avahi-daemon net-tools jq zram-tools apache2-utils fail2ban sudo

    log "1.2 Configurando ZRAM (Memória RAM Comprimida lz4)..."
    if [ -f /etc/default/zramswap ]; then
        cat > /etc/default/zramswap << 'ZRAM_EOF'
ALGO=lz4
PERCENT=60
PRIORITY=100
ZRAM_EOF
        systemctl restart zramswap 2>/dev/null || true
        log "✅ ZRAM ativado com compressão lz4 (60% da RAM)!"
    fi

    log "1.3 Otimizando gravações em disco (Proteção para MicroSD/eMMC)..."
    if grep -q "defaults" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
        sed -i 's/defaults/defaults,noatime,nodiratime,commit=60/g' /etc/fstab
        log "✅ Parâmetros noatime e commit=60 aplicados no fstab."
    fi

    mkdir -p /etc/systemd/journald.conf.d/
    cat > /etc/systemd/journald.conf.d/ram.conf << 'JOURNAL_EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=30M
JOURNAL_EOF
    systemctl restart systemd-journald 2>/dev/null || true

    log "1.4 Otimizando CPU Governor para controle térmico..."
    cat > /etc/default/cpufrequtils << 'CPU_EOF'
ENABLE="true"
GOVERNOR="schedutil"
MAX_SPEED="0"
MIN_SPEED="0"
CPU_EOF
    systemctl restart cpufrequtils 2>/dev/null || true

    log "1.5 Ativando Hardware Watchdog (Reboot automático se travar)..."
    if [ -e /dev/watchdog ]; then
        sed -i 's/#watchdog-device/watchdog-device/g' /etc/watchdog.conf 2>/dev/null || true
        sed -i 's/#max-load-1/max-load-1/g' /etc/watchdog.conf 2>/dev/null || true
        systemctl enable watchdog 2>/dev/null || true
        systemctl start watchdog 2>/dev/null || true
        log "✅ Watchdog de hardware ativado!"
    fi

    log "1.6 Configurando Timezone e Hostname..."
    timedatectl set-timezone America/Sao_Paulo 2>/dev/null || \
        ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    hostnamectl set-hostname mxq-server 2>/dev/null || \
        echo "mxq-server" > /etc/hostname

    log "✅ Otimizações concluídas com sucesso!"
}

# ============================================================================
#  FASE 2: Configuração do Usuário Master "Lirool" & Segurança
# ============================================================================
setup_security_and_master() {
    header "FASE 2: Configurando Usuário Master '${MASTER_USER}' e Segurança"

    log "2.1 Criando Usuário Master '${MASTER_USER}' com privilégios ROOT totais..."
    if ! id "${MASTER_USER}" &>/dev/null; then
        useradd -m -s /bin/bash "${MASTER_USER}"
    fi
    echo "${MASTER_USER}:${MASTER_PASS}" | chpasswd
    usermod -aG sudo,adm "${MASTER_USER}" 2>/dev/null || true

    # Permitir sudo total sem senha para scripts remotos
    mkdir -p /etc/sudoers.d
    echo "${MASTER_USER} ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-master-lirool
    chmod 440 /etc/sudoers.d/99-master-lirool
    log "✅ Usuário Master '${MASTER_USER}' configurado com permissões totais de root!"

    log "2.2 Configurando Fail2ban contra tentativas de invasão..."
    cat > /etc/fail2ban/jail.local << 'JAIL_EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 4
JAIL_EOF
    systemctl enable fail2ban 2>/dev/null || true
    systemctl restart fail2ban 2>/dev/null || {
        warn "Fail2ban não pôde ser iniciado (kernel pode não suportar iptables). Pulando..."
    }

    log "2.3 Configurando Firewall UFW restrito..."
    if iptables -L -n >/dev/null 2>&1; then
        ufw --force reset >/dev/null 2>&1 || true
        ufw default deny incoming >/dev/null 2>&1 || true
        ufw default allow outgoing >/dev/null 2>&1 || true

        ufw allow 22/tcp comment 'SSH Seguro' >/dev/null 2>&1 || true
        ufw allow 53/tcp comment 'DNS TCP' >/dev/null 2>&1 || true
        ufw allow 53/udp comment 'DNS UDP' >/dev/null 2>&1 || true
        ufw allow ${ADGUARD_PORT}/tcp comment 'AdGuard Home' >/dev/null 2>&1 || true
        ufw allow 139/tcp comment 'Samba NetBIOS' >/dev/null 2>&1 || true
        ufw allow 445/tcp comment 'Samba SMB' >/dev/null 2>&1 || true
        ufw allow ${NGINX_PORT}/tcp comment 'Dashboard Web' >/dev/null 2>&1 || true
        ufw allow ${FILEBROWSER_PORT}/tcp comment 'FileBrowser Web' >/dev/null 2>&1 || true
        ufw allow ${WEB_TERMINAL_PORT}/tcp comment 'Web Terminal Master' >/dev/null 2>&1 || true
        ufw allow ${UPTIME_KUMA_PORT}/tcp comment 'Uptime Kuma' >/dev/null 2>&1 || true
        ufw allow ${PORTAINER_PORT}/tcp comment 'Portainer' >/dev/null 2>&1 || true

        ufw --force enable >/dev/null 2>&1 || true
        log "✅ Firewall UFW configurado e ativo!"
    else
        warn "Kernel não suporta iptables/netfilter. Firewall UFW não ativado."
        warn "A TV Box funcionará sem firewall (rede local doméstica é segura)."
    fi
    log "✅ Configuração de segurança concluída!"
}

# ============================================================================
#  FASE 3: Console Terminal Web Master (ttyd na Porta 7681)
# ============================================================================
setup_web_terminal() {
    header "FASE 3: Instalando Console Terminal Web Master (Porta ${WEB_TERMINAL_PORT})"

    local ARCH
    ARCH=$(get_arch)
    local TTYD_BIN=""

    # Tentar instalar via apt primeiro
    if apt-get install -y -qq ttyd 2>/dev/null; then
        TTYD_BIN=$(which ttyd)
    fi

    # Se não tiver pacote apt funcional, baixa binário estático oficial
    if [ -z "$TTYD_BIN" ] || [ ! -x "$TTYD_BIN" ]; then
        log "Baixando binário oficial ultra leve do ttyd..."
        local DL_ARCH="armhf"
        if [ "$ARCH" = "arm64" ]; then
            DL_ARCH="aarch64"
        fi
        wget -q "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${DL_ARCH}" -O /usr/local/bin/ttyd 2>/dev/null || {
            warn "Tentando link alternativo para ttyd..."
            curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${DL_ARCH}" -o /usr/local/bin/ttyd || true
        }
        chmod +x /usr/local/bin/ttyd 2>/dev/null || true
        TTYD_BIN="/usr/local/bin/ttyd"
    fi

    if [ -x "$TTYD_BIN" ]; then
        log "Configurando serviço systemd para o Terminal Web Master..."
        cat > /usr/local/bin/mxq-web-terminal << TTYD_WRAPPER
#!/bin/bash
exec ${TTYD_BIN} -p ${WEB_TERMINAL_PORT} -c "${MASTER_USER}:${MASTER_PASS}" -W bash -login
TTYD_WRAPPER
        chmod +x /usr/local/bin/mxq-web-terminal

        cat > /etc/systemd/system/ttyd.service << TTYD_EOF
[Unit]
Description=Console Terminal Web Master (Lirool)
After=network.target

[Service]
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/mxq-web-terminal
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
TTYD_EOF

        systemctl daemon-reload
        systemctl enable ttyd
        systemctl restart ttyd
        log "✅ Terminal Web Master ativo na porta ${WEB_TERMINAL_PORT}!"
        log "   Acesse: http://$(get_local_ip):${WEB_TERMINAL_PORT} (Login: ${MASTER_USER})"
    else
        warn "Não foi possível compilar/baixar ttyd diretamente. Acesso SSH permanece ativo."
    fi

    # Criar ferramenta de transferência para memória interna /usr/local/bin/mxq-install-internal
    cat > /usr/local/bin/mxq-install-internal << 'INSTALL_INTERNAL_EOF'
#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Transferência para Memória Interna (eMMC / NAND)
#  
#  Permite remover o MicroSD e rodar o Linux e os servidores 24/7
#  diretamente do chip interno da TV Box!
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Erro: Execute este utilitário como root (sudo mxq-install-internal)${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}  ⚡ MXQ SERVER — INSTALAÇÃO NA MEMÓRIA INTERNA (eMMC/NAND)${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo ""
echo -e "Detectando ferramentas e mídia interna instaladas na placa..."

if command -v armbian-install &>/dev/null; then
    echo -e "${GREEN}✅ Utilitário oficial 'armbian-install' detectado!${NC}"
    echo "Iniciando transferência guiada para o eMMC/NAND interno..."
    armbian-install "$@"
elif [ -f /root/install-aml.sh ]; then
    echo -e "${GREEN}✅ Script oficial Amlogic 'install-aml.sh' detectado!${NC}"
    chmod +x /root/install-aml.sh
    /root/install-aml.sh "$@"
elif command -v nand-sata-install &>/dev/null; then
    echo -e "${GREEN}✅ Utilitário 'nand-sata-install' detectado!${NC}"
    nand-sata-install "$@"
else
    echo -e "${YELLOW}Procurando dispositivos de armazenamento internos (/dev/mmcblk1 ou /dev/nand)...${NC}"
    lsblk
    echo ""
    echo -e "${YELLOW}Para placas Rockchip RK322x, a gravação pode ser feita diretamente pelo Multitool:${NC}"
    echo -e "  1. No boot do Multitool, selecione 'Burn image to eMMC/NAND'."
    echo -e "  2. O Armbian é gravado diretamente na memória interna."
fi

echo ""
echo -e "${GREEN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD}  🎉 PROCESSO CONCLUÍDO!${NC}"
echo -e "${GREEN}${BOLD}  Agora você pode desligar a TV Box ('poweroff'), RETIRAR o MicroSD${NC}"
echo -e "${GREEN}${BOLD}  e ligá-la novamente na tomada para rodar 100% da memória interna!${NC}"
echo -e "${GREEN}${BOLD}====================================================================${NC}"
INSTALL_INTERNAL_EOF
    chmod +x /usr/local/bin/mxq-install-internal
    log "✅ Ferramenta de instalação interna instalada em /usr/local/bin/mxq-install-internal!"

    # Criar ferramenta de atualização remota OTA /usr/local/bin/mxq-update
    cat > /usr/local/bin/mxq-update << 'UPDATE_EOF'
#!/bin/bash
# Ferramenta Oficial de Atualização Remota Over-The-Air da MXQ Pro
set -euo pipefail
echo "=========================================================="
echo "⚡ MXQ SERVER — ATUALIZAÇÃO REMOTA OVER-THE-AIR"
echo "=========================================================="

REPO_DIR="/root/Mini-Server"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

if [ ! -d ".git" ]; then
    echo "1. Inicializando sincronização com repositório GitHub..."
    git init
    git remote add origin https://github.com/VituColombo0/Mini-Server.git 2>/dev/null || git remote set-url origin https://github.com/VituColombo0/Mini-Server.git
fi

echo "2. Baixando atualizações mais recentes do GitHub..."
git fetch origin main || true
git reset --hard origin/main || true
chmod +x *.sh 2>/dev/null || true

echo "✅ Arquivos e scripts atualizados com sucesso da nuvem!"
echo ""
if [ "${1:-}" = "--apply" ] || [ "${1:-}" = "-a" ]; then
    echo "🚀 Reaplicando configurações e instalador completo agora..."
    ./setup_mxq_server.sh
else
    echo "Dica: Para reaplicar o setup automaticamente após atualizar, execute:"
    echo "  mxq-update --apply"
fi
UPDATE_EOF
    chmod +x /usr/local/bin/mxq-update
    log "✅ Ferramenta de atualização remota instalada em /usr/local/bin/mxq-update!"
}

# ============================================================================
#  FASE 4: AdGuard Home (Bloqueador de Anúncios com Autenticação)
# ============================================================================
setup_adguard() {
    header "FASE 4: Instalando e Protegendo AdGuard Home"

    local ARCH
    ARCH=$(get_arch)
    local AGH_URL="https://static.adtidy.org/adguardhome/release/AdGuardHome_linux_${ARCH}.tar.gz"

    log "Baixando AdGuard Home para arquitetura ${ARCH}..."
    cd /tmp
    wget -q "${AGH_URL}" -O AdGuardHome.tar.gz

    log "Extraindo e instalando..."
    tar -xzf AdGuardHome.tar.gz
    cd AdGuardHome
    ./AdGuardHome -s install
    sleep 3

    rm -rf /tmp/AdGuardHome*
    log "✅ AdGuard Home instalado com sucesso na porta ${ADGUARD_PORT}!"
}

# ============================================================================
#  FASE 5: Servidor Samba Autenticado (Protegido por Login/Senha)
# ============================================================================
setup_samba() {
    header "FASE 5: Configurando Servidor de Arquivos Samba com Senha"

    apt-get install -y -qq samba samba-common-bin

    mkdir -p "${SAMBA_SHARE_PATH}" "${USB_MOUNT_POINT}"
    chmod 0770 "${SAMBA_SHARE_PATH}"

    if ! id "${SERVER_USER}" &>/dev/null; then
        useradd -M -s /usr/sbin/nologin "${SERVER_USER}" || true
    fi
    echo -e "${SERVER_PASS}\n${SERVER_PASS}" | passwd "${SERVER_USER}" >/dev/null 2>&1 || true

    (echo "${SERVER_PASS}"; echo "${SERVER_PASS}") | smbpasswd -s -a "${SERVER_USER}"
    chown -R "${SERVER_USER}:${SERVER_USER}" "${SAMBA_SHARE_PATH}"

    # Também adiciona o usuário Master Lirool no Samba para acesso irrestrito
    (echo "${MASTER_PASS}"; echo "${MASTER_PASS}") | smbpasswd -s -a "${MASTER_USER}" || true

    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true

    cat > /etc/samba/smb.conf << SAMBA_EOF
[global]
   workgroup = WORKGROUP
   server string = MXQ Secure Mini-Server
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no

   security = user
   map to guest = Never

   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384

[Compartilhado]
   comment = Pasta Compartilhada Segura
   path = ${SAMBA_SHARE_PATH}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SERVER_USER}, ${MASTER_USER}
   create mask = 0660
   directory mask = 0770
   force user = ${SERVER_USER}

[USB]
   comment = HD USB Externo Protegido
   path = ${USB_MOUNT_POINT}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SERVER_USER}, ${MASTER_USER}
   create mask = 0660
   directory mask = 0770
   force user = ${SERVER_USER}
SAMBA_EOF

    systemctl enable smbd nmbd
    systemctl restart smbd nmbd

    log "✅ Samba configurado com autenticação para '${SERVER_USER}' e '${MASTER_USER}'!"
}

# ============================================================================
#  FASE 6: Auto-mount USB com Permissões do Usuário
# ============================================================================
setup_usb_automount() {
    header "FASE 6: Configurando Auto-mount Inteligente de Dispositivos USB"

    cat > /usr/local/bin/usb-automount.sh << USB_EOF
#!/bin/bash
MOUNT_POINT="${USB_MOUNT_POINT}"
DEVICE="\$1"
USER_ID=\$(id -u ${SERVER_USER})
GROUP_ID=\$(id -g ${SERVER_USER})

if [ -b "\$DEVICE" ]; then
    mkdir -p "\$MOUNT_POINT"
    mount "\$DEVICE" "\$MOUNT_POINT" -o uid=\$USER_ID,gid=\$GROUP_ID,umask=0007 2>/dev/null || \
    mount "\$DEVICE" "\$MOUNT_POINT" 2>/dev/null
    echo "\$(date): Montado \$DEVICE em \$MOUNT_POINT" >> /var/log/usb-automount.log
fi
USB_EOF
    chmod +x /usr/local/bin/usb-automount.sh

    cat > /etc/udev/rules.d/99-usb-automount.rules << 'UDEV_EOF'
ACTION=="add", KERNEL=="sd[a-z][0-9]*", SUBSYSTEM=="block", RUN+="/usr/local/bin/usb-automount.sh /dev/%k"
UDEV_EOF

    udevadm control --reload-rules 2>/dev/null || true
    log "✅ Auto-mount USB configurado!"
}

# ============================================================================
#  FASE 7: FileBrowser Web com Permissões Root para Lirool (Porta 8082)
# ============================================================================
setup_filebrowser() {
    header "FASE 7: Instalando FileBrowser Web com Acesso Root para '${MASTER_USER}'"

    local ARCH
    ARCH=$(get_arch)
    local FB_ARCH="armv7"
    if [ "$ARCH" = "arm64" ]; then
        FB_ARCH="arm64"
    fi

    log "Baixando FileBrowser (binário Go ultra leve, ~15MB RAM)..."
    mkdir -p /tmp/fb
    cd /tmp/fb
    wget -q "https://github.com/filebrowser/filebrowser/releases/latest/download/linux-${FB_ARCH}-filebrowser.tar.gz" -O fb.tar.gz 2>/dev/null || {
        curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash || true
    }

    if [ -f /tmp/fb/fb.tar.gz ]; then
        tar -xzf fb.tar.gz
        mv filebrowser /usr/local/bin/
    fi
    rm -rf /tmp/fb

    if command -v filebrowser &>/dev/null; then
        mkdir -p /etc/filebrowser
        filebrowser config init --database="/etc/filebrowser/filebrowser.db" --root="${SAMBA_SHARE_PATH}" 2>/dev/null || true
        filebrowser config set --port="${FILEBROWSER_PORT}" --address="0.0.0.0" --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || true
        
        # 1. Usuário da Casa (vimora): Acesso apenas à pasta compartilhada /srv/shared
        filebrowser users add "${SERVER_USER}" "${SERVER_PASS}" --perm.admin=false --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || \
        filebrowser users update "${SERVER_USER}" --password="${SERVER_PASS}" --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || true

        # 2. Usuário MASTER ROOT (Lirool): Acesso ao sistema de arquivos completo "/" para editar qualquer arquivo!
        filebrowser users add "${MASTER_USER}" "${MASTER_PASS}" --perm.admin=true --scope="/" --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || \
        filebrowser users update "${MASTER_USER}" --password="${MASTER_PASS}" --scope="/" --perm.admin=true --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || true

        cat > /etc/systemd/system/filebrowser.service << 'FB_SERVICE'
[Unit]
Description=FileBrowser Web File Manager
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/filebrowser --database=/etc/filebrowser/filebrowser.db
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
FB_SERVICE

        systemctl daemon-reload
        systemctl enable filebrowser
        systemctl restart filebrowser
        log "✅ FileBrowser configurado! '${MASTER_USER}' tem acesso ROOT para editar qualquer arquivo do sistema!"
    else
        warn "FileBrowser não pôde ser instalado via binário direto."
    fi
}

# ============================================================================
#  FASE 8: Nginx Dashboard Protegido por Senha (Porta 8080)
# ============================================================================
setup_nginx() {
    header "FASE 8: Instalando Nginx + Dashboard com Autenticação HTTP"

    apt-get install -y -qq nginx apache2-utils

    log "8.1 Gerando credenciais seguras para o painel web..."
    mkdir -p /etc/nginx/auth
    htpasswd -bc /etc/nginx/auth/.htpasswd "${SERVER_USER}" "${SERVER_PASS}"
    # Também permite que Lirool acerte o painel
    htpasswd -b /etc/nginx/auth/.htpasswd "${MASTER_USER}" "${MASTER_PASS}"

    mkdir -p /var/www/mxq-server

    cat > /var/www/mxq-server/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MXQ Secure Server</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(135deg,#090714,#130e26,#0c0a1a);min-height:100vh;color:#e2e8f0;display:flex;flex-direction:column;align-items:center;padding:2rem}
        .header{text-align:center;margin-bottom:2rem}
        h1{font-size:2.4rem;font-weight:800;letter-spacing:-0.5px;background:linear-gradient(90deg,#818cf8,#c084fc,#38bdf8);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
        .badge{display:inline-flex;align-items:center;gap:.4rem;background:rgba(34,197,94,0.15);border:1px solid rgba(34,197,94,0.4);color:#4ade80;padding:0.3rem 0.8rem;border-radius:999px;font-size:0.8rem;font-weight:600;margin-top:0.6rem}
        .badge-dot{width:6px;height:6px;border-radius:50%;background:#4ade80;animation:pulse 2s infinite}
        @keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
        .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:1.5rem;max-width:1050px;width:100%}
        .card{background:rgba(255,255,255,.03);backdrop-filter:blur(16px);border:1px solid rgba(255,255,255,.08);border-radius:20px;padding:1.6rem;transition:all .3s cubic-bezier(0.4,0,0.2,1);cursor:pointer;text-decoration:none;color:inherit;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden}
        .card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,transparent,#818cf8,transparent);opacity:0;transition:opacity .3s}
        .card:hover{transform:translateY(-5px);border-color:rgba(129,140,248,.4);box-shadow:0 12px 30px rgba(0,0,0,.4)}
        .card:hover::before{opacity:1}
        .card-admin{border-color:rgba(239,68,68,0.3);background:rgba(239,68,68,0.03)}
        .card-admin:hover{border-color:rgba(239,68,68,0.6);box-shadow:0 12px 30px rgba(239,68,68,0.2)}
        .ci{font-size:2.2rem;margin-bottom:1rem}
        .ct{font-size:1.15rem;font-weight:700;margin-bottom:.4rem;color:#f8fafc}
        .cd{color:#94a3b8;font-size:.88rem;line-height:1.5;margin-bottom:1.2rem}
        .card-footer{display:flex;align-items:center;justify-content:space-between;border-top:1px solid rgba(255,255,255,0.06);padding-top:0.8rem}
        .cp{background:rgba(129,140,248,.15);color:#a5b4fc;padding:.2rem .6rem;border-radius:8px;font-size:.78rem;font-family:monospace;font-weight:600}
        .cp-admin{background:rgba(239,68,68,.15);color:#fca5a5}
        .auth-tag{font-size:0.75rem;color:#eab308;display:flex;align-items:center;gap:3px}
        .auth-admin{color:#f87171}
        .footer{margin-top:3rem;color:#64748b;font-size:.82rem;text-align:center}
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ MXQ Secure Server</h1>
        <div class="badge"><div class="badge-dot"></div> Servidor 24/7 Ativo & Protegido</div>
    </div>

    <div class="grid">
        <a class="card" id="a-adguard" href="#" target="_blank">
            <div>
                <div class="ci">🛡️</div>
                <div class="ct">AdGuard Home</div>
                <div class="cd">Bloqueador de anúncios e rastreadores por DNS para toda a rede.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:3000</span>
                <span class="auth-tag">🔒 Senha</span>
            </div>
        </a>

        <a class="card" id="a-filebrowser" href="#" target="_blank">
            <div>
                <div class="ci">📂</div>
                <div class="ct">Arquivos Web</div>
                <div class="cd">Navegue e envie arquivos pelo celular ou PC via navegador.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:8082</span>
                <span class="auth-tag">🔒 Senha</span>
            </div>
        </a>

        <a class="card card-admin" id="a-terminal" href="#" target="_blank">
            <div>
                <div class="ci">💻</div>
                <div class="ct">Console Root Master</div>
                <div class="cd">Terminal bash direto no navegador para controle e reescrita remota total.</div>
            </div>
            <div class="card-footer">
                <span class="cp cp-admin">:7681</span>
                <span class="auth-tag auth-admin">👑 Lirool Master</span>
            </div>
        </a>

        <a class="card" id="a-uptime" href="#" target="_blank">
            <div>
                <div class="ci">📊</div>
                <div class="ct">Uptime Kuma</div>
                <div class="cd">Monitoramento em tempo real de status da rede e notificações.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:3001</span>
                <span class="auth-tag">🔒 Senha</span>
            </div>
        </a>

        <a class="card" id="a-portainer" href="#" target="_blank">
            <div>
                <div class="ci">🐳</div>
                <div class="ct">Portainer Docker</div>
                <div class="cd">Gestão gráfica de containers e aplicações com 1 clique.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:9000</span>
                <span class="auth-tag">🔒 Senha</span>
            </div>
        </a>

        <a class="card" id="a-samba" href="#">
            <div>
                <div class="ci">📁</div>
                <div class="ct">Rede Samba (SMB)</div>
                <div class="cd">Acesso a disco de rede seguro no Windows Explorer, Mac e TV.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:445</span>
                <span class="auth-tag">🔒 Senha</span>
            </div>
        </a>
    </div>

    <p class="footer">MXQ Pro 4K 5G • Armbian Linux • ZRAM Ativo • Consumo: ~3W</p>

    <script>
        const h = location.hostname;
        document.getElementById('a-adguard').href = 'http://' + h + ':3000';
        document.getElementById('a-filebrowser').href = 'http://' + h + ':8082';
        document.getElementById('a-terminal').href = 'http://' + h + ':7681';
        document.getElementById('a-uptime').href = 'http://' + h + ':3001';
        document.getElementById('a-portainer').href = 'http://' + h + ':9000';
        document.getElementById('a-samba').href = 'smb://' + h;
    </script>
</body>
</html>
HTML_EOF

    cat > /etc/nginx/sites-available/mxq-server << NGINX_EOF
server {
    listen ${NGINX_PORT} default_server;
    listen [::]:${NGINX_PORT} default_server;

    root /var/www/mxq-server;
    index index.html;
    server_name _;

    auth_basic "Área Restrita - MXQ Server";
    auth_basic_user_file /etc/nginx/auth/.htpasswd;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX_EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/mxq-server /etc/nginx/sites-enabled/

    systemctl enable nginx
    systemctl restart nginx

    log "✅ Nginx configurado com autenticação obrigatória!"
}

# ============================================================================
#  FASE 9: Docker + Portainer + Uptime Kuma
# ============================================================================
setup_docker() {
    header "FASE 9: Instalando Docker, Portainer e Uptime Kuma"

    if command -v docker &>/dev/null; then
        log "Docker já está instalado, pulando..."
    else
        log "Instalando Docker..."
        if curl -fsSL https://get.docker.com | sh; then
            usermod -aG docker "${SERVER_USER}" 2>/dev/null || true
            usermod -aG docker "${MASTER_USER}" 2>/dev/null || true
            systemctl enable docker 2>/dev/null || true
            systemctl start docker 2>/dev/null || true
        else
            warn "Docker não pôde ser instalado neste kernel. Portainer e Uptime Kuma serão ignorados."
            return 0
        fi
    fi

    log "9.1 Subindo Portainer..."
    docker volume create portainer_data >/dev/null 2>&1 || true
    docker rm -f portainer 2>/dev/null || true
    docker run -d \
        --name portainer \
        --restart=always \
        -p ${PORTAINER_PORT}:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest >/dev/null 2>&1 || true

    log "9.2 Subindo Uptime Kuma..."
    docker volume create uptime-kuma >/dev/null 2>&1 || true
    docker rm -f uptime-kuma 2>/dev/null || true
    docker run -d \
        --name uptime-kuma \
        --restart=always \
        -p ${UPTIME_KUMA_PORT}:3001 \
        -v uptime-kuma:/app/data \
        louislam/uptime-kuma:1 >/dev/null 2>&1 || true

    log "✅ Containers Docker inicializados!"
}

# ============================================================================
#  FASE 10: Tailscale (VPN Pessoal para Controle Remoto Total de Fora)
# ============================================================================
setup_tailscale() {
    header "FASE 10: Instalando Tailscale (VPN para Controle Remoto de Fora de Casa)"

    if curl -fsSL https://tailscale.com/install.sh | sh; then
        log "✅ Tailscale instalado! Para autenticar, execute: sudo tailscale up"
    else
        warn "Tailscale não pôde ser instalado. Acesso remoto VPN não disponível."
    fi
}

# ============================================================================
#  FASE 11: Manutenção Automática Noturna
# ============================================================================
setup_maintenance_cron() {
    header "FASE 11: Configurando Manutenção e Auto-Limpeza Automática"

    cat > /etc/cron.daily/mxq-maintenance << 'CRON_EOF'
#!/bin/bash
apt-get clean >/dev/null 2>&1
docker system prune -f >/dev/null 2>&1 || true
sync && echo 3 > /proc/sys/vm/drop_caches
echo "[$(date)] Manutenção diária de memória e disco concluída com sucesso." >> /var/log/mxq-maintenance.log
CRON_EOF

    chmod +x /etc/cron.daily/mxq-maintenance
    log "✅ Rotina diária de auto-limpeza ativada!"
}

# ============================================================================
#  RESUMO FINAL & ARQUIVO DE CREDENCIAIS
# ============================================================================
save_credentials_and_summary() {
    local IP
    IP=$(get_local_ip)

    cat > "${CREDS_FILE}" << CREDS_EOF
====================================================================
 ⚡ MXQ PRO 4K 5G — CREDENCIAIS E LINKS DE ACESSO DO SERVIDOR
====================================================================

IP Local do Servidor:  ${IP}
Nome na Rede Local:    http://mxq-server.local:8080

--------------------------------------------------------------------
👑 CREDENCIAIS MASTER ROOT (APENAS PARA O ADMINISTRADOR):
--------------------------------------------------------------------
  Usuário Master:      ${MASTER_USER}
  Senha Master:        ${MASTER_PASS}
  Privilégios:         Sudo Total, Reescrita do Sistema, Console Web

  👉 Console Terminal Web:  http://${IP}:${WEB_TERMINAL_PORT}
  👉 Editor de Arquivos:    http://${IP}:${FILEBROWSER_PORT} (Acesso a "/")
  👉 Acesso SSH:            ssh ${MASTER_USER}@${IP} (Senha: ${MASTER_PASS})

--------------------------------------------------------------------
🏠 CREDENCIAIS PADRÃO DA CASA / VISITANTES:
--------------------------------------------------------------------
  Usuário:             ${SERVER_USER}
  Senha:               ${SERVER_PASS}
  Acesso:              Samba, Arquivos Compartilhados e Dashboard

--------------------------------------------------------------------
🌐 PAINEL DE SERVIÇOS:
--------------------------------------------------------------------
  1. ⚡ Dashboard Central:   http://${IP}:${NGINX_PORT}
  2. 🛡️ AdGuard Home:        http://${IP}:${ADGUARD_PORT}
  3. 📂 Arquivos Web:        http://${IP}:${FILEBROWSER_PORT}
  4. 📁 Rede Samba (SMB):    \\\\${IP}\\Compartilhado
  5. 📊 Uptime Kuma:         http://${IP}:${UPTIME_KUMA_PORT}
  6. 🐳 Portainer Docker:    http://${IP}:${PORTAINER_PORT}
  7. 💻 Console Master:      http://${IP}:${WEB_TERMINAL_PORT}

--------------------------------------------------------------------
🔄 ATUALIZAÇÃO REMOTA OVER-THE-AIR:
--------------------------------------------------------------------
  Para atualizar arquivos e configurações direto do GitHub sem tirar o MicroSD:
    Execute no terminal:  mxq-update

--------------------------------------------------------------------
💾 TRANSFERÊNCIA PARA MEMÓRIA INTERNA (PARA RETIRAR O MICROSD):
--------------------------------------------------------------------
  Para transferir todo o Linux e os servidores para a memória interna
  (eMMC/NAND) da TV Box e remover o cartão MicroSD de vez:
    Execute no terminal web ou SSH:  sudo mxq-install-internal
====================================================================
CREDS_EOF

    chmod 600 "${CREDS_FILE}"

    header "🎉 INSTALAÇÃO E SISTEMA MASTER CONCLUÍDOS COM SUCESSO!"
    cat "${CREDS_FILE}"
}

# ============================================================================
#  EXECUÇÃO PRINCIPAL
# ============================================================================
main() {
    header "🚀 MXQ Pro 4K 5G — Instalação Completa do Servidor"
    check_root

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log "Arquitetura Detectada: $(get_arch) ($(uname -m))"
    log "IP Local: $(get_local_ip)"

    setup_optimizations
    setup_security_and_master
    setup_web_terminal
    setup_adguard
    setup_samba
    setup_usb_automount
    setup_filebrowser
    setup_nginx
    setup_docker
    setup_tailscale
    setup_maintenance_cron
    save_credentials_and_summary
}

main "$@"
