# Conectar o Make à central (sem código)

O Make vira o "roteador" da central: cada projeto dispara um webhook, e o
Make entrega no contato ou grupo certo do Signal. Você só monta módulos —
nenhuma linha de código.

## Cenário básico: um projeto → um destino

**1. Módulo `Webhooks → Custom webhook`**

- Crie o webhook (ex: `notificacao-projeto-a`) e copie a URL gerada.
- Essa URL é o que o Projeto A vai chamar quando quiser avisar algo.

**2. Módulo `HTTP → Make a request`** (logo depois do webhook)

| Campo | Valor |
|---|---|
| URL | `http://SEU-IP:8880/v2/send` |
| Method | `POST` |
| Headers | `Authorization` : `Bearer SUA_CHAVE` |
| Body type | `Raw` |
| Content type | `JSON (application/json)` |

Request content:

```json
{
  "message": "{{1.mensagem}}",
  "number": "+55NUMERO_DO_BOT",
  "recipients": ["group.ID_DO_GRUPO_DO_PROJETO_A"]
}
```

> `{{1.mensagem}}` é o campo `mensagem` vindo do webhook — mapeie pelo
> painel do Make. Em `recipients` use o grupo do projeto (pegue o id com
> `./grupos.sh` na VPS) ou um contato direto (`+5521988887777`).

**3. Teste**

```bash
curl -X POST 'https://hook.us1.make.com/SEU_WEBHOOK' \
  -H 'Content-Type: application/json' \
  -d '{"mensagem": "Primeiro aviso do Projeto A 🎉"}'
```

## Vários projetos em um cenário só (Router)

Se preferir um único webhook para tudo:

1. Os projetos enviam também um campo `projeto`:
   `{"projeto": "site", "mensagem": "..."}`
2. Depois do webhook, adicione um módulo **Router**.
3. Em cada rota, defina o filtro `projeto = site`, `projeto = app`, etc.
4. Cada rota tem seu módulo HTTP igual ao de cima, mudando só o
   `recipients` para o grupo daquele projeto.

## Ideias de gatilhos prontos no Make

Qualquer módulo de gatilho do Make pode terminar no módulo HTTP da central:

- **Gmail** → e-mail importante chegou → aviso no grupo
- **ClickUp** → tarefa mudou de status → aviso no grupo do projeto
- **Google Forms / Sheets** → lead novo → aviso na hora
- **Schedule** → resumo diário às 8h
