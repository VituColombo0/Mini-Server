#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Setup Completo: Mini Servidor + Bloqueador de Anúncios
#  
#  Executar como root após o primeiro boot do Armbian:
#    chmod +x setup_mxq_server.sh
#    sudo ./setup_mxq_server.sh
#
#  Este script instala e configura:
#    1. AdGuard Home (bloqueador de anúncios / DNS)
#    2. Samba (compartilhamento de arquivos)
#    3. Nginx (servidor web com dashboard)
#    4. Docker + Portainer (gerenciamento de containers)
#    5. Uptime Kuma (monitoramento)
#    6. Tailscale (VPN pessoal)
# ============================================================================

set -euo pipefail

# ── Cores para output ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ── Variáveis de configuração ──────────────────────────────────────────────
ADGUARD_PORT=3000
UPTIME_KUMA_PORT=3001
PORTAINER_PORT=9000
NGINX_PORT=8080
SAMBA_SHARE_PATH="/srv/shared"
USB_MOUNT_POINT="/mnt/usb"
LOG_FILE="/var/log/mxq-setup.log"

# ── Funções auxiliares ─────────────────────────────────────────────────────
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
#  FASE 1: Configuração Básica do Sistema
# ============================================================================
setup_system() {
    header "FASE 1: Configuração Básica do Sistema"

    log "Atualizando lista de pacotes..."
    apt-get update -qq

    log "Atualizando pacotes instalados..."
    apt-get upgrade -y -qq

    log "Instalando dependências básicas..."
    apt-get install -y -qq \
        curl wget git htop nano ufw unzip \
        ca-certificates gnupg lsb-release \
        ntfs-3g avahi-daemon net-tools jq 2>/dev/null || \
    apt-get install -y \
        curl wget git htop nano ufw unzip \
        ca-certificates gnupg \
        ntfs-3g avahi-daemon net-tools jq

    log "Configurando timezone para América/São Paulo..."
    timedatectl set-timezone America/Sao_Paulo 2>/dev/null || \
        ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

    log "Configurando hostname..."
    hostnamectl set-hostname mxq-server 2>/dev/null || \
        echo "mxq-server" > /etc/hostname

    log "✅ Sistema base configurado!"
}

# ============================================================================
#  FASE 2: Firewall Básico
# ============================================================================
setup_firewall() {
    header "FASE 2: Configurando Firewall (UFW)"

    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1

    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
    ufw allow 53/tcp comment 'DNS TCP' >/dev/null 2>&1
    ufw allow 53/udp comment 'DNS UDP' >/dev/null 2>&1
    ufw allow ${ADGUARD_PORT}/tcp comment 'AdGuard Home' >/dev/null 2>&1
    ufw allow 139/tcp comment 'Samba NetBIOS' >/dev/null 2>&1
    ufw allow 445/tcp comment 'Samba' >/dev/null 2>&1
    ufw allow ${NGINX_PORT}/tcp comment 'Nginx' >/dev/null 2>&1
    ufw allow ${UPTIME_KUMA_PORT}/tcp comment 'Uptime Kuma' >/dev/null 2>&1
    ufw allow ${PORTAINER_PORT}/tcp comment 'Portainer' >/dev/null 2>&1

    ufw --force enable >/dev/null 2>&1

    log "✅ Firewall configurado!"
}

# ============================================================================
#  FASE 3: AdGuard Home (Bloqueador de Anúncios)
# ============================================================================
setup_adguard() {
    header "FASE 3: Instalando AdGuard Home"

    local ARCH
    ARCH=$(get_arch)
    local AGH_URL="https://static.adtidy.org/adguardhome/release/AdGuardHome_linux_${ARCH}.tar.gz"

    log "Baixando AdGuard Home para ${ARCH}..."
    cd /tmp
    wget -q "${AGH_URL}" -O AdGuardHome.tar.gz

    log "Extraindo e instalando..."
    tar -xzf AdGuardHome.tar.gz
    cd AdGuardHome
    ./AdGuardHome -s install
    sleep 3

    rm -rf /tmp/AdGuardHome*

    log "✅ AdGuard Home instalado!"
    log "   Dashboard: http://$(get_local_ip):${ADGUARD_PORT}"
}

