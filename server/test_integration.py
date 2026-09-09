import json
import os
import socket
import struct
import subprocess
import sys
import time
import cv2
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(BASE_DIR, ".."))
PYTHON_BIN = os.path.join(BASE_DIR, "venv", "bin", "python")
if not os.path.exists(PYTHON_BIN):
    PYTHON_BIN = sys.executable

HOST = "127.0.0.1"
PORT = 5000

def recvall(sock, n):
    data = bytearray()
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data.extend(packet)
    return bytes(data)

def send_image(image_bytes, host=HOST, port=PORT, timeout=10.0):
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client_socket.settimeout(timeout)
    try:
        client_socket.connect((host, port))
        # 4 bytes de tamanho + payload
        msglen = struct.pack('>I', len(image_bytes))
        client_socket.sendall(msglen)
        client_socket.sendall(image_bytes)

        # 4 bytes de tamanho da resposta JSON
        raw_resplen = recvall(client_socket, 4)
        if not raw_resplen:
            raise ConnectionError("Servidor fechou conexão sem enviar cabeçalho de resposta.")
        
        resplen = struct.unpack('>I', raw_resplen)[0]
        json_bytes = recvall(client_socket, resplen)
        if not json_bytes:
            raise ConnectionError("Resposta incompleta do servidor.")

        # Verifica se o servidor fecha a conexão após o envio da resposta
        extra = client_socket.recv(1)
        is_closed = (len(extra) == 0)

        response = json.loads(json_bytes.decode('utf-8'))
        return response, is_closed
    finally:
        client_socket.close()

def create_blank_jpeg():
    # Cria imagem branca 640x480 sem objetos
    blank = np.full((480, 640, 3), 255, dtype=np.uint8)
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80]
    _, buf = cv2.imencode('.jpg', blank, encode_param)
    return buf.tobytes()

