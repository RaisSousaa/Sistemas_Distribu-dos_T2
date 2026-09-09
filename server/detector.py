import cv2
import datetime
import os
from ultralytics import YOLO

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(BASE_DIR, ".."))

MODEL_PATH = os.path.join(BASE_DIR, "yolov8n.pt")
model = YOLO(MODEL_PATH)

def process_image(image_bytes):
    import numpy as np
    
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Falha ao decodificar a imagem: formato inválido ou corrompido.")

    results = model(img, conf=0.5) 
    detected_objects = []
    
    # Extração de Nome e Confidence Score
    for r in results:
        for box in r.boxes:
            class_id = int(box.cls[0])
            class_name = model.names[class_id]
            confidence = float(box.conf[0])
            
            # Adiciona ao formato exigido (name e confidence)
            detected_objects.append({
                "name": class_name,
                "confidence": round(confidence, 2)
            })

    # Timestamp no formato especificado no PDF (ex: 2026-09-08_18-10-21.jpg)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    
    # Salva no diretório received_images (tanto raiz quanto em server/ se existir)
    save_dirs = [
        os.path.join(ROOT_DIR, "received_images"),
        os.path.join(BASE_DIR, "received_images"),
    ]
    for s_dir in save_dirs:
        os.makedirs(s_dir, exist_ok=True)
        filename = os.path.join(s_dir, f"{timestamp}.jpg")
        cv2.imwrite(filename, img)
    
    return detected_objects