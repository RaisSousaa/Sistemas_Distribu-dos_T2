import socket
import struct
import json
import logging
from detector import process_image

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

HOST = '0.0.0.0'
PORT = 5000

def start_server():
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((HOST, PORT))
    server_socket.listen(1)
    
    logging.info(f"Servidor aguardando conexão na porta {PORT}...")

    while True:
        try:
            conn, addr = server_socket.accept()
            logging.info(f"Conectado a {addr}")

            raw_msglen = recvall(conn, 4)
            if not raw_msglen:
                conn.close()
                continue
                
            msglen = struct.unpack('>I', raw_msglen)[0]
            image_bytes = recvall(conn, msglen)
            
            if not image_bytes:
                conn.close()
                continue

            # Construção do JSON no novo formato
            try:
                detected_objects = process_image(image_bytes)
                response = {
                    "success": True,
                    "objects": detected_objects,
                    "error": None
                }
            except Exception as e:
                logging.error(f"Erro no processamento: {e}")
                response = {
                    "success": False,
                    "objects": [],
                    "error": str(e)
                }

            response_data = json.dumps(response).encode('utf-8')
            response_len = len(response_data)
            
            # Envio do tamanho do JSON (4 bytes, big-endian)
            conn.sendall(struct.pack('>I', response_len))
            # Envio do JSON em UTF-8
            conn.sendall(response_data)
            
            # O servidor encerra a conexão após cada análise
            conn.close() 
            logging.info("Resposta enviada. Conexão encerrada.\n")

        except Exception as e:
            logging.error(f"Erro no servidor: {e}")

def recvall(sock, n):
    data = bytearray()
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data.extend(packet)
    return bytes(data)

if __name__ == "__main__":
    start_server()