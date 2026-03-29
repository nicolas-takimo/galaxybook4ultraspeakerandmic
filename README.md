# Samsung Galaxy Book4 Ultra Linux Fixes

Guia prático para o `Samsung Galaxy Book4 Ultra (960XGL / NP960XGL-XG1BR)` no Linux, com foco em áudio interno e microfone.

Este material foi validado neste ambiente:

- Modelo: `960XGL / NP960XGL-XG1BR`
- Vendor: `SAMSUNG ELECTRONICS CO., LTD.`
- Distribuição: `Fedora 43`
- Kernel: `6.18.5-200.fc43.x86_64`
- Codec HDA: `Realtek ALC298`
- Amplificadores: `4x MAX98390`

## O que foi confirmado

- Áudio interno funcionando pelos alto-falantes.
- Enumeração dos 4 amplificadores `MAX98390` em `0x38`, `0x39`, `0x3c`, `0x3d`.
- Sink padrão em `Speaker`.
- Microfone interno digital visível como `DMIC Raw`.
- Source padrão apontando para o microfone digital.

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
- `scripts/fix-runtime-speakers.sh`: sobe o serviço de enumeração dos amplificadores sem reboot.
- `scripts/check-audio-status.sh`: mostra estado atual de sink, source, DKMS, módulos e logs.
- `scripts/test-stereo.sh`: teste rápido de esquerda e direita.
- `scripts/test-mic.sh`: gravação e reprodução local para validar o microfone.
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

## Observações

- O som pode continuar mais fraco ou com menos grave que no Windows. Isso é esperado: o Windows usa processamento proprietário adicional.
- Se o áudio sair só de um lado, rode `./scripts/fix-runtime-speakers.sh` e confira os logs.
- Se Secure Boot estiver ativo, pode ser necessário enrolar chave MOK para módulos DKMS.
- Este material não copia o código upstream. Ele apenas automatiza a instalação e documenta o que foi validado.

## Créditos

- `Andycodeman/samsung-galaxy-book4-linux-fixes`
- trabalho original do driver `MAX98390 HDA` citado pelo projeto upstream
- comunidade Linux que documentou os modelos Galaxy Book4

## Publicação

Para publicar como repositório:

```bash
cd /home/nicolasgabriel/Documentos/galaxy-book4-ultra-linux-fixes-community
git init
git add .
git commit -m "Add Galaxy Book4 Ultra Linux audio fix guide and scripts"
```
