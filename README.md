# Atividade 2 — Foto via Botão (Android → Servidor Python por Sockets)

Sistema distribuído composto por um aplicativo móvel em **Flutter (Android)** e um servidor em **Python (OpenCV + YOLO)** comunicando-se diretamente via **Sockets TCP**. O aplicativo realiza a captura de fotos através da câmera do dispositivo, redimensiona e comprime a imagem em JPEG e a transmite para o servidor, que executa inferência de detecção de objetos e responde com os itens identificados em formato JSON estruturado.

---

## 👥 Divisão da Dupla

| Pessoa | Frente Principal | Responsabilidades |
| :--- | :--- | :--- |
| **Pessoa 1** | Flutter (Cliente TCP & Mobile) | Câmera, captura e compressão de imagem (JPEG ~80%, max 1280px), cliente socket TCP, exibição dos resultados na interface. |
| **Pessoa 2** | Python (Servidor TCP & IA) | Servidor socket TCP multiconexão sequencial, decodificação OpenCV, modelo YOLOv8n, persistência das fotos com timestamp. |
| **Ambos** | Integração & Qualidade | Protocolo de rede, testes automatizados de integração, documentação, capturas de tela e roteiro de demonstração. |

---

## 🏛️ Arquitetura do Projeto

```
atividade-foto-socket/
├── app/                         # Pessoa 1 — Flutter
│   ├── android/                 # Configurações nativas Android
│   ├── lib/
│   │   ├── main.dart            # Ponto de entrada do app
│   │   ├── models/              # Modelos de dados (Detection, DetectionResponse)
│   │   ├── screens/
│   │   │   └── home_screen.dart # Interface: IP, Porta, Câmera, Botão e Resultados
│   │   └── services/
│   │       ├── camera_service.dart # Gerenciamento da câmera do aparelho
│   │       ├── image_service.dart  # Redimensionamento e compressão JPEG
│   │       └── socket_service.dart # Conexão TCP e envio/recebimento de bytes
│   ├── test/                    # Testes de unidade do aplicativo
│   └── pubspec.yaml             # Dependências Flutter
│
├── server/                      # Pessoa 2 — Python
│   ├── server.py                # Servidor socket TCP (porta 5000)
│   ├── detector.py              # Processamento de imagem e inferência YOLOv8n
│   ├── requirements.txt         # Dependências Python (ultralytics, opencv, numpy)
│   ├── yolov8n.pt               # Pesos do modelo YOLOv8 Nano
│   ├── test_client.py           # Cliente de teste em Python
│   ├── test_integration.py      # Bateria de testes de integração ponta a ponta
│   ├── test_images/             # Imagens de teste
│   └── received_images/         # Imagens recebidas salvas com timestamp
│
├── screenshots/                 # Ambos — Capturas de tela e evidências
│   ├── app.png                  # Tela do aplicativo Flutter
│   ├── captured_image.jpg       # Fotografia capturada
│   └── detection_result.png     # Detecção visual dos objetos pelo modelo
│
├── received_images/             # Imagens recebidas na raiz do projeto
└── README.md                    # Documentação completa da atividade
```

---

## 📡 Protocolo de Comunicação TCP

A comunicação ocorre sobre o protocolo TCP na porta padrão **5000**, seguindo uma política de **uma conexão TCP por fotografia analisada**.

### 1. Flutter → Servidor Python
O aplicativo envia um cabeçalho fixo de 4 bytes contendo o tamanho exato da imagem em ordem **big-endian** (inteiro de 32 bits sem sinal), seguido imediatamente pelos bytes da imagem JPEG:

```
┌───────────────────────────┬──────────────────────────────────────────┐
│          4 bytes          │                 N bytes                  │
│ Tamanho da imagem (uint32)│          Bytes da imagem JPEG            │
└───────────────────────────┴──────────────────────────────────────────┘
```

* **Formato da imagem:** JPEG
* **Qualidade:** ~80%
* **Largura máxima:** 1280 px

### 2. Servidor Python → Flutter
Após processar a imagem, o servidor envia primeiro 4 bytes em **big-endian** com o tamanho do JSON e, logo em seguida, o conteúdo do JSON codificado em **UTF-8**:

```
┌───────────────────────────┬──────────────────────────────────────────┐
│          4 bytes          │                 N bytes                  │
│ Tamanho do JSON (uint32)  │             JSON codificado UTF-8        │
└───────────────────────────┴──────────────────────────────────────────┘
```

Ao concluir o envio da resposta completa, o servidor encerra a conexão (`socket.close()`). O Flutter lê os dados recebidos, decodifica a resposta e fecha o socket localmente.

---

## 📋 Estrutura da Resposta JSON

### Sucesso com objetos detectados
```json
{
  "success": true,
  "objects": [
    {
      "name": "chair",
      "confidence": 0.89
    },
    {
      "name": "chair",
      "confidence": 0.71
    }
  ],
  "error": null
}
```
*O aplicativo exibe os itens em português com concordância (ex.: "Cadeira detectada", "Confiança: 89%").*

### Nenhum objeto detectado
```json
{
  "success": true,
  "objects": [],
  "error": null
}
```
*O aplicativo exibe a mensagem:* **`Nada Detectado`**.

### Erro no processamento ou dados corrompidos
```json
{
  "success": false,
  "objects": [],
  "error": "Falha ao decodificar a imagem: formato inválido ou corrompido."
}
```

---

