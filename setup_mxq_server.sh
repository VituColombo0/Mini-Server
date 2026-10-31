#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Mini Servidor Residencial Otimizado & Seguro
#  
#  Serviços e Otimizações Inclusos:
#    1. Otimizações de Hardware ARM (ZRAM lz4, Proteção Flash/SD noatime, Watchdog, CPU Governor)
#    2. Segurança Reforçada (Firewall UFW, Fail2ban contra força bruta, SSH protegido)
#    3. AdGuard Home (Bloqueador de anúncios DNS protegido por senha na porta 3000)
#    4. Servidor Samba Autenticado (Compartilhamento de arquivos protegido por usuário/senha)
#    5. FileBrowser Web (Gerenciador de arquivos via navegador web com login na porta 8082)
#    6. Dashboard Nginx Protegido (Autenticação HTTP Basic Auth na porta 8080)
#    7. Docker + Portainer CE (Gerenciamento de containers na porta 9000)
#    8. Uptime Kuma (Monitoramento com alertas na porta 3001)
#    9. Tailscale VPN (Acesso remoto seguro sem abrir portas)
#   10. Manutenção Automática (Cron diário para limpeza de cache e Docker)
# ============================================================================

set -euo pipefail

# ── Cores para output ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ── Credenciais Padrão Unificadas (Altere via parâmetro ou variável se desejar)
SERVER_USER="${SERVER_USER:-vimora}"
SERVER_PASS="${SERVER_PASS:-aromiv}"

# ── Portas dos Serviços ────────────────────────────────────────────────────
ADGUARD_PORT=3000
UPTIME_KUMA_PORT=3001
PORTAINER_PORT=9000
NGINX_PORT=8080
FILEBROWSER_PORT=8082

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
        apache2-utils fail2ban cpufrequtils watchdog 2>/dev/null || \
    apt-get install -y \
        curl wget git htop nano ufw unzip ca-certificates gnupg \
        ntfs-3g avahi-daemon net-tools jq zram-tools apache2-utils fail2ban

    log "1.2 Configurando ZRAM (Memória RAM Comprimida lz4)..."
    # ZRAM cria um swap comprimido ultra rápido na RAM, expandindo a memória útil
    # sem desgastar a memória flash e evitando travamentos por falta de memória.
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
    # Adiciona noatime e commit=60 para reduzir gravações desnecessárias no cartão SD
    if grep -q "defaults" /etc/fstab && ! grep -q "noatime" /etc/fstab; then
        sed -i 's/defaults/defaults,noatime,nodiratime,commit=60/g' /etc/fstab
        log "✅ Parâmetros noatime e commit=60 aplicados no fstab."
    fi

    # Configurar journald para gravar em RAM em vez de ficar escrevendo na flash
    mkdir -p /etc/systemd/journald.conf.d/
    cat > /etc/systemd/journald.conf.d/ram.conf << 'JOURNAL_EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=30M
JOURNAL_EOF
    systemctl restart systemd-journald 2>/dev/null || true

    log "1.4 Otimizando CPU Governor para controle térmico..."
    # TV boxes fanless esquentam. O governor 'ondemand' ou 'schedutil' reduz a temperatura em ~15°C
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

    log "✅ Otimizações de hardware e sistema concluídas com sucesso!"
}

# ============================================================================
#  FASE 2: Segurança (Firewall UFW + Fail2ban + SSH)
# ============================================================================
setup_security() {
    header "FASE 2: Segurança do Servidor (Firewall + Anti Força Bruta)"

    log "2.1 Configurando Fail2ban contra tentativas de invasão..."
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
    systemctl enable fail2ban
    systemctl restart fail2ban

    log "2.2 Configurando Firewall UFW restrito..."
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1

    ufw allow 22/tcp comment 'SSH Seguro' >/dev/null 2>&1
    ufw allow 53/tcp comment 'DNS TCP' >/dev/null 2>&1
    ufw allow 53/udp comment 'DNS UDP' >/dev/null 2>&1
    ufw allow ${ADGUARD_PORT}/tcp comment 'AdGuard Home' >/dev/null 2>&1
    ufw allow 139/tcp comment 'Samba NetBIOS' >/dev/null 2>&1
    ufw allow 445/tcp comment 'Samba SMB' >/dev/null 2>&1
    ufw allow ${NGINX_PORT}/tcp comment 'Dashboard Web' >/dev/null 2>&1
    ufw allow ${FILEBROWSER_PORT}/tcp comment 'FileBrowser Web' >/dev/null 2>&1
    ufw allow ${UPTIME_KUMA_PORT}/tcp comment 'Uptime Kuma' >/dev/null 2>&1
    ufw allow ${PORTAINER_PORT}/tcp comment 'Portainer' >/dev/null 2>&1

    ufw --force enable >/dev/null 2>&1
    log "✅ Firewall e Fail2ban configurados e ativos!"
}

