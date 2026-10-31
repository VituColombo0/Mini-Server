# ⚡ Mini-Server — MXQ Pro 4K 5G

Transforme sua TV Box **MXQ Pro 4K 5G** em um **Mini Servidor Residencial 24/7** e **Bloqueador de Anúncios para toda a rede**, consumindo apenas ~3W de energia!

---

## 🎯 O que este projeto faz?

Ao inicializar, a TV Box instala e disponibiliza automaticamente:

1. **🛡️ AdGuard Home (`:3000`)**: Bloqueador de anúncios e rastreadores por DNS para toda a rede (celulares, TVs, PCs).
2. **📁 Servidor de Arquivos Samba / NAS (`:445`)**: Compartilhamento de arquivos em rede com auto-montagem de HDs/pendrives USB em `/mnt/usb`.
3. **🌐 Dashboard Web Nginx (`:8080`)**: Painel centralizado elegante com links rápidos para todos os serviços locais.
4. **📊 Uptime Kuma (`:3001`)**: Monitoramento contínuo de status e disponibilidade da sua rede e serviços com alertas.
5. **🐳 Docker + Portainer (`:9000`)**: Gerenciador gráfico de containers para instalar qualquer aplicação futura com 1 clique.
6. **🔒 Tailscale VPN**: Acesso remoto seguro de fora de casa sem precisar abrir portas no roteador.

---

## 🔌 Modo Plug & Play (Sem Controle Remoto, Sem TV, Sem Teclado)

Se você **não tem o controle remoto** da TV Box e não quer lidar com telas de terminal interativas:

### 💡 Como funciona a mágica?
A TV Box inicializa o sistema operacional Linux (Armbian) diretamente pelo **slot de cartão MicroSD (TF Card)**. 

Ao gravar a imagem no cartão e rodar nosso script de preparação no computador, o cartão é pré-configurado com um **serviço autônomo de inicialização (`mxq-bootstrap`)**.

Assim que a box é ligada na tomada com o cabo de rede conectado:
1. Ela dá boot no Linux pelo MicroSD.
2. Solicita um endereço IP automaticamente ao seu roteador via DHCP.
3. Executa o `autorun-headless.sh` em segundo plano.
4. Baixa e configura todos os serviços sem intervenção manual.

---

## 🛠️ Passo a Passo Rápido

### Passo 1: Gravar o Armbian no MicroSD
1. Baixe a imagem do **Armbian Minimal (CLI/Bookworm)** para o SoC da sua placa (Rockchip RK322x, Amlogic S905x ou Allwinner H3/H616).
2. Grave no cartão MicroSD usando o [balenaEtcher](https://etcher.balena.io/) ou [Rufus](https://rufus.ie/).

### Passo 2: Pré-Configurar o Cartão (No Computador)
No seu computador Linux/WSL, monte a partição raiz (`rootfs`) do cartão MicroSD recém-gravado e execute:

```bash
git clone https://github.com/VituColombo0/Mini-Server.git
cd Mini-Server
sudo chmod +x *.sh
sudo ./prepare_sd_card.sh /media/$USER/armbi_root
```
*(Substitua `/media/$USER/armbi_root` pelo caminho onde a partição do cartão foi montada)*.

### Passo 3: Ligar a TV Box
1. Insira o MicroSD na MXQ Pro 4K 5G.
2. Conecte o **cabo de rede (Ethernet)** vindo do roteador.
3. Plugue a fonte na **tomada**.
4. ☕ Aguarde de 10 a 15 minutos enquanto ela instala tudo silenciosamente.

---

## 🖥️ Como Acessar os Serviços

Após o término da instalação, você pode acessar todos os serviços pelo navegador de qualquer celular ou PC conectado no mesmo Wi-Fi/rede:

| Serviço | URL de Acesso | Descrição |
|---|---|---|
| **Painel Geral** | `http://mxq-server.local:8080` | Dashboard unificado |
| **AdGuard Home** | `http://mxq-server.local:3000` | Painel de bloqueio de anúncios |
| **Uptime Kuma** | `http://mxq-server.local:3001` | Monitor de disponibilidade |
| **Portainer** | `http://mxq-server.local:9000` | Gestão de Containers Docker |
| **Samba (Arquivos)** | `\\mxq-server.local\Compartilhado` | Rede Windows/Mac/Android |

> **Dica:** Se `mxq-server.local` não resolver pelo seu roteador, olhe na lista de clientes do seu roteador qual IP foi atribuído à box (ex: `192.168.1.150`) e acesse usando o IP.

---

## 💡 Não tenho controle e preciso mexer no Android primeiro?
Caso você ainda esteja com o Android original e precise abri-lo (por exemplo, para rodar o app AIDA64 e ver o chip):
- **Qualquer mouse USB comum de computador funciona na TV Box!**
- Basta plugar o mouse em uma das 4 portas USB da MXQ Pro: uma seta de ponteiro aparecerá na tela e você poderá navegar normalmente sem precisar do controle remoto infravermelho.

---

## 📁 Estrutura do Repositório

```
Mini-Server/
├── setup_mxq_server.sh         # Script mestre de instalação de todos os serviços
├── configure_adguard_lists.sh  # Script de configuração das listas BR e DNS seguro
├── autorun-headless.sh         # Script autônomo executado no primeiro boot headless
├── prepare_sd_card.sh          # Injetor no cartão SD feito para rodar no PC
├── systemd/
│   └── mxq-bootstrap.service   # Serviço systemd de disparo no primeiro boot
└── docs/                       # Guias e manuais complementares
```

---

## 🛡️ Segurança e Dicas
- **Senha padrão de root criada:** `admin123` (altere via SSH com `passwd` se desejar).
- **Consumo elétrico:** ~2 a 4 Watts (menos de R$ 1,00 por mês na conta de luz).
- Para ativar o bloqueio de anúncios na casa inteira, acesse a página do seu roteador Wi-Fi e altere o **DNS Primário** para o IP da TV Box!
