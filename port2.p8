pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
x=20
y=20

vx=0
vy=0

function _draw()
	cls(1)
	line(10,100,30,100,3)
	line(100,10,100,30,3)
	circfill(x,y,5,10)
end

function _update()
	x += vx
	y += vy
	
	vy += 0.3
	
	vx *= 0.92
	
	if y > 100 then
		x = 100
		y = 20
		
		local h = sqrt(vx*vx+vy*vy)
		local a1 = atan2(vx,vy)
		local a2 = a1 - 0.25
		vx = cos(a2) * h
		vy = sin(a2) * h
	end
end

