# ⚡ Mini-Server — MXQ Pro 4K 5G (Edição Otimizada & Segura)

Transforme sua TV Box **MXQ Pro 4K 5G** em um **Mini Servidor Residencial 24/7** e **Bloqueador de Anúncios para toda a rede**, consumindo apenas ~3W de energia!

---

## 🎯 O que este projeto inclui?

### 🛡️ Serviços & Aplicações
1. **🛡️ AdGuard Home (`:3000`)**: Bloqueador de anúncios e rastreadores por DNS para toda a rede (celulares, Smart TVs, PCs), protegido por login/senha de administrador.
2. **📂 FileBrowser Web (`:8082`)**: Gerenciador de arquivos completo via navegador web (estilo Google Drive/OneDrive pessoal) com login e senha. Envie e baixe arquivos do HD/pendrive diretamente pelo celular ou PC sem instalar nada!
3. **📁 Servidor Samba / NAS (`:445`)**: Compartilhamento de arquivos em rede com autenticação obrigatória de usuário e senha (sem acesso anônimo desprotegido) e auto-montagem de drives USB.
4. **🌐 Dashboard Web Nginx (`:8080`)**: Painel centralizado elegante com tema escuro e protegido por autenticação HTTP (usuário e senha).
5. **📊 Uptime Kuma (`:3001`)**: Monitoramento contínuo de status e disponibilidade da sua rede e serviços com alertas.
6. **🐳 Docker + Portainer (`:9000`)**: Gerenciador gráfico de containers para instalar qualquer aplicação futura com 1 clique.
7. **🔒 Tailscale VPN**: Acesso remoto seguro de fora de casa sem precisar abrir portas no roteador.

### ⚙️ Otimizações de Hardware & Estabilidade (Feito para não travar!)
* **🚀 ZRAM com compressão lz4:** Expande a memória RAM útil da TV Box em até 60% comprimindo blocos em tempo real na memória. Evita travamentos por falta de RAM sem desgastar o cartão.
* **💾 Proteção de vida útil do MicroSD/eMMC:** Configuração de `noatime`, `nodiratime` e `commit=60` no sistema de arquivos, além de logs voláteis do `journald` em RAM para não desgastar o cartão de memória com escritas contínuas.
* **❄️ Controle Térmico (CPU Governor):** Ajuste automático de clock (`schedutil`/`ondemand`) para manter a placa fria mesmo sem ventoinha.
* **🐕 Hardware Watchdog Ativo:** Se a TV Box por ventura sofrer uma queda de tensão ou congelamento de kernel, o circuito de watchdog reinicializa o aparelho automaticamente em segundos.
* **🛡️ Fail2ban Anti-Intrusão:** Monitora e bloqueia automaticamente qualquer endereço IP que falhar várias tentativas de login no SSH ou nos serviços.
* **🧹 Auto-Manutenção Diária:** Script no `cron` limpa caches de pacotes, containers e imagens órfãs do Docker todos os dias na madrugada.

---

## 🔌 Modo Plug & Play (Sem Controle Remoto, Sem TV, Sem Teclado)

Se você **não tem o controle remoto** da TV Box e não quer lidar com telas de terminal interativas:

### 💡 Como funciona a mágica?
A TV Box inicializa o sistema operacional Linux (Armbian) diretamente pelo **slot de cartão MicroSD (TF Card)**. 

Ao gravar a imagem no cartão e rodar nosso script de preparação no computador, o cartão é pré-configurado com um **serviço autônomo de inicialização (`mxq-bootstrap`)**.

Assim que a box é ligada na tomada com o cabo de rede conectado:
1. Ela dá boot no Linux pelo MicroSD.
2. Solicita um endereço IP automaticamente ao seu roteador via DHCP.
3. Executa o instalador em segundo plano configurando as senhas e otimizações.
4. Ao finalizar, desliga o instalador e deixa todos os serviços ativos 24/7.

---

## 🛠️ Passo a Passo de Instalação

### Passo 1: Gravar o Armbian no MicroSD
1. Baixe a imagem do **Armbian Minimal (CLI/Bookworm)** para o SoC da sua placa (Rockchip RK322x, Amlogic S905x ou Allwinner H3/H616).
2. Grave no cartão MicroSD usando o [balenaEtcher](https://etcher.balena.io/) ou [Rufus](https://rufus.ie/).

### Passo 2: Pré-Configurar o Cartão (No Computador)
No seu computador Linux/WSL, monte a partição raiz (`rootfs`) do cartão MicroSD recém-gravado e execute:

```bash
git clone https://github.com/VituColombo0/Mini-Server.git
cd Mini-Server
sudo chmod +x *.sh

# Com credenciais padrão (admin / admin123):
sudo ./prepare_sd_card.sh /media/$USER/armbi_root

# OU definindo seu próprio usuário e senha:
sudo ./prepare_sd_card.sh /media/$USER/armbi_root seunome suasenha123
```
*(Substitua `/media/$USER/armbi_root` pelo caminho onde a partição do cartão foi montada)*.

### Passo 3: Ligar a TV Box
1. Insira o MicroSD na MXQ Pro 4K 5G.
2. Conecte o **cabo de rede (Ethernet)** vindo do roteador.
3. Plugue a fonte na **tomada**.
4. ☕ Aguarde de 10 a 15 minutos enquanto ela instala e otimiza tudo silenciosamente.

---

## 🖥️ Como Acessar os Serviços

Após o término da instalação, você pode acessar todos os serviços pelo navegador de qualquer celular ou PC conectado no mesmo Wi-Fi/rede:

| Serviço | URL de Acesso | Login Padrão | Descrição |
|---|---|---|---|
| **Painel Geral** | `http://mxq-server.local:8080` | `admin` / `admin123` | Dashboard unificado protegido por senha |
| **AdGuard Home** | `http://mxq-server.local:3000` | Definido no 1º acesso | Bloqueador de anúncios de rede |
| **FileBrowser (Web)** | `http://mxq-server.local:8082` | `admin` / `admin123` | Gerenciador de arquivos na nuvem |
| **Uptime Kuma** | `http://mxq-server.local:3001` | Definido no 1º acesso | Monitor de disponibilidade |
| **Portainer** | `http://mxq-server.local:9000` | Definido no 1º acesso | Gestão de Containers Docker |
| **Samba (Arquivos)** | `\\mxq-server.local\Compartilhado` | `admin` / `admin123` | Rede Windows/Mac/Android |

> **Dica:** Um arquivo com todas as senhas e links é salvo automaticamente na própria TV Box em `/root/server-credentials.txt` e na pasta de rede compartilhada `README_CREDENCIAIS.txt`.

---

## 💡 Não tenho controle e preciso mexer no Android primeiro?
Caso você ainda esteja com o Android original e precise abri-lo (por exemplo, para rodar o app AIDA64 e ver o chip):
* **Qualquer mouse USB comum de computador funciona na TV Box!**
* Basta plugar o mouse em uma das 4 portas USB da MXQ Pro: uma seta de ponteiro aparecerá na tela e você poderá navegar normalmente sem precisar do controle remoto infravermelho.

---

## 🛡️ Ativar o Bloqueador na Casa Toda
Para que celulares, Smart TVs e computadores fiquem sem anúncios automaticamente:
1. Acesse o painel do seu roteador Wi-Fi (geralmente `192.168.1.1` ou `192.168.0.1`).
2. Vá na seção **DHCP / Servidor DNS**.
3. Altere o **DNS Primário** para o endereço IP da TV Box (ex: `192.168.1.100`).
4. Pronto! Toda a rede passará a ter anúncios bloqueados na raiz.
