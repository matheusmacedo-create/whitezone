# Enviar de qualquer lugar (curl / HTTP)

Tudo é a mesma chamada — muda só o `recipients`. Substitua `SEU-IP`,
`SUA_CHAVE` e os números pelos seus (a chave está no `.env` da VPS e no
resumo final do `./instalar.sh`).

## Para um contato

```bash
curl -X POST http://SEU-IP:8880/v2/send \
  -H 'Authorization: Bearer SUA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "🔔 Lead novo no site!",
    "number": "+55NUMERO_DO_BOT",
    "recipients": ["+5521988887777"]
  }'
```

## Para um grupo (um por projeto)

```bash
curl -X POST http://SEU-IP:8880/v2/send \
  -H 'Authorization: Bearer SUA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "🚀 Projeto A: deploy concluído",
    "number": "+55NUMERO_DO_BOT",
    "recipients": ["group.COLE_AQUI_O_ID_DO_GRUPO"]
  }'
```

> O id do grupo vem do `./grupos.sh` na VPS. Ele começa com `group.`.

## Para várias pessoas de uma vez

```json
"recipients": ["+5521988887777", "+5521977776666"]
```

## Mensagem com várias linhas

Use `\n` dentro do texto:

```json
"message": "🔴 ERRO no servidor\nProjeto: site\nHora: 14:32\nDetalhe: banco fora do ar"
```

## De dentro de Python / Node

**Python**

```python
import requests

requests.post(
    "http://SEU-IP:8880/v2/send",
    headers={"Authorization": "Bearer SUA_CHAVE"},
    json={
        "message": "🔔 Aviso do sistema",
        "number": "+55NUMERO_DO_BOT",
        "recipients": ["group.ID_DO_GRUPO"],
    },
    timeout=30,
)
```

**Node.js**

```js
await fetch("http://SEU-IP:8880/v2/send", {
  method: "POST",
  headers: {
    Authorization: "Bearer SUA_CHAVE",
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    message: "🔔 Aviso do sistema",
    number: "+55NUMERO_DO_BOT",
    recipients: ["group.ID_DO_GRUPO"],
  }),
});
```