# ============================================================================
#  FASE 4: Samba (Compartilhamento de Arquivos)
# ============================================================================
setup_samba() {
    header "FASE 4: Instalando Samba"

    apt-get install -y -qq samba samba-common-bin

    mkdir -p "${SAMBA_SHARE_PATH}" "${USB_MOUNT_POINT}"
    chmod 0777 "${SAMBA_SHARE_PATH}"

    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true

    cat > /etc/samba/smb.conf << 'SAMBA_EOF'
[global]
   workgroup = WORKGROUP
   server string = MXQ Server
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no
   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384
   map to guest = Bad User
   usershare allow guests = yes

[Compartilhado]
   comment = Pasta Compartilhada MXQ Server
   path = /srv/shared
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0664
   directory mask = 0775
   force user = nobody
   force group = nogroup

[USB]
   comment = HD USB Externo
   path = /mnt/usb
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0664
   directory mask = 0775
   force user = nobody
   force group = nogroup
SAMBA_EOF

    systemctl enable smbd nmbd
    systemctl restart smbd nmbd

    log "✅ Samba instalado!"
}

# ============================================================================
#  FASE 5: Auto-mount USB
# ============================================================================
setup_usb_automount() {
    header "FASE 5: Configurando Auto-mount USB"

    cat > /usr/local/bin/usb-automount.sh << 'USB_EOF'
#!/bin/bash
MOUNT_POINT="/mnt/usb"
DEVICE="$1"
if [ -b "$DEVICE" ]; then
    mkdir -p "$MOUNT_POINT"
    mount "$DEVICE" "$MOUNT_POINT" -o uid=nobody,gid=nogroup,umask=0000 2>/dev/null || \
    mount "$DEVICE" "$MOUNT_POINT" 2>/dev/null
    echo "$(date): Mounted $DEVICE at $MOUNT_POINT" >> /var/log/usb-automount.log
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
#  FASE 6: Nginx (Servidor Web + Dashboard)
# ============================================================================
setup_nginx() {
    header "FASE 6: Instalando Nginx + Dashboard"

    apt-get install -y -qq nginx

    mkdir -p /var/www/mxq-server

    cat > /var/www/mxq-server/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MXQ Server</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(135deg,#0f0c29,#302b63,#24243e);min-height:100vh;color:#e0e0e0;display:flex;flex-direction:column;align-items:center;padding:2rem}
        h1{font-size:2.5rem;margin-bottom:.5rem;background:linear-gradient(90deg,#667eea,#764ba2);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
        .subtitle{color:#888;margin-bottom:2rem;font-size:1.1rem}
        .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1.5rem;max-width:900px;width:100%}
        .card{background:rgba(255,255,255,.05);backdrop-filter:blur(10px);border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:1.5rem;transition:all .3s;cursor:pointer;text-decoration:none;color:inherit;display:block}
        .card:hover{transform:translateY(-4px);border-color:rgba(102,126,234,.5);box-shadow:0 8px 32px rgba(102,126,234,.2)}
        .ci{font-size:2.5rem;margin-bottom:1rem}
        .ct{font-size:1.2rem;font-weight:600;margin-bottom:.5rem}
        .cd{color:#999;font-size:.9rem;line-height:1.5}
        .cp{display:inline-block;margin-top:.8rem;background:rgba(102,126,234,.2);color:#667eea;padding:.2rem .6rem;border-radius:8px;font-size:.8rem;font-family:monospace}
        .st{display:flex;align-items:center;gap:.5rem;margin-top:.8rem;font-size:.85rem}
        .sd{width:8px;height:8px;border-radius:50%;background:#4ade80;animation:p 2s infinite}
        @keyframes p{0%,100%{opacity:1}50%{opacity:.5}}
        .footer{margin-top:3rem;color:#555;font-size:.85rem}
    </style>
</head>
<body>
    <h1>⚡ MXQ Server</h1>
    <p class="subtitle">Mini Servidor + Bloqueador de Anúncios</p>
    <div class="grid">
        <a class="card" id="a1" href="#">
            <div class="ci">🛡️</div><div class="ct">AdGuard Home</div>
            <div class="cd">Bloqueador de anúncios DNS para toda a rede.</div>
            <span class="cp">:3000</span>
            <div class="st"><div class="sd"></div> Ativo</div>
        </a>
        <a class="card" id="a2" href="#">
            <div class="ci">📊</div><div class="ct">Uptime Kuma</div>
            <div class="cd">Monitor de disponibilidade dos serviços.</div>
            <span class="cp">:3001</span>
            <div class="st"><div class="sd"></div> Ativo</div>
        </a>
        <a class="card" id="a3" href="#">
            <div class="ci">🐳</div><div class="ct">Portainer</div>
            <div class="cd">Gerenciador visual de containers Docker.</div>
            <span class="cp">:9000</span>
            <div class="st"><div class="sd"></div> Ativo</div>
        </a>
        <a class="card" id="a4" href="#">
            <div class="ci">📁</div><div class="ct">Arquivos (Samba)</div>
            <div class="cd">Acesse arquivos compartilhados na rede.</div>
            <span class="cp">:445</span>
            <div class="st"><div class="sd"></div> Ativo</div>
        </a>
    </div>
    <p class="footer">MXQ Pro 4K 5G • Armbian Linux • 24/7</p>
    <script>
        const h=location.hostname;
        document.getElementById('a1').href='http://'+h+':3000';
        document.getElementById('a2').href='http://'+h+':3001';
        document.getElementById('a3').href='http://'+h+':9000';
        document.getElementById('a4').href='smb://'+h;
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
    location / { try_files \$uri \$uri/ =404; }
}
NGINX_EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/mxq-server /etc/nginx/sites-enabled/

    systemctl enable nginx
    systemctl restart nginx

    log "✅ Nginx + Dashboard instalado!"
}

# ============================================================================
#  FASE 7: Docker + Portainer + Uptime Kuma
# ============================================================================
setup_docker() {
    header "FASE 7: Instalando Docker"

    if command -v docker &>/dev/null; then
        log "Docker já instalado, pulando..."
    else
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "${SUDO_USER:-root}" 2>/dev/null || true
        systemctl enable docker
        systemctl start docker
    fi

    log "✅ Docker instalado!"
}

setup_portainer() {
    header "Instalando Portainer"

    docker volume create portainer_data
    docker run -d \
        --name portainer \
        --restart=always \
        -p ${PORTAINER_PORT}:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    log "✅ Portainer instalado!"
}

setup_uptime_kuma() {
    header "Instalando Uptime Kuma"

    docker volume create uptime-kuma
    docker run -d \
        --name uptime-kuma \
        --restart=always \
        -p ${UPTIME_KUMA_PORT}:3001 \
        -v uptime-kuma:/app/data \
        louislam/uptime-kuma:1

    log "✅ Uptime Kuma instalado!"
}

# ============================================================================
#  FASE 8: Tailscale (VPN)
# ============================================================================
setup_tailscale() {
    header "FASE 8: Instalando Tailscale"

    curl -fsSL https://tailscale.com/install.sh | sh

    log "✅ Tailscale instalado!"
    log "   Para ativar: sudo tailscale up"
    log "   Exit node:   sudo tailscale up --advertise-exit-node"
}

# ============================================================================
#  RESUMO FINAL
# ============================================================================
show_summary() {
    local IP
    IP=$(get_local_ip)

    header "🎉 INSTALAÇÃO COMPLETA!"

    echo -e "${BOLD}Seus serviços:${NC}"
    echo ""
    echo -e "  🛡️  AdGuard Home     →  ${CYAN}http://${IP}:${ADGUARD_PORT}${NC}"
    echo -e "  📁  Samba            →  ${CYAN}\\\\\\\\${IP}\\\\Compartilhado${NC}"
    echo -e "  🌐  Dashboard        →  ${CYAN}http://${IP}:${NGINX_PORT}${NC}"
    echo -e "  📊  Uptime Kuma      →  ${CYAN}http://${IP}:${UPTIME_KUMA_PORT}${NC}"
    echo -e "  🐳  Portainer        →  ${CYAN}http://${IP}:${PORTAINER_PORT}${NC}"
    echo -e "  🔒  Tailscale        →  ${YELLOW}sudo tailscale up${NC}"
    echo ""
    echo -e "${BOLD}Próximos passos:${NC}"
    echo -e "  1. Acesse ${CYAN}http://${IP}:${ADGUARD_PORT}${NC} — configure o AdGuard Home"
    echo -e "  2. No roteador, mude o DNS para ${CYAN}${IP}${NC}"
    echo -e "  3. Plugue um HD USB para compartilhar arquivos"
    echo -e "  4. Execute ${CYAN}sudo tailscale up${NC} para ativar a VPN"
    echo ""
    echo -e "${GREEN}${BOLD}✅ MXQ Server pronto! Consumo: ~3-4W${NC}"
}

# ── MAIN ───────────────────────────────────────────────────────────────────
main() {
    header "🚀 MXQ Pro 4K 5G — Setup Completo"
    check_root

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log "Arquitetura: $(get_arch) ($(uname -m))"
    log "IP local: $(get_local_ip)"

    setup_system
    setup_firewall
    setup_adguard
    setup_samba
    setup_usb_automount
    setup_nginx
    setup_docker
    setup_portainer
    setup_uptime_kuma
    setup_tailscale

    show_summary
}

main "$@"
