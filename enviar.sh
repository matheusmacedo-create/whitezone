#!/usr/bin/env bash
#
# Envia uma notificação pela central, direto da VPS.
#
#     ./enviar.sh DESTINO "sua mensagem"
#
# DESTINO pode ser:
#   • um contato:  +5521988887777
#   • um grupo:    group.abc123==   (pegue o id com ./grupos.sh)
#
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "Rode ./instalar.sh primeiro."; exit 1; }
set -a
. ./.env
set +a

if [ $# -lt 2 ]; then
  echo 'Uso: ./enviar.sh DESTINO "sua mensagem"'
  echo '     DESTINO = +5521988887777 (contato) ou group.abc== (grupo, veja ./grupos.sh)'
  exit 1
fi

command -v python3 >/dev/null 2>&1 \
  || { echo "Este script precisa do python3. Instale com:  sudo apt install -y python3"; exit 1; }

destino="$1"
shift
mensagem="$*"

payload="$(SIGNAL_NUMBER="$SIGNAL_NUMBER" python3 - "$destino" "$mensagem" <<'PY'
import json, os, sys
destino, mensagem = sys.argv[1], sys.argv[2]
print(json.dumps({
    "message": mensagem,
    "number": os.environ["SIGNAL_NUMBER"],
    "recipients": [destino],
}))
PY
)"

if curl -fs --max-time 30 -X POST "http://127.0.0.1:8880/v2/send" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null; then
  echo "Enviado ✔"
else
  echo "Falhou. Veja os logs:  docker compose logs seguranca signal-api"
  exit 1
fi
