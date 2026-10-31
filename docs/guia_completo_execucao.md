# 📖 Guia Completo: MXQ Pro 4K 5G → Mini Servidor + Bloqueador de Anúncios

> [!IMPORTANT]
> Este guia cobre **TODO o processo**, do começo ao fim.
> Tempo estimado: ~1 a 2 horas (incluindo downloads).

---

## 📋 O que você vai precisar

- [ ] **MXQ Pro 4K 5G** (funcionando com Android)
- [ ] **MicroSD card** de 8GB ou maior (de boa qualidade — SanDisk, Samsung, Kingston)
- [ ] **Leitor de MicroSD** para o seu PC
- [ ] **Cabo Ethernet** (recomendado — Wi-Fi pode falhar no primeiro boot)
- [ ] **Teclado USB** (para o primeiro boot)
- [ ] **TV/Monitor com HDMI** (para o setup inicial)
- [ ] **PC com Windows/Linux/Mac** (para gravar o SD card)
- [ ] *Opcional*: HD externo USB ou pendrive (para o NAS)

---

## ETAPA 1 — Identificar o Chip (SoC)

### Opção A: Pelo AIDA64 (sem abrir a caixa)
1. Ligue a MXQ Pro → conecte na TV → conecte na internet
2. Instale o app **AIDA64** pela Play Store
3. Abra e vá em **CPU** → anote o **SoC** (ex: `Rockchip RK3229`)

### Opção B: Abrindo a caixa
1. Desligue tudo
2. Remova os 4 parafusos da parte de baixo (podem estar sob os pés de borracha)
3. Procure o texto no chip quadrado grande (centro da placa)

### 🔍 Qual é o seu?

Anote qual SoC você tem e siga para a Etapa 2:

| Se o SoC for... | Família | Siga para... |
|-----------------|---------|--------------|
| RK3228A, RK3229, RK3228B | **Rockchip** | Etapa 2A |
| S905, S905W, S905X, S905L | **Amlogic** | Etapa 2B |
| H3, H616, H313 | **Allwinner** | Etapa 2C |

---

## ETAPA 2A — Download do Armbian (Rockchip RK322x)

### 1. Baixar o Multitool
O Multitool é um loader que facilita flashar o Armbian em boxes Rockchip.

- **Download**: Procure a release mais recente em:
  `https://github.com/paolosabatino/armbian-build/releases`
- Baixe o arquivo `multitool.img.xz`

### 2. Baixar o Armbian para RK322x
- Na mesma página de releases, baixe a imagem **Armbian** para `rk322x-box`
- Recomendo a versão **Bookworm CLI minimal** (sem desktop gráfico)
- Arquivo será algo como: `Armbian_*_Rk322x-box_bookworm_*.img.xz`

### 3. Gravar o Multitool no MicroSD
1. No PC, baixe o **balenaEtcher**: `https://etcher.balena.io/`
2. Insira o MicroSD no leitor
3. No Etcher: selecione `multitool.img.xz` → selecione o SD card → Flash!
4. Após o flash, **NÃO ejete o SD** ainda
5. Abra o SD card no explorador de arquivos
6. Encontre a pasta `/images/` e copie o arquivo `.img.xz` do Armbian para dentro dela
7. Ejete o SD card com segurança

### → Pule para a Etapa 3

---

## ETAPA 2B — Download do Armbian (Amlogic S905x)

### 1. Baixar o Armbian
- Acesse: `https://www.armbian.com/download/`
- Procure por **aml-s9xx-box** ou o modelo específico do seu SoC
- Baixe a versão **Bookworm CLI minimal**

### 2. Gravar no MicroSD
1. Baixe o **balenaEtcher**: `https://etcher.balena.io/`
2. No Etcher: selecione a imagem Armbian → selecione o SD card → Flash!

### 3. Preparar o boot
1. Após flashar, abra o SD card no explorador
2. Na pasta raiz, procure o arquivo `u-boot-*` correspondente ao seu SoC
3. Renomeie-o para `u-boot.ext` (siga as instruções do README se houver)
4. Ejete o SD card

### → Pule para a Etapa 3

