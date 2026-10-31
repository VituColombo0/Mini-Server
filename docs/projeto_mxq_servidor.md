# 🚀 Projeto: MXQ Pro 4K 5G — Mini Servidor + Bloqueador de Anúncios

## Visão Geral

Transformar a TV box em um **appliance de rede 2-em-1** que roda 24/7 com ~3-4W de consumo:

```
┌──────────────────────────────────────────────────────────────┐
│                    MXQ Pro 4K 5G + Armbian                   │
│                                                              │
│  ┌─────────────────────────────────┐  ┌───────────────────┐  │
│  │  🛡️  BLOQUEADOR DE ANÚNCIOS     │  │  📁 MINI SERVIDOR │  │
│  │                                 │  │                   │  │
│  │  AdGuard Home                   │  │  Samba (NAS)      │  │
│  │  ├─ DNS Server (porta 53)       │  │  ├─ File sharing  │  │
│  │  ├─ Bloqueia ads em toda rede   │  │  ├─ HD USB ext.   │  │
│  │  ├─ Dashboard web (:3000)       │  │  └─ Porta 445     │  │
│  │  ├─ HTTPS/DoH (:443)           │  │                   │  │
│  │  └─ Logs e estatísticas         │  │  Tailscale VPN    │  │
│  │                                 │  │  └─ Acesso remoto │  │
│  └─────────────────────────────────┘  │                   │  │
│                                       │  Uptime Kuma      │  │
│  ┌─────────────────────────────────┐  │  ├─ Monitor :3001 │  │
│  │  🔧 GERENCIAMENTO               │  │  └─ Alertas       │  │
│  │                                 │  │                   │  │
│  │  Portainer (Docker UI)          │  │  Nginx (webserv.) │  │
│  │  └─ Dashboard web (:9000)       │  │  └─ Porta 80/8080 │  │
│  └─────────────────────────────────┘  └───────────────────┘  │
│                                                              │
│  🔌 Consumo: ~3-4W │ 🔇 Silencioso │ 🕐 24/7 │ 💰 R$0,80/mês │
└──────────────────────────────────────────────────────────────┘
```

---

## 📦 Stack de Serviços

| Serviço | Função | RAM estimada | Porta |
|---------|--------|-------------|-------|
| **AdGuard Home** | DNS + bloqueio de anúncios | ~30-50 MB | 53, 3000 |
| **Samba** | Compartilhamento de arquivos (NAS) | ~20-30 MB | 445 |
| **Nginx** | Servidor web estático | ~5-10 MB | 80, 8080 |
| **Tailscale** | VPN mesh / acesso remoto | ~15-20 MB | — |
| **Uptime Kuma** | Monitor de serviços | ~40-60 MB | 3001 |
| **Portainer** | UI para gerenciar Docker | ~30-40 MB | 9000 |
| **Total estimado** | | **~140-210 MB** | |

> [!NOTE]
> Mesmo com 1GB de RAM sobra espaço. Com 2GB fica super confortável.

---

## 🌐 Como funciona na rede

```
                    ┌─────────────┐
                    │  INTERNET   │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │   ROTEADOR  │
                    │  DNS ──────────► MXQ Pro (AdGuard Home)
                    └──┬───┬───┬──┘      │
                       │   │   │         ├─ Bloqueia ads
         ┌─────────────┤   │   │         ├─ Resolve DNS limpo
         │             │   │   │         └─ Retorna resposta
    ┌────┴────┐  ┌─────┴┐ ┌┴────┐
    │ Celular │  │ Note │ │ TV  │   ← Todos sem anúncios!
    └─────────┘  └──────┘ └─────┘
```

**Como ativar o bloqueio para toda a rede:**
- No roteador: mudar o DNS primário para o IP da MXQ Pro
- Resultado: **todos os dispositivos** da rede ficam sem anúncios automaticamente

---

## 📋 Roadmap de Execução

### Fase 1 — Preparação (hoje)
- [ ] Identificar o SoC com AIDA64
- [ ] Baixar Armbian correto
- [ ] Preparar MicroSD card (8GB+)
- [ ] Backup do Android original

### Fase 2 — Instalação do Linux
- [ ] Flashar Armbian via Multitool/SD
- [ ] Primeiro boot e configuração básica
- [ ] Configurar IP fixo na rede
- [ ] Atualizar sistema e instalar dependências

### Fase 3 — Serviços Core
- [ ] Instalar e configurar AdGuard Home
- [ ] Configurar listas de bloqueio BR + internacionais
- [ ] Instalar Samba + montar HD USB externo
- [ ] Instalar Nginx para servir páginas/arquivos

### Fase 4 — Extras e Polimento
- [ ] Instalar Tailscale (VPN)
- [ ] Instalar Uptime Kuma (monitoramento)
- [ ] Instalar Portainer (gerenciamento Docker)
- [ ] Configurar o roteador para usar DNS da MXQ Pro
- [ ] Testar tudo e ajustar

---

## ⏭️ Próximo Passo

> [!IMPORTANT]
> Para avançar, preciso saber o **SoC da sua box** (instale o AIDA64 no Android).
> Enquanto isso, vou preparar todos os scripts de instalação automatizados.
