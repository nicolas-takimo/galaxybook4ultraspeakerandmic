# Samsung Galaxy Book4 Ultra Linux Fixes

Guia pratico para o `Samsung Galaxy Book4 Ultra (960XGL / NP960XGL-XG1BR)` no Linux, com foco em audio interno e microfone.

Este material foi validado neste ambiente:

- Modelo: `960XGL / NP960XGL-XG1BR`
- Vendor: `SAMSUNG ELECTRONICS CO., LTD.`
- Distribuicao: `Fedora 43`
- Kernel: `6.18.5-200.fc43.x86_64`
- Codec HDA: `Realtek ALC298`
- Amplificadores: `4x MAX98390`

## O que foi confirmado

- Audio interno funcionando pelos alto-falantes.
- Enumeracao dos 4 amplificadores `MAX98390` em `0x38`, `0x39`, `0x3c`, `0x3d`.
- Sink padrao em `Speaker`.
- Microfone interno digital visivel como `DMIC Raw`.
- Source padrao apontando para o microfone digital.

## Problema

No Galaxy Book4 Ultra, o codec `ALC298` sozinho nao basta para tocar os alto-falantes internos. O kernel costuma detectar o sink `Speaker`, mas os amplificadores `MAX98390` nao sobem completamente. O efeito comum e:

- sem som nos speakers internos
- som saindo so de um lado
- HDMI, Bluetooth e fone funcionando

## Correcao usada

Foi usado o projeto abaixo para instalar um driver `DKMS` fora da arvore do kernel:

- Projeto: `Andycodeman/samsung-galaxy-book4-linux-fixes`
- Area usada: `speaker-fix`
- Tipo de correcao: modulos `snd-hda-scodec-max98390` e `snd-hda-scodec-max98390-i2c`

Depois da instalacao, o servico `max98390-hda-i2c-setup.service` enumerou os 3 amplificadores adicionais no barramento `i2c-2`, completando o conjunto de 4 amplificadores do notebook.

## Estrutura

- `scripts/install-speaker-fix.sh`: instala a correcao de speaker usando o projeto upstream.
- `scripts/fix-runtime-speakers.sh`: sobe o servico de enumeracao dos amplificadores sem reboot.
- `scripts/check-audio-status.sh`: mostra estado atual de sink, source, DKMS, modulos e logs.
- `scripts/test-stereo.sh`: teste rapido de esquerda e direita.
- `scripts/test-mic.sh`: gravacao e reproducao local para validar o microfone.
- `scripts/collect-galaxybook-audio-debug.sh`: coleta diagnosticos em um diretorio local.

## Instalacao rapida

```bash
cd scripts
./install-speaker-fix.sh
```

O script:

- instala `dkms`, `kernel-devel` e `i2c-tools` no Fedora
- baixa o projeto upstream
- executa o instalador oficial do `speaker-fix`
- sobe o servico de runtime para os amplificadores extras
- mostra um resumo final

## Verificacao

Checagem de estado:

```bash
./scripts/check-audio-status.sh
```

Teste de estereo:

```bash
./scripts/test-stereo.sh
```

Teste de microfone:

```bash
./scripts/test-mic.sh
```

## Resultado esperado

Depois da correcao:

- `lsmod` deve mostrar `snd_hda_scodec_max98390` e `snd_hda_scodec_max98390_i2c`
- `dkms status` deve mostrar `max98390-hda/... installed`
- o journal do servico deve mencionar os enderecos `0x39 0x3c 0x3d`
- `speaker-test -c 2 -t wav -l 1` deve tocar `Front Left` e `Front Right`
- `arecord -l` deve listar `DMIC Raw`

## Observacoes

- O som pode continuar mais fraco ou com menos grave que no Windows. Isso e esperado: o Windows usa processamento proprietario adicional.
- Se o audio sair so de um lado, rode `./scripts/fix-runtime-speakers.sh` e confira os logs.
- Se Secure Boot estiver ativo, pode ser necessario enrolar chave MOK para modulos DKMS.
- Este material nao copia o codigo upstream. Ele apenas automatiza a instalacao e documenta o que foi validado.

## Creditos

- `Andycodeman/samsung-galaxy-book4-linux-fixes`
- trabalho original do driver `MAX98390 HDA` citado pelo projeto upstream
- comunidade Linux que documentou os modelos Galaxy Book4

## Publicacao

Para publicar como repositorio:

```bash
cd /home/nicolasgabriel/Documentos/galaxy-book4-ultra-linux-fixes-community
git init
git add .
git commit -m "Add Galaxy Book4 Ultra Linux audio fix guide and scripts"
```