def run_integration_tests():
    print("=" * 70)
    print("INICIANDO SUITE DE TESTES DE INTEGRAÇÃO (PESSOA 1 ↔ PESSOA 2)")
    print("=" * 70)

    server_process = None
    # Verifica se o servidor já está rodando ou inicia um
    sock_test = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    is_running = (sock_test.connect_ex((HOST, PORT)) == 0)
    sock_test.close()

    if not is_running:
        print(f"Iniciando servidor Python ({PYTHON_BIN} server.py)...")
        server_process = subprocess.Popen(
            [PYTHON_BIN, os.path.join(BASE_DIR, "server.py")],
            cwd=BASE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        time.sleep(1.5)
    else:
        print(f"Servidor já detectado rodando em {HOST}:{PORT}")

    tests_passed = 0
    total_tests = 6

    try:
        # -------------------------------------------------------------
        # TESTE 1: Múltiplos Objetos / Reconhecimento Real
        # -------------------------------------------------------------
        print("\n[TESTE 1] Envio de foto real para detecção de múltiplos objetos...")
        test_img_path = os.path.join(BASE_DIR, "test_images", "Imagem colada.png")
        if not os.path.exists(test_img_path):
            test_img_path = os.path.join(ROOT_DIR, "mock_received.jpg")

        with open(test_img_path, "rb") as f:
            raw_bytes = f.read()

        # Comprime para JPEG 80% e max 1280px como o Flutter
        img = cv2.imdecode(np.frombuffer(raw_bytes, np.uint8), cv2.IMREAD_COLOR)
        h, w = img.shape[:2]
        if w > 1280:
            img = cv2.resize(img, (1280, int(h * 1280.0 / w)), interpolation=cv2.INTER_AREA)
        _, enc = cv2.imencode('.jpg', img, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        jpeg_bytes = enc.tobytes()

        resp, is_closed = send_image(jpeg_bytes)
        print(f"  Resposta: {resp}")
        print(f"  Conexão fechada pelo servidor após envio: {is_closed}")
        assert resp["success"] is True, "Deveria retornar success=True"
        assert len(resp["objects"]) > 0, "Deveria detectar objetos na imagem de teste"
        assert is_closed, "O servidor deve fechar a conexão após enviar a resposta"
        print("  -> TESTE 1 PASSOU! Objetos detectados com sucesso.")
        tests_passed += 1

        # -------------------------------------------------------------
        # TESTE 2: Nova análise após análise anterior (conexão individual)
        # -------------------------------------------------------------
        print("\n[TESTE 2] Nova conexão subsequente (teste de persistência do loop)...")
        resp2, is_closed2 = send_image(jpeg_bytes)
        assert resp2["success"] is True, "Segunda análise deveria ser bem sucedida"
        assert is_closed2, "Segunda conexão deve ser fechada corretamente"
        print("  -> TESTE 2 PASSOU! Servidor continuou responsivo e atendeu nova conexão.")
        tests_passed += 1

        # -------------------------------------------------------------
        # TESTE 3: Cenário 'Nada Detectado'
        # -------------------------------------------------------------
        print("\n[TESTE 3] Imagem sem objetos visíveis (Cenário 'Nada Detectado')...")
        blank_jpeg = create_blank_jpeg()
        resp3, _ = send_image(blank_jpeg)
        print(f"  Resposta: {resp3}")
        assert resp3["success"] is True, "Deveria retornar success=True para imagem vazia"
        assert resp3["objects"] == [], "Deveria retornar lista vazia de objetos"
        assert resp3["error"] is None, "Error deve ser None"
        print("  -> TESTE 3 PASSOU! 'Nada Detectado' tratado corretamente.")
        tests_passed += 1

        # -------------------------------------------------------------
        # TESTE 4: Erro no processamento / Payload corrompido
        # -------------------------------------------------------------
        print("\n[TESTE 4] Tratamento de payload corrompido...")
        corrupt_bytes = b"NOT_A_VALID_JPEG_IMAGE_DATA_BYTES_123456"
        resp4, _ = send_image(corrupt_bytes)
        print(f"  Resposta: {resp4}")
        assert resp4["success"] is False, "Deveria retornar success=False para bytes inválidos"
        assert resp4["objects"] == [], "Lista de objetos deve ser vazia em erro"
        assert resp4["error"] is not None, "Mensagem de erro deve estar presente"
        print("  -> TESTE 4 PASSOU! Servidor tratou erro de decodificação adequadamente.")
        tests_passed += 1

        # -------------------------------------------------------------
        # TESTE 5: Servidor desligado / Porta incorreta
        # -------------------------------------------------------------
        print("\n[TESTE 5] Conexão em porta incorreta (simulando servidor offline)...")
        try:
            send_image(jpeg_bytes, port=5999, timeout=1.0)
            assert False, "Deveria ter falhado com ConnectionRefusedError ou Timeout"
        except (ConnectionRefusedError, socket.timeout, OSError):
            print("  -> TESTE 5 PASSOU! Erro de conexão tratado corretamente pelo cliente.")
            tests_passed += 1

        # -------------------------------------------------------------
        # TESTE 6: Verificação do salvamento de imagem com timestamp
        # -------------------------------------------------------------
        print("\n[TESTE 6] Verificando salvamento no diretório received_images/...")
        saved_files = []
        for check_dir in [os.path.join(ROOT_DIR, "received_images"), os.path.join(BASE_DIR, "received_images")]:
            if os.path.exists(check_dir):
                files = [f for f in os.listdir(check_dir) if f.endswith(".jpg")]
                saved_files.extend(files)

        assert len(saved_files) > 0, "Deveria haver imagens salvas em received_images/"
        print(f"  Total de imagens salvas encontradas: {len(saved_files)}")
        # Verifica se alguma imagem segue o padrão YYYY-MM-DD_HH-MM-SS.jpg
        timestamp_pattern_matches = [f for f in saved_files if len(f) == 23 and f[4] == '-' and f[7] == '-' and f[10] == '_' and f[13] == '-' and f[16] == '-']
        print(f"  Imagens com padrão YYYY-MM-DD_HH-MM-SS.jpg: {timestamp_pattern_matches[-3:]}")
        assert len(timestamp_pattern_matches) > 0, "Imagens salvas devem seguir o padrão YYYY-MM-DD_HH-MM-SS.jpg"
        print("  -> TESTE 6 PASSOU! Salvamento com timestamp validado com sucesso.")
        tests_passed += 1

        print("\n" + "=" * 70)
        print(f"RESULTADO: {tests_passed}/{total_tests} TESTES PASSARAM COM 100% DE SUCESSO!")
        print("=" * 70)

    finally:
        if server_process:
            print("Encerrando processo do servidor de testes...")
            server_process.terminate()
            try:
                server_process.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                server_process.kill()

if __name__ == "__main__":
    run_integration_tests()
