import json
import os
import socket
import struct
import cv2

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEST_FOLDER = os.path.join(BASE_DIR, 'test_images')

HOST = '127.0.0.1'
PORT = 5000

def recvall(sock, n):
    """Recebe exatamente n bytes ou None caso a conexão seja encerrada prematuramente."""
    data = bytearray()
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data.extend(packet)
    return bytes(data)

def prepare_image(image_path):
    """Simula o Flutter: redimensiona para máx 1280px e comprime JPEG a ~80%."""
    img = cv2.imread(image_path)
    if img is None:
        return None

    # Redimensiona se a largura for maior que 1280px
    height, width = img.shape[:2]
    if width > 1280:
        ratio = 1280.0 / width
        new_dimensions = (1280, int(height * ratio))
        img = cv2.resize(img, new_dimensions, interpolation=cv2.INTER_AREA)

    # Comprime para JPEG com qualidade 80
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80]
    success, encoded_image = cv2.imencode('.jpg', img, encode_param)
    
    if success:
        return encoded_image.tobytes()
    return None

def send_image_to_server(image_bytes, host=HOST, port=PORT):
    """Envia a imagem e retorna o dicionário JSON de resposta."""
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client_socket.settimeout(10.0)
    try:
        client_socket.connect((host, port))
        
        # Envia 4 bytes com o tamanho (big-endian) + bytes da imagem JPEG
        msglen = struct.pack('>I', len(image_bytes))
        client_socket.sendall(msglen)
        client_socket.sendall(image_bytes)

        # Recebe os 4 bytes com o tamanho do JSON
        raw_resplen = recvall(client_socket, 4)
        if not raw_resplen:
            raise ConnectionError("Servidor fechou conexão sem enviar tamanho da resposta.")

        resplen = struct.unpack('>I', raw_resplen)[0]
        
        # Recebe o JSON completo usando o tamanho exato
        response_bytes = recvall(client_socket, resplen)
        if not response_bytes:
            raise ConnectionError("Resposta incompleta do servidor.")

        response_json = json.loads(response_bytes.decode('utf-8'))
        return response_json
    finally:
        client_socket.close()

def test_server():
    if not os.path.exists(TEST_FOLDER):
        print(f"Pasta '{TEST_FOLDER}' não encontrada.")
        return

    images = [f for f in sorted(os.listdir(TEST_FOLDER)) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    if not images:
        print(f"Nenhuma imagem encontrada em '{TEST_FOLDER}'.")
        return

    print(f"Encontradas {len(images)} imagens de teste em '{TEST_FOLDER}'.")
    for filename in images:
        filepath = os.path.join(TEST_FOLDER, filename)
        print(f"\n--- Testando imagem: {filename} ---")
        
        image_bytes = prepare_image(filepath)
        if not image_bytes:
            print(f"Erro ao processar {filename}")
            continue

        print(f"Bytes preparados (JPEG ~80%, max 1280px): {len(image_bytes)} bytes")
        try:
            response = send_image_to_server(image_bytes)
            print("Resposta do Servidor:")
            print(json.dumps(response, indent=2, ensure_ascii=False))
            if response.get("success"):
                objs = response.get("objects", [])
                if objs:
                    print(f"-> {len(objs)} objeto(s) detectado(s):")
                    for obj in objs:
                        print(f"   - {obj['name']}: {int(obj['confidence'] * 100)}% de confiança")
                else:
                    print("-> Nada Detectado")
            else:
                print(f"-> Erro reportado: {response.get('error')}")
        except ConnectionRefusedError:
            print("Erro: Servidor não está rodando na porta especificada.")
            break
        except Exception as e:
            print(f"Erro no teste de {filename}: {e}")

if __name__ == "__main__":
    test_server()