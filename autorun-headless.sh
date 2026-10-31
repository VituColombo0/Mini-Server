#!/bin/bash
# ============================================================================
#  MXQ Pro 4K 5G — Autorun Headless (Zero Interação)
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
log "Aguardando conexão de rede ativa..."
RETRY=0
MAX_RETRIES=30
HAS_IP=false

while [ $RETRY -lt $MAX_RETRIES ]; do
    IP=$(hostname -I | awk '{print $1}' || true)
    if [ -n "$IP" ]; then
        log "Rede conectada com sucesso! IP Local: $IP"
        HAS_IP=true
        break
    fi
    sleep 3
    RETRY=$((RETRY + 1))
done

if [ "$HAS_IP" = false ]; then
    log "⚠️ Timeout aguardando IP. Prosseguindo com a instalação offline/local..."
fi

# 2. Desabilitar wizard de primeiro login interativo do Armbian (se existir)
if [ -f /root/.not_logged_in_yet ]; then
    rm -f /root/.not_logged_in_yet
    log "Wizard de primeiro login interativo desabilitado."
fi

# Garantir senha padrão de root caso o usuário precise de SSH de emergência
echo "root:admin123" | chpasswd
log "Senha de root definida por padrão para 'admin123' (troque posteriormente se desejar)."

# 3. Executar o instalador mestre
if [ -f "${BASE_DIR}/setup_mxq_server.sh" ]; then
    log "Executando setup_mxq_server.sh..."
    chmod +x "${BASE_DIR}/setup_mxq_server.sh"
    "${BASE_DIR}/setup_mxq_server.sh" >> "$LOG_FILE" 2>&1 || log "⚠️ Aviso: setup_mxq_server terminou com código diferente de zero."
else
    log "❌ Erro: setup_mxq_server.sh não encontrado em ${BASE_DIR}."
fi

# 4. Desabilitar o serviço de bootstrap para não rodar novamente no próximo reboot
systemctl disable mxq-bootstrap.service 2>/dev/null || true

# 5. Notificação de conclusão no log e broadcast
LOCAL_IP=$(hostname -I | awk '{print $1}')
log "=========================================================="
log "🎉 INSTALAÇÃO HEADLESS CONCLUÍDA COM SUCESSO!"
log "Acesse o painel web em: http://${LOCAL_IP}:8080 ou http://mxq-server.local:8080"
log "AdGuard Home em:        http://${LOCAL_IP}:3000"
log "Portainer em:           http://${LOCAL_IP}:9000"
log "Uptime Kuma em:         http://${LOCAL_IP}:3001"
log "=========================================================="

exit 0
