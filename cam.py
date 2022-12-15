from pyvcam import pvc 
from pyvcam.camera import Camera   

pvc.init_pvcam()                  
cam = next(Camera.detect_camera()) 
cam.open()  
#frame_stack = cam.get_sequence(num_frames=100, exp_time=20)