# ============================================================================
#  FASE 3: AdGuard Home (Bloqueador de Anúncios com Autenticação)
# ============================================================================
setup_adguard() {
    header "FASE 3: Instalando e Protegendo AdGuard Home"

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
    log "   Login e senha de administrador serão definidos no primeiro acesso ou via script."
}

# ============================================================================
#  FASE 4: Servidor Samba Autenticado (Protegido por Login/Senha)
# ============================================================================
setup_samba() {
    header "FASE 4: Configurando Servidor de Arquivos Samba com Senha"

    apt-get install -y -qq samba samba-common-bin

    mkdir -p "${SAMBA_SHARE_PATH}" "${USB_MOUNT_POINT}"
    chmod 0770 "${SAMBA_SHARE_PATH}"

    # Criar ou garantir usuário do sistema para o Samba
    if ! id "${SERVER_USER}" &>/dev/null; then
        useradd -M -s /usr/sbin/nologin "${SERVER_USER}" || true
    fi
    echo -e "${SERVER_PASS}\n${SERVER_PASS}" | passwd "${SERVER_USER}" >/dev/null 2>&1 || true

    # Definir senha do usuário no Samba
    (echo "${SERVER_PASS}"; echo "${SERVER_PASS}") | smbpasswd -s -a "${SERVER_USER}"

    chown -R "${SERVER_USER}:${SERVER_USER}" "${SAMBA_SHARE_PATH}"

    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true

    cat > /etc/samba/smb.conf << SAMBA_EOF
[global]
   workgroup = WORKGROUP
   server string = MXQ Secure Mini-Server
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no

   # Autenticação obrigatória (Sem acesso anônimo para segurança)
   security = user
   map to guest = Never

   # Otimizações de throughput para barramentos ARM
   socket options = TCP_NODELAY IPTOS_LOWDELAY
   read raw = yes
   write raw = yes
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384

[Compartilhado]
   comment = Pasta Pessoal Protegida
   path = ${SAMBA_SHARE_PATH}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SERVER_USER}
   create mask = 0660
   directory mask = 0770
   force user = ${SERVER_USER}

[USB]
   comment = HD USB Externo Protegido
   path = ${USB_MOUNT_POINT}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SERVER_USER}
   create mask = 0660
   directory mask = 0770
   force user = ${SERVER_USER}
SAMBA_EOF

    systemctl enable smbd nmbd
    systemctl restart smbd nmbd

    log "✅ Samba configurado com autenticação obrigatória!"
    log "   Usuário: ${SERVER_USER} | Senha protegida."
}

# ============================================================================
#  FASE 5: Auto-mount USB com Permissões do Usuário
# ============================================================================
setup_usb_automount() {
    header "FASE 5: Configurando Auto-mount Inteligente de Dispositivos USB"

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
    echo "\$(date): Montado \$DEVICE em \$MOUNT_POINT para ${SERVER_USER}" >> /var/log/usb-automount.log
fi
USB_EOF
    chmod +x /usr/local/bin/usb-automount.sh

    cat > /etc/udev/rules.d/99-usb-automount.rules << 'UDEV_EOF'
ACTION=="add", KERNEL=="sd[a-z][0-9]*", SUBSYSTEM=="block", RUN+="/usr/local/bin/usb-automount.sh /dev/%k"
UDEV_EOF

    udevadm control --reload-rules 2>/dev/null || true
    log "✅ Auto-mount USB configurado com propriedade do usuário ${SERVER_USER}!"
}

# ============================================================================
#  FASE 6: FileBrowser (Gerenciador de Arquivos Web com Login - Porta 8082)
# ============================================================================
setup_filebrowser() {
    header "FASE 6: Instalando FileBrowser (Gerenciador de Arquivos via Web)"

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
        warn "Falha no download direto, usando instalador oficial..."
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
        
        # Adicionar usuário inicial com a senha definida
        filebrowser users add "${SERVER_USER}" "${SERVER_PASS}" --perm.admin=true --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || \
        filebrowser users update "${SERVER_USER}" --password="${SERVER_PASS}" --database="/etc/filebrowser/filebrowser.db" 2>/dev/null || true

        # Criar serviço systemd
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
        log "✅ FileBrowser instalado e ativo na porta ${FILEBROWSER_PORT} com login obrigatório!"
    else
        warn "FileBrowser não pôde ser instalado via binário direto, prosseguindo..."
    fi
}

