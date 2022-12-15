using GLMakie, NIDAQ, ThreadPools, Statistics, DataStructures, Dates, CSV, Tables

#DATA FOlDER

DATA_SAVE="/home/"*ENV["USER"]*"/data/"

#CONSTANTS
SAMPLE_RATE=10000 #sampling rate into DAQ buffer
DISPLAY_TS=SAMPLE_RATE*5 #plot width
DT=1/SAMPLE_RATE 
READ_RATE=100 #sampling from DAQ buffer (per read, not per unit time)
PLOT_TS=500 #update plot after multiple reads. should be lower than DISPLAY_TS so that the whole plot does not get overwritten

# Input = AxoClamp => Cell (NIDAQ Out)
# Output = Cell => AxoClamp (NIDAQ In)

I_c = 1

#AXES_LIMITS

#A_B_C_D:
#A=V-Clamp/I-Clamp
#B=Input/Outout
#C=X/Y Axis
#D=LOW/HIGH

X_L=-DISPLAY_TS*DT
X_H=0


Y_L=-1
Y_H=6


#OBSERVABLES
mode = Observable(5.0)
recording=Observable(false)
MASTER_SWITCH=Observable(true)
update=Observable(1)


#HELPER FUNCTIONS

#NIDAQ SETUP
function reset_nidaq()
	try
		clear(a_in)
		clear(a_out)
	catch
	end
	global a_in=analog_input("Dev2/ai0")
	global a_out=analog_output("Dev2/ao0")

	NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE*10)

	NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE*10)

	start(a_out)
	NIDAQ.write(a_out,[0.0])
end

function reset_vars()
	#DATA
	global i_vec=zeros(1)
	global t_vec=Vector(-DISPLAY_TS:-1)*DT
	global i_buf=CircularBuffer{Float64}(DISPLAY_TS)
	fill!(i_buf,0)
	#RESET OBSERVABLE VALUES
	recording[]=false
	notify(update)
end

function generate_pulse(width, isi, amplitude, number)
    x=zeros(Int(round(SAMPLE_RATE*isi)))
    y=zeros(Int(round(SAMPLE_RATE*width)))
	x=vcat(x, y.+amplitude*I_c)
	out=x
	for i in 2:number
		out=vcat(out,x)
    end
    push!(out,0.0)
	return out
end

function save_data()
	if recording[]
		println("Stop recording before saving data.")
	else
		save_dir=SAVE_DATA*Dates.format(now(),"yyyy-mm-dd-HH-MM-SS")
		mkdir(save_dir)
		println("Description:")
		desc=readline()
		open(save_dir*"/desc.txt","w") do io
			   write(io,desc)
		end
		CSV.write(save_dir*"/data.csv",Tables.table(hcat(i_vec,o_vec,m_vec)),header=["Input","Output","Mode"]) 
	end
end


function stim_pulse(h,w,i,n)
	stim=generate_pulse(w,i,h,n)
	dur=w*2*n+0.1
	NIDAQ.write(a_out,stim)
	sleep(dur)
end

function read_loop()
	read_length=0
	println("STARTED \n")
	while MASTER_SWITCH[]
		data = NIDAQ.read(a_in)
		append!(i_buf,data/I_c)
		if recording[]
			append!(i_vec,data)
		end
		read_length+=size(data)[1]
		if read_length>=PLOT_TS
			notify(update)
			read_length=0
		end
		sleep(0.001)
	end
	println("STOPPED \n")
	stop(a_in)
end

function bye()
	MASTER_SWITCH=false
	sleep(0.5)
	exit()
end

#PLOT ELEMENTS

fontsize_theme = Theme(fontsize = 20)
set_theme!(fontsize_theme)

figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1:2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()


ax_i=Axis(a[1,1],ylabel="Voltage",xlims=(X_L,X_H), ylims=(Y_L,Y_H))

xlims!(ax_i,X_L,X_H)
ylims!(ax_i,Y_L,Y_H)


stim_i=Textbox(c[5,:], placeholder="I",validator = Float64,tellwidth=false, textsize=24)
stim_n=Textbox(c[6,:], placeholder="N",validator = Int,tellwidth=false,textsize=24)

stim_trig=Button(c[7,:], label="Stimulate", textsize=30, tellwidth=false) 


switch=Button(c[11,:], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellwidth=false) 

#LISTENERS
on(switch.clicks) do x
	append!(i_vec,zeros(5))
	recording[] = 1-recording[]
#	println("Pressed")
end



on(stim_trig.clicks) do x
	u=0.05
	try
		i,n=parse(Float64,stim_i.stored_string[]),parse(Int,stim_n.stored_string[])
		println("Starting stim protocol\n N:$n, T:$(i*n) s")
		stim_pulse(5.0,u,i-u,n)
	catch
		println("Enter all values.")
	end
end

reset_vars()
reset_nidaq()

lines!(ax_i,t_vec,@lift(i_buf[$update:DISPLAY_TS]))

display(figure)

@tspawnat 1 read_loop()
