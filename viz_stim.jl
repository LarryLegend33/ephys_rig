using GLMakie

figure =Figure()


box=Box(figure, color = RGBf(0.0,0.0,0.0),width=3000,height=3000)


function flash(n,s,isi,r=1.0,g=1.0,b=1.0)
	for i in 1:n
		box.color=RGBf(r,g,b)
		sleep(s)
		box.color=RGBf(0.0,0.0,0.0)
		sleep(isi)
	end
end

function solid(r=0.0,g=0.0,b=0.0)
	box.color=RGBf(r,g,b)
end

display(figure)
