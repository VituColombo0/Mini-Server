# Mini-Server: MXQ Pro 4K 5G Headless Server

Transformação de TV Box baseadas em SoC ARM (Rockchip RK322x, Amlogic S905x ou Allwinner H3) em servidor doméstico autônomo 24/7 com consumo reduzido (~3W), bloqueador de anúncios em rede, NAS, VPN e orquestração de contêineres Docker.

[![OS: Armbian Minimal](https://img.shields.io/badge/OS-Armbian%20Debian%20Bookworm-red.svg)](https://www.armbian.com/)
[![Architecture: ARM](https://img.shields.io/badge/Architecture-ARMv7%20%2F%20ARM64-blue.svg)](https://github.com/VituColombo0/Mini-Server)
[![DNS: AdGuard Home](https://img.shields.io/badge/DNS-AdGuard%20Home-success.svg)](https://adguard.com/adguard-home.html)
[![Containers: Docker](https://img.shields.io/badge/Containers-Docker%20%2B%20Portainer-2496ED.svg)](https://www.docker.com/)
[![Mesh VPN: Tailscale](https://img.shields.io/badge/VPN-Tailscale-black.svg)](https://tailscale.com/)

---

## Arquitetura de Serviços

O sistema disponibiliza uma suíte integrada de utilitários de infraestrutura local:

```
┌─────────────────────────────────────────────────────────────┐
│                    TV Box MXQ Pro 4K                        │
│             Armbian Minimal (Linux Kernel LTS)              │
├─────────────────────────────────────────────────────────────┤
│  [ AdGuard Home :3000 ]  ── Bloqueio de anúncios por DNS    │
│  [ Dashboard Web :8080 ] ── Painel unificado (Nginx)        │
│  [ FileBrowser :8082 ]   ── Gerenciador web de arquivos     │
│  [ Samba / SMB :445 ]    ── Compartilhamento de rede local  │
│  [ Uptime Kuma :3001 ]   ── Monitoramento de integridade    │
│  [ Portainer :9000 ]     ── Painel de controle de Docker    │
│  [ Web Terminal :7681 ]  ── Console interativo (ttyd)       │
│  [ Tailscale VPN ]       ── Conexão remota externa segura   │
└─────────────────────────────────────────────────────────────┘
```

### Otimizações de Kernel e Resiliência de Hardware

A configuração inclui ajustes específicos para contornar limitações de memória e prolongar a durabilidade dos componentes:
- **ZRAM com Compressão LZ4:** Expande a memória RAM efetiva em até 60% por meio de compressão rápida em bloco, prevenindo *Out-Of-Memory* (OOM) em placas com 1GB de RAM.
- **Proteção do Armazenamento (Flash Wear Leveling):** Montagem do sistema com flags `noatime`, `nodiratime` e `commit=60`. O buffer do `systemd-journald` opera em memória volátil (`volatile`), reduzindo o ciclo contínuo de escritas em memórias MicroSD e eMMC baratas.
- **Governor de CPU Térmico:** Configuração dos governors `schedutil` ou `ondemand` para adequação dinâmica de clock, assegurando operação estável sem superaquecimento mesmo em gabinetes passivos sem cooler.
- **Hardware Watchdog:** Módulo de kernel ativo para forçar reinicialização automática do hardware caso ocorra congelamento de kernel ou microquedas de tensão.
- **Prevenção de Ataques (Fail2ban):** Bloqueio progressivo de endereços IP após tentativas repetidas de força bruta no SSH e nos serviços HTTP.
- **Manutenção Automatizada:** Rotinas no `cron` para limpeza diária de imagens órfãs do Docker e descarte de cache de pacotes APT.

---

## Modos de Instalação

### Instalação Headless (Sem TV, Sem Teclado e Sem Controle)

O processo de instalação automatizado roda a partir do cartão MicroSD sem necessidade de monitor ou teclado conectado à TV Box.

#### 1. Gravação da Imagem Base
1. Baixe o **Armbian Minimal (CLI)** correspondente ao processador da sua placa (ex.: RK322x, S905x ou H3).
2. Grave o arquivo `.img` em um cartão MicroSD (TF Card) Classe 10 ou A1 através do [balenaEtcher](https://etcher.balena.io/) ou [Rufus](https://rufus.ie/).

#### 2. Preparação do Cartão no Computador Host
No computador com Linux ou WSL, monte a partição raiz (`rootfs`) do cartão e aplique o script de inicialização autônoma:

```bash
git clone https://github.com/VituColombo0/Mini-Server.git
cd Mini-Server
sudo chmod +x *.sh

# Com credenciais padrão (admin / admin123):
sudo ./prepare_sd_card.sh /media/$USER/armbi_root

# Ou definindo usuário e senha customizados:
sudo ./prepare_sd_card.sh /media/$USER/armbi_root usuario senha123
```
*(Substitua `/media/$USER/armbi_root` pelo ponto de montagem real da partição no seu sistema).*

#### 3. Inicialização e Provisionamento
1. Insira o MicroSD na TV Box.
2. Conecte o cabo de rede Ethernet ao roteador.
3. Conecte a fonte de alimentação na tomada.
4. O serviço `mxq-bootstrap` efetuará a requisição DHCP, instalará os pacotes e configurará os serviços em segundo plano (processo dura entre 10 e 15 minutos).

---

## Mapeamento de Portas e Credenciais de Acesso

Ao término do provisionamento, todos os serviços estarão acessíveis na rede local via endereço IP atribuído ou mDNS (`mxq-server.local`):

### Painéis de Usuário

| Serviço | Porta / URL | Usuário Padrão | Finalidade |
| :--- | :--- | :--- | :--- |
| **Painel Geral** | `http://<IP>:8080` | `vimora` / `aromiv` | Dashboard unificado de navegação |
| **AdGuard Home** | `http://<IP>:3000` | Definido no 1º login | Bloqueador de anúncios e filtros de rede |
| **FileBrowser Web** | `http://<IP>:8082` | `vimora` / `aromiv` | Nuvem pessoal de arquivos e mídias USB |
| **Uptime Kuma** | `http://<IP>:3001` | Definido no 1º login | Monitoramento de serviços e alertas |
| **Portainer** | `http://<IP>:9000` | Definido no 1º login | Gestão de contêineres Docker |
| **Samba (NAS)** | `\\<IP>\Compartilhado` | `vimora` / `aromiv` | Compartilhamento SMB para Windows/Mac/Linux |

### Acesso Administrativo e Manutenção Remota

| Recurso | Método de Acesso | Credenciais | Operação |
| :--- | :--- | :--- | :--- |
| **Terminal Web (ttyd)** | `http://<IP>:7681` | `Lirool` / `vitubidi123` | Shell Bash interativo diretamente no navegador |
| **Editor de Arquivos Root** | `http://<IP>:8082` | `Lirool` / `vitubidi123` | Edição de arquivos do sistema (`/etc`, `/boot`) |
| **Acesso SSH** | `ssh Lirool@<IP>` (porta 22) | `Lirool` / `vitubidi123` | Sessão remota com permissão sudo total |
| **Atualização OTA** | Comando `mxq-update` | Terminal / SSH | Sincronização direta com o repositório GitHub |
| **Rede Remota** | Cliente Tailscale | Conta Pessoal | Acesso de fora da LAN sem encaminhamento de porta |

> Um registro completo com links e senhas é gerado no próprio dispositivo em `/root/server-credentials.txt` com restrição de permissão `chmod 600`.

---

## Armazenamento: MicroSD vs Memória Interna (eMMC/NAND)

### Opção 1: Operação Contínua via MicroSD (Recomendado)
- **Vantagem:** Inexistência de risco de inutilização (*brick*) da placa. Para restaurar o sistema Android original, basta remover o cartão e reiniciar o dispositivo.
- **Performance:** Cartões modernos de padrão A1/A2 oferecem taxas de leitura randômica superiores aos chips eMMC legados que equipam TV Boxes genéricas.

### Opção 2: Gravação na Memória Flash Interna
Se houver preferência por liberar o slot MicroSD após o término da configuração:
1. Conecte-se ao terminal web ou SSH e execute:
   ```bash
   sudo mxq-install-internal
   ```
2. O script identifica o subsistema correspondente (`armbian-install`, `install-aml.sh` ou `nand-sata-install`), formata a partição eMMC interna e migra os binários e o bootloader.
3. Desligue o dispositivo (`sudo poweroff`), retire o cartão MicroSD e religue na tomada.
*(Em chips Rockchip RK322x, o procedimento também pode ser realizado com o Rockchip Multitool selecionando "Burn image to eMMC/NAND").*

---

## Métricas de Consumo de Recursos

Medições práticas em operação estável sob o Armbian Minimal:

| Serviço / Componente | Consumo Real de RAM | Uso Médio de CPU em Repouso |
| :--- | :--- | :--- |
| **Armbian Minimal (Base)** | ~60 MB | < 1.0% |
| **AdGuard Home** | ~35 MB | < 0.5% |
| **FileBrowser Web** | ~15 MB | < 0.2% |
| **Serviço Samba (SMB)** | ~20 MB | < 0.5% |
| **Nginx Dashboard** | ~8 MB | < 0.1% |
| **Fail2ban** | ~12 MB | < 0.2% |
| **Uptime Kuma (Docker)** | ~60 MB | ~1.0% |
| **Portainer (Docker)** | ~35 MB | < 0.5% |
| **Total Estimado** | **~245 MB de RAM** | **~3% a 5% de CPU** |

---

## Configuração do DNS no Roteador

Para estender a filtragem de anúncios e telemetria a todos os dispositivos conectados à rede doméstica:
1. Acesse o painel de administração do seu roteador (frequentemente em `192.168.1.1` ou `192.168.0.1`).
2. Localize a seção **DHCP / Configurações de DNS**.
3. Defina o **DNS Primário (IPv4)** com o endereço IP fixo atribuído à TV Box.
4. Reinicie a conexão dos clientes para que recebam a nova tabela DHCP.

---

## Estrutura do Repositório

```text
Mini-Server/
├── autorun-headless.sh          # Script de execução autônoma pós-boot
├── configure_adguard_lists.sh   # Configuração de listas de bloqueio e filtros
├── prepare_sd_card.sh           # Utilitário para gravação e injeção do bootstrap no host
├── setup_mxq_server.sh          # Script mestre de provisionamento de serviços e kernel
├── systemd/                     # Unidades de serviço para inicialização
├── docs/                        # Documentações adicionais de suporte e pinouts
└── README.md                    # Documentação técnica do projeto
```

---

## Licença

Projeto desenvolvido para reaproveitamento de hardware e automação residencial. Código aberto para uso pessoal e comunitário.
