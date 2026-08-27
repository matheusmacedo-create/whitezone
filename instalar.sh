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
# O bot parou de funcionar / aparece desconectado no celular?
#
#     ./instalar.sh reconectar
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

# Se uma instalação anterior foi interrompida no meio do QR code, este
# arquivo pode ter sobrado — removê-lo garante que a porta temporária
# do QR nunca fica aberta sem necessidade.
rm -f docker-compose.override.yml

# ── Modo reconectar ───────────────────────────────────────────────────────
# Usado quando o Signal desvinculou o aparelho da VPS (ex.: celular do bot
# muito tempo offline). Guarda os dados antigos e refaz o pareamento.
if [ "${1:-}" = "reconectar" ]; then
  if [ -d signal-cli-config ]; then
    azul "Guardando os dados antigos da conta e preparando um novo pareamento…"
    docker compose down >/dev/null 2>&1 || true
    mv signal-cli-config "signal-cli-config.antigo-$(date +%Y%m%d-%H%M%S)"
  fi
fi

# ── 1. Configuração (.env) ────────────────────────────────────────────────
if [ ! -f .env ]; then
  echo
  echo "Digite o número do Signal do BOT: só dígitos, com o código do país,"
  echo "sem espaços, traços ou parênteses. Exemplo: +5521999999999"
  read -rp "Número: " NUMERO
  if ! [[ "$NUMERO" =~ ^\+[0-9]{8,15}$ ]]; then
    falha "Número inválido: \"$NUMERO\". Use o formato +5521999999999 (só + e dígitos)."
  fi
  TOKEN="$(openssl rand -hex 32)"
  printf 'SIGNAL_NUMBER=%s\nAPI_TOKEN=%s\n' "$NUMERO" "$TOKEN" > .env
  chmod 600 .env
  verde "Arquivo .env criado (número do bot + chave de acesso gerada)."
fi

# O tr remove quebras de linha do Windows, caso o .env seja editado por lá.
set -a
. <(tr -d '\r' < .env)
set +a
[ -n "${SIGNAL_NUMBER:-}" ] || falha "SIGNAL_NUMBER está vazio no .env"
[ -n "${API_TOKEN:-}" ]     || falha "API_TOKEN está vazio no .env"
[[ "$SIGNAL_NUMBER" =~ ^\+[0-9]{8,15}$ ]] \
  || falha "SIGNAL_NUMBER no .env está num formato inválido (\"$SIGNAL_NUMBER\"). Corrija para algo como +5521999999999."

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

espera_porta_publica() {
  # Sem -f de propósito: qualquer resposta HTTP (mesmo 403) prova que subiu.
  for _ in $(seq 1 30); do
    if curl -s --max-time 3 -o /dev/null "http://127.0.0.1:8880/"; then
      return 0
    fi
    sleep 2
  done
  falha "A porta 8880 não respondeu. Veja os logs com:  docker compose logs seguranca"
}

# Fecha a porta temporária do QR aconteça o que acontecer (Ctrl+C, erro,
# queda da conexão SSH) — nunca pode ficar aberta depois do script.
fecha_porta_qr() {
  rm -f docker-compose.override.yml
  docker compose up -d --remove-orphans >/dev/null 2>&1 || true
}

# ── 2. Sobe os serviços ───────────────────────────────────────────────────
azul "Baixando e subindo os serviços (a primeira vez demora alguns minutos)…"
docker compose up -d --remove-orphans
espera_api

# ── 3. Conecta o número do bot (QR code) ──────────────────────────────────
if ja_conectado; then
  verde "O número $SIGNAL_NUMBER já está conectado. Pulando o QR code."
  echo "(se o celular diz que o aparelho foi desconectado, rode: ./instalar.sh reconectar)"
else
  # Abre temporariamente a porta 8092 só para você ver o QR no navegador.
  # A limpeza roda em QUALQUER saída: sucesso, erro, Ctrl+C ou queda do SSH.
  trap 'fecha_porta_qr; trap - EXIT; exit 130' INT TERM HUP
  trap fecha_porta_qr EXIT
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
  echo "  • QR expirado ou deu erro? Atualize a página para gerar outro."
  echo "  • A página não abriu? Se a VPS usa ufw, rode em outro terminal:"
  echo "      sudo ufw allow 8092"
  echo "    (depois de conectar, remova a regra:  sudo ufw delete allow 8092)"
  echo
  azul "Aguardando você escanear… (pode levar até 1 min para confirmar — aguarde"
  azul "mesmo que a página do navegador pareça travada; Ctrl+C cancela com segurança)"

  LIMITE=$(( $(date +%s) + 600 ))
  until ja_conectado; do
    if [ "$(date +%s)" -ge "$LIMITE" ]; then
      falha "Tempo esgotado (10 min). Rode ./instalar.sh de novo quando quiser tentar outra vez."
    fi
    sleep 3
  done

  fecha_porta_qr
  trap - EXIT INT TERM HUP
  verde "Número conectado! A porta temporária do QR (8092) foi fechada."
fi

# ── 4. Teste real ─────────────────────────────────────────────────────────
espera_api
espera_porta_publica
azul "Enviando uma mensagem de teste…"
if curl -fs --max-time 60 --retry 3 --retry-delay 2 -X POST "http://127.0.0.1:8880/v2/send" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"✅ Central de notificações instalada e funcionando!\", \"number\": \"$SIGNAL_NUMBER\", \"recipients\": [\"$SIGNAL_NUMBER\"]}" >/dev/null; then
  verde "Teste enviado! Confira no celular do bot, na conversa \"Anotações pessoais\"."
else
  echo
  echo "A mensagem de teste falhou. O que fazer:"
  echo "  • Veja os logs:  docker compose logs seguranca signal-api"
  echo "  • Se o celular do bot mostra o aparelho como desconectado,"
  echo "    rode:  ./instalar.sh reconectar"
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
echo "  • Enviar da própria VPS:            ./enviar.sh +5521988887777 \"olá\""
echo "  • Usar grupos (um por projeto):     crie no celular do bot e rode ./grupos.sh"
echo "  • Conectar o Make:                  veja exemplos/make.md"
echo
echo "Se algum serviço externo não alcançar a central, verifique o firewall"
echo "no PAINEL do seu provedor de VPS e libere a porta 8880 (TCP)."
echo