# Diagnostico do teclado do login

Os logs registram toques, mudancas de foco, alturas do teclado, motivos para o app
remover foco, ativacao/desativacao da protecao e pedidos para mostrar o teclado.
Nao registram texto digitado, email, senha, tokens nem conteudo da conta.

Estao ativos por padrao em debug. Em release, exigem esta compilacao temporaria:

```powershell
C:\flutter\bin\flutter.bat build apk --release --dart-define=LOGIN_IME_TRACE=true
```

Uma compilacao release normal, sem esse parametro, desativa os logs do app.

## Capturar no celular

1. Abra o app e deixe a tela de login aberta, com USB/depuracao autorizados.
2. No terminal do projeto, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\trace_login_keyboard.ps1
```

3. Abra um campo, feche pelo toque fora e reabra rapidamente varias vezes.
4. Repita fechando pelo Voltar do Android. Teste email e senha separadamente.
5. Quando reproduzir a queda inesperada, aguarde dois segundos e pressione Ctrl+C
   no terminal. Envie o arquivo indicado em `build/login-keyboard-logs` e diga
   qual campo/forma de fechamento estava testando.

Para outro dispositivo, passe `-Device SERIAL` ao script. Se reiniciar o app,
execute o script novamente; a captura acompanha apenas o processo iniciado.
Nao e necessario limpar logs do aparelho nem apagar dados do app.

## Ler a sequencia

`[LOGIN_IME]` identifica os logs do app. `session` identifica uma abertura da tela,
`seq` ordena os eventos e `ms` informa o tempo desde a abertura. `focusSession`
identifica cada novo foco.

- `field.tap` / `pointer.down`: toque recebido.
- `focus.changed`: campo ganhando/perdendo foco.
- `android.metrics` / `keyboard.height`: altura nativa e altura calculada no app.
- `keyboard.close_owner` / `keyboard.reopen_owner`: sessao responsavel pelo
  fechamento e sessao que pediu uma nova abertura. Aumento de altura sozinho
  nao apaga mais essa associacao.
- `keyboard.visible_confirmed`: altura positiva estabilizada com campo focado.
- `keyboard.closed_confirmed`: zero estabilizado por 100 ms, ainda na mesma
  sessao, com insets nativos tambem em zero. Informa se o fechamento pertence
  a uma sessao anterior. Um zero transitorio nao remove o foco.
- `app.unfocus`: o proprio app retirou foco; `reason` explica o motivo.
- `app.show_keyboard`: pedido do app para reabrir; o `ack` confirma apenas a
  resposta ao comando, nao garante que o teclado ficou visualmente aberto.
- `field.edit`: houve edicao, sem registrar o texto nem seu tamanho.

As linhas nativas `ImeTracker`/`InsetsController`/`InputMethodManager` ajudam a
comparar pedidos de abertura/fechamento do Android com as decisoes do Flutter.
Os nomes desses eventos nao comprovam a causa sozinhos; compare a sequencia.

A confirmacao de estabilidade e cancelada a cada nova altura, toque/foco ou
saida da tela. Nao existe mais o prazo de 600 ms que apagava a protecao anterior.
