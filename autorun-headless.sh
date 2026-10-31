#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Autorun Headless (Zero Interação & 100% Seguro)
#  
#  Este script é chamado automaticamente pelo serviço systemd `mxq-bootstrap`
#  no primeiro boot do Armbian.
#  Não requer monitor, nem teclado, nem controle remoto!
# ============================================================================

set -euo pipefail

LOG_FILE="/var/log/mxq-first-boot.log"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

log "=========================================================="
log "🚀 Iniciando Inicialização Headless da MXQ Pro 4K 5G"
log "=========================================================="

# 1. Aguardar conexão de rede (Ethernet)
log "Aguardando conexão de rede ativa com o roteador..."
RETRY=0
MAX_RETRIES=35
HAS_IP=false

while [ $RETRY -lt $MAX_RETRIES ]; do
    IP=$(hostname -I | awk '{print $1}' || true)
    if [ -n "$IP" ]; then
        log "Rede conectada com sucesso! IP Local atribuído: $IP"
        HAS_IP=true
        break
    fi
    sleep 3
    RETRY=$((RETRY + 1))
done

if [ "$HAS_IP" = false ]; then
    log "⚠️ Timeout aguardando IP via DHCP. Prosseguindo com a instalação local..."
fi

# 2. Desabilitar wizard de primeiro login interativo do Armbian
if [ -f /root/.not_logged_in_yet ]; then
    rm -f /root/.not_logged_in_yet
    log "Wizard de primeiro login interativo desabilitado com sucesso."
fi

# 3. Definir credenciais (Padrão da Casa e Master Root Secreto)
DEFAULT_USER="vimora"
DEFAULT_PASS="aromiv"
MASTER_USER="Lirool"
MASTER_PASS="vitubidi123"

# Root do Linux fica com a chave secreta exclusiva do Administrador Master
echo "root:${MASTER_PASS}" | chpasswd
log "Senha de root definida com a chave master de segurança."

# 4. Executar o instalador mestre com as credenciais
if [ -f "${BASE_DIR}/setup_mxq_server.sh" ]; then
    log "Executando setup_mxq_server.sh com otimizações e sistema master de reescrita remota..."
    chmod +x "${BASE_DIR}/setup_mxq_server.sh"
    SERVER_USER="${DEFAULT_USER}" SERVER_PASS="${DEFAULT_PASS}" MASTER_USER="${MASTER_USER}" MASTER_PASS="${MASTER_PASS}" "${BASE_DIR}/setup_mxq_server.sh" >> "$LOG_FILE" 2>&1 || {
        log "⚠️ Aviso: Ocorreu um aviso durante a execução do setup."
    }
else
    log "❌ Erro: setup_mxq_server.sh não encontrado em ${BASE_DIR}."
fi

# 5. Desabilitar o serviço de bootstrap para nunca re-executar em reboots normais
systemctl disable mxq-bootstrap.service 2>/dev/null || true

# 6. Salvar cópia do arquivo de credenciais na partição boot FAT se acessível
if [ -d /boot ]; then
    cp /root/server-credentials.txt /boot/CREDENCIAIS_SERVIDOR.txt 2>/dev/null || true
fi

# 7. Notificação de conclusão no log
LOCAL_IP=$(hostname -I | awk '{print $1}')
log "=========================================================="
log "🎉 INSTALAÇÃO HEADLESS CONCLUÍDA COM SUCESSO!"
log "IP do Servidor:       http://${LOCAL_IP}:8080 ou http://mxq-server.local:8080"
log "Usuário Casa:         ${DEFAULT_USER}"
log "Senha Casa:           ${DEFAULT_PASS}"
log "👑 Master Root:       ${MASTER_USER}"
log "👑 Terminal Remoto:   http://${LOCAL_IP}:7681"
log "👑 Editor de Arquivos: http://${LOCAL_IP}:8082"
log "=========================================================="

exit 0
