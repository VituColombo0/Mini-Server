# 🔍 Passo 1: Identificar o Chip da sua MXQ Pro 4K 5G

## O que fazer agora (leva ~3 minutos)

### 1. Ligar a MXQ Pro e conectar na TV
- Conecte o cabo HDMI na TV
- Conecte o cabo de alimentação
- Espere o Android carregar normalmente

### 2. Conectar na Internet
- Vá em **Configurações → Wi-Fi** e conecte na sua rede
- Ou conecte um cabo Ethernet (mais fácil)

### 3. Instalar o AIDA64
- Abra a **Google Play Store** (ou o app de loja que tiver)
- Pesquise por **"AIDA64"** e instale o app gratuito
- Se não tiver Play Store, baixe o APK:
  - No navegador da box, acesse: `https://www.aida64.com/downloads`
  - Baixe a versão Android (.apk)
  - Instale (pode precisar habilitar "fontes desconhecidas" nas configurações)

### 4. Abrir o AIDA64 e anotar estas informações

Abra o app e navegue até as seções abaixo. **Anote ou tire foto de tudo:**

#### 📱 Na aba "CPU":
- **SoC (System on Chip)** — Ex: `Rockchip RK3229`, `Amlogic S905W`, `Allwinner H3`
- **Arquitetura** — Ex: `ARMv7` (32-bit) ou `ARMv8` (64-bit)
- **Cores** — Ex: `4x ARM Cortex-A7 @ 1.2GHz`

#### 💾 Na aba "Memory":
- **Total RAM** — Ex: `1024 MB`, `2048 MB`
- **Tipo** — Ex: `DDR3`, `DDR4`

#### 📀 Na aba "Storage":
- **Armazenamento interno** — Ex: `8 GB`, `16 GB`
- **Tipo** — Ex: `eMMC`, `NAND`

#### 📡 Na aba "Network":
- **Wi-Fi chip** — Ex: `ESP8089`, `SSV6051`, `RTL8189`

---

## 📋 Template para copiar e preencher

Depois de verificar no AIDA64, me passe essas informações:

```
SoC/Processador: _______________
Arquitetura: _______________
Cores/Clock: _______________
RAM total: _______________
Storage: _______________
Wi-Fi chip: _______________
Código da placa (se abriu a caixa): _______________
```

---

## 🔄 Alternativa: Abrir a caixa

Se preferir verificar fisicamente (ou se o AIDA64 não mostrar info confiável):

1. **Desligue** a box e desconecte tudo
2. **Remova os 4 parafusos** na parte de baixo (podem estar sob os pés de borracha)
3. **Abra a tampa** com cuidado
4. **Procure textos impressos** na placa verde:
   - O nome do SoC geralmente está impresso no chip maior (quadrado preto no centro)
   - O modelo da placa está impresso na borda (ex: `MXQ_HX_V3.0`)

> [!WARNING]
> Abrir a caixa **NÃO invalida garantia** em TV boxes genéricas (elas não têm garantia formal). Mas tenha cuidado para não danificar os conectores dos cabos flat internos.

---

## ⏭️ Próximo passo

Assim que você me passar as informações do chip, eu vou:
1. ✅ Identificar a build correta do Armbian para sua box
2. ✅ Criar o guia completo de instalação do Linux
3. ✅ Montar os scripts de instalação dos serviços que você escolher
