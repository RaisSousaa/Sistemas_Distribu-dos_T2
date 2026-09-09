# Aplicativo Flutter — Cliente TCP Android

Este diretório contém o aplicativo Android desenvolvido em **Flutter/Dart** para a Atividade 2 de Sistemas Distribuídos.

O aplicativo é responsável por capturar uma fotografia utilizando a câmera do dispositivo, preparar a imagem e enviá-la para um servidor Python por meio de uma conexão **Socket TCP**.

## Funcionalidades

- Captura de fotografias utilizando a câmera do dispositivo Android.
- Conversão e compressão da imagem em JPEG com qualidade aproximada de 80%.
- Redimensionamento da imagem para largura máxima de 1280 px.
- Configuração do IP e da porta do servidor.
- Envio da imagem utilizando Socket TCP.
- Recebimento da resposta do servidor em JSON.
- Exibição dos objetos detectados e de suas respectivas confianças.
- Exibição da mensagem `Nada Detectado` quando nenhum objeto é identificado.
- Tratamento de erros de conexão, timeout e respostas inválidas.
- Possibilidade de realizar novas análises sem reiniciar o aplicativo.

## Tecnologias utilizadas

- Flutter
- Dart
- `camera`
- `image`
- `dart:io`

## Estrutura principal

```text
lib/
├── main.dart
├── models/
│   ├── detection.dart
│   └── detection_response.dart
├── screens/
│   └── home_screen.dart
└── services/
    ├── camera_service.dart
    ├── image_service.dart
    └── socket_service.dart
```

### Responsabilidade dos arquivos

`camera_service.dart`

Responsável por inicializar a câmera do dispositivo e capturar as fotografias.

`image_service.dart`

Responsável por redimensionar a fotografia quando necessário e gerar a imagem JPEG com qualidade 80%.

`socket_service.dart`

Responsável pela conexão TCP com o servidor Python, envio da imagem e recebimento da resposta.

`home_screen.dart`

Responsável pela interface do aplicativo, configuração de IP/porta, captura da fotografia e apresentação dos resultados.

## Protocolo de envio

O aplicativo envia a fotografia para o servidor utilizando o seguinte formato:

```text
4 bytes             N bytes
┌──────────────────┬────────────────────┐
│ Tamanho da imagem│ Imagem JPEG        │
│ uint32 big-endian│                    │
└──────────────────┴────────────────────┘
```

Os primeiros 4 bytes representam o tamanho da imagem.

Em seguida são enviados todos os bytes da fotografia JPEG.

A resposta do servidor segue o formato:

```text
4 bytes             N bytes
┌──────────────────┬────────────────────┐
│ Tamanho do JSON  │ JSON UTF-8         │
│ uint32 big-endian│                    │
└──────────────────┴────────────────────┘
```

Exemplo:

```json
{
  "success": true,
  "objects": [
    {
      "name": "person",
      "confidence": 0.87
    }
  ],
  "error": null
}
```

## Como executar

Entre na pasta do aplicativo:

```powershell
cd app
```

Instale as dependências:

```powershell
flutter pub get
```

Verifique os dispositivos disponíveis:

```powershell
flutter devices
```

Execute o aplicativo:

```powershell
flutter run
```

Ou informe diretamente o dispositivo:

```powershell
flutter run -d ID_DO_DISPOSITIVO
```

## Configuração do servidor

O aplicativo possui campos para informar:

```text
IP do servidor
Porta
```

A porta utilizada pelo projeto é:

```text
5000
```

O celular e o computador onde o servidor Python está sendo executado devem estar na mesma rede.

Exemplo:

```text
IP: 192.168.1.35
Porta: 5000
```

## Fluxo de utilização

```text
Abrir aplicativo
       ↓
Informar IP e porta
       ↓
Visualizar câmera
       ↓
Tirar e Analisar
       ↓
Capturar fotografia
       ↓
Preparar JPEG
       ↓
Enviar via TCP
       ↓
Aguardar servidor
       ↓
Exibir resultado
       ↓
Nova análise
```

## Resultado

Quando objetos são detectados, o aplicativo apresenta informações como:

```text
Pessoa detectada
Confiança: 87%
```

Caso nenhum objeto seja identificado:

```text
Nada Detectado
```