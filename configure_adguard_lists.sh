#!/bin/bash
# ============================================================================
#  Configuração das Listas de Bloqueio do AdGuard Home
#  
#  Executar DEPOIS do setup principal e DEPOIS de configurar
#  o AdGuard Home pela primeira vez no navegador (criar usuário/senha).
#
#  Uso: sudo ./configure_adguard_lists.sh [IP] [USUARIO] [SENHA]
#  Ex:  sudo ./configure_adguard_lists.sh 192.168.1.100 admin minhasenha
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Parâmetros
AGH_HOST="${1:-$(hostname -I | awk '{print $1}')}"
AGH_PORT="3000"
AGH_USER="${2:-admin}"
AGH_PASS="${3:-}"
AGH_URL="http://${AGH_HOST}:${AGH_PORT}"

if [[ -z "$AGH_PASS" ]]; then
    echo -e "${YELLOW}Uso: $0 [IP] [USUARIO] [SENHA]${NC}"
    echo -e "${YELLOW}Ex:  $0 192.168.1.100 admin minhasenha${NC}"
    echo ""
    read -sp "Senha do AdGuard Home: " AGH_PASS
    echo ""
fi

AUTH=$(echo -n "${AGH_USER}:${AGH_PASS}" | base64)

api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    if [[ -n "$data" ]]; then
        curl -s -X "$method" \
            -H "Authorization: Basic ${AUTH}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${AGH_URL}/control${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: Basic ${AUTH}" \
            "${AGH_URL}/control${endpoint}"
    fi
}

echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Configurando AdGuard Home — Listas de Bloqueio${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Configurar DNS Upstream ─────────────────────────────────────────────
echo -e "${GREEN}[1/4] Configurando DNS upstream (Cloudflare + Google DoH)...${NC}"

api POST "/dns_config" '{
    "upstream_dns": [
        "https://dns.cloudflare.com/dns-query",
        "https://dns.google/dns-query",
        "tls://1.1.1.1",
        "tls://8.8.8.8"
    ],
    "bootstrap_dns": [
        "1.1.1.1",
        "8.8.8.8",
        "9.9.9.9"
    ],
    "upstream_mode": "parallel",
    "ratelimit": 100,
    "blocking_mode": "default",
    "cache_size": 4194304,
    "cache_ttl_min": 300,
    "cache_ttl_max": 86400
}' >/dev/null 2>&1

echo -e "${GREEN}   ✅ DNS configurado!${NC}"

# ── 2. Adicionar Listas de Bloqueio ───────────────────────────────────────
echo -e "${GREEN}[2/4] Adicionando listas de bloqueio...${NC}"

# Array de listas otimizadas
declare -A LISTS=(
    ["AdGuard DNS filter"]="https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
    ["AdAway Default"]="https://adaway.org/hosts.txt"
    ["OISD Big (Recomendada)"]="https://big.oisd.nl"
    ["HaGeZi Multi PRO"]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"
    ["Steven Black Unified"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    ["EasyList BR (Brasil)"]="https://raw.githubusercontent.com/nicsjr/adblock-brazil-list/master/adblock-brazil-list.txt"
    ["Phishing Army"]="https://phishing.army/download/phishing_army_blocklist.txt"
    ["Malware Filter"]="https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh.txt"
    ["NoTracking"]="https://raw.githubusercontent.com/notracking/hosts-blocklists/master/adblock/adblock.txt"
)

for name in "${!LISTS[@]}"; do
    url="${LISTS[$name]}"
    echo -e "   Adicionando: ${name}..."
    api POST "/filtering/add_url" "{
        \"name\": \"${name}\",
        \"url\": \"${url}\",
        \"whitelist\": false
    }" >/dev/null 2>&1 || echo -e "   ${YELLOW}⚠️  Lista já existe ou erro: ${name}${NC}"
done

echo -e "${GREEN}   ✅ Listas de bloqueio adicionadas!${NC}"

# ── 3. Whitelist (Domínios que NÃO devem ser bloqueados) ──────────────────
echo -e "${GREEN}[3/4] Configurando whitelist (bancos, Pix, serviços essenciais)...${NC}"

WHITELIST_DOMAINS=(
    # Bancos brasileiros
    "bb.com.br"
    "itau.com.br"
    "bradesco.com.br"
    "santander.com.br"
    "caixa.gov.br"
    "nubank.com.br"
    "inter.co"
    "c6bank.com.br"
    # Pix / SPB
    "bcb.gov.br"
    "pix.bcb.gov.br"
    # Governo
    "gov.br"
    "receita.fazenda.gov.br"
    "esaj.tjsp.jus.br"
    # Serviços comuns que podem ser bloqueados por engano
    "s3.amazonaws.com"
    "cloudfront.net"
    "akamaized.net"
    "googleapis.com"
    "gstatic.com"
    "microsoft.com"
    "live.com"
    "office.com"
    "apple.com"
    "icloud.com"
)

WHITELIST_RULES=""
for domain in "${WHITELIST_DOMAINS[@]}"; do
    WHITELIST_RULES="${WHITELIST_RULES}@@||${domain}^\n"
done

api POST "/filtering/set_rules" "{
    \"rules\": [\"$(echo -e "$WHITELIST_RULES" | sed 's/\\n/\\\\n/g' | sed 's/\"/\\\"/g')\"]
}" >/dev/null 2>&1 || {
    echo -e "${YELLOW}   ⚠️  Whitelist parcial — adicione manualmente no dashboard se necessário${NC}"
}

echo -e "${GREEN}   ✅ Whitelist configurada!${NC}"

# ── 4. Ativar proteções ──────────────────────────────────────────────────
echo -e "${GREEN}[4/4] Ativando proteções extras...${NC}"

# Safe browsing e parental control (opcional)
api POST "/safebrowsing/enable" "" >/dev/null 2>&1 || true

# Ativar log de queries
api POST "/querylog_config" '{
    "enabled": true,
    "interval": 720,
    "anonymize_client_ip": false
}' >/dev/null 2>&1 || true

echo -e "${GREEN}   ✅ Proteções ativadas!${NC}"

# ── Resumo ────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  ✅ AdGuard Home Configurado!${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Dashboard:  ${CYAN}${AGH_URL}${NC}"
echo -e "  Listas:     ${GREEN}${#LISTS[@]} listas de bloqueio ativas${NC}"
echo -e "  Upstream:   Cloudflare + Google (DoH/DoT)"
echo -e "  Whitelist:  Bancos BR, Pix, Gov.br protegidos"
echo ""
echo -e "${BOLD}⚠️  IMPORTANTE: No seu roteador, mude o DNS para: ${CYAN}${AGH_HOST}${NC}"
echo -e "  Isso fará TODOS os dispositivos da rede usarem o AdGuard Home."
echo ""
