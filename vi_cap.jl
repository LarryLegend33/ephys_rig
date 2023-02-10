using PVCAM
using GLMakie
using DataStructures
using AMQPClient

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

struct RabServer
    port::Int64
    connection::AMQPClient.Connection
    exchange::String
    routing_key::String
    channel::AMQPClient.MessageChannel
end
    
function RabServer()
    port = AMQPClient.AMQP_DEFAULT_PORT
    amqps = amqps_configure()
    conn = connection(; virtualhost="/", host="localhost", port=port, auth_params=AMQPClient.DEFAULT_AUTH_PARAMS)
    # DO NOT USE THE AUTH PARAMS! 
    EXCG_DIRECT = "amq.direct"
    ROUTE1 = "routingkey1"
    chan1 = channel(conn, 1, true)
    qvarbs = queue_declare(chan1, "fish_queue")
    queue_bind(chan1, "fish_queue", EXCG_DIRECT, ROUTE1)       
    return RabServer(port, conn, EXCG_DIRECT, ROUTE1, chan1)
end

function post_message(server::RabServer, message::String)
    data = convert(Vector{UInt8}, codeunits(message))
    msg = Message(data, content_type="text/plain", delivery_mode=PERSISTENT)
    basic_publish(server.channel, msg; exchange=server.exchange, routing_key=server.routing_key)
end


cv.VideoWriter()

# note that 1200x1200 UInt8 goes into an hdf5 at ~1.4-1.9 msec.
# using VideoIO takes 10-14 milliseconds. but its probably a good idea at the end of the run to write a video from HDF5.
# to use hdf5,
#      file = h5open("test.h5", "w")
#      write(file, "1", myarr)
#      when you're done, close file. 

