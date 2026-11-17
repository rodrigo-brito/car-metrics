#!/usr/bin/env bash
# Cria (ou reaproveita) a chave de upload da Google Play e gera o android/key.properties.
# A mesma chave pode servir a vários apps: rode este script em cada projeto.
# O keytool pede a senha no terminal; ela vai só para o key.properties local (fora do git).
set -euo pipefail
cd "$(dirname "$0")/.."
KS="${1:-$HOME/keys/android-upload.jks}"
# O /usr/bin/keytool do macOS é só um atalho que exige Java instalado; prefere o do Android Studio.
KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
[ -x "$KEYTOOL" ] || KEYTOOL=keytool
mkdir -p "$(dirname "$KS")"
if [ -e "$KS" ]; then
  echo "Chave já existe em $KS: só vou gerar o android/key.properties apontando para ela."
  read -rp "Alias da chave [upload]: " ALIAS; ALIAS="${ALIAS:-upload}"
  read -rsp "Senha da chave: " PW; echo
  "$KEYTOOL" -list -keystore "$KS" -alias "$ALIAS" -storepass "$PW" >/dev/null
else
ALIAS=upload
read -rsp "Senha da chave (mín. 6 caracteres): " PW; echo
read -rsp "Repita a senha: " PW2; echo
[ "$PW" = "$PW2" ] || { echo "Senhas diferentes"; exit 1; }
# 10000 dias (~27 anos): a Play exige validade além de 22/10/2033.
"$KEYTOOL" -genkeypair -v -keystore "$KS" -storetype PKCS12 -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10000 -storepass "$PW" -keypass "$PW"
fi
cat > android/key.properties <<PROPS
storeFile=$KS
storePassword=$PW
keyAlias=$ALIAS
keyPassword=$PW
PROPS
chmod 600 android/key.properties
echo "Pronto: $KS e android/key.properties. FAÇA BACKUP da chave e da senha."
