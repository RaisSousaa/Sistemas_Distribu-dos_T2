import socket
import struct
import json
import logging
from detector import process_image

# Configuração de Logs do servidor
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

HOST = '0.0.0.0'  # Escuta em todas as interfaces de rede
PORT = 5000       # Porta que o Flutter vai conectar (Configuração IP/porta)

def start_server():
    # Cria o Servidor TCP
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((HOST, PORT))
    server_socket.listen(1)
    
    logging.info(f"Servidor aguardando conexão na porta {PORT}...")

    while True:
        try:
            conn, addr = server_socket.accept()
            logging.info(f"Conectado a {addr}")

            # 1. Recebimento dos 4 bytes (Tamanho da imagem)
            raw_msglen = recvall(conn, 4)
            if not raw_msglen:
                logging.warning("Não foi possível receber o tamanho da imagem.")
                conn.close()
                continue
                
            # Desempacota os 4 bytes para um número inteiro (big-endian)
            msglen = struct.unpack('>I', raw_msglen)[0]
            logging.info(f"Tamanho da imagem esperado: {msglen} bytes")

            # 2. Recebimento completo da imagem
            image_bytes = recvall(conn, msglen)
            if not image_bytes:
                logging.warning("Falha ao receber os bytes da imagem.")
                conn.close()
                continue

            # 3. Processamento (OpenCV e YOLO)
            logging.info("Processando a imagem...")
            try:
                detected_objects = process_image(image_bytes)
                
                # 4. Construção do JSON
                if len(detected_objects) > 0:
                    response = {"status": "success", "objects": detected_objects}
                else:
                    response = {"status": "success", "objects": [], "message": "Nada Detectado"}
                    
            except Exception as e:
                logging.error(f"Erro no processamento: {e}")
                response = {"status": "error", "message": str(e)}

            # 5. Retorno pelo socket
            response_data = json.dumps(response).encode('utf-8')
            conn.sendall(response_data)
            logging.info(f"Resposta enviada: {response}")

            conn.close()
            logging.info("Conexão encerrada. Aguardando próxima imagem...\n")

        except Exception as e:
            logging.error(f"Erro no servidor: {e}")

def recvall(sock, n):
    """Função auxiliar para receber 'n' bytes exatamente ou retornar None"""
    data = bytearray()
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data.extend(packet)
    return bytes(data)

if __name__ == "__main__":
    start_server()