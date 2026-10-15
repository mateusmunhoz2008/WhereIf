# Diagnóstico do A24 — 12/10/2026

Galaxy A24 SM-A245M, Android 16, GPU Mali-G57 MC2. APK release ARM64,
sem reduções automáticas por hardware. Configuração efetiva: luz simples,
PBR, sombras, shaders, céu, seleção e janelas básicas; sem texturas,
reflexos adicionais, grading, bloom, antisserrilhado ou blurs. Nitidez 70%,
DPR 2,1, framebuffer 882 × 1913. Nenhum bloco selecionado na comparação.

O usuário esclareceu que tinha ligado o blur sem querer. Ele foi desligado
antes da segunda comparação, que usa o padrão como referência. A primeira
execução exploratória teve uma redução direta de DPR que não persistiu;
esse resultado NÃO serve para comparar resolução.

## Comparação controlada no mesmo ângulo

`tools/map/profile-map-runtime.mjs 9234 --label texture-composition`.
O teste captura o renderizador com um breakpoint de função, suspende o
loop normal e desenha o mesmo frame com movimento sinusoidal de câmera.
As alterações são diagnósticas e temporárias, restauradas em `finally`.
Não interpretar as amostras como garantia de FPS em gestos reais: elas
isolam desenho/composição e não toda a lógica de interação.

| Comparação | FPS da amostra | DPR | Framebuffer |
| --- | ---: | ---: | --- |
| Visual atual, sem blur | 50,5 | 2,1 | 882 × 1913 |
| Blur da navegação ligado | 50,3 | 2,1 | 882 × 1913 |
| Visual atual repetido, sem blur | 54,1 | 2,1 | 882 × 1913 |
| Sem chamadas WebGL de desenho | 89,3 | 2,1 | 882 × 1913 |
| Menos pixels — somente diagnóstico | 67,5 | 1,5 | 630 × 1366 |
| Sem sombras — somente diagnóstico | 62,9 | 2,1 | 882 × 1913 |
| Sem shaders próprios — somente diagnóstico | 51,9 | 2,1 | 882 × 1913 |
| Somente luz simples — somente diagnóstico | 71,2 | 2,1 | 882 × 1913 |
| Materiais crus — somente diagnóstico | 71,3 | 2,1 | 882 × 1913 |
| Visual atual restaurado, sem blur | 50,6 | 2,1 | 882 × 1913 |

Visual atual: cerca de 35 chamadas, 186.439 triângulos no último frame;
envio CPU mediano entre 2,4 e 3,4 ms. A GPU não expõe a extensão de timer
WebGL, portanto o tempo de GPU isolado não está disponível. `gl.finish()`
não mede o restante do pipeline de apresentação/composição do Android.
Frame mediano em parte das amostras: 22,3 ms, p90 33,6 ms. Sem desenho,
callback mediano 11,2 ms. Android sinalizou Thermal Status 0 e pouca evidência
de redução térmica naquele momento. Os contadores acumulados de `gfxinfo`
não são exclusivos de cada comparação e não devem ser usados como A/B.

Inferência: o custo dominante observado é o pipeline de desenho/composição
com a iluminação PBR/sombras e a quantidade de pixels, não um limite de FPS
no código. Tirar apenas os shaders próprios quase não mudou a amostra.
Também não se reproduziu perda de 20 FPS pelo blur nesta vista do A24.
Isso não exclui custos de interface em outras vistas ou durante seleção.

## Alternativa sem redução de qualidade

APK de comparação gerado com `MAP_DIRECT_COMPOSITION=true`, preservando
resolução, GLB, clima e todos os efeitos. A conexão USB caiu antes de instalar;
não há resultado dessa alternativa ainda. APK experimental separado em
`build/map-a24-direct-composition-test.apk`; o APK normal é reconstruído.
Nenhuma nova mudança de composição foi adotada sem teste no aparelho.

Fundamento: a [documentação oficial de Platform Views do Flutter](https://docs.flutter.dev/platform-integration/android/platform-views)
descreve custos e trade-offs diferentes entre composição por textura e
Hybrid Composition. A alternativa pode reduzir trabalho de composição,
mas pode piorar a sincronização de Flutter e não deve ser presumida melhor.

Resultados brutos: `build/a24-map-texture-composition-profile.json`.
