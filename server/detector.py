import cv2
import datetime
import os
from ultralytics import YOLO

MODEL_PATH = "yolov8n.pt" 
model = YOLO(MODEL_PATH)

def process_image(image_bytes):
    import numpy as np
    
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Falha ao decodificar a imagem.")

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

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    save_dir = "../received_images" 
    os.makedirs(save_dir, exist_ok=True)
    
    filename = os.path.join(save_dir, f"captured_{timestamp}.jpg")
    cv2.imwrite(filename, img)
    
    return detected_objects