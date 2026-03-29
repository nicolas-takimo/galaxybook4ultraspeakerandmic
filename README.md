# Samsung Galaxy Book4 Ultra Linux Fixes

Guia prático para o `Samsung Galaxy Book4 Ultra (960XGL / NP960XGL-XG1BR)` no Linux, com foco em áudio interno, microfone e câmera interna.

Este material foi validado neste ambiente:

- Modelo: `960XGL / NP960XGL-XG1BR`
- Vendor: `SAMSUNG ELECTRONICS CO., LTD.`
- Distribuição: `Fedora 43`
- Kernel: `6.18.5-200.fc43.x86_64`
- Codec HDA: `Realtek ALC298`
- Amplificadores: `4x MAX98390`
- Webcam: `OVTI02C1 / ov02c10` via `Intel IPU6`

## O que foi confirmado

- Áudio interno funcionando pelos alto-falantes.
- Enumeração dos 4 amplificadores `MAX98390` em `0x38`, `0x39`, `0x3c`, `0x3d`.
- Sink padrão em `Speaker`.
- Microfone interno digital visível como `DMIC Raw`.
- Source padrão apontando para o microfone digital.
- Câmera interna detectada via `libcamera`.
- Relay V4L2 persistente via `camera-relay.service`.
- Persistência após reboot com `LIBCAMERA_SOFTISP_MODE=cpu`.
- Nós crus do `IPU6` ocultados no WirePlumber para os apps não pegarem o dispositivo errado.

## Problema

No Galaxy Book4 Ultra, o codec `ALC298` sozinho não basta para tocar os alto-falantes internos. O kernel costuma detectar o sink `Speaker`, mas os amplificadores `MAX98390` não sobem completamente. O efeito comum é:

- sem som nos speakers internos
- som saindo só de um lado
- HDMI, Bluetooth e fone funcionando

## Correção usada

Foi usado o projeto abaixo para instalar um driver `DKMS` fora da árvore do kernel:

- Projeto: `Andycodeman/samsung-galaxy-book4-linux-fixes`
- Área usada: `speaker-fix`
- Tipo de correção: módulos `snd-hda-scodec-max98390` e `snd-hda-scodec-max98390-i2c`

Depois da instalação, o serviço `max98390-hda-i2c-setup.service` enumerou os 3 amplificadores adicionais no barramento `i2c-2`, completando o conjunto de 4 amplificadores do notebook.

## Estrutura

- `scripts/install-speaker-fix.sh`: instala a correção de speaker usando o projeto upstream.
- `scripts/install-webcam-fix.sh`: instala a correção da webcam usando o projeto upstream.
- `scripts/install-camera-user-overrides.sh`: aplica os overrides locais que deixaram a câmera estável neste modelo.
- `scripts/fix-runtime-speakers.sh`: sobe o serviço de enumeração dos amplificadores sem reboot.
- `scripts/check-audio-status.sh`: mostra estado atual de sink, source, DKMS, módulos e logs.
- `scripts/check-camera-status.sh`: mostra estado atual da câmera, relay, PipeWire e serviços.
- `scripts/test-stereo.sh`: teste rápido de esquerda e direita.
- `scripts/test-mic.sh`: gravação e reprodução local para validar o microfone.
- `scripts/test-camera-frame.sh`: captura um frame da câmera relay e salva em JPEG.
- `scripts/collect-galaxybook-audio-debug.sh`: coleta diagnósticos em um diretório local.

## Instalação rápida

```bash
cd scripts
./install-speaker-fix.sh
```

O script:

- instala `dkms`, `kernel-devel` e `i2c-tools` no Fedora
- baixa o projeto upstream
- executa o instalador oficial do `speaker-fix`
- sobe o serviço de runtime para os amplificadores extras
- mostra um resumo final

## Instalação rápida da câmera

```bash
cd scripts
./install-webcam-fix.sh
./install-camera-user-overrides.sh
```

O fluxo da câmera faz isto:

- instala a correção `ov02c10` para `26 MHz`
- instala a correção `ipu-bridge`
- instala `libcamera`, `PipeWire` e `camera-relay` pelo projeto upstream
- cria overrides de usuário para forçar `LIBCAMERA_SOFTISP_MODE=cpu`
- adiciona um filtro leve no relay para reduzir ruído visível
- garante o `camera-relay.service` no login

## Verificação da câmera

Checagem de estado:

```bash
./scripts/check-camera-status.sh
```

Teste de frame:

```bash
./scripts/test-camera-frame.sh
```

## Verificação

Checagem de estado:

```bash
./scripts/check-audio-status.sh
```

Teste de estéreo:

```bash
./scripts/test-stereo.sh
```

Teste de microfone:

```bash
./scripts/test-mic.sh
```

## Resultado esperado

Depois da correção:

- `lsmod` deve mostrar `snd_hda_scodec_max98390` e `snd_hda_scodec_max98390_i2c`
- `dkms status` deve mostrar `max98390-hda/... installed`
- o journal do serviço deve mencionar os endereços `0x39 0x3c 0x3d`
- `speaker-test -c 2 -t wav -l 1` deve tocar `Front Left` e `Front Right`
- `arecord -l` deve listar `DMIC Raw`

Depois da correção da câmera:

- `camera-relay status` deve mostrar `Persistent: ENABLED`
- `wpctl status` deve mostrar `Camera Relay` e `ov02c10`
- o app deve usar `Camera Relay (V4L2)` ou `Câmera frontal interna`
- `test-camera-frame.sh` deve gerar um JPEG em `~/Imagens` ou no caminho informado

## Observações

- O som pode continuar mais fraco ou com menos grave que no Windows. Isso é esperado: o Windows usa processamento proprietário adicional.
- Se o áudio sair só de um lado, rode `./scripts/fix-runtime-speakers.sh` e confira os logs.
- A câmera ainda pode ter mais ruído que no Windows em ambiente escuro. Neste modelo o sensor sobe com ganho alto no Linux quando a iluminação é fraca.
- Em máquinas com GPU NVIDIA, deixar `LIBCAMERA_SOFTISP_MODE=cpu` evita frames pretos ou debayer quebrado.
- Se um app listar um monte de entradas `ipu6`, aplique `install-camera-user-overrides.sh` e reinicie a sessão.
- Se Secure Boot estiver ativo, pode ser necessário enrolar chave MOK para módulos DKMS.
- Este material não copia o código upstream. Ele apenas automatiza a instalação e documenta o que foi validado.

## Créditos

- `Andycodeman/samsung-galaxy-book4-linux-fixes`
- trabalho original do driver `MAX98390 HDA` citado pelo projeto upstream
- comunidade Linux que documentou os modelos Galaxy Book4