---

## ETAPA 2C — Download do Armbian (Allwinner H3/H616)

### 1. Baixar o Armbian
- Acesse: `https://www.armbian.com/download/`
- Procure pela família **sunxi** ou pelo SoC específico
- Baixe a versão **Bookworm CLI minimal**

### 2. Gravar no MicroSD
- Mesmo procedimento da Etapa 2B

### → Pule para a Etapa 3

---

## ETAPA 3 — Primeiro Boot do Armbian

### Para Rockchip (com Multitool):
1. Insira o MicroSD na MXQ Pro (slot lateral)
2. Conecte: cabo Ethernet + teclado USB + HDMI na TV
3. **Conecte a alimentação** — deve bootar o Multitool automaticamente
4. Se não bootar, tente segurar o botão de **reset** (buraco pequeno com um palito) enquanto liga
5. No menu do Multitool:
   - Selecione **"Backup flash"** → faça backup do Android (segurança!)
   - Selecione **"Install Armbian"** ou **"Burn image to flash"**
   - Escolha a imagem do Armbian da pasta `/images/`
   - Aguarde a gravação terminar
6. Desligue, **remova o SD card**, e ligue novamente

### Para Amlogic:
1. Insira o MicroSD na MXQ Pro
2. Conecte: cabo Ethernet + teclado USB + HDMI na TV
3. **Com a box DESLIGADA**, use um palito no **botão AV/reset** (buraco pequeno na lateral)
4. **Segure o botão e conecte a alimentação** ao mesmo tempo
5. Após ~5 segundos, solte o botão
6. O Armbian deve bootar direto pelo SD card

### Primeiro login:
```
Login: root
Senha: 1234
```
O sistema vai pedir para:
1. Criar uma nova senha para root
2. Criar um usuário normal

### Configurar IP fixo (recomendado):
```bash
# Verificar o IP atual
ip addr show

# Configurar IP fixo via nmtui (interface gráfica no terminal)
sudo nmtui
# → Editar conexão → Ethernet → IPv4 → Manual
# → Endereço: 192.168.1.100/24 (ou o que fizer sentido na sua rede)
# → Gateway: 192.168.1.1 (IP do seu roteador)
# → DNS: 127.0.0.1 (vai ser o próprio AdGuard Home)
```

> [!TIP]
> Anote o IP que você configurou — você vai usar ele pra tudo daqui pra frente.

---

## ETAPA 4 — Transferir e Rodar os Scripts

### Opção A: Via SCP (do seu PC para a MXQ Pro)
```bash
# No seu PC, execute:
scp setup_mxq_server.sh configure_adguard_lists.sh root@IP_DA_MXQ:/root/
```

### Opção B: Via wget (baixar direto na MXQ Pro)
Se preferir, copie os scripts para um GitHub Gist ou pendrive USB.

### Opção C: Via pendrive USB
1. Copie os 2 arquivos `.sh` para um pendrive
2. Plugue na MXQ Pro
3. Monte e copie:
```bash
sudo mount /dev/sda1 /mnt/usb
cp /mnt/usb/*.sh /root/
```

### 🚀 Executar o setup principal:
```bash
# Na MXQ Pro (via SSH ou teclado):
cd /root
chmod +x setup_mxq_server.sh
sudo ./setup_mxq_server.sh
```

> [!WARNING]
> O script leva **15-30 minutos** dependendo da velocidade da internet.
> Não desligue a box durante a instalação!

Ao terminar, você verá um resumo com todos os endereços dos serviços.

---

## ETAPA 5 — Configurar o AdGuard Home

### 1. Acessar o Dashboard
No navegador do seu PC/celular, acesse:
```
http://IP_DA_MXQ:3000
```

### 2. Setup inicial
- Criar usuário e senha de administrador
- Manter a porta DNS como `53`
- Manter a porta web como `3000`

### 3. Adicionar listas de bloqueio BR
Rode o segundo script:
```bash
sudo ./configure_adguard_lists.sh IP_DA_MXQ admin SUA_SENHA
```

