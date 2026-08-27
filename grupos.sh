#!/usr/bin/env bash
#
# Lista os grupos do Signal que o bot participa, com os IDs prontos
# para copiar e usar no campo "recipients" dos envios.
#
#     ./grupos.sh
#
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "Rode ./instalar.sh primeiro."; exit 1; }
set -a
. ./.env
set +a

# Processa as mensagens pendentes — é assim que o bot "fica sabendo"
# de grupos novos criados no celular.
curl -fs --max-time 30 "http://127.0.0.1:8091/v1/receive/${SIGNAL_NUMBER}?timeout=5" >/dev/null 2>&1 || true

resposta="$(curl -fs --max-time 30 "http://127.0.0.1:8091/v1/groups/${SIGNAL_NUMBER}")" \
  || { echo "Não consegui falar com a API. Os serviços estão de pé? Veja:  docker compose ps"; exit 1; }

if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$resposta" | python3 -c '
import json, sys
grupos = json.load(sys.stdin)
if not grupos:
    print()
    print("Nenhum grupo encontrado ainda.")
    print("Crie um grupo no celular do bot, mande qualquer mensagem nele")
    print("e rode ./grupos.sh de novo.")
else:
    print()
    for g in grupos:
        print("  Grupo:", g.get("name") or "(sem nome)")
        print("  id:   ", g.get("id"))
        print()
    print("Use o id no campo \"recipients\" do envio, no lugar do número.")
'
else
  printf '%s\n' "$resposta"
fi