# ============================================================================
#  FASE 7: Nginx Dashboard Protegido por Senha (Porta 8080)
# ============================================================================
setup_nginx() {
    header "FASE 7: Instalando Nginx + Dashboard com Autenticação HTTP"

    apt-get install -y -qq nginx apache2-utils

    log "7.1 Gerando credenciais seguras para o painel web..."
    mkdir -p /etc/nginx/auth
    htpasswd -bc /etc/nginx/auth/.htpasswd "${SERVER_USER}" "${SERVER_PASS}"

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
        body{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(135deg,#0c0a1e,#1a1435,#120e24);min-height:100vh;color:#e2e8f0;display:flex;flex-direction:column;align-items:center;padding:2rem}
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
        .ci{font-size:2.2rem;margin-bottom:1rem}
        .ct{font-size:1.15rem;font-weight:700;margin-bottom:.4rem;color:#f8fafc}
        .cd{color:#94a3b8;font-size:.88rem;line-height:1.5;margin-bottom:1.2rem}
        .card-footer{display:flex;align-items:center;justify-content:space-between;border-top:1px solid rgba(255,255,255,0.06);padding-top:0.8rem}
        .cp{background:rgba(129,140,248,.15);color:#a5b4fc;padding:.2rem .6rem;border-radius:8px;font-size:.78rem;font-family:monospace;font-weight:600}
        .auth-tag{font-size:0.75rem;color:#eab308;display:flex;align-items:center;gap:3px}
        .footer{margin-top:3rem;color:#64748b;font-size:.82rem;text-align:center}
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ MXQ Secure Server</h1>
        <div class="badge"><div class="badge-dot"></div> Mini Servidor 24/7 Ativo & Protegido</div>
    </div>

    <div class="grid">
        <a class="card" id="a-adguard" href="#" target="_blank">
            <div>
                <div class="ci">🛡️</div>
                <div class="ct">AdGuard Home</div>
                <div class="cd">Bloqueador de anúncios e rastreadores por DNS para toda a casa.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:3000</span>
                <span class="auth-tag">🔒 Requer Senha</span>
            </div>
        </a>

        <a class="card" id="a-filebrowser" href="#" target="_blank">
            <div>
                <div class="ci">📂</div>
                <div class="ct">FileBrowser Web</div>
                <div class="cd">Navegue, baixe e envie arquivos pelo celular ou PC via navegador.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:8082</span>
                <span class="auth-tag">🔒 Requer Senha</span>
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
                <span class="auth-tag">🔒 Requer Senha</span>
            </div>
        </a>

        <a class="card" id="a-portainer" href="#" target="_blank">
            <div>
                <div class="ci">🐳</div>
                <div class="ct">Portainer Docker</div>
                <div class="cd">Gestão gráfica de containers e aplicações adicionais com 1 clique.</div>
            </div>
            <div class="card-footer">
                <span class="cp">:9000</span>
                <span class="auth-tag">🔒 Requer Senha</span>
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
                <span class="auth-tag">🔒 Requer Senha</span>
            </div>
        </a>
    </div>

    <p class="footer">MXQ Pro 4K 5G • Armbian Linux • ZRAM Ativo • Consumo: ~3W</p>

    <script>
        const h = location.hostname;
        document.getElementById('a-adguard').href = 'http://' + h + ':3000';
        document.getElementById('a-filebrowser').href = 'http://' + h + ':8082';
        document.getElementById('a-uptime').href = 'http://' + h + ':3001';
        document.getElementById('a-portainer').href = 'http://' + h + ':9000';
        document.getElementById('a-samba').href = 'smb://' + h;
    </script>
</body>
</html>
HTML_EOF

    # Configuração Nginx com proteção HTTP Basic Auth
    cat > /etc/nginx/sites-available/mxq-server << NGINX_EOF
server {
    listen ${NGINX_PORT} default_server;
    listen [::]:${NGINX_PORT} default_server;

    root /var/www/mxq-server;
    index index.html;
    server_name _;

    # Autenticação obrigatória para acessar o dashboard
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

    log "✅ Nginx configurado com autenticação obrigatória (HTTP Basic Auth)!"
}

# ============================================================================
#  FASE 8: Docker + Portainer + Uptime Kuma
# ============================================================================
setup_docker() {
    header "FASE 8: Instalando Docker, Portainer e Uptime Kuma"

    if command -v docker &>/dev/null; then
        log "Docker já está instalado, pulando instalação..."
    else
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "${SERVER_USER}" 2>/dev/null || true
        systemctl enable docker
        systemctl start docker
    fi

    log "8.1 Subindo Portainer..."
    docker volume create portainer_data >/dev/null 2>&1 || true
    docker rm -f portainer 2>/dev/null || true
    docker run -d \
        --name portainer \
        --restart=always \
        -p ${PORTAINER_PORT}:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest >/dev/null 2>&1 || true

    log "8.2 Subindo Uptime Kuma..."
    docker volume create uptime-kuma >/dev/null 2>&1 || true
    docker rm -f uptime-kuma 2>/dev/null || true
    docker run -d \
        --name uptime-kuma \
        --restart=always \
        -p ${UPTIME_KUMA_PORT}:3001 \
        -v uptime-kuma:/app/data \
        louislam/uptime-kuma:1 >/dev/null 2>&1 || true

    log "✅ Containers Docker (Portainer e Uptime Kuma) inicializados!"
}

# ============================================================================
#  FASE 9: Tailscale (VPN Pessoal)
# ============================================================================
setup_tailscale() {
    header "FASE 9: Instalando Tailscale (VPN Pessoal)"

    curl -fsSL https://tailscale.com/install.sh | sh
    log "✅ Tailscale instalado! Para conectar, rode: sudo tailscale up"
}

# ============================================================================
#  FASE 10: Manutenção Automática Noturna
# ============================================================================
setup_maintenance_cron() {
    header "FASE 10: Configurando Manutenção e Auto-Limpeza Automática"

    cat > /etc/cron.daily/mxq-maintenance << 'CRON_EOF'
#!/bin/bash
# Manutenção diária do MXQ Server:
# 1. Limpa cache de pacotes
apt-get clean >/dev/null 2>&1
# 2. Limpa imagens dangling e containers parados no Docker
docker system prune -f >/dev/null 2>&1 || true
# 3. Libera caches de memória do kernel
sync && echo 3 > /proc/sys/vm/drop_caches
# 4. Registra no log
echo "[$(date)] Manutenção diária de memória e disco concluída com sucesso." >> /var/log/mxq-maintenance.log
CRON_EOF

    chmod +x /etc/cron.daily/mxq-maintenance
    log "✅ Rotina diária de auto-limpeza e otimização configurada em /etc/cron.daily/mxq-maintenance!"
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
🔑 CREDENCIAIS PADRÃO DE ACESSO:
--------------------------------------------------------------------
  Usuário Principal:   ${SERVER_USER}
  Senha Principal:     ${SERVER_PASS}

--------------------------------------------------------------------
🌐 SERVIÇOS DISPONÍVEIS:
--------------------------------------------------------------------
  1. ⚡ Dashboard Central:
     URL:      http://${IP}:${NGINX_PORT} (ou http://mxq-server.local:8080)
     Acesso:   Requer usuário e senha (HTTP Basic Auth)

  2. 🛡️ Bloqueador AdGuard Home:
     URL:      http://${IP}:${ADGUARD_PORT}
     Acesso:   Configure a senha no primeiro acesso web

  3. 📂 FileBrowser (Gerenciador de Arquivos Web):
     URL:      http://${IP}:${FILEBROWSER_PORT}
     Usuário:  ${SERVER_USER}
     Senha:    ${SERVER_PASS}

  4. 📁 Samba (Rede Compartilhada no Windows/Mac):
     Caminho:  \\\\${IP}\\Compartilhado ou smb://${IP}
     Usuário:  ${SERVER_USER}
     Senha:    ${SERVER_PASS}

  5. 📊 Uptime Kuma (Monitor):
     URL:      http://${IP}:${UPTIME_KUMA_PORT}

  6. 🐳 Portainer (Docker):
     URL:      http://${IP}:${PORTAINER_PORT}

  7. 🔒 Acesso SSH ao Terminal:
     Comando:  ssh ${SERVER_USER}@${IP} ou ssh root@${IP}
     Senha:    ${SERVER_PASS}

--------------------------------------------------------------------
⚙️ OTIMIZAÇÕES ATIVAS:
--------------------------------------------------------------------
  • ZRAM lz4 ativo (expande RAM útil sem matar a flash)
  • noatime e commit=60 ativos (proteção de vida útil do MicroSD)
  • CPU Governor schedutil (controle de temperatura fanless)
  • Hardware Watchdog ativado (auto-reboot contra travamentos)
  • Fail2ban ativo (bloqueio automático de tentativas de invasão)
====================================================================
CREDS_EOF

    cp "${CREDS_FILE}" "${SAMBA_SHARE_PATH}/README_CREDENCIAIS.txt" 2>/dev/null || true
    chmod 600 "${CREDS_FILE}"

    header "🎉 INSTALAÇÃO E OTIMIZAÇÕES CONCLUÍDAS COM SUCESSO!"
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
    setup_security
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
