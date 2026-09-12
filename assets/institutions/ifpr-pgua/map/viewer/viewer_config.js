// Ajustes visuais do mapa. Depois de alterar, faça hot restart no Flutter.
window.WHEREIF_MAP_TUNING = {
  renderer: {
    // A imagem repousada ganha nitidez; durante gestos a resolucao cai para
    // preservar a fluidez inclusive em aparelhos intermediarios.
    maxPixelRatio: 1.6,
    interactionPixelRatio: 0.5,
    // Pode ser trocado em tempo real durante a calibracao do mapa.
    toneMapping: 'aces',
    exposure: 1.04,
    postProcessing: {
      // Mantem as arestas dos blocos suaves mesmo com bloom e color grading.
      multisample: 0,
      bloom: {
        enabled: true,
        nightOnly: true,
        strength: 0.15,
        radius: 0.24,
        threshold: 0.93,
        // O reforco aparece apenas quando o sol esta baixo e forte. Como o
        // bloom reage a luminancia, somente superficies realmente iluminadas
        // florescem; nenhuma cor e pintada permanentemente na grama.
        sunlightStrength: 0.50,
        sunlightRadius: 0.32,
        sunlightThreshold: 0.74,
        // Comprime apenas o clarão frontal. Não altera a luz que atinge o mapa.
        directSunView: {
          startFacing: 0.68,
          fullFacing: 0.92,
          strengthScale: 0.18,
          radiusScale: 0.28,
          threshold: 0.96,
          exposureScale: 0.60,
        },
      },
      // Aquecimento seletivo: vegetacao iluminada fica dourada sem tingir
      // por igual as faces neutras que estao na sombra.
      grading: {
        warmColor: '#ff9a2e',
        warmStrength: 0,
        warmStart: 0.008,
        warmEnd: 0.12,
        neutralWarmResponse: 0.12,
        contrast: 1.01,
        saturation: 1.02,
      },
    },
    // Reflexo e apenas acabamento. A aparencia principal vem das luzes fixas.
    environmentIntensity: 0.05,
    // A noite, amplia o reflexo frio nas coberturas sem alterar a cor-base.
    nightEnvironmentScale: 22.0,
    nightBuildingBrightness: 0.86,
    sunsetEnvironmentScale: 4.5,
    sunsetReflectionFinish: {
      concrete: {
        roughness: 0.12,
        clearcoat: 0.82,
        clearcoatRoughness: 0.055,
      },
      generic: {
        roughness: 0.15,
        clearcoat: 0.74,
        clearcoatRoughness: 0.07,
      },
    },
    // Acabamento molhado/frio aplicado somente a noite. A grama permanece
    // fosca para os reflexos nao transformarem o terreno em plastico.
    nightReflectionFinish: {
      pavement: {
        roughness: 0.30,
        clearcoat: 0.62,
        clearcoatRoughness: 0.16,
      },
      concrete: {
        roughness: 0.24,
        clearcoat: 0.55,
        clearcoatRoughness: 0.14,
      },
      generic: {
        roughness: 0.17,
        clearcoat: 0.72,
        clearcoatRoughness: 0.08,
      },
    },
    atmosphereDensity: 0.00018,
    concreteBrightness: 0.90,
    materialFinish: {
      // O brilho principal deve vir do sol, nao do angulo da camera.
      concrete: {
        roughnessMin: 0.26,
        roughnessMax: 0.32,
        clearcoatMin: 0.36,
        clearcoatMax: 0.40,
        clearcoatRoughnessMin: 0.18,
        envMapIntensity: 0.08,
      },
      grass: {
        brightness: 0.80,
        roughnessMin: 0.92,
        clearcoatMax: 0.01,
        envMapIntensity: 0.025,
      },
      ground: {
        brightness: 0.84,
        roughnessMin: 0.82,
        clearcoatMax: 0.05,
        envMapIntensity: 0.06,
      },
      street: {
        roughnessMin: 0.88,
        clearcoatMax: 0.025,
        envMapIntensity: 0.045,
      },
    },
  },

  camera: {
    fov: 42,
    // Norte visual definido a partir da vista aprovada no S24.
    zeroBearingDegrees: 142,
    // O botao 0 restaura esta vista completa, incluindo alvo e distancia.
    zeroZoneId: 'portaria',
    // Abre diretamente no mesmo angulo usado ao focar o Bloco Didatico.
    initialZoneId: 'bloco-didatico',
    verticalLensShift: 0,
    // Enquadramento reconstruido a partir da referencia: campus ao fundo,
    // gramado em primeiro plano e o bloco lateral apenas na borda direita.
    initialPosition: [145.0, 42.5, -75.0],
    initialTarget: [30.0, 1.14, -75.0],
    // Direcao da vista inicial: x = lateral, y = altura, z = profundidade.
    positionOffset: { x: 0.68, y: 0.42, z: 0.74 },
    // Objetos que definem o enquadramento. Ruas longas ficam fora do calculo.
    framingNodes: [
      'bloco_central',
      'bloco_didatico',
      'portaria',
      'chao_if',
      'chao_if_2',
      'grama',
    ],
    // 'cover' preenche a tela e aceita cortes; 'contain' mostra tudo.
    framing: 'cover',
    // Menor aproxima; maior afasta.
    fitPadding: 0.72,
    minDistanceMultiplier: 0.22,
    maxDistanceMultiplier: 0.42,

    navigation: {
      // Tudo que pertence ao terreno do IF. Rua e calcada externas ficam de fora.
      boundsNodes: [
        'bloco_central',
        'bloco_didatico',
        'chao_if',
        'chao_if_2',
        'grama',
        'portaria',
      ],
      groundNodes: ['chao_if', 'chao_if_2', 'grama'],
      boundaryInset: 0.008,
      lockTargetToGround: true,
      targetHeightOffset: 0,
      // Parcela central da tela que deve permanecer sobre a area util.
      // A margem cresce e diminui automaticamente junto com o zoom.
      viewport: {
        left: 0.14,
        right: 0.14,
        top: 0.10,
        bottom: 0.30,
      },
      // Mola deliberadamente visivel ao alcancar uma borda.
      elasticResistance: 0.36,
      maxOvershootRatio: 0.075,
      zoomElasticResistance: 0.32,
      maxZoomOvershootRatio: 0.14,
      returnDuration: 420,
      returnBounce: 0.55,
    },
  },

  controls: {
    // Um dedo desloca. Dois dedos fazem zoom e giram.
    oneFingerAction: 'pan',
    twoFingerAction: 'rotate',
    rotateSpeed: 0.86,
    zoomSpeed: 0.96,
    panSpeed: 1.12,
    dampingFactor: 0.075,
    // Impede vista totalmente vertical e vista rente ao chao/horizonte.
    minPolarAngle: 0.36,
    maxPolarAngle: 1.25,
  },

  lighting: {
    // Camada noturna independente dos horarios e acabamentos do dia.
    nightLook: {
      exposure: 0.25,
      moonlight: 2.4,
      ambient: 0,
      hemisphere: 0,
      fill: 0,
      windows: 1.5,
      reflections: 3.0,
      wetness: 0.225,
      textureDetail: 0,
      grassBrightness: 0.045,
      floorRoughness: 1.0,
      floorReflection: 0.7,
      moonShafts: 0,
      windowSpill: 0.075,
    },
    // Escurece a luz indireta quando o sol esta forte. A noite mantem sua
    // iluminacao original para o mapa continuar legivel.
    shadowContrast: {
      enabled: true,
      startKeyIntensity: 0.75,
      fullKeyIntensity: 3.0,
      ambientScale: 0.55,
      hemisphereScale: 0.55,
      fillScale: 0.58,
    },
    // Ciclo diario baseado no horario local enviado pelo Flutter.
    // Os valores entre os horarios sao interpolados para evitar trocas bruscas.
    dayCycle: {
      enabled: true,
      // Refinamentos novos devem ser adicionados aqui, nunca alterando os
      // keyframes-base que ja definem o restante do dia. Cada perfil so existe
      // entre startMinute e endMinute e desaparece suavemente nas bordas.
      // Exemplo:
      // { id: 'midday', startMinute: 690, endMinute: 870,
      //   fadeMinutes: 20, profile: { key: { color: '#ffd77a' } } }
      isolatedPhases: [
        {
          id: 'warm-morning-grade',
          startMinute: 390,
          endMinute: 660,
          fadeMinutes: 30,
          profile: {
            grading: {
              warmColor: '#ffd16f',
              warmStrength: 0.095,
              warmStart: 0.10,
              warmEnd: 0.78,
              neutralWarmResponse: 0.040,
              saturation: 1.07,
            },
          },
        },
        {
          id: 'morning-side-light',
          startMinute: 450,
          endMinute: 630,
          fadeMinutes: 30,
          profile: {
            exposure: 1.00,
            rays: {
              color: '#ffb45d',
              opacity: 0.070,
            },
            ambient: {
              color: '#d8c9b7',
              intensity: 0.025,
            },
            hemisphere: {
              skyColor: '#e1d3c2',
              groundColor: '#332d27',
              intensity: 0.18,
            },
            key: {
              color: '#ffb45f',
              intensity: 4.30,
              positionOffset: { x: 0.86, y: 0.58, z: -0.68 },
            },
            fill: {
              color: '#c6ceda',
              intensity: 0.10,
              positionOffset: { x: -0.50, y: 0.42, z: 0.58 },
            },
            grading: {
              warmColor: '#ff9b34',
              warmStrength: 0.040,
              warmStart: 0.12,
              warmEnd: 0.66,
              neutralWarmResponse: 0.020,
              contrast: 1.08,
              saturation: 1.05,
            },
            shadowIntensity: 1.0,
            shadowRadius: 0.68,
          },
        },
        {
          id: 'warm-afternoon',
          startMinute: 855,
          endMinute: 1080,
          fadeMinutes: 30,
          profile: {
            grading: {
              warmColor: '#ffad55',
              warmStrength: 0.135,
              warmStart: 0.09,
              warmEnd: 0.78,
              neutralWarmResponse: 0.048,
              saturation: 1.08,
            },
          },
        },
      ],
      windows: {
        nodePrefix: 'janelas_preset_',
        // Apagadas, clonam o proprio material do concreto do GLB.
        surfaceMaterialName: 'whereif_ultra_concrete',
        fallbackSurfaceColor: '#85898d',
        // Luz interna: branco quente claro, diferente do reflexo do ceu/sol.
        color: '#ffd39a',
        duskIntensity: 0.14,
        nightIntensity: 0.92,
        duskActiveRatio: 0.34,
        nightActiveRatio: 0.67,
        // A emissao fica presa a fachada; luzes pontuais criam manchas no piso.
        glowEnabled: false,
        glowDuskIntensity: 8,
        glowNightIntensity: 92,
        glowDistanceRatio: 0.72,
        glowDecay: 2,
        // Janelas acendem apenas quando o sol ja saiu da cena.
        schedule: [
          { minute: 0, amount: 1.0 },
          { minute: 300, amount: 1.0 },
          { minute: 345, amount: 0.0 },
          { minute: 1170, amount: 0.0 },
          { minute: 1200, amount: 1.0 },
        ],
      },
      keyframes: [
        {
          minute: 0,
          exposure: 0.40,
          rays: { color: '#ffad55', opacity: 0.0 },
          ambient: { color: '#6079aa', intensity: 0.006 },
          hemisphere: {
            skyColor: '#6079a6',
            groundColor: '#0e1524',
            intensity: 0.06,
          },
          key: {
            color: '#9eb9ef',
            intensity: 1.45,
            positionOffset: { x: -0.72, y: 1.05, z: 0.82 },
          },
          fill: {
            color: '#7894c7',
            intensity: 0.04,
            positionOffset: { x: 0.42, y: 1.24, z: -0.48 },
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.75,
        },
        {
          minute: 330,
          exposure: 0.40,
          rays: { color: '#ffad55', opacity: 0.0 },
          ambient: { color: '#6079aa', intensity: 0.006 },
          hemisphere: {
            skyColor: '#6079a6',
            groundColor: '#0e1524',
            intensity: 0.06,
          },
          key: {
            color: '#9eb9ef',
            intensity: 1.45,
            positionOffset: { x: -0.72, y: 1.05, z: 0.82 },
          },
          fill: {
            color: '#7894c7',
            intensity: 0.04,
            positionOffset: { x: 0.42, y: 1.24, z: -0.48 },
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.75,
        },
        {
          // Hora azul antes do amanhecer, ainda sem misturar azul e laranja.
          minute: 360,
          exposure: 0.62,
          rays: { color: '#ffc07a', opacity: 0.012 },
          ambient: { color: '#8b8990', intensity: 0.025 },
          hemisphere: {
            skyColor: '#96949a',
            groundColor: '#242126',
            intensity: 0.16,
          },
          key: {
            color: '#ffd0a0',
            intensity: 0.65,
            positionOffset: { x: 0.82, y: 0.14, z: -0.82 },
          },
          fill: {
            color: '#9da6b7',
            intensity: 0.08,
            positionOffset: { x: -0.42, y: 0.36, z: 0.62 },
          },
          grading: {
            warmStrength: 0.0,
            neutralWarmResponse: 0.0,
            contrast: 1.10,
            saturation: 0.96,
          },
          shadowIntensity: 0.72,
          shadowRadius: 1.60,
        },
        {
          // Primeira luz quente antes do pico dourado do amanhecer.
          minute: 375,
          exposure: 0.82,
          rays: { color: '#ffb45d', opacity: 0.065 },
          ambient: { color: '#aaa098', intensity: 0.025 },
          hemisphere: {
            skyColor: '#b8aea4',
            groundColor: '#28231f',
            intensity: 0.17,
          },
          key: {
            color: '#ffad55',
            intensity: 2.20,
            positionOffset: { x: 0.80, y: 0.19, z: -0.79 },
          },
          fill: {
            color: '#b4bac4',
            intensity: 0.11,
            positionOffset: { x: -0.38, y: 0.38, z: 0.76 },
          },
          grading: {
            warmColor: '#ff9b34',
            warmStrength: 0.01,
            warmStart: 0.12,
            warmEnd: 0.66,
            neutralWarmResponse: 0.004,
            contrast: 1.08,
            saturation: 1.0,
          },
          shadowIntensity: 0.90,
          shadowRadius: 0.85,
        },
        {
          minute: 390,
          exposure: 0.96,
          rays: { color: '#ffb45d', opacity: 0.10 },
          ambient: { color: '#d3c5b5', intensity: 0.010 },
          hemisphere: {
            skyColor: '#d8cec2',
            groundColor: '#27231f',
            intensity: 0.07,
          },
          key: {
            color: '#ffad55',
            intensity: 5.20,
            positionOffset: { x: 0.76, y: 0.28, z: -0.72 },
          },
          fill: {
            color: '#c3c7ce',
            intensity: 0.045,
            positionOffset: { x: -0.42, y: 0.35, z: 0.70 },
          },
          grading: {
            warmColor: '#ff9b34',
            warmStrength: 0.010,
            warmStart: 0.12,
            warmEnd: 0.66,
            neutralWarmResponse: 0.006,
            contrast: 1.08,
            saturation: 1.05,
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.55,
        },
        {
          minute: 510,
          exposure: 1.00,
          rays: { color: '#ffc47a', opacity: 0.045 },
          ambient: { color: '#ddd3c7', intensity: 0.04 },
          hemisphere: {
            skyColor: '#e9e2d9',
            groundColor: '#39342f',
            intensity: 0.28,
          },
          key: {
            color: '#ffd09a',
            intensity: 3.70,
            positionOffset: { x: 0.55, y: 0.70, z: -0.45 },
          },
          fill: {
            color: '#d5dce8',
            intensity: 0.18,
            positionOffset: { x: -0.48, y: 0.46, z: 0.54 },
          },
          grading: {
            warmColor: '#ffb66a',
            warmStrength: 0.035,
            neutralWarmResponse: 0.02,
            saturation: 1.03,
          },
          shadowIntensity: 0.96,
          shadowRadius: 0.72,
        },
        {
          minute: 720,
          exposure: 1.04,
          rays: { color: '#ffe0b2', opacity: 0.015 },
          ambient: { color: '#eee8e1', intensity: 0.06 },
          hemisphere: {
            skyColor: '#f5f1ec',
            groundColor: '#514b45',
            intensity: 0.38,
          },
          key: {
            color: '#fff0db',
            intensity: 3.20,
            positionOffset: { x: 0.18, y: 1.20, z: -0.12 },
          },
          fill: {
            color: '#e4e8ef',
            intensity: 0.22,
            positionOffset: { x: -0.35, y: 0.52, z: 0.38 },
          },
          grading: {
            warmColor: '#ffd3a0',
            warmStrength: 0.012,
            neutralWarmResponse: 0.008,
            contrast: 1.05,
            saturation: 1.03,
          },
          shadowIntensity: 0.98,
          shadowRadius: 0.82,
        },
        {
          minute: 990,
          exposure: 1.00,
          rays: { color: '#ffc47a', opacity: 0.055 },
          ambient: { color: '#ddd3c7', intensity: 0.035 },
          hemisphere: {
            skyColor: '#e9e2d9',
            groundColor: '#34302b',
            intensity: 0.24,
          },
          key: {
            color: '#ffd09a',
            intensity: 3.90,
            positionOffset: { x: -0.55, y: 0.70, z: 0.45 },
          },
          fill: {
            color: '#d5d9e1',
            intensity: 0.16,
            positionOffset: { x: 0.48, y: 0.42, z: -0.52 },
          },
          grading: {
            warmColor: '#ffb66a',
            warmStrength: 0.045,
            neutralWarmResponse: 0.025,
            saturation: 1.03,
          },
          shadowIntensity: 0.98,
          shadowRadius: 0.70,
        },
        {
          minute: 1080,
          exposure: 0.96,
          rays: { color: '#ffb45d', opacity: 0.10 },
          ambient: { color: '#cbc1b8', intensity: 0.008 },
          hemisphere: {
            skyColor: '#d0c7be',
            groundColor: '#2b2824',
            intensity: 0.065,
          },
          key: {
            color: '#ffad55',
            intensity: 5.40,
            positionOffset: { x: -0.76, y: 0.28, z: 0.72 },
          },
          fill: {
            color: '#b7bec8',
            intensity: 0.045,
            positionOffset: { x: 0.39, y: 0.35, z: -0.39 },
          },
          grading: {
            warmColor: '#ff9b34',
            warmStrength: 0.010,
            warmStart: 0.12,
            warmEnd: 0.66,
            neutralWarmResponse: 0.006,
            contrast: 1.08,
            saturation: 1.05,
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.55,
        },
        {
          // O dourado permanece forte ate as 19h para alongar o por do sol.
          minute: 1140,
          exposure: 0.88,
          rays: { color: '#ffad55', opacity: 0.075 },
          ambient: { color: '#b5aaa0', intensity: 0.012 },
          hemisphere: {
            skyColor: '#c1b7ad',
            groundColor: '#27221f',
            intensity: 0.07,
          },
          key: {
            color: '#ffa64f',
            intensity: 4.20,
            positionOffset: { x: -0.82, y: 0.20, z: 0.78 },
          },
          fill: {
            color: '#b0b6c0',
            intensity: 0.04,
            positionOffset: { x: 0.40, y: 0.38, z: -0.74 },
          },
          grading: {
            warmColor: '#ff9b34',
            warmStrength: 0.01,
            warmStart: 0.12,
            warmEnd: 0.66,
            neutralWarmResponse: 0.004,
            contrast: 1.08,
            saturation: 1.0,
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.60,
        },
        {
          // Ultimos minutos quentes antes da transicao para a hora azul.
          minute: 1155,
          exposure: 0.72,
          rays: { color: '#ff9f45', opacity: 0.035 },
          ambient: { color: '#8f8986', intensity: 0.025 },
          hemisphere: {
            skyColor: '#999696',
            groundColor: '#222125',
            intensity: 0.16,
          },
          key: {
            color: '#ff9950',
            intensity: 1.40,
            positionOffset: { x: -0.85, y: 0.13, z: 0.82 },
          },
          fill: {
            color: '#8993a5',
            intensity: 0.09,
            positionOffset: { x: 0.40, y: 0.40, z: -0.78 },
          },
          grading: {
            warmColor: '#ff9f50',
            warmStrength: 0.008,
            neutralWarmResponse: 0.003,
            contrast: 1.09,
            saturation: 1.0,
          },
          shadowIntensity: 0.92,
          shadowRadius: 0.85,
        },
        {
          // Hora azul neutra evita a mistura rosada entre laranja e noite.
          minute: 1170,
          exposure: 0.50,
          rays: { color: '#ffad55', opacity: 0.0 },
          ambient: { color: '#6c7484', intensity: 0.03 },
          hemisphere: {
            skyColor: '#727c91',
            groundColor: '#151b27',
            intensity: 0.20,
          },
          key: {
            color: '#8ea4c7',
            intensity: 0.30,
            positionOffset: { x: -0.82, y: 0.12, z: 0.80 },
          },
          fill: {
            color: '#435d8b',
            intensity: 0.07,
            positionOffset: { x: 0.50, y: 0.42, z: -0.62 },
          },
          grading: {
            warmStrength: 0.0,
            neutralWarmResponse: 0.0,
            contrast: 1.10,
            saturation: 0.96,
          },
          shadowIntensity: 1.0,
          shadowRadius: 1.0,
        },
        {
          minute: 1200,
          exposure: 0.40,
          rays: { color: '#ffad55', opacity: 0.0 },
          ambient: { color: '#6079aa', intensity: 0.006 },
          hemisphere: {
            skyColor: '#6079a6',
            groundColor: '#0e1524',
            intensity: 0.06,
          },
          key: {
            color: '#9eb9ef',
            intensity: 1.45,
            positionOffset: { x: -0.72, y: 1.05, z: 0.82 },
          },
          fill: {
            color: '#7894c7',
            intensity: 0.04,
            positionOffset: { x: 0.42, y: 1.24, z: -0.48 },
          },
          shadowIntensity: 1.0,
          shadowRadius: 0.75,
        },
      ],
    },
    hemisphere: {
      skyColor: '#f7f9ff',
      groundColor: '#515867',
      intensity: 0.70,
    },
    key: {
      // Sol baixo e quente: y menor alonga as sombras.
      color: '#ffd2a3',
      intensity: 2.50,
      positionOffset: { x: -1.0, y: 0.68, z: 0.70 },
    },
    fill: {
      color: '#d4e0ff',
      intensity: 0.30,
      positionOffset: { x: 0.7, y: 0.32, z: -0.8 },
    },
    atmosphere: {
      enabled: true,
      // A atmosfera fica atras da arquitetura e acompanha a direcao do sol.
      resolution: 720,
      opacityMultiplier: 1.45,
      glowColor: '#ffc45a',
      glowOpacity: 0.14,
      glowRadiusRatio: 0.20,
      rayOpacity: 0.95,
      rayBlur: 16,
      rayLengthRatio: 0.42,
      rayWidths: [0.050, 0.028, 0.018, 0.011],
      rayOffsets: [-0.16, -0.05, 0.07, 0.18],
      // Reaplica uma parte pequena dos feixes sobre a geometria. A origem
      // continua sendo a posicao do sol no mundo, nao a rotacao da camera.
      surfaceRayStrength: 0.0,
      // Mantem os feixes no horizonte mesmo com a camera inclinada para o solo.
      // A elevacao fisica da luz continua sendo a do keyframe acima.
      visualSunElevation: 0.02,
      // Distancia visual em relacao ao tamanho do campus. Continua distante,
      // mas preso ao mundo 3D em vez de preso a tela do celular.
      visualSunDistanceMultiplier: 1.25,
      horizontalOverflow: 0.03,
      sourceYOffset: 0.30,
      destination: { x: 0.84, y: 0.03 },
      directSunView: {
        startFacing: 0.68,
        fullFacing: 0.92,
        glowRadiusScale: 0.46,
        rayLengthScale: 0.62,
      },
    },
    nightSky: {
      enabled: true,
      backgroundColor: '#02050c',
      counts: {
        basic: 8000,
        balanced: 12000,
        cinematic: 16000,
      },
      minSize: 1.15,
      maxSize: 2.8,
      brightStarChance: 0.04,
      brightStarMaxSize: 6.0,
      fadeInStartMinute: 1140,
      fullAtMinute: 1200,
      fadeOutStartMinute: 300,
      hiddenAtMinute: 360,
    },
    // A luz principal ja projeta os raios e as sombras no mundo. Focos extras
    // criavam manchas laranjas que mudavam a leitura da cena.
    sunProjection: {
      // Refletores sem sombra atravessavam paredes e acendiam janelas ocultas.
      // O sol direcional cuida da arquitetura; as faixas abaixo ficam no piso.
      enabled: false,
      intensityMultiplier: 700000,
    },
    // Faixas de luz no proprio terreno. Diferente do reflexo, permanecem no
    // mesmo lugar do campus quando o usuario gira a camera.
    groundRays: {
      enabled: false,
      color: '#ff7610',
      opacity: 0.20,
      lengthRatio: 1.60,
      widths: [0.055, 0.14, 0.04],
      offsets: [-0.16, 0.02, 0.20],
      strengths: [0.68, 1.0, 0.54],
      profileColorMix: 0.30,
    },
    shadows: {
      enabled: true,
      // O WebView do Xclipse 940 aceita texturas maiores, mas deixa o mapa de
      // profundidade vazio acima de 2048. Este e o maior valor validado no S24
      // que preserva nitidez e projeta todas as sombras corretamente.
      mapSize: 1280,
      tightFit: true,
      fitPadding: 0.035,
      // Concentra a textura na parte do campus que esta na tela. Assim 2048
      // ganha definicao visual de uma textura muito maior sem quebrar o S24.
      dynamicFit: true,
      // Durante o gesto a camera continua em 60 fps, mas a textura pesada de
      // sombra e atualizada em uma cadencia menor. Ao soltar, ela e refeita
      // imediatamente na qualidade total.
      interactionUpdateInterval: 48,
      viewPadding: 0.065,
      minimumViewSpanRatio: 0.18,
      maximumViewSpanRatio: 0.60,
      viewRayDistanceMultiplier: 1.75,
      // Pisos nao precisam projetar sombra sobre eles mesmos.
      casterExclusions: [
        'calcada_rua',
        'chao_if',
        'chao_if_2',
        'grama',
        'rua',
        'rua_if',
      ],
      coverageMultiplier: 0.82,
      radius: 1.15,
      bias: -0.00035,
      normalBias: 0.025,
    },
  },

  selection: {
    tapTolerance: 18,
    initialOutlineWidth: 11,
    outlineWidth: 4,
    entranceDuration: 760,
    exitDuration: 260,
    startColor: '#ffffff',
    restingOpacity: 0.92,
    flashIntensity: 0.48,
    flashSpatialFrequency: 0.075,
    flashCycles: 1.15,
    focusDuration: 620,
    focusSafeWidth: 0.95,
    focusSafeHeight: 0.76,
    focusPadding: 1.0,
    focusMaxSamplePoints: 8000,
    // Blocos que pedem mais que o zoom maximo recebem uma vista mais elevada.
    largeFocusThreshold: 1.15,
    largeFocusElevation: 0.64,
  },
};
