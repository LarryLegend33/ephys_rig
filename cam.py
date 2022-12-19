from pyvcam import pvc 
from pyvcam.camera import Camera   

pvc.init_pvcam()                  
cam = next(Camera.detect_camera())
cam.open()
cam._set_dtype()
cam.set_roi(1, 1, 200, 200)
# interesting -- if you set roi1 to 200 but roi2 to 1, it halts at get_frame. 
#frame_stack = cam.get_sequence(num_frames=100, exp_time=20)

#timing of get_frame does not increase with roi size. 

def my_get_sequence(cm, num_frames, roi=(1, 1, 200, 200)):
    cm.set_roi(roi[0], roi[1], roi[2], roi[3])
    shape = [roi[3], roi[2]]
    stack = np.empty((num_frames, shape[1], shape[0]), dtype=np.uint8)
    for i in range(num_frames):
        stack[i] = cm.get_frame()
    return stack
    
