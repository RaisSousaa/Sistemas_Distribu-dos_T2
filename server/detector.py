import cv2
import datetime
import os
from ultralytics import YOLO

# Carrega o modelo YOLO (pode ser o yolov8n.pt ou yolo11n.pt)
# O modelo será baixado automaticamente na primeira execução
MODEL_PATH = "yolov8n.pt" 
model = YOLO(MODEL_PATH)

def process_image(image_bytes):
    """
    Recebe os bytes da imagem, decodifica, passa pelo YOLO,
    salva com timestamp e retorna uma lista de objetos.
    """
    import numpy as np
    
    # 1. Converter bytes para um formato legível pelo OpenCV
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Falha ao decodificar a imagem.")

    # 2. Executar detecção de objetos (YOLO)
    # Aqui você pode ajustar o threshold (Confidence score) se necessário
    results = model(img, conf=0.5) 
    
    detected_objects = []
    
    # 3. Processar os resultados (Confidence score e Nomes)
    for r in results:
        for box in r.boxes:
            class_id = int(box.cls[0])
            class_name = model.names[class_id]
            # confidence = float(box.conf[0]) # Caso queira usar o confidence score
            detected_objects.append(class_name)

    # 4. Salvamento com timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    save_dir = "../received_images" # Sobe um nível para a pasta raiz
    os.makedirs(save_dir, exist_ok=True)
    
    filename = os.path.join(save_dir, f"captured_{timestamp}.jpg")
    cv2.imwrite(filename, img)
    print(f"Imagem salva em: {filename}")
    
    # Remove duplicatas caso tenha detectado "person" duas vezes, por exemplo
    # ou mantenha se o app precisar saber a quantidade
    unique_objects = list(set(detected_objects))
    
    return unique_objects