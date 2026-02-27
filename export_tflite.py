from ultralytics import YOLO
model = YOLO("best.pt")
model.export(format="tflite", half=False)
print("DONE")