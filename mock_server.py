import json
import socket
import struct


HOST = "0.0.0.0"
PORT = 5000


def recv_exact(connection, size):
    data = bytearray()

    while len(data) < size:
        chunk = connection.recv(size - len(data))

        if not chunk:
            raise ConnectionError(
                "Cliente desconectou antes de enviar todos os dados."
            )

        data.extend(chunk)

    return bytes(data)


def handle_client(connection, address):
    print(f"\nCliente conectado: {address[0]}:{address[1]}")

    # 1. Recebe os 4 bytes do tamanho da imagem.
    size_bytes = recv_exact(connection, 4)

    # !I = unsigned int 32 bits em big-endian.
    image_size = struct.unpack("!I", size_bytes)[0]

    print(f"Tamanho informado: {image_size} bytes")

    # 2. Recebe exatamente a quantidade informada.
    image_bytes = recv_exact(
        connection,
        image_size,
    )

    print(
        f"Imagem recebida: "
        f"{len(image_bytes)} bytes"
    )

    # Opcional: salva a última imagem recebida
    # para confirmar visualmente o teste.
    with open("mock_received.jpg", "wb") as image_file:
        image_file.write(image_bytes)

    print("Imagem salva em mock_received.jpg")

    # 3. Cria uma resposta falsa.
    response = {
        "success": True,
        "objects": [
            {
                "name": "person",
                "confidence": 0.95
            },
            {
                "name": "chair",
                "confidence": 0.87
            }
        ],
        "error": None
    }

    response_bytes = json.dumps(
        response
    ).encode("utf-8")

    # 4. Envia 4 bytes com tamanho do JSON.
    response_size = struct.pack(
        "!I",
        len(response_bytes),
    )

    connection.sendall(
        response_size
    )

    # 5. Envia JSON.
    connection.sendall(
        response_bytes
    )

    print(
        f"Resposta enviada: "
        f"{len(response_bytes)} bytes"
    )


def main():
    with socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    ) as server:
        server.setsockopt(
            socket.SOL_SOCKET,
            socket.SO_REUSEADDR,
            1,
        )

        server.bind(
            (HOST, PORT)
        )

        server.listen()

        print(
            f"Servidor mock iniciado em "
            f"{HOST}:{PORT}"
        )

        print(
            "Aguardando imagem..."
        )

        while True:
            connection, address = (
                server.accept()
            )

            with connection:
                try:
                    handle_client(
                        connection,
                        address,
                    )
                except Exception as error:
                    print(
                        f"Erro: {error}"
                    )

            print(
                "\nAguardando imagem..."
            )


if __name__ == "__main__":
    main()