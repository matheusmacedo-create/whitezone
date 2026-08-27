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

- Uma VPS com Docker instalado
- Um número dedicado para o bot, com o app do Signal ativo num celular

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

> Se a VPS usa firewall ufw, libere a porta pública depois:
> `sudo ufw allow 8880`

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

## Segurança

- A chave de acesso (`API_TOKEN` no arquivo `.env`) é a senha da central —
  quem tem a chave consegue enviar mensagens pelo bot. Não commite o `.env`
  (já está no `.gitignore`).
- Vazou a chave? Troque o valor de `API_TOKEN` no `.env` e rode
  `docker compose up -d`. Atualize a chave nos lugares que enviam.
- A API do Signal em si nunca fica exposta na internet — só a porta 8880,
  que exige a chave.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `./grupos.sh` não mostra um grupo novo | Mande qualquer mensagem no grupo pelo celular e rode de novo |
| Mensagens pararam de sair | `docker compose ps` e `docker compose logs signal-api` na VPS |
| Bot aparece "desconectado" no celular | Rode `./instalar.sh` de novo para reconectar via QR |
| Página do QR não abre na instalação | `sudo ufw allow 8092` e atualize a página |

O celular do bot é o "aparelho principal" da conta — deixe o app instalado e
abra-o de vez em quando (o Signal desconecta aparelhos ligados a contas que
ficam muito tempo offline).

## Como funciona por dentro

Dois containers Docker (veja `docker-compose.yml`):

- [`signal-cli-rest-api`](https://github.com/bbernhard/signal-cli-rest-api) —
  o "Signal Desktop" do bot, conectado como aparelho secundário do número.
  Acessível só de dentro da VPS.
- [`secured-signal-api`](https://github.com/codeshelldev/secured-signal-api) —
  a porta de entrada pública (8880), que exige a chave de acesso antes de
  repassar qualquer envio.

Os dados da conta ficam na pasta `signal-cli-config/` (fora do git). Faça
backup dela se quiser migrar de VPS sem escanear o QR de novo.