Isso vai adicionar automaticamente:
- ✅ 9 listas de bloqueio otimizadas (incluindo listas brasileiras)
- ✅ DNS upstream seguro (Cloudflare + Google via DoH)
- ✅ Whitelist protegendo bancos BR, Pix, gov.br
- ✅ Safe browsing ativado

---

## ETAPA 6 — Configurar o Roteador

Esta é a etapa que faz o bloqueio funcionar para **TODA a rede**.

### Na configuração do seu roteador:
1. Acesse o painel do roteador (geralmente `http://192.168.1.1`)
2. Vá em **DHCP** ou **Configurações de LAN/DNS**
3. Mude o **DNS Primário** para o **IP da MXQ Pro**
4. (Opcional) DNS Secundário: `1.1.1.1` (fallback se a MXQ cair)
5. Salve e reinicie o roteador

### Se não conseguir mudar no roteador:
Você pode mudar o DNS **manualmente em cada dispositivo**:
- **Windows**: Configurações → Rede → Alterar opções do adaptador → Propriedades → IPv4 → DNS
- **Android**: Wi-Fi → Configurações da rede → DNS privado → IP da MXQ Pro
- **iPhone**: Wi-Fi → ⓘ → Configurar DNS → Manual → IP da MXQ Pro

---

## ETAPA 7 — Verificação Final

### Testar o bloqueio de anúncios:
1. No celular/PC, acesse: `https://d3ward.github.io/toolz/adblock.html`
2. Deve mostrar **muitos bloqueios** (quanto mais verde, melhor!)
3. Teste sites como UOL, G1, YouTube — anúncios devem estar reduzidos

### Verificar todos os serviços:
```
🛡️  AdGuard Home     →  http://IP_DA_MXQ:3000
📁  Samba (Arquivos) →  \\IP_DA_MXQ\Compartilhado
🌐  Dashboard        →  http://IP_DA_MXQ:8080
📊  Uptime Kuma      →  http://IP_DA_MXQ:3001
🐳  Portainer        →  http://IP_DA_MXQ:9000
```

### Testar compartilhamento de arquivos:
- **Windows**: Abra o Explorador → digite `\\IP_DA_MXQ\Compartilhado`
- **Mac**: Finder → Ir → Conectar ao Servidor → `smb://IP_DA_MXQ`
- **Android**: Use o app **Cx File Explorer** → Rede → SMB

### Ativar VPN (opcional):
```bash
sudo tailscale up --advertise-exit-node
```

---

## 🔧 Troubleshooting

### A box não boota pelo SD card
- Tente outro MicroSD card (compatibilidade varia muito)
- Para Amlogic: segure o botão reset **antes** de ligar a alimentação
- Para Rockchip: verifique se o Multitool foi gravado corretamente

### Wi-Fi não funciona no Armbian
- **Use cabo Ethernet** — é mais estável e recomendado para servidor 24/7
- Muitos chips Wi-Fi dessas boxes têm drivers ruins no Linux
- Se precisar de Wi-Fi, compre um **dongle USB Wi-Fi** com chip RTL8811 (~R$25)

### Pouca RAM (1GB)
- Não instale Portainer (economia de ~40MB)
- Use Uptime Kuma via binário em vez de Docker
- O AdGuard Home + Samba + Nginx rodam bem com 512MB

### A box esquenta muito
- Abra a caixa e cole um **dissipador de calor** no SoC (~R$5)
- O consumo real é baixo (~3W), mas a ventilação da caixa original é péssima

---

## 💰 Custo Final

| Item | Custo estimado |
|------|---------------|
| MXQ Pro 4K 5G (já tem) | R$ 0 |
| MicroSD 16GB | ~R$ 20 |
| Cabo Ethernet | ~R$ 10 |
| Energia elétrica (3W 24/7) | ~R$ 0,80/mês |
| **Total** | **~R$ 30 + R$ 0,80/mês** |

Comparação: um Pi-hole dedicado (Raspberry Pi) custaria R$ 300-500.

---

> [!TIP]
> Quando tiver o SoC identificado, me avise aqui que eu refino o guia com os links de download exatos e instruções específicas para o seu chip!
