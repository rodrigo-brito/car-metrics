# Publicar na Google Play

O build de release já está pronto para a Play: App Bundle (`.aab`), `applicationId`
`br.com.brito.painel_obd2`, `targetSdk` 36 e versão `1.0.0+1` (em `pubspec.yaml`).
O release não pede INTERNET: o app só fala com o adaptador por Bluetooth.

## 1. Chave de upload (uma vez só)

```bash
tool/criar_chave_upload.sh
```

O script cria `~/keys/android-upload.jks` e `android/key.properties` (este fica fora
do git). A mesma chave serve para outros apps: se ela já existe, o script só gera o
`key.properties` apontando para ela. Ele pede a senha no terminal. **Faça backup da chave e da senha.**
Com a "assinatura de apps do Google Play" ativa, o Google guarda a chave final, e a
chave de upload perdida pode ser trocada pelo suporte. Mesmo assim, guarde as duas.

Sem `key.properties`, o release é assinado com a chave de depuração. Ele compila, mas a
Play recusa o upload.

## 2. Gerar o bundle

```bash
flutter build appbundle --release
```

Saída: `build/app/outputs/bundle/release/app-release.aab`.

A cada nova versão, aumente o número depois do `+` em `pubspec.yaml`
(`1.0.1+2`, `1.0.2+3`...). A Play não aceita repetir o `versionCode`.

A mensagem "failed to strip debug symbols" aparece quando falta o
`cmdline-tools` do Android SDK (Android Studio → Settings → Android SDK → SDK Tools →
"Android SDK Command-line Tools"). Os símbolos já vão separados para
`BUNDLE-METADATA`, e o `.aab` é válido mesmo com a mensagem.

## 3. Play Console

1. Crie a conta de desenvolvedor (taxa única de US$ 25). Contas pessoais novas
   precisam de **teste fechado com 12 testadores por 14 dias** antes da produção.
2. Crie o app: nome "Painel OBD2", idioma pt-BR, app gratuito.
3. Envie o `.aab` em Testes → Teste interno ou fechado.
4. Preencha a ficha da loja, a classificação de conteúdo, a segurança dos dados e a
   política de privacidade (rascunhos abaixo).

### Ficha da loja e artes

Textos prontos para colar e o mapa dos arquivos de imagem estão em
[store/ficha-da-loja.md](store/ficha-da-loja.md). As artes ficam em `store/`.

Para renderizar uma arte de novo depois de editar o HTML:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,500 \
  --screenshot="$PWD/store/feature-1024x500.png" "file://$PWD/store/src/feature.html"
```

(Para o ícone, use `--window-size=512,512`, `icon.html` e `icon-512.png`.)

### Política de privacidade

A Play exige uma URL pública, porque o app usa Bluetooth e, no Android 11 ou
anterior, localização. Publique o texto abaixo, por exemplo num GitHub Pages ou num gist.

> **Política de privacidade do Painel OBD2**
>
> O Painel OBD2 não coleta, armazena em servidores nem compartilha dados pessoais.
> O app não acessa a internet.
>
> - **Bluetooth:** é usado só para encontrar e se conectar ao adaptador OBD2
>   escolhido por você e ler os dados do veículo.
> - **Localização (Android 11 ou anterior):** o sistema exige essa permissão para a
>   varredura Bluetooth. O app não lê nem guarda a sua localização.
> - **Sensores de movimento:** o acelerômetro é usado só para o inclinômetro, dentro do app.
> - **Dados locais:** o último adaptador conectado e a calibração ficam salvos só no
>   seu aparelho e são apagados ao desinstalar o app.
>
> Contato: (seu e-mail de desenvolvedor)
