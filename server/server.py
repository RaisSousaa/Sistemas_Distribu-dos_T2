import json
import logging
import os
import socket
import struct
import sys

# Garante que o diretório server/ esteja no sys.path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from detector import process_image

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

HOST = '0.0.0.0'
PORT = 5000
MAX_IMAGE_SIZE = 25 * 1024 * 1024  # Limite de segurança de 25 MB

def recvall(sock, n):
    """Recebe exatamente n bytes do socket ou retorna None se a conexão fechar antes."""
    data = bytearray()
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data.extend(packet)
    return bytes(data)

def handle_client(conn, addr):
    logging.info(f"Cliente conectado: {addr[0]}:{addr[1]}")
    try:
        # 1. Recebe os 4 bytes contendo o tamanho da imagem (big-endian)
        raw_msglen = recvall(conn, 4)
        if not raw_msglen:
            logging.warning("Conexão encerrada pelo cliente antes de enviar o tamanho.")
            return

        msglen = struct.unpack('>I', raw_msglen)[0]
        logging.info(f"Tamanho informado da imagem: {msglen} bytes")

        if msglen <= 0 or msglen > MAX_IMAGE_SIZE:
            logging.error(f"Tamanho de imagem inválido ou excede o limite permitido: {msglen} bytes")
            response = {
                "success": False,
                "objects": [],
                "error": f"Tamanho de imagem inválido: {msglen} bytes."
            }
        else:
            # 2. Recebe os bytes da imagem JPEG
            image_bytes = recvall(conn, msglen)
            if not image_bytes or len(image_bytes) != msglen:
                logging.error("Dados da imagem incompletos ou conexão encerrada.")
                response = {
                    "success": False,
                    "objects": [],
                    "error": "Dados da imagem incompletos."
                }
            else:
                logging.info(f"Imagem recebida completamente ({len(image_bytes)} bytes). Processando com YOLO...")
                try:
                    detected_objects = process_image(image_bytes)
                    logging.info(f"Detecção concluída. Objetos identificados: {detected_objects}")
                    response = {
                        "success": True,
                        "objects": detected_objects,
                        "error": None
                    }
                except Exception as e:
                    logging.error(f"Erro no processamento da imagem: {e}")
                    response = {
                        "success": False,
                        "objects": [],
                        "error": str(e)
                    }

        # 3. Monta resposta JSON codificada em UTF-8
        response_data = json.dumps(response, ensure_ascii=False).encode('utf-8')
        response_len = len(response_data)

        # 4. Envia primeiro os 4 bytes do tamanho do JSON em big-endian
        conn.sendall(struct.pack('>I', response_len))
        # 5. Em seguida envia os bytes do JSON
        conn.sendall(response_data)

        logging.info(f"Resposta JSON enviada ({response_len} bytes).")

    except Exception as e:
        logging.error(f"Erro durante comunicação com cliente {addr}: {e}")
    finally:
        # Encerra a conexão com aquele cliente após a análise
        conn.close()
        logging.info("Conexão com cliente encerrada.")
        logging.info("Aguardando imagem...\n")

def start_server():
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((HOST, PORT))
    server_socket.listen(5)

    logging.info(f"Servidor TCP iniciado e escutando em {HOST}:{PORT}")
    logging.info("Aguardando imagem...\n")

    try:
        while True:
            conn, addr = server_socket.accept()
            handle_client(conn, addr)
    except KeyboardInterrupt:
        logging.info("Servidor finalizado pelo usuário.")
    finally:
        server_socket.close()

if __name__ == "__main__":
    start_server()