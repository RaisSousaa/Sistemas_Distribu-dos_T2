import socket
import struct
import json
import os
import cv2

HOST = '127.0.0.1'
PORT = 5000
TEST_FOLDER = 'test_images'

def prepare_image(image_path):
    """Simula o Flutter: redimensiona para máx 1280px e comprime JPEG a ~80%."""
    img = cv2.imread(image_path)
    if img is None:
        return None

    # Redimensiona se a largura for maior que 1280px
    height, width = img.shape[:2]
    if width > 1280:
        ratio = 1280 / width
        new_dimensions = (1280, int(height * ratio))
        img = cv2.resize(img, new_dimensions, interpolation=cv2.INTER_AREA)

    # Comprime para JPEG com qualidade 80
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80]
    success, encoded_image = cv2.imencode('.jpg', img, encode_param)
    
    if success:
        return encoded_image.tobytes()
    return None

def test_server():
    if not os.path.exists(TEST_FOLDER):
        print(f"Crie a pasta '{TEST_FOLDER}' e adicione imagens nela.")
        return

    for filename in os.listdir(TEST_FOLDER):
        if not filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
            
        filepath = os.path.join(TEST_FOLDER, filename)
        print(f"\n--- Testando imagem: {filename} ---")
        
        image_bytes = prepare_image(filepath)
        if not image_bytes:
            print(f"Erro ao processar {filename}")
            continue

        client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            client_socket.connect((HOST, PORT))
            
            # Envia 4 bytes + Imagem
            msglen = struct.pack('>I', len(image_bytes))
            client_socket.sendall(msglen)
            client_socket.sendall(image_bytes)

            # Recebe Resposta
            response_bytes = client_socket.recv(4096)
            response_json = json.loads(response_bytes.decode('utf-8'))
            
            print(f"Resultado: {json.dumps(response_json, ensure_ascii=False)}")

        except ConnectionRefusedError:
            print("Servidor não está rodando.")
            break
        finally:
            client_socket.close()

if __name__ == "__main__":
    test_server()