#!/usr/bin/env bash
#
# Instalador da central de notificações Signal.
#
# Rode UMA VEZ na VPS, dentro desta pasta:
#
#     ./instalar.sh
#
# Pode rodar de novo quando quiser — ele detecta o que já está pronto
# e não estraga nada.
#
set -euo pipefail
cd "$(dirname "$0")"

verde() { printf '\n\033[1;32m%s\033[0m\n' "$*"; }
azul()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
falha() { printf '\n\033[1;31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 \
  || falha "Docker não está instalado. Instale com:  curl -fsSL https://get.docker.com | sh"
docker compose version >/dev/null 2>&1 \
  || falha "O comando 'docker compose' não está disponível nesta VPS."
command -v curl >/dev/null 2>&1 \
  || falha "O 'curl' não está instalado. Instale com:  sudo apt install -y curl"

# ── 1. Configuração (.env) ────────────────────────────────────────────────
if [ ! -f .env ]; then
  echo
  read -rp "Número do Signal do BOT, com código do país (ex: +5521999999999): " NUMERO
  case "$NUMERO" in
    +[0-9][0-9]*) ;;
    *) falha "O número precisa começar com + e o código do país. Ex: +5521999999999" ;;
  esac
  TOKEN="$(openssl rand -hex 32)"
  printf 'SIGNAL_NUMBER=%s\nAPI_TOKEN=%s\n' "$NUMERO" "$TOKEN" > .env
  chmod 600 .env
  verde "Arquivo .env criado (número do bot + chave de acesso gerada)."
fi

set -a
. ./.env
set +a
[ -n "${SIGNAL_NUMBER:-}" ] || falha "SIGNAL_NUMBER está vazio no .env"
[ -n "${API_TOKEN:-}" ]     || falha "API_TOKEN está vazio no .env"

IP="$(curl -fs --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"

ja_conectado() {
  curl -fs --max-time 5 "http://127.0.0.1:8091/v1/accounts" 2>/dev/null \
    | grep -q -- "${SIGNAL_NUMBER#+}"
}

espera_api() {
  for _ in $(seq 1 60); do
    if curl -fs --max-time 3 "http://127.0.0.1:8091/v1/about" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  falha "A API do Signal não respondeu. Veja os logs com:  docker compose logs signal-api"
}

# ── 2. Sobe os serviços ───────────────────────────────────────────────────
azul "Baixando e subindo os serviços (a primeira vez demora alguns minutos)…"
docker compose up -d --remove-orphans
espera_api

# ── 3. Conecta o número do bot (QR code) ──────────────────────────────────
if ja_conectado; then
  verde "O número $SIGNAL_NUMBER já está conectado. Pulando o QR code."
else
  # Abre temporariamente a porta 8092 só para você ver o QR no navegador.
  # Ela é fechada automaticamente assim que a conexão é feita.
  cat > docker-compose.override.yml <<'EOF'
services:
  signal-api:
    ports:
      - "8092:8080"
EOF
  docker compose up -d
  espera_api

  echo
  azul "════════════════ ESCANEIE O QR CODE ════════════════"
  echo
  echo "  1. No SEU COMPUTADOR, abra este endereço no navegador:"
  echo
  echo "     http://$IP:8092/v1/qrcodelink?device_name=central-whitezone"
  echo
  echo "  2. No CELULAR DO BOT ($SIGNAL_NUMBER), abra o Signal e vá em:"
  echo "     Configurações → Aparelhos conectados → Conectar novo aparelho"
  echo
  echo "  3. Escaneie o QR code que apareceu na tela do computador."
  echo
  echo "  Dicas:"
  echo "  • A página não abriu? Libere a porta na VPS:  sudo ufw allow 8092"
  echo "  • QR expirado? Atualize a página do navegador para gerar outro."
  echo
  azul "Aguardando você escanear… (pode levar até 1 min para confirmar; Ctrl+C cancela)"

  LIMITE=$(( $(date +%s) + 600 ))
  until ja_conectado; do
    if [ "$(date +%s)" -ge "$LIMITE" ]; then
      rm -f docker-compose.override.yml
      docker compose up -d --remove-orphans >/dev/null 2>&1 || true
      falha "Tempo esgotado (10 min). Rode ./instalar.sh de novo quando quiser tentar outra vez."
    fi
    sleep 3
  done

  rm -f docker-compose.override.yml
  docker compose up -d --remove-orphans
  verde "Número conectado! A porta temporária do QR (8092) foi fechada."
fi

# ── 4. Teste real ─────────────────────────────────────────────────────────
azul "Enviando uma mensagem de teste…"
if curl -fs --max-time 30 -X POST "http://127.0.0.1:8880/v2/send" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"✅ Central de notificações instalada e funcionando!\", \"number\": \"$SIGNAL_NUMBER\", \"recipients\": [\"$SIGNAL_NUMBER\"]}" >/dev/null; then
  verde "Teste enviado! Confira no celular do bot, na conversa \"Anotações pessoais\"."
else
  echo "A mensagem de teste falhou. Veja os logs:  docker compose logs seguranca signal-api"
fi

# ── 5. Resumo final ───────────────────────────────────────────────────────
verde "════════════════ TUDO PRONTO ════════════════"
echo
echo "Endereço da central (para o Make, GitHub ou qualquer projeto):"
echo
echo "    http://$IP:8880/v2/send"
echo
echo "Chave de acesso (também guardada no arquivo .env desta pasta):"
echo
echo "    $API_TOKEN"
echo
echo "Exemplo — enviar notificação para um contato:"
echo
echo "    curl -X POST http://$IP:8880/v2/send \\"
echo "      -H 'Authorization: Bearer SUA_CHAVE' \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"message\": \"Deploy concluído 🚀\", \"number\": \"$SIGNAL_NUMBER\", \"recipients\": [\"+5521988887777\"]}'"
echo
echo "Próximos passos:"
echo "  • Liberar a porta pública (se a VPS usa ufw):  sudo ufw allow 8880"
echo "  • Enviar da própria VPS:                       ./enviar.sh +5521988887777 \"olá\""
echo "  • Usar grupos (um por projeto):                crie no celular do bot e rode ./grupos.sh"
echo "  • Conectar o Make:                             veja exemplos/make.md"
echo
