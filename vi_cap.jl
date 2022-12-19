using PVCAM
using GLMakie
using DataStructures

function start_image_session()
    polled_cont!()
end

function cap_and_show()
    f = latest_frame()
    im = reshape(f, (1200, 1200))
    image(im)
    return im
end

function live_image()
    framerate = 100
    f = latest_frame()
    im = reshape(f, (1200, 1200))
    image_buffer = CircularBuffer{typeof(im)}(5)
    image_figure = Figure(resolution=(1200,1200), outer_padding=0)
    image_axis = Axis(image_figure[1,1])
    curr_image = Observable(im)
    imshown = image!(image_axis, curr_image)
    #    record(gt_scene, "stimulus.mp4", 1:size(dotmotion)[1]; framerate=60) do i
    #    for i in 1:size(dotmotion)[1]
    display(image_figure)
    stop_anim = false
    on(events(image_figure).keyboardbutton) do event
        if event.key == Keyboard.enter
            stop_anim = true
        end
    end
    i = 0
    while(!stop_anim)
        i += 1
        f = latest_frame()
        im = reshape(f, (1200, 1200))
        curr_image[] = im
        sleep(1/framerate)
    end   
end
