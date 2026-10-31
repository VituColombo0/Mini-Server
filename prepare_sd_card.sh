#!/bin/bash
# ============================================================================
#  Preparador de MicroSD Headless para MXQ Pro 4K 5G
#  
#  Rode este script no seu PC (Linux ou WSL) após gravar o Armbian no SD Card.
#  Ele injeta os arquivos e configura a inicialização 100% automática,
#  eliminando a necessidade de monitor, teclado ou controle remoto na TV Box!
#  
#  Uso:
#    sudo ./prepare_sd_card.sh /caminho/do/ponto_de_montagem_rootfs
#  Exemplo:
#    sudo ./prepare_sd_card.sh /media/$USER/armbi_root
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

if [ "$#" -lt 1 ]; then
    echo -e "${YELLOW}Uso: sudo $0 <ponto_de_montagem_da_particao_rootfs>${NC}"
    echo "Exemplo: sudo $0 /media/$USER/armbi_root"
    exit 1
fi

TARGET_ROOTFS="$1"

if [ ! -d "${TARGET_ROOTFS}/etc" ] || [ ! -d "${TARGET_ROOTFS}/root" ]; then
    echo -e "${RED}Erro: '${TARGET_ROOTFS}' não parece ser a partição rootfs do Linux!${NC}"
    echo "Certifique-se de apontar para a partição raiz (onde ficam /etc, /root, /var)."
    exit 1
fi

echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD} Preparando MicroSD para Inicialização 100% Headless${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Copiar pasta do projeto para /root/Mini-Server no SD Card
echo -e "${GREEN}[1/4] Copiando arquivos do Mini-Server para o SD Card...${NC}"
mkdir -p "${TARGET_ROOTFS}/root/Mini-Server"
cp -r "${SCRIPT_DIR}/"* "${TARGET_ROOTFS}/root/Mini-Server/"
chmod +x "${TARGET_ROOTFS}/root/Mini-Server"/*.sh

# 2. Instalar e habilitar o serviço systemd de primeiro boot
echo -e "${GREEN}[2/4] Configurando serviço de bootstrap automático...${NC}"
cp "${SCRIPT_DIR}/systemd/mxq-bootstrap.service" "${TARGET_ROOTFS}/etc/systemd/system/"
mkdir -p "${TARGET_ROOTFS}/etc/systemd/system/multi-user.target.wants"
ln -sf "/etc/systemd/system/mxq-bootstrap.service" \
       "${TARGET_ROOTFS}/etc/systemd/system/multi-user.target.wants/mxq-bootstrap.service"

# 3. Desativar wizard interativo do Armbian (evita travar na tela de boas-vindas)
echo -e "${GREEN}[3/4] Desativando telas de configuração interativa...${NC}"
rm -f "${TARGET_ROOTFS}/root/.not_logged_in_yet" 2>/dev/null || true
touch "${TARGET_ROOTFS}/root/.first_run_completed"

# 4. Sincronizar gravações de disco
echo -e "${GREEN}[4/4] Sincronizando dados com o cartão...${NC}"
sync

echo ""
echo -e "${GREEN}${BOLD}✅ Pronto! O cartão MicroSD está configurado para Plug & Play!${NC}"
echo ""
echo -e "Agora você só precisa:"
echo -e "  1. Desmontar e retirar o MicroSD do computador"
echo -e "  2. Inserir o MicroSD na MXQ Pro 4K 5G"
echo -e "  3. Conectar o cabo de rede Ethernet do roteador à TV Box"
echo -e "  4. Ligar a TV Box na tomada!"
echo ""
echo -e "A TV Box vai ligar, pegar IP automaticamente e configurar todos os serviços."
echo -e "Aguarde cerca de 10 a 15 minutos e acesse no navegador:"
echo -e "  👉 ${CYAN}http://mxq-server.local:8080${NC} ou pelo IP do roteador."
echo ""
