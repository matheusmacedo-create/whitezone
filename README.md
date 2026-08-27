# Central de Notificações no Signal

Uma central que recebe avisos de **todos os seus projetos** (Make, GitHub,
sistemas próprios…) e entrega no **Signal** — direto no seu contato ou em um
grupo por projeto. Roda na sua própria VPS, sem mensalidade extra.

```
Projeto A ─┐
Make      ─┼──►  http://SUA-VPS:8880/v2/send  ──►  Signal do bot  ──►  você / grupos
Projeto B ─┘         (com chave de acesso)
```

Depois de instalada, **enviar uma notificação é só chamar uma URL** — de
qualquer lugar, sem tocar mais na VPS.

## O que você precisa

- Uma VPS com **Docker** instalado
  (não tem? `curl -fsSL https://get.docker.com | sh`)
- **git** na VPS (não tem? `sudo apt install -y git`)
- Um número dedicado para o bot, com o app do Signal ativo num celular

Os comandos deste guia são digitados **na VPS**, conectado por SSH.

## Instalação (uma única vez, ~10 minutos)

Na VPS:

```bash
git clone https://github.com/matheusmacedo-create/whitezone.git
cd whitezone
./instalar.sh
```

O instalador faz tudo sozinho e te guia no único passo manual: **escanear um
QR code** com o celular do bot (igual conectar o Signal Desktop). No final ele
envia uma mensagem de teste e mostra o endereço + chave de acesso da sua
central.

## Como enviar notificações

Qualquer projeto envia com uma chamada HTTP simples:

```bash
curl -X POST http://SEU-IP:8880/v2/send \
  -H 'Authorization: Bearer SUA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "🚀 Deploy do site concluído!",
    "number": "+55NUMERO_DO_BOT",
    "recipients": ["+5521988887777"]
  }'
```

- `message` — o texto do aviso (use `\n` para pular linha, emojis funcionam)
- `number` — o número do bot (sempre o mesmo)
- `recipients` — para quem vai: um **contato** (`+55...`) ou um **grupo**
  (`group.abc==`)
- `SEU-IP` e `SUA_CHAVE` — aparecem no resumo final do `./instalar.sh`
  (a chave também fica no arquivo `.env` da VPS)

Na primeira mensagem para um contato novo, o Signal mostra um "pedido de
mensagem" no celular da pessoa — é só aceitar uma vez.

Da própria VPS dá para testar com o atalho:

```bash
./enviar.sh +5521988887777 "funcionou!"
```

## Um grupo para cada projeto (recomendado conforme crescer)

1. No **celular do bot**, crie um grupo (ex: "🔔 Projeto A") e adicione quem
   deve receber os avisos.
2. Na VPS, rode `./grupos.sh` — ele lista os grupos com o `id` pronto para
   copiar.
3. Use esse `id` no campo `recipients` do envio. Só isso.

Assim cada projeto notifica seu próprio grupo, e você adiciona/remove pessoas
pelo próprio app do Signal, sem mexer em nada na VPS.

## Conectando as ferramentas

- **Make** (sem código): [exemplos/make.md](exemplos/make.md)
- **GitHub Actions** (aviso de deploy/erro): [exemplos/github-actions.yml](exemplos/github-actions.yml)
- **Qualquer outra coisa** (curl/HTTP): [exemplos/curl.md](exemplos/curl.md)

## Segurança — o que é protegido e o que não é

- A chave de acesso (`API_TOKEN` no arquivo `.env`) é a senha da central.
  Ela **só permite enviar mensagens** — os endpoints administrativos da API
  (ler mensagens recebidas, desregistrar a conta, etc.) são bloqueados na
  porta pública pela configuração incluída no `docker-compose.yml`.
- Vazou (ou desconfia que vazou) a chave? Troque o valor de `API_TOKEN` no
  `.env`, rode `docker compose up -d` e atualize a chave nos lugares que
  enviam. Não commite o `.env` (já está no `.gitignore`).
- **O tráfego para a porta 8880 é HTTP simples, sem criptografia**: a chave e
  o texto das notificações podem, em teoria, ser observados no caminho. Para
  avisos operacionais ("deploy concluído", "lead novo") isso costuma ser um
  risco aceitável; se for trafegar dados sensíveis, coloque HTTPS na frente
  (um proxy Caddy com um subdomínio resolve — peça ajuda ao Claude que ele
  monta).
- A API interna do Signal (sem senha) fica acessível **só de dentro da VPS**
  (porta local 8091). A única exceção é durante o pareamento por QR code: o
  instalador abre a porta 8092 por alguns minutos e **fecha sozinho** — mesmo
  se o script for interrompido no meio (Ctrl+C, queda de conexão).
- Observação sobre firewall: o Docker publica as portas direto no sistema,
  **passando por cima do ufw** na configuração padrão do Ubuntu/Debian. Quem
  realmente controla o acesso externo é o firewall do painel do seu provedor
  de VPS — mantenha a 8880 liberada lá e o resto fechado.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `./grupos.sh` não mostra um grupo novo | Mande qualquer mensagem no grupo pelo celular e rode de novo |
| Mensagens pararam de sair | `docker compose ps` e `docker compose logs signal-api` na VPS |
| Bot aparece "desconectado" no celular do bot | Rode `./instalar.sh reconectar` e escaneie o QR de novo |
| Teste do instalador falhou e os logs não ajudam | `./instalar.sh reconectar` resolve a maioria dos casos |
| Página do QR não abre na instalação | `sudo ufw allow 8092`, atualize a página (e depois `sudo ufw delete allow 8092`) |
| Make/projeto não alcança a central | Libere a porta 8880 (TCP) no firewall do painel do provedor |

O celular do bot é o "aparelho principal" da conta — deixe o app instalado e
abra-o de vez em quando (o Signal desconecta aparelhos ligados a contas que
ficam muito tempo offline). Se acontecer, `./instalar.sh reconectar` refaz o
pareamento em 2 minutos.

## Como funciona por dentro

Dois containers Docker (veja `docker-compose.yml`):

- [`signal-cli-rest-api`](https://github.com/bbernhard/signal-cli-rest-api) —
  o "Signal Desktop" do bot, conectado como aparelho secundário do número.
  Acessível só de dentro da VPS. Uma vez por dia ele sincroniza sozinho as
  novidades de grupos (o `./grupos.sh` também força essa sincronização na
  hora).
- [`secured-signal-api`](https://github.com/codeshelldev/secured-signal-api) —
  a porta de entrada pública (8880), que exige a chave de acesso e só deixa
  passar o envio de mensagens.

Os dados da conta ficam na pasta `signal-cli-config/` (fora do git). Faça
backup dela se quiser migrar de VPS sem escanear o QR de novo.