## 🧠 Modelo e Bibliotecas Utilizadas

### Servidor Python
- **YOLOv8n (`ultralytics`)**: Modelo neural YOLOv8 Nano pré-treinado na base COCO (80 classes), oferecendo inferência rápida em CPU para detecção de objetos (pessoas, carros, cadeiras, mochilas, celulares, garrafas, etc.).
- **OpenCV (`opencv-python`)**: Decodificação dos bytes em memória (`imdecode`), manipulação de matrizes e gravação no disco (`imwrite`).
- **NumPy (`numpy`)**: Manipulação eficiente do buffer de bytes da imagem.
- **Sockets (`socket`, `struct`)**: Comunicação de rede em baixo nível e empacotamento binário em big-endian.

### Aplicativo Flutter
- **`camera`**: Acesso à câmera nativa do dispositivo Android e captura fotográfica em alta resolução.
- **`image`**: Redimensionamento proporcional (largura máxima de 1280 px) e compressão em JPEG com qualidade 80%.
- **`dart:io`**: Sockets TCP assíncronos (`Socket.connect`), timeouts e manipulação de buffers binários com `ByteData`.

---

## ⚙️ Como Configurar o IP e a Porta

1. No computador onde o servidor Python será executado, verifique o IP local na rede Wi-Fi:
   - **Linux / macOS:**
     ```bash
     ip a
     # ou
     ifconfig
     ```
     Localize a interface Wi-Fi (ex.: `wlan0` ou `wlp2s0`) e anote o IP (ex.: `192.168.1.105`).
   - **Windows:**
     ```bash
     ipconfig
     ```
     Localize o `Adaptador de Rede Sem Fio Wi-Fi` e anote o `Endereço IPv4`.

2. Certifique-se de que o smartphone e o computador estão conectados na **mesma rede Wi-Fi** e que a porta **5000** não está bloqueada pelo firewall.

3. No aplicativo Android, insira o IP anotado no campo **"IP do servidor"** e confirme a porta **"5000"**.

---

## 🚀 Como Executar o Projeto

### 1. Executando o Servidor Python

No terminal, a partir da raiz do repositório:

```bash
# Ative o ambiente virtual (se necessário)
source server/venv/bin/activate

# Instale as dependências (se ainda não instaladas)
pip install -r server/requirements.txt

# Inicie o servidor
python server/server.py
```

O terminal exibirá:
```text
2026-09-09 14:18:29 [INFO] Servidor TCP iniciado e escutando em 0.0.0.0:5000
2026-09-09 14:18:29 [INFO] Aguardando imagem...
```

### 2. Executando o Aplicativo Flutter

Conecte um celular Android via USB com depuração ativada (ou inicie um emulador):

```bash
cd app
flutter pub get
flutter run
```

Para gerar o arquivo APK de instalação:
```bash
flutter build apk --release
```
O arquivo gerado estará em `app/build/app/outputs/flutter-apk/app-release.apk`.

---

## 🧪 Testes Automatizados

O repositório inclui suítes de testes automatizados para validação integral da comunicação e dos dados.

### Testes de Integração Fim a Fim (Python)
Para testar todos os fluxos da especificação de forma automatizada (detecção múltipla, reconexão sucessiva, cenário "Nada Detectado", dados corrompidos, servidor offline e salvamento com timestamp):

```bash
./server/venv/bin/python server/test_integration.py
```

### Teste de Envio com Imagens de Teste
```bash
./server/venv/bin/python server/test_client.py
```

### Testes Unitários do Flutter
```bash
cd app
flutter test
```

---

## 📸 Capturas de Tela

| Interface do Aplicativo (`app.png`) | Imagem Capturada (`captured_image.jpg`) | Resultado da Detecção (`detection_result.png`) |
| :---: | :---: | :---: |
| ![Interface do App](screenshots/app.png) | ![Foto Capturada](screenshots/captured_image.jpg) | ![Detecção YOLO](screenshots/detection_result.png) |

---

## 📝 Roteiro de Demonstração

1. **Iniciar o Servidor:** Inicie o servidor Python no computador (`python server/server.py`). O console exibirá `"Aguardando imagem..."`.
2. **Configuração no App:** Abra o aplicativo Android, digite o IP do servidor e a porta `5000`.
3. **Primeira Análise:** Aponte a câmera para um ou mais objetos (ex.: pessoa, cadeira, celular) e toque em **"Tirar e Analisar"**.
4. **Processamento:** O app exibe o loading enquanto a foto é comprimida e transmitida. O servidor loga a recepção, processa a imagem com YOLO e salva o arquivo em `received_images/` com timestamp (`YYYY-MM-DD_HH-MM-SS.jpg`).
5. **Exibição do Resultado:** O app recebe a resposta e exibe os objetos identificados com suas respectivas taxas de confiança (ex.: *"Cadeira detectada - Confiança: 89%"*).
6. **Teste de "Nada Detectado":** Aponte para uma superfície lisa (como uma parede branca ou folha) e toque em **"Tirar e Analisar"**. O app exibirá **"Nada Detectado"**.
7. **Nova Análise:** Toque novamente para analisar outra cena, confirmando que o servidor reinicia o ciclo e aceita a nova conexão sem necessidade de reinicialização.
8. **Tratamento de Erros:** Desligue o servidor no computador e tente realizar uma análise no celular; confirme que o app exibe uma mensagem amigável informando a impossibilidade de conexão.
