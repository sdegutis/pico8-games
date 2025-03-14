pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- jelpi demo
-- by zep

level 1

nun_players = 1
corrupt_mode = false
paint_mode = false
max_actors = 64
play_music = true

function make_actor(k,x,y,d)
	local a = {
		k=k,
		frame=0,
		frames=4,
		life = 1,
		hit_t=0,
		x=x,y=y,dx=0,dy=0,
		homex=x,homey=y,
		ddx = 0.02, -- acceleration
		ddy = 0.06, -- gravity
		w=3/8,h=0.5, -- half-width
		d=d or -1, -- direction
		bounce=0.8,
		friction=0.9,
		can_bump=true,
		dash=0,
		super=0,
		t=0,
		standing = false,
		draw=draw_actor,
		move=move_actor,
	}
	
	-- attributes by flag
	
	if (fget(k,6)) then
		a.is_pickup=true
	end
	
	if (fget(k,7)) then
		a.is_monster=true
		a.move=move_monster
	end
	
	if (fget(k,4)) then
		a.ddy = 0 -- zero gravity
	end
	
	-- attributes from actor_dat
	
	for k,v in pairs(actor_dat[k])
	do
		a[k]=v
	end
	
	if (#actor < max_actors) then
		add(actor, a)
	end
	
	return a
end

function make_sparkle(k,x,y,col)
	local s = {
		x=x,y=y,k=k,
		frames=1,
		col=col,
		t=0, max_t = 8+rnd(4),
		dx = 0, dy = 0,
		ddy = 0
	}
	if (#sparkle < 512) then
		add(sparkle,s)
	end
	return s
end

function make_player(k, x, y, d)

	local a = make_actor(k, x, y, d)
	
	a.is_player=true
	a.move=move_player

	a.score   = 0
	a.bounce  = 0
	a.delay   = 0
	a.id      = 0 -- player 1

	
	return a
end




-- called at start by pico-8
function _init()

	init_actor_data() 
	init_level(level)
	
	menuitem(1,
	"restart level",
	function()
		init_level(level)
	end)
		
end

-- clear_cel using neighbour val
-- prefer empty, then non-ground
-- then left neighbour

function clear_cel(x, y)
	local val0 = mget(x-1,y)
	local val1 = mget(x+1,y)
	if ((x>0 and val0 == 0) or 
					(x<127 and val1 == 0)) then
		mset(x,y,0)
	elseif (not fget(val1,1)) then
		mset(x,y,val1)
	elseif (not fget(val0,1)) then
		mset(x,y,val0)
	else
		mset(x,y,0)
	end
end


function move_spawns(x0, y0)

	x0=flr(x0)
	y0=flr(y0)
	
	-- spawn actors close to x0,y0

	for y=0,16 do
		for x=x0-10,max(16,x0+14) do
			local val = mget(x,y)
			
			-- actor
			if (fget(val, 5)) then    
				m = make_actor(val,x+0.5,y+1)
				clear_cel(x,y)
			end
			
		end
	end

end

-- test if a point is solid
function solid (x, y, ignore)

	if (x < 0 or x >= 128 ) then
		return true end
	
	local val = mget(x, y)
	
	-- flag 6: can jump up through
	-- (and only top half counts)	
	if (fget(val,6)) then
		if (ignore) return false
		-- bottom half: solid iff solid below
		if (y%1 > 0.5) return solid(x,y+1)
	end
	
	return fget(val, 1)
end

-- solidx: solid at 2 points
-- along x axis
local function solidx(x,y,w)
	return solid(x-w,y) or
		solid(x+w,y)
end


function move_player(pl)

	move_actor(pl)
	
	if (pl.y > 18) pl.life=0

	local b = pl.id

	if (pl.life <= 0) then
				
				for i=1,32 do
					s=make_sparkle(69,
						pl.x, pl.y-0.6)
					s.dx = cos(i/32)/2
					s.dy = sin(i/32)/2
					s.max_t = 30 
					s.ddy = 0.01
					s.frame=69+rnd(3)
					s.col = 7
				end
				
				sfx(17)
				pl.death_t=time()
				
				
		return
	end
	
	local accel = 0.05
	local q=0.7
	
	if (pl.dash > 10) then
		accel = 0.08
	end
	
	if (pl.super > 0) then 
		q*=1.5
		accel*=1.5
	end
	
	if (not pl.standing) then
		accel = accel / 2
	end
		
	-- player control
	if (btn(0,b)) then 
			pl.dx = pl.dx - accel; pl.d=-1 end
	if (btn(1,b)) then 
		pl.dx = pl.dx + accel; pl.d=1 end

	if ((btn(4,b)) and 
		pl.standing) then
		pl.dy = -0.7
		sfx(8)
	end

	-- charge

	if (btn(5,b) and pl.delay == 0)
	then
		pl.dash = 15
		pl.delay= 20
		-- charge in dir of buttons
		dx=0 dy=0
		if (btn(0,b)) dx-=1*q
		if (btn(1,b)) dx+=1*q
		
		-- keep controls to 4 btns
		if (btn(2,b)) dy-=1*q
		if (btn(3,b)) dy+=1*q
		
		if (dx==0 and dy==0) then
			pl.dx += pl.d * 0.4
		else
			local aa=atan2(dx,dy)
			pl.dx += cos(aa)/2
			pl.dy += sin(aa)/3
			
			pl.dy=max(-0.5,pl.dy)
		end
		
		-- tiny extra vertical boost
		if (not pl.standing) then
			pl.dy = pl.dy - 0.2
		end 
	
		sfx(11)
	
	end
	
	-- super: give more dash
	
	if (pl.super > 0) pl.dash=2
	
	-- dashing
	
	if pl.dash > 0 then
		
		if (abs(pl.dx) > 0.4 or
						abs(pl.dy) > 0.2
		) then
		
		for i=1,3 do
			local s = make_sparkle(
				69+rnd(3),
				pl.x+pl.dx*i/3, 
				pl.y+pl.dy*i/3 - 0.3,
				(pl.t*3+i)%9+7)
			if (rnd(2) < 1) then
				s.col = 7
			end
			s.dx = -pl.dx*0.1
			s.dy = -0.05*i/4
			s.x = s.x + rnd(0.6)-0.3
			s.y = s.y + rnd(0.6)-0.3
		end
		end
	end 
	
	pl.dash = max(0,pl.dash-1)
	pl.delay = max(0,pl.delay-1)
	pl.super = max(0, pl.super-1)
	
	-- frame	

	if (pl.standing) then
		pl.frame = (pl.frame+abs(pl.dx)*2) % pl.frames
	else
		pl.frame = (pl.frame+abs(pl.dx)/2) % pl.frames
	end
	
	if (abs(pl.dx) < 0.1) pl.frame = 0
	
end

function move_monster(m)
	
	move_actor(m)
	
	if (m.life<=0) then
		bang_puff(m.x,m.y-0.5,104)

		sfx(14)
		return
	end
	

	m.dx = m.dx + m.d * m.ddx

	m.frame = (m.frame+abs(m.dx)*3+4) % m.frames
	
	-- jump
	if (false and m.standing and rnd(10) < 1)
	then
		m.dy = -0.5
	end
	
	-- hit cooldown
	-- (can't get hit twice within
	--  half a second)
	if (m.hit_t>0) m.hit_t-=1

end


function smash(x,y,b)

		local val = mget(x, y, 0)
		if (not fget(val,4)) then
			-- not smashable
			-- -> pass on to solid()
			return solid(x,y,b)
		end    
		
		
		-- spawn
		if (val == 48) then
			local a=make_actor(
				loot[#loot],
				x+0.5,y-0.2)
			
			a.dy=-0.8
			a.d=flr(rnd(2))*2-1
			a.d=0.25 -- swirly
			loot[#loot]=nil
		end
		
				
		clear_cel(x,y)
		sfx(10)
			
		-- make debris
		
		for by=0,1 do
			for bx=0,1 do
				s=make_sparkle(22,
				0.25+flr(x) + bx*0.5, 
				0.25+flr(y) + by*0.5,
				0)
				s.dx = (bx-0.5)/4
				s.dy = (by-0.5)/4
				s.max_t = 30 
				s.ddy = 0.02
			end
		end

		return false -- not solid
end

function move_actor(a)

	if (a.life<=0) del(actor,a)
	
	a.standing=false
	
	-- when dashing, call smash()
	-- for any touched blocks
	-- (except for landing blocks)
	local ssolid=
		a.dash>0 and smash or solid 
	
	-- solid going down -- only
	-- smash when holding down
	local ssolidd=
		a.dash>0 and (btn(3,a.id))
		 and smash or solid 
		
	--ignore jump-up-through
	--blocks only when have gravity
	local ign=a.ddy > 0
	
	-- x movement 
	
	-- candidate position
	x1 = a.x + a.dx + sgn(a.dx)/4
	
	if not ssolid(x1,a.y-0.5,ign)
	then
		-- nothing in the way->move
		a.x += a.dx 
		
	else -- hit wall
	
		-- bounce
		if (a.dash > 0)sfx(12) 
		a.dx *= -1
		
		a.hit_wall=true
		
		-- monsters turn around
		if (a.is_monster) then
			a.d *= -1
			a.dx = 0
		end
		
	end
	
	-- y movement
	
	local fw=0.25

	if (a.dy < 0) then
		-- going up
		
		if (
		 ssolid(a.x-fw, a.y+a.dy-1,ign) or
		 ssolid(a.x+fw, a.y+a.dy-1,ign))
		then
			a.dy=0
			
			-- snap to roof
			a.y=flr(a.y+.5)
			
		else
			a.y += a.dy
		end

	else
		-- going down
	
		local y1=a.y+a.dy
		if ssolidd(a.x-fw,y1) or
		   ssolidd(a.x+fw,y1)
		then
		
			-- bounce
			if (a.bounce > 0 and 
			    a.dy > 0.2) 
			then
				a.dy = a.dy * -a.bounce
			else
			
			a.standing=true
			a.dy=0
			end
			
			-- snap to top of ground
			a.y=flr(a.y+0.75)	
			
		else
			a.y += a.dy  
		end
		-- pop up
		
		while solid(a.x,a.y-0.05) do
			a.y -= 0.125
		end

	end


	-- gravity and friction
	a.dy += a.ddy
	a.dy *= 0.95

	-- x friction

	a.dx *= a.friction
	if (a.standing) then
		a.dx *= a.friction
	end

--end
	
	-- counters
	a.t = a.t + 1
end


function monster_hit(m)
	if(m.hit_t>0) return
	
	m.life-=1
	m.hit_t=15
	m.dx/=4
	m.dy/=4
	-- survived: thunk sound
	if (m.life>0) sfx(21)
	
end

function player_hit(p)
		if (p.dash>0) return
		p.life-=1
end

function collide_event(a1, a2)

	if (a1.is_monster and
					a1.can_bump and
					a2.is_monster) then
					local d=sgn(a1.x-a2.x)
					if (a1.d!=d) then
						a1.dx=0
						a1.d=d
					end
	end
	
	-- bouncy mushroom
	if (a2.k==82) then
		if (a1.dy > 0 and 
		not a1.standing) then
			a1.dy=-1.1
			a2.active_t=6
			sfx(18)
		end
	end

	if(a1.is_player) then
		if(a2.is_pickup) then

			if (a2.k==64) then
				a1.super = 30*4
				--sfx(17)
				a1.dx = a1.dx * 2
				--a1.dy = a1.dy-0.1
				-- a1.standing = false
				sfx(13)
			end

			-- watermelon
			if (a2.k==80) then
				a1.score+=5
				sfx(9)
			end
			
			-- end level
			if (a2.k==65) then
				finished_t=1
				bang_puff(a2.x,a2.y-0.5,108)
				del(actor,pl[1])
				del(actor,pl[2])
				music(-1,500)
				sfx(24)
			end
			
			-- glitch mushroom
			if (a2.k==84) then
				glitch_mushroom = true
				sfx(29)
			end
			
			-- gem
			if (a2.k==67) then
				a1.score = a1.score + 1
				
				-- total gems between players
				gems+=1
				
			end
			
			-- bridge builder
			if (a2.k==99) then
				local x,y=flr(a2.x)+.5,flr(a2.y+0.5)
				for xx=-1,1 do
				if (mget(x+xx,y)==0) then
					local a=make_actor(53,x+xx,y+1)
					a.dx=xx/2
				end
				end
			end
			
			a2.life=0
			
			s=make_sparkle(85,a2.x,a2.y-.5)
			s.frames=3
			s.max_t=15
			sfx(9)
		end
		
		-- charge or dupe monster
		
		if(a2.is_monster) then -- monster
			
			if(
					(a1.dash > 0 or 
						a1.y < a2.y-a2.h/2)
					and a2.can_bump
				) then
				
				-- slow down player
				a1.dx *= 0.7
				a1.dy *= -0.7
				
				if (btn(🅾️,a1.id))a1.dy -= .5
				
				monster_hit(a2)
				
			else
				-- player death
				a1.life=0
				
			end
		end
			
	end
end

function move_sparkle(sp)
	if (sp.t > sp.max_t) then
		del(sparkle,sp)
	end
	
	sp.x = sp.x + sp.dx
	sp.y = sp.y + sp.dy
	sp.dy= sp.dy+ sp.ddy
	sp.t = sp.t + 1
end


function collide(a1, a2)
	if (not a1) return
	if (not a2) return
	
	if (a1==a2) then return end
	local dx = a1.x - a2.x
	local dy = a1.y - a2.y
	if (abs(dx) < a1.w+a2.w) then
		if (abs(dy) < a1.h+a2.h) then
			collide_event(a1, a2)
			collide_event(a2, a1)
		end
	end
end

function collisions()

	-- to do: optimize if too
	-- many actors

	for i=1,#actor do
		for j=i+1,#actor do
			collide(actor[i],actor[j])
		end
	end
	
end



function outgame_logic()

	if death_t==0 and
			not alive(pl[1]) and 
			not alive(pl[2]) then
			death_t=1
			music(-1)
			sfx(5)
			
	end

	if (finished_t > 0) then
	
		finished_t += 1
		
		if (finished_t > 60) then
			if (btnp(❎)) then
				fade_out()
				init_level(level+1)
			end
		end
	
	end

	if (death_t > 0) then
		death_t = death_t + 1
		if (death_t > 45 and 
			btn()>0)
		then 
				music(-1)
				sfx(-1)
				sfx(0)
				fade_out()
				
				
				-- restart cart end of slice
				init_level(level)
			end
	end
	
end

function _update() 
	
	for a in all(actor) do
		a:move()
	end
		
	foreach(sparkle, move_sparkle)
	collisions()
	
	for i=1,#pl do
		move_spawns(pl[i].x,0)
	end
	
	outgame_logic()
	update_camera()

	if (glitch_mushroom or corrupt_mode) then
		for i=1,4 do
			poke(rnd(0x8000),rnd(0x100))
		end
	end
	
	level_t += 1
end



function _draw()

	cls(12)
	
	-- view width
	local vw=split and 64 or 128

	cls()
	
	-- decide which side to draw
	-- player 1 view
	local view0_x = 0
	if (split and pl[1].x>pl[2].x)
	then view0_x = 64 end
	
	-- player 1 (or whole screen)
	draw_world(
		view0_x,0,vw,128,
		cam_x,cam_y)
	
	-- player 2 view if needed
	if (split) then
		cam_x = pl_camx(pl[2].x,64)
		draw_world(64-view0_x,0,vw,128,
			cam_x, cam_y)
	end
	
	camera()pal()clip()
	if (split) line(64,0,64,128,0)

	-- player score
	camera(0,0)
	color(7)
	
	if (death_t > 45) then
		print("❎ restart",
			44,10+1,14)
		print("❎ restart",
			44,10,7)
	end
	
	if (finished_t > 0) then
		draw_finished(finished_t)
	end
	
	if (paint_mode) apply_paint()

	draw_sign()
end


sign_str={
"",
[[
	this is an empty level!
	use the map editor to add
	some blocks and monsters.
	in the code editor you
	can also set level=2
	]],
"",
[[
	this is not a level!
	
	the bottom row of the map 
	in this cartridge is used
	for making backgrounds.
]]
}

function draw_sign()

if (mget(pl[1].x,pl[1].y-0.5)!=25) return

rectfill(8,6,120,46,0)
rect(8,6,120,46,7)

print(sign_str[level],12,12,6)


end


function fade_out()

	dpal={0,1,1, 2,1,13,6,
							4,4,9,3, 13,1,13,14}
	
	
					
	-- palette fade
	for i=0,40 do
		for j=1,15 do
			col = j
			for k=1,((i+(j%5))/4) do
				col=dpal[col]
			end
			pal(j,col,1)
		end
		flip()
	end
	
end
-->8
-- draw world

function draw_sparkle(s)

	--spinning
	if (s.k == 0) then
		local sx=s.x*8
		local sy=s.y*8
		
		line(sx,sy,
				sx+cos(s.t*s.spin)*1.4,
				sy+sin(s.t*s.spin)*1.4,
				s.col)
				
		return
	end
	
	if (s.col and s.col > 0) then
		for i=1,15 do
			pal(i,s.col)
		end
	end

	local fr=s.frames * s.t/s.max_t
	fr=s.k+mid(0,fr,s.frames-1)
	spr(fr, s.x*8-4, s.y*8-4)

	pal()
end

function draw_actor(a)

	local fr=a.k + a.frame

	-- rainbow colour when dashing
	if (a.dash>0) for i=2,15 do pal(i,7+((a.t/2) % 8)) end
	
	local sx=a.x*8-4
	local sy=a.y*8-8
	
	-- sprite flag 3 (green):
	-- draw one pixel up
	if (fget(fr,3)) sy-=1

	-- draw the sprite
	spr(fr, sx,sy,1,1,a.d<0)

	-- sprite flag 2 (yellow):
	-- repeat top line
	-- (for mimo's ears!)
	
	if (fget(fr,2)) then
		pal(14,7)
		spr(fr,sx,sy-1,1,1/8,
						a.d<0)
	end
	
	pal()
end

function draw_tail(a)

	draw_actor(a)
	
	local sx=a.x*8
	local sy=a.y*8-2
	local d=-a.d
	sx += d*3
	if (a.d>0) sx-=1
	
	for i=0,4,2 do
		pset(sx+i*d*1,
		  sy + cos(i/16-time())*
		  (1+i)*abs(a.dx)*4,7)
	end
	
end


function apply_paint()
	if (tt==nil) tt=0
	tt=tt+0.25
	srand(flr(tt))
	local nn=rnd(128)
	local xx=0
	local yy=nn&127
	for i=1,1000*13,13 do
		nn+=i
		nn*=33
		xx=nn&127
		local col=pget(xx,yy)
		rectfill(xx,yy,xx+1,yy+1,col)
		line(xx-1,yy-1,xx+2,yy+2,col)
		nn+=i
		nn*=57
		yy=nn&127
		rectfill(xx-1,yy-1,xx,yy,pget(xx,yy))
			
	end
end

-- draw the world at sx,sy
-- with a view size: vw,vh
function draw_world(
		sx,sy,vw,vh,cam_x,cam_y)

	-- reduce jitter
	cam_x=flr(cam_x) 
	cam_y=flr(cam_y)
	
	if (level>=4) cam_y = 0
	
	clip(sx,sy,vw,vh)
	cam_x -= sx
	
	local ldat=theme_dat[level]
	if (not ldat) ldat={}
	
	-- sky
	camera (cam_x/4, cam_y/4)
	
	-- sample palette colour
	local colx=120+level
	
	-- sky gradient
	if (ldat.sky) then
		for y=cam_y,127 do
			col=ldat.sky[
				flr(mid(1,#ldat.sky,
					(y+(y%4)*6) / 16))]
				
			line(0,y,511,y,col)
		end
	end
	
	-- elements
	
	
	for pass=0,1 do
	camera()
	
	for el in all(ldat.bgels) do
	
	if (pass==0 and el.xyz[3]>1) or
	   (pass==1 and el.xyz[3]<=1)
	then
	
		pal()
		if (el.cols) then
		for i=1,#el.cols, 2 do
			if (el.cols[i+1]==-1) then
				palt(el.cols[i],true)
			else
				pal(el.cols[i],el.cols[i+1])
			end
		end
		end
		
		local s=el.src
		local pixw=s[3] * 8
		local pixh=s[4] * 8
		local sx=el.xyz[1]
		if (el.dx) then
			sx += el.dx*t()
		end
		local sy=el.xyz[2]
		
		sx = (sx-cam_x)/el.xyz[3]
		sy = (sy-cam_y)/el.xyz[3]
		
		repeat
			map(s[1],s[2],sx,sy,s[3],s[4])
			if (el.fill_up) then
				rectfill(sx,-1,sx+pixw-1,sy-1,el.fill_up)
			end
			if (el.fill_down) then
				rectfill(sx,sy+pixh,sx+pixw-1,128,el.fill_down)
			end
			sx+=pixw
		
		until sx >= 128 or not el.xyz[4] 
	
	end
	end
	pal()
	
		if (pass==0) then
			draw_z1(cam_x,cam_y)
		end
	end
	

	
	clip()
	
end
	

-- map and actors
function draw_z1(cam_x,cam_y)
	
	camera (cam_x,cam_y)
	pal(12,0)	-- 12 is transp
	map (0,0,0,0,128,64,0)
	pal()
	foreach(sparkle, draw_sparkle)
	for a in all(actor) do
		pal()
		if (a.hit_t>0 and a.t%4 < 2) then
			for i=1,15 do
				pal(i,8+(a.t/4)%4)
			end
		end
		a:draw() -- same as a.draw(a)
	end
	-- forground map
	map (0,0,0,0,128,64,1)
end


-->8
-- explosions

function bang_puff(mx,my,sp)

	local aa=rnd(1)
	for i=0,5 do
	
		local dx=cos(aa+i/6)/4
		local dy=sin(aa+i/6)/4
		local s=make_sparkle(
			sp,mx + dx, my + dy) 
		s.dx = dx
		s.dy = dy
		s.max_t=10
	end
	
end

function atomize_sprite(s,mx,my,col)

	local sx=(s%16)*8
	local sy=flr(s/16)*8
	local w=0.04
	
	for y=0,7 do
		for x=0,7 do
			if (sget(sx+x,sy+y)>0) then
				local q=make_sparkle(0,
					mx+x/8,
					my+y/8)
				q.dx=(x-3.5)/32 +rnd(w)-rnd(w)
				q.dy=(y-7)/32   +rnd(w)-rnd(w)
				q.max_t=20+rnd(20)
				q.t=rnd(10)
				q.spin=0.05+rnd(0.1)
				if (rnd(2)<1) q.spin*=-1
				q.ddy=0.01
				q.col=col or sget(sx+x,sy+y)
			end
		end
	end

end
-->8
-- camera

-- (camera y is lazy)
ccy_t=0
ccy  =0

-- splitscreen (multiplayer)
split=false

-- camera x for player i
function pl_camx(x,sw)
	return mid(0,x*8-sw/2,1024-sw)
end


function update_camera()

	local num=0
	if (alive(pl[1])) num+=1
	if (alive(pl[2])) num+=1
	
	split = num==2 and
		abs(pl_camx(pl[1].x,64) -
		    pl_camx(pl[2].x,64)) > 64
	
	-- camera y target changes
	-- when standing. quantize y
	-- into 2 blocks high so don't
	-- get small adjustments
	-- (should be in _update)
	
	if (num==2) then
		-- 2 active players: average y
		ccy_t=0
		for i=1,2 do
			ccy_t += (flr(pl[i].y/2+.5)*2-12)*3
		end
		ccy_t/=2
	else
	
		-- single: set target only
		-- when standing
		for i=1,#pl do
			if (alive(pl[i]) and
			    pl[i].standing) then
			    ccy_t=(
			     flr(pl[i].y/2+.5)*2-12
			    )*3
			end
		end
	end
	
	-- target always <= 0
	ccy_t=min(0,ccy_t)
	
	ccy = ccy*7/8+ccy_t*1/8
	cam_y = ccy
	
	local xx=0
	local qq=0
	for i=1,#pl do
			if (alive(pl[i])) then
				local q=1
				
				-- pan across when first
				-- player dies and not in
				-- split screen
				if (pl[i].life<=0 and pl[i].death_t) then
					q=time()-pl[i].death_t
					q=mid(0,1-q*2,1)
					q*=q
				end
				
				xx+=pl[i].x * q
				qq += q
			end
	end
	
	if (split) then
		cam_x = pl_camx(pl[1].x,64)
	elseif qq>0 then
		cam_x = pl_camx(xx/qq,128)
	end
	
end
-->8
-- actors

function init_actor_data()

function dummy() end

actor_dat=
{
	-- bridge builder
	[53]={
		ddy=0,
		friction=1,
		move=move_builder,
		draw=dummy
	},
	
	[64]={
		draw=draw_charge_powerup
	},
	
	[65]={
		draw=draw_exit
	},
	
	-- swirly
	[80]={
		life=2,
		frames=1,
		bounce=0,
		ddy=0, -- gravity
		move=move_swirly,
		draw=draw_swirly,
		can_bump=false,
		d=0.25,
		r=5 -- collisions
	},
	
	-- bouncy mushroom
	[82]={
		ddx=0,
		frames=1,
		active_t=0,
		move=move_mushroom
	},
	
	-- glitch mushroom
	[84]={
		draw=draw_glitch_mushroom
	},
	
	-- bird
	[93]={
		move=move_bird,
		draw=draw_bird,
		
		bounce=0,
		ddy=0.03,-- default:0.06
	},
	
	-- frog
	[96]={
		move=move_frog,
		draw=draw_frog,
		bounce=0,
		friction=1,
		tongue=0,
		tongue_t=0
	},
	
	[116]={
		draw=draw_tail
	}

}

end



function move_builder(a)
	
	local x,y=a.x,a.y-0.5
	local val=mget(x,y)
	if val==0 then
		mset(x,y,53)
		sfx(19)
	elseif val!=53
	then
		del(actor,a)
	end
	a.t += 1
	
	if (x<1 or x>126 or a.t > 30)
	then del(actor,a) end 
	
	for i=0,0.2,0.1 do
	local s=make_sparkle(
			104,a.x,a.y-0.5)   
	s.dx=cos(i+a.x/4)/8
	s.dy=sin(i+a.x/4)/8
	s.col=10
	s.max_t=10+rnd(10)
	end
	
	a.x+=a.dx
end

function move_frog(a)

	move_actor(a)
	
	if (a.life<=0) then
		bang_puff(a.x,a.y-0.5,104)
		sfx(26)
	end

	a.frame=0
	
	local p=closest_p(a,16)
	

	if (a.standing) then
		a.dy=0 a.dx=0
		
		-- jump
		
		if (rnd(20)<1 and
						a.tongue_t==0) then -- jump freq
			-- face player 2/3 times
			if rnd(3)<2 and p then
				a.d=sgn(p.x-a.x)
			end
			a.dy=-0.6-rnd(0.4)
			a.dx=a.d/4
			a.standing=false
			sfx(23)
		end
	else
		a.frame=1
	end
		
	-- move tongue
	
	-- stick tongue out when standing
	if a.tongue_t==0 and
				p and abs(a.x-p.x)<5 and
				rnd(20)<1 and
				a.standing then
		a.tongue_t=1
	end
	
	-- move active tongue
	if (a.tongue_t>0) then
		a.frame=2
		a.tongue_t = (a.tongue_t+1)%24
		local tlen = sin(a.tongue_t/48)*5
		a.tongue_x=a.x-tlen*a.d

		-- catch player
		
		if not a.ha and p then
			local dx=p.x-a.tongue_x
			local dy=p.y-a.y
			if (dx*dx+dy*dy<0.7^2)
			then a.ha=p sfx(22) end
		end
		
		-- skip to retracting
		if (solid(a.tongue_x,
						a.y-.5) and 
				a.tongue_t < 11) then
				a.tongue_t = 24-a.tongue_t
		end
	end
	
	-- move caught actor
	if (a.ha) then
		if (a.tongue_t>0) then
			a.ha.x = a.tongue_x
			a.ha.y = a.y
		else
			a.ha=nil
		end
	end
	
	--a.tongue=1 -- tiles
	
	a.t += 1
end


function draw_frog(a)
	draw_actor(a)
	
	local sx=a.x*8+a.d*4
	local sy=a.y*8-3
	local d=a.d
	
	
	if (a.tongue_t==0 or not a.tongue_t) return
	
	local sx2=a.tongue_x*8
	local sy2=(a.y+0.25)*8
	line(sx,sy,sx2,sy,8)
	rectfill(sx2,sy,sx2+d,sy-1,14)
end

function draw_charge_powerup(a)
	--pal(6,13+(a.t/4)%3)
	draw_actor(a)
	local sx=a.x*8
	local sy=a.y*8-4
	for i=0,5 do
		circfill(
			sx+cos(i/6+time()/2)*5.5,
			sy+sin(i/6+time()/2)*5.5,
			(i+time()*3)%1.5,7)
		end
		
end

function move_mushroom(a)
	a.frame=0
	if (a.active_t>0) then
		a.active_t-=1
		a.frame=1
	end
end

function draw_glitch_mushroom(a)
	local sx=a.x*8
	local sy=a.y*8-4
	
	draw_actor(a)


	dx=cos(time()*5)*3
	dy=sin(time()*3)*3
	
	for y=sy-12,sy+12 do
	for x=sx-12,sx+12 do
		local d=sqrt((y-sy)^2+(x-sx)^2)
		if (d<12 and 
			cos(d/5-time()*2)>.4) then
		pset(x,y,pget(x+dx,y+dy)
		+rnd(1.5))
--  pset(x,y,rnd(16))
		end
	end
	end
	
	pset(sx,sy,rnd(16))
	
	draw_actor(a)
end

function draw_exit(a)
	local sx=a.x*8
	local sy=a.y*8-4
	
	sy += cos(time()/2)*1.5
	
	circfill(sx-1+cos(time()*1.5),sy,3.5+cos(time()),8)
	circfill(sx+1+cos(time()*1.3),sy,3.5+cos(time()),12)
	circfill(sx,sy,3,7)
	
	for i=0,3 do
		circfill(
			sx+cos(i/8+time()*.6)*6,
			sy+sin(i/5+time()*.4)*6,
			1.5+cos(i/7+time()),
			8+i%5)
		circfill(
			sx+cos(.5+i/7+time()*.9)*5,
			sy+sin(.5+i/9+time()*.7)*5,
			.5+cos(.5+i/7+time()),
			14+i%2)
	end
	
end


function turn_to(a,ta,spd)
	
	a %=1 
	ta%=1
	
	while (ta < a-.5) ta += 1
	while (ta > a+.5) ta -= 1
	
	if (ta > a) then
		a = min(ta, a + spd)
	else
		a = max(ta, a - spd)
	end
	
	return a
end

function move_swirly(a)

	-- dying
	if (a.life==0 and a.t%4==0) then
		
		local tail=a.tail[1] 
		local s=tail[#tail]
		
		local cols= {7,15,14,15}
		-- reuse
		atomize_sprite(64,s.x-.5,s.y-.5,cols[1+#tail%#cols])
		del(tail,s) sfx(26)
		if (s==a) del(actor,a) sfx(27)
		
	end
	
	local ah=a.holding
	
	if (ah and a.tail and a.tail[1][15]) then
		ah.x=a.tail[1][15].x
		ah.y=a.tail[1][15].y
		
		ah.dy=-0.1 -- don't land
		if (a.standing) ah.x-=a.d/2
		if (ah.life==0) a.holding=nil
	end
	
	a.t += 1
	if (a.hit_t>0) a.hit_t-=1
	
	if (a.t < 20) then
		a.dx *=.95
		a.dy *=.95
	end
	
	a.x+=a.dx
	a.y+=a.dy
	a.dx *=.95
	a.dy *=.95
	
	local tx=a.homex
	local ty=a.homey
	local p=closest_p(a,200)
	if (p) tx,ty=p.x,p.y
	
	-- local variation
-- tx += cos(a.t/60)*3
-- ty += sin(a.t/40)*3
	
	local turn_spd=1/60
	local accel = 1/64
		
	-- charge 3 seconds 
	-- swirl 3 seconds
	if ((a.t%360 < 180
					and a.life > 1) 
					or a.life==0) and
					abs(a.x-tx<12) then
		ty -= 6
	else
		-- heat-seeking
		-- instant turn, but inertia
		-- means still get swirls
		turn_spd=1/30
		accel=1/40
		if (abs(a.x-tx)>12)accel*=1.5
	end
	
	
	a.d=turn_to(a.d,
		atan2(tx-a.x,ty-a.y),
		turn_spd
	)
	

	a.dx += cos(a.d)*accel
	a.dy += sin(a.d)*accel
	
	-- spawn tail
	if (not a.tail) then
		a.tail={}
		for j=1,3 do
		
			a.tail[j]={}
			for i=1,15 do
				local r=5-i*4/15
				r=mid(1,r,4)
				local slen=r/9 + 0.3
				if (j>1) then
					r=r/3 slen=0.3
					--if (i==1) slen=0
				end
				
				local seg={
					x=a.x-cos(a.d)*i/8,
					y=a.y-sin(a.d)*i/8,
					r=r,slen=slen
				}
				
				add(a.tail[j],seg)
				
			end
			a.tail[j][0]=a
		end
		
	end
	
	-- move tail
	
	for j=1,3 do
	for i=1,#a.tail[j] do
		
		local s=a.tail[j][i]
		local h=a.tail[j][i-1]
		local slen=s.len
		local hx = h.x
		local hy = h.y
		
		if (i==1) then
			if (j==2) hx -=.5 --hy-=.7
			if (j==3) hx +=.5 --hy-=.7
		end
		
		local dx=hx-s.x
		local dy=hy-s.y
		
		local aa=atan2(dx,dy)
	
		if (j==2) aa=turn_to(aa,7/8,0.02)
		if (j==3) aa=turn_to(aa,3/8,0.02)
		s.x=hx-cos(aa)*s.slen
		s.y=hy-sin(aa)*s.slen
	end
	end
	
	-- players collide with tail
	
	for i=0,#a.tail[1] do
	for pi=1,#pl do
		local p=pl[pi]
		if (alive(p) and a.life>0 and 
			p.life>0) then
			s = a.tail[1][i]
			local r=s.r/8 -- from pixels
			local dx=p.x-s.x
			local dy=(p.y-0.5)-s.y
			local dd=sqrt(dx*dx+dy*dy)
			local rr=0.5+r
			if (dd<0.5+r) then
					// janky bounce away
					local aa=atan2(dx,dy)
					aa+=rnd(0.4)-rnd(0.4)
					p.dx=cos(aa)/2
					p.dy=sin(aa)/2
					if (p.is_standing) p.dy=min(p.dy,-0.2)
					sfx(19)
					
					if (p.dash>0) then
						if (i==0) monster_hit(a)
					else
						player_hit(p)
					end
					
			end
		end
		end
		end
		
	
end


function draw_swirly(a)

	if (not a.tail) return
	
	for j=1,3 do
	for i=#a.tail[j],1,-1 do
		seg=a.tail[j][i]
		local sx=seg.x*8
		local sy=seg.y*8
		
		cols =  {7,15,14,15,7,7}
		cols2 = {6,14,8,14,6,6}
		local q= a.life==1 and 4 or 6
		local c=1+flr(i-time()*16)%q
		
		if (j>1) then
			if (i%2==0) then
			circfill(sx,sy,1,8)
			else
			pset(sx,sy,10)
			end
		else
			local r=seg.r+cos(i/8-time())/2
			r=mid(1,r,5)
			r=seg.r
			circfill(sx,sy+r/2,r,cols2[c])
			circfill(sx,sy,r,cols[c])
		end
		
	end
	end
	
	local sx=a.x*8
	local sy=a.y*8-4
	--circ(sx,sy+4,5,rnd(16))
	
	-- mouth
	spr(81,sx-4,sy+5+
		flr(cos(a.t/30)))
	-- head
	spr(80,sx-8,sy)
	spr(80,sx+0,sy,1,1,true)
-- 


end

function alive(a)
	if (not a) return false
	if (a.life <=0 and 
		(a.death_t and
			time() > a.death_t+0.5)
		) then return false end
	return true
end

-- ignore everything more than
-- 8 blocks away horizontally
function closest_a(a0,l,attr,maxdx)
	local best
	local best_d
	for i=1,#l do
		if not attr or l[i][attr] then
			local dx=l[i].x-a0.x
			local dy=l[i].y-a0.y
			d=dx*dx+dy*dy
			if (not best or d<best_d)
							and l[i]!=a0
							and l[i].life > 0
							and (not  maxdx or 
											abs(dx)<maxdx)
			then best=l[i] best_d=d end
		end
	end

	
	return best
end

function closest_p(a,dd)
	return closest_a(a,pl,nil,dd)
end


--[[
	birb
	follow player while close
	
	collect 
	
]]
function move_bird(a)

--[[
	-- spawn with gem
	if (a.t==0) then
		gem=make_actor(67,a.x,a.y)
		a.holding=gem
	end
]]

	move_actor(a)
	
	local ah=a.holding
	
	if (ah) then
		ah.x=a.x
		ah.y=a.y+0x0.e
		ah.dy=0
		if (a.standing) ah.x-=a.d/2
		if (ah.life==0) then
			a.holding=nil 
			sfx(28) -- chirp
		end
	end
	
	local p=closest_p(a,12)
	
	dx=100 dy=100
	-- patrol home no target
	tx,ty=
		a.homex+cos(a.t/120)*6,
		a.homey+sin(a.t/160)*4
	
	if (p) tx,ty=p.x,p.y-3
	
	local a2
	
	if (not a.holding) then
		a2=closest_a(a,actor,"is_pickup")
		if a2 and abs(a2.x-a.x)<4 and
					abs(a2.y-a.y)<4 then
			p=nil -- ignore player
			tx,ty=a2.x,a2.y
			if (a.standing) a.dy=-0.1
		else
			a2=nil -- ignore if far
		end
	end

	-- debug
-- a.tx=tx
-- a.ty=ty

	local dx,dy=tx-a.x,ty-a.y 
	local dd=sqrt(dx*dx+dy*dy)
	
	-- pick up
	if (a2 and dd<1) then
		
		a.holding=a2
		sfx(28) -- chirp
	
	end
	
	-- uncomment: pick up player!
	--[[
	if (p) then
		if (dd<0.5) a.holding=p
		if (a.holding==p) then
			if (btn(4,p.id) or btn(5,p.id)) a.holding=nil
			a.d=p.d
		end
	end
	]]
	
	if (a.t%8==0) a.d=sgn(dx)
	
	if (a.standing) then
		a.frame=0
		
		-- jump to start flying
		if (not solid(a.x,a.y+.2))a.dy=-0.2
		if (p and dd<5) a.dy=-0.3
		
		a.dx=0
		
	else
		-- flying
		local tt=a.t%12
		a.frame=1+tt/6
		-- flap
		if (tt==6) then
			local mag=.3 -- slowly decend
			
			-- fly up
			if (dd<4 and a.y>ty) mag=.4
			
			-- wall: fly to top
			if (a.hit_wall)mag=.45
			
			-- player can shoo upwards
			if (p and a.y>ty and not ah) mag=.45
			
			a.hit_wall = false
			a.dy-=mag
		end
	
		
		if (a.dy<0.2) then
			a.dx+=a.d/64
		end
		
	end
	
	a.frame=a.standing and 0 or
			1+(a.t/4)%2

end


function draw_bird(a)
	local q=flr(a.t/8)
	if ((q^2)%11<1) pal(1,15)
	
	draw_actor(a)
	
	-- debug: show target
	--[[
	if (a.tx) then
		local sx=a.tx*8
		local sy=a.ty*8
		circfill(sx,sy,1,rnd(16))
	end
	]]
end
-->8
-- themes (backgrounds)


theme_dat={

[1]={
	sky={12,12,12,12,12},
	bgels={
	
	{
		-- clouds
		src={16,56,16,8},
		xyz = {0,28*4,4,true},
		dx=-8,
		cols={15,7,1,-1},
		fill_down = 12
	},
	-- mountains
	{src={0,56,16,8},
		xyz = {0,28*4,4,true},
		fill_down=13,
	},
	
	-- leaves: light
	{src={32,48,16,6},
		xyz = {(118*8),-8,1.5},
		cols={1,3},
		fill_up=1
	},
	
	-- leaves: dark (foreground)
	{src={32,48,16,6},
		xyz = {(118*8),-12,0.8},
		cols={3,1},
		fill_up=1
	},
	
		
	}
},

--------------------------
-- level 2

[2]={
	sky={12},
	bgels={
	
	{
		-- gardens
		src={32,56,16,8},
		xyz = {0,100,4,true},
		--cols={7,6,15,6},
		cols={3,13,7,13,10,13,1,13,11,13,9,13,14,13,15,13,2,13},
		
		fill_down=13
	},
	{
		-- foreground shrubbery
		src={16,56,16,8},
		xyz = {0,64*0.8,0.6,true},
		cols={15,1,7,1},
		fill_down = 12
	},
	-- foreground shrubbery feature
	{
		src={32,56,8,8},
		xyz = {60,60*0.9,0.8,false},
		cols={15,1,7,1,3,1,11,1,10,1,9,1},
	},
	-- foreground shrubbery feature
	{
		src={32,56,8,8},
		xyz = {260,60*0.9,0.8,false},
		cols={15,1,7,1,3,1,11,1,10,1,9,1},
	},
	
	
		-- leaves: indigo
	{src={32,48,16,6},
		xyz = {40,64,4,true},
		cols={1,13,3,13},
		fill_up=13
	},
	
		-- leaves: light
	{src={32,48,16,6},
		xyz = {0,-4,1.5,true},
		cols={1,3},
		fill_up=1
	},
	
	-- leaves: dark (foreground)
	{src={32,48,16,6},
		xyz = {-40,-6,0.8,true},
		cols={3,1},
		fill_up=1
	}
	
	
	
	},
},
	----------------

-- double mountains

[3]={
	sky={12,14,14,14,14},
	bgels={
	
	
	-- mountains indigo (far)
	{src={0,56,16,8},
		xyz = {-64,30,8,true},
		fill_down=13,
		cols={6,15,13,6}
	},
	
	{
		-- clouds inbetween
		src={16,56,16,8},
		xyz = {0,50,8,true},
		dx=-30,
		cols={15,7,1,-1},
		fill_down = 7
	},
	
	-- mountains close
	{src={0,56,16,8},
		xyz = {0,140,8,true},
		fill_down=13,
		cols={6,5,13,1}
	},
		
	}
},

}

function init_level(lev)

  cls()reset()

	level=lev
	level_t = 0
	death_t = 0
	finished_t = 0
	gems = 0
	gem_sfx = {}
	total_gems = 0
	glitch_mushroom = false
	
	music(-1)

	if play_music then
	if (level==1) music(0)
	if (level==2) music(4)
	if (level==3) music(16)
	
	end

	actor = {}
	sparkle = {}
	pl = {}
	loot = {}
	
	reload()
	
	if (level <= 4) then
	-- copy section of map
	memcpy(0x2000,
			0x1000+((lev+1)%4)*0x800,
			0x800)
	end
	
	-- spawn player
	for y=0,15 do for x=0,127 do
	
		local val=mget(x,y)
		
		if (val == 72) then
			clear_cel(x,y)
			pl[1] = make_player(72, x+0.5,y+0.5,1)

			if (num_players==2) then
				pl[2] = make_player(88, x+2,y+1,1)
				pl[2].id = 1
			end
			
		end
		
		-- count gems
		if (val==67) then
			total_gems+=1
		end
		
		-- lootboxes
		if (val==48) then
			add(loot,67)
		end
	end end
	
	local num_booby=0
	-- shuffle lootboxes
	if (#loot > 1) then
		-- ~25% are booby prizes
		num_booby=flr((#loot+2) / 4)
		for i=1,num_booby do
			loot[i]=96
			if (rnd(10)<1) then
				loot[i]=84 -- mushroom
			end
		end
		
		-- shuffle
		for i=1,#loot do
			-- swap 2 random items
			j=flr(rnd(#loot))+1
			k=flr(rnd(#loot))+1
			loot[j],loot[k]=loot[k],loot[j]
		end
	end
	
	total_gems+= #loot-num_booby
	
	
	if (not pl[1]) then
		pl[1] = make_player(72,4,4,1)
	end

end

-->8
-- draw died / finished

function draw_finished(tt)

	if (tt < 15) return
	tt -= 15

	local str="★ stage clear ★  "
	
	print(str,64-#str*2,31,14)
	print(str,64-#str*2,30,7)
	
	-- gems
	local n = total_gems
	
	for i=1,15 do pal(i,13) end
	for pass=0,1 do
			
				for i=0,n-1 do
					t2=tt-(i*4+15)
					q=i<gems and t2>=0
					if (pass == 0 or q) then
						local y=50-pass
						if (q) then
								y+=sin(t2/8)*4/(t2/2)
								if (not gem_sfx[i]) sfx(25)
								gem_sfx[i]=true
						end
						
						spr(67,64-n*4+i*8,y)
						
					end
				end
	
		pal()
	end
	
	if (tt > 45) then
		print("❎ continue",42,91,12)
		print("❎ continue",42,90,7)
	end
	
end


__gfx__
00000000cccccccc888888880000000000000000000dd000600000003aaaa63a77777772c0000008cccccccc44444444cc4ccccc22d2222dc000000051155555
00000000cccccccc88888888cccccccc00000000000550009cccccc103aa6a03777777279c000080cccccccc44444449c44444cc2ddddddd9cccccc085155555
00000000cccccccc88888888cccccccc00000000d54440009cccccc10033aa004444447799cccc00cccccccc4444449944444cccdddddddd9cccccc088555555
00000000cccccccc88888888cccccccc00000000d54445d09cccccc10033aa004444447799cccc00cccccccc44444999c444cccc2ddddddd9999999c55555555
00000000cccccccc88888888ccc1cc1100090000004445d09cccccc10033aa004444447799cccc00cccccccc44444494cc4ccccc22d222d2dddddddd55555115
00000000cccccccc88888888cc11c111009d9000005500009cccccc10033aa004444447799cccc00cccccccc4449999944ccccccdddd2ddd5555555555558515
00000000cccccccc88888888c19119910009000000dd00009cccccc109993a09cccccc47911111c0cccccccc449949994cccccccdddddddd5555585555558855
00000000cccccccc8888888819999991000c0000000800009999999699999399ccccccc41111111ccccccccc49999999ccccccccdddd2ddd8888888855555555
44c444c45552221108080ccc4444949422020000cccccccccccccccc55555555cccccccc0000000088844888dddccdddccc1cccc999cc999cccccccceeeeeeee
44c444c45522111800080ccc4444944402820000cccccccccccccccc55555555cccccccc5555555588441488dd998cddccc10ccc999cc999cccccc4444eeeeee
4ece4ecec521118c808800c94444849900820000cccccccccc5884cc555c5555cccccccc5c5cc515644441464c8858c4ccc10ccc999cc999cccc44444444eeee
41c94cccc521118c80000ccc4444849900020220cccccccccc0558cc555c5555ccddddcc55555555146444418c9c85c8ccc1cccc999c0999ccc4444444444eee
99939993cc5118cc88880ccc4444999900028200cccccccccc0558ccc55c5555cddddddc5115c5c588464488ddc9c5ddccc1cccc999c0999cc444444444444ee
39333933cc5118cc888800c94444499900028000cccccccccc0005cc5c5c55c5ddd4dddd5555555588844888dd9ccdddcc01cccc999c0999cc444444444444ee
33333333ccc18ccc8880cccc8444449900020000cccccccccccccccc5c5c5c55dd494ddd0005500088888888ddd5ddddcc01cccc999c0999c44444444444444e
33333333ccc18ccc8800000c8444444900020000cccccccccccccccc5c5c5c55ddd4dddd0005500088888888ddd9ddddccc1cccc999c0999c44444444444444e
cccccccccccccccc9999999900000000cccccccccccccccccccccccccccccccccccccccc00000000dc0ddc0d5d055d052812281200000000c000000c00cccc00
11cc11cccccccccc9999999900cc0000cc544ccccccccccccccccccccccc0ccccccccccc00000000dc0ddc0d5d055d052812281200099000dccccccc0dcccc10
c11cc11cccc88ccc99899999084c5000cd5540ccccccccccccc40ccccccc080ccccccccc88888888dccccccd5dddddd52888888200995500ddddddddddcccc1c
cc11cc1ccccc88cc988849998844cc00dd5544cccc0c0ccccc40d0ccccc000cccccccccc88888888dc8ccc8d5dcdddc5281888120cc9559044444444dd99991c
1cc11cccc88cc88c9004888988444cc0dd5544ccccc8cccccc4404ccccccc0cccccccccc80088088dccccccd5dddddd5288888820ccc99904dd44dd499999999
11cc11cccc88cccc99900809884444c0dd5555cccc050cccccc44cccc0cccccccccccccc80088888dd559ddd55dd4d5522ccdc220c9cc990ddccddcc99988999
c11cc11cccc88ccc9999009988888800cdddddcccccfcccccccccccccccccccccccccccc88888888dd599cdd55d44d552ccddd8200c8cc00dd0cdd0c88888888
cccccccccccccccc9999999900000000cccccccccccfcccccccccccccccccccccccccccc88888888ddcddddd55d5555528222222000cc000d4d0d4d08aadddd8
c1111111c00cc00c104444cc0d11112288888888ddccc7dd4400000044444455cccccccc00cccc001c011c019c099c09c88ccccccccccccc0e400e40990ddd80
8444444500000000108888cc01cccc82886666889cc44c794000000044444445cccccccc0cccccc01c011c019c099c094c8cccccccccccccee44ee4400dddd8d
844c4445000000001088884c01cccc8866cccc66dc9dd4cd00cccccccccccc44cccccccccccccccc1cccccc19cccccc944cccccccccccccceec4eec400dddd8d
8ccccc45000000001080884c01cccc8866cccc6494c99cc90cccccccccccccc4ccccccccccccc8cc1c9ccc919c8ccc89cccc888ccc4cc4cce0ece0ec00dddd8d
84ccc44500000000108d004c01cccc8866cccc44dd4cccddcccc00cccccccccccc8cc8cccccccccc1cccccc19cccccc9ccc4cc8ccccccccc0e400e400055558d
84c4c445000000001088d0cc01cccc8866cccc4dddd44dddcccc00cccc44ccccc8c88c8cc8cccccc1199891199cc4c99ccc4cc8cccc44cccee44ee440555555d
8444444500000000108888cc01cccc8866ccccddddddddddcccccccccc44cccc8c8888c8cccccccc199888c19cc444c9ccc444cc4c4444c4eec4eec455577555
8888888c000000001000000c0111111866666644ddddddddcccccccccccccccc88888888cccccccc1c1111119c999999ccccccccc444444ce00ce00c55777755
ffccccff9999999911111111555555558885588844444444cccccccc9999999900000000999999995c555c55c0ccc0cccccccccc9900990911cccccceeeeeeee
fcddddcf99a9199911111111555ac5558885958844444444cccccccc999999990c000c009d999d995cccccc5c000000cc8ccc8cc89900998811ccccceeeeeedd
cdd04ddc999999899c8088aa55a49c558885898844444444cccc0ccc999999990cccccc09dddddd95c4ccc45c010001cc888888c8898998881cc1ccceeeeedcc
cd1778dc9b9ff9999c8808c95a4ac9c588898cc0444dd444ccc0c0cc999099990c9ccc909d0ddd0958cccc85c800008cc8e888ec88888998111111cceeeeeedc
cdb77edc999ff9c99dc88cd95c9ca4a58cc08ccc444dd444cccc0ccc9999099908cccc809cddddc955ddd555cc999cccc088880c8888888888881cc1eededded
cdd92ddc9399999919dccd9155c94a558ccc88cc44444444cccccccc99999999004440009922299955666c55c0dddccccc222ccc8888888888118111edddeccc
fcddddcf9996909911999911555ca55588cc888844444444cccccccc9999999900ddd00099fffd995c555555ccccc0ccc8dddccc8888888881188111ddccddcc
ffccccff9999999911111111555555558888888844444444cccccccc9999999900c0c00099d9999955555555cccccccccccc8ccc8888888888881188ccdccddc
a999aa5a11111111cccccccc0011cc0011bdd011ccccccccddddddddcccccccc148114812c122c129c199c199ce99ce9a80aa80acc9ccccc88888888cc9fffcc
aaa9985911111111cc0055cc0cccccc01bbdb001ccccccccddddddddccccc4cc148114812c122c129c199c199ce99ce9a80aa80accc444cc8880ccc8cccf0fcc
aaa919991cccccc1c555555c0cccc1101dddbbd1ccc0ccccdd0dd0ddc4cccccc144444412cccccc29cccccc99cccccc9a888888accc454cc8d88c1c8cccfffbc
a9a959991cccccc1555550050cccc110ddbdddddccccc0ccddddddddcccccccc145444512c9ccc929c5ccc599c0ccc09a858885accc444ac81d8ccc9cc115ccc
aa99999919000091555550050cccccc099999999cc0cccccddddddddcccccccc144444412cccccc29cccccc99cccccc9a888888aceceeccc811ddd88c1111dcc
aaa88959119999116666666609999990111cc111cccc0cccdd0dd0ddcccccc4c11998911228858229988d89999882899aaeeceaaccaeeecc881ddd88ccbb1ddc
aa8aa89911111111ccddddcc00aaaa00111c6111ccccccccddddddddcc4ccccc1998889122855c22988dddc99c822289aa8ecceacaaeeecc888dd888cc5bccdc
aaaaaa8811111111cc5555cc00cccc0011166111ccccccccddddddddcccccccc1141141122c222229c999999999999c9aaaaa8aaccc6cccc888f8888cccccccc
666666660000bb3b00000000000000000c900c900d400d4008c008c008e008e000000000000000066666dddd0000000000000000666666660000011001100000
66666666000bb2b200000000000aa0000c900c900d400d4008c008c008e008e00000000000000066d666ddddd000000000000000666666660111007777111000
66666666007bbbbb0000bb3b009997000cccccc00dddddd00888888008888880000070000000066ddd6d66dddd000000000a0000d66666dd0011177ff7770000
666688a807bb3300000bb2b2099449700c8ccc800d1ddd10088c88c008188810000777000000666ddd66666ddd0000000aaaaa00dd6666dd000177fff7ff7110
68888c8c0bb330b00b7bbbbb49a0049a0cccccc00dddddd00888888008888880000070000006666dddd666ddddd0000000aaa000dddd6ddd017777fffffff711
84488888bb330000b7bb2288049aa99000ee8e0000ddcd0000c88c0000cc8c0000000000006666ddddd6dddddddd000000a0a000dddddddd0777777fffff7710
8888aa660b0b0000bbbb3330004999000ee888e00ddcccd00cc888c000c8880000000000066d6dddddddddddddddd00000000000dddddddd17fff77fffff7770
aa668688b0b000003300b0bb0004400000c00c0000d00d0000800800008000000000000066d66dddddddddddddddddd000000000dddddddd77ffffffffffff77
00008ee0000ee00000e80000000e80000767676700766670000767000067676000000006666666666666ddddddddddddd0000000ddddddd6ffffffff07e007e0
000080000000800000008000000080000000500000005000000050000000500000000066666666666666dddddddddddddd000000ddddddd6ffffffff07e007e0
00777700007777000077770000777700007777000077770000777700007777000000006666666666666dddddddddddddddd00000dddddd66ffffffff07777770
07777770077777700777777007777770077777700777777007777770077777700000666666666666666ddddddddddddddddd0000ddddd666ffffffff07177710
07177710071777100717771007177710071777100717771007177710071777100006666666666666666dddddddddddddddddd000ddddd666ffffffff07777770
077777700777777007777770077777700777777007777770077777700777777000666d666666666666dddddddddddddddddddd00dddddd66ffffffff00882800
099999900999999777999997779999900eeeeee00eeeeee00eeeeee00eeeeee00666d666666666666dddddddddddddddddddddd0dddddd66ffffffff08822270
077007707700000000000000000000770a00a000a000a000a00a00000a0a00006d666666666666666dddddddddddddddddddddddddddddd6ffffffff07000000
0000200000000000000000000000000000000020000000808080a1a1a1a1a1000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d200000000000000d50000000000000000d2000000000000000000000000000000000000
00002000000000000000000000000000005300200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000300000000000000000000000000000000000000000000f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2000000000000000000000000d20000000000
00002020202020202020202020202020202020200000000000000000000000050000000034000000000000000000000000000000000000003400000000000000
00000000000000000000000000000000000000000000000000000000f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3000000000000000000000000d13400000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0b0000000000000000000000000e0e0e0e0e0e0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000a0a0d3a0a0a0a0a0d3a0a0a0a0a0d3a0b0d0000000000000000000000000f1f0f0f0f0f0
0000000000000000000000000000000000000000000000000000000000000000000000e0e0e00000000000000000000000000000000000e0e0e0000000000000
00000000000000000000000000000000000000000000000000000000a0b000a0a0a0a0b000a0a0a0a0b000b0d0d005000000000000000000000000f1f0f0f0f0
0000000000000000000000000000000000000000000000000000000000000000000000f1f0e1000000000000000000000000e0e0000000f1f0e1000000e0e000
00000000000000000000000000000000000000000000000000000000b0d000a0a0a0b0d000a0a0a0b0d000d0d0d00000000000000000000000000000f1f0f0f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d0d0c0a0a0b0d0d0c0a0a0b0d0d0d0d0d0d0000000000000000000000000000000a0a0a0
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0e00000000000000000000000000000000000
0000e0e0000000000000000000000000000000000000000000000000d0c0a0a0b0d0d0c0a0a0b0d0d0d0d0d0d0d0000000000000000000000000000000a0a0a0
52000000000000000000000000000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000a0a0a0
93810000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f0f0f0f0f000000000000000000000000000000000000000000000
000000000000000000000000000000000000d2000000000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e1d100000000000000000000000000a0a0a0
828293000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000f1f0f0f0e100f1f0f0f0e100000000000000000000000000000000000000000000
000000000000000000000000000000000000d1000000e0e0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d100000000000000000000000000a014a0
848383000036000000000000000000f0c3f0f0f0f0f0f0f0f0f0f0f0f0f00000f0f0f0000000f0f0f00000000000000000000000000000003600000000000000
000000000000000000000000000000000000d1000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000000000000000d200000000a0a0a0
e0e0e0e0e0e0000000000000000000f0f0e10000f1f0c3e10000f1f0f0e10000f0f0f0000000f0f0f0000000003400340000000000000000e000000000000000
000000000000000034003400000000000000e0e0e0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1f0e100d10000000000000000d1000000e0e0e0e0
f0f0c3f0f0f0000000000000000000c3f000000000f0f000000000f0f0000000f0f0f0000000f0f0f0000000e0e0e0e0e000000000000000f000000000000000
00000000000000e0e0e0e0e0000000000000f0e100f1f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000d10000000000000000e0e0e0e0f0f0f0f0
c3f0f0f0f0f0000000000000000000f0f000000000f0f000000000f0f0000000f0f0f0000000f0f0f0000000f1f0f0f0e100000000000000f000000000000000
00000000000000f1f0f0f0e1000000000000d1000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000d10000000000000000f1f0f0f0f0f0f0f0
0000000000000000000000000000000000000000000000000000000000000000e48282828282828282828282828282f400000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000e482828282828282828282f4e4f40000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000d4d4e4f4d4e48282f4d40000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000e4f400000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
84000000000000000000000000910000000000000000000000240000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000820000000000828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000820000000000828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000e6f6000000000000000000000000000000000000820000000000828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000096b60000000000000000e6f6e6e7e7f60000000000000000000000000000520000825200715200828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000096c7000087a7b7b696b6000087b6e6e7e7e7e7e7e7f6e6f60000e6f6000000000000524100008241009341e6828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b687a7b7b68797a7b7b7a6b7b696d6b7e7e7e7e7e7e7e7e7e7e7f6e6e7e7f6e671000000419371e68293f6828282828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d797a7b7b7d6d6b7b7b7b7b7b7d6b7b7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e79393f6e693829382828282728282828200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b7d6b7b7b7b7b7b7b7b7b7b7b7b7b7b7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e76282828282728282828282828282828200000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccfeccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccf7decccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cf7fedeccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cedef7fccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cced7fccccccccccccccccccccccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccefccccccccccccccccccccccccccccc7777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccc777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333333333333333333333bb777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3333333333333333333333333333333b7777777777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3bb33b333bb33b333bb33b33333333337777777777777cccccccccccccccccc6cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3bb333333bb333333bb3333333bb3333777777777777777ccccccccccccccc66dccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333333333333333333bb333377777777777777777cccccccccccc66dddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333333333333333333333333777777777777777777cccccccccc666dddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333333333333333333333337777777777777777777cccccccc6666ddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333b333333333333333b3337777777777777777777ccccccc6666ddddddcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
333333333333bab33339a3333333bab377777777777777777777ccccc66d6ddddddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
33333333333bbb33339a7a33333bbb33777777777777777777777ccc66d66ddddddddddccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
3333333333333b333399a93333333b33777777777777777777777cc66666ddddddddddddccccccccccccccc6ccccccccccccccccccccccccccccccc6cccccccc
333333333b333333333993333b3333337777777777777777777777666666dddddddddddddccccccccccccc66dcccccccccc7777ccccccccccccccc66dccccccc
33333333333333333333333333333333777777777777777777777766666dddddddddddddddccccccccccc66dddcccccccc7777777ccccccccccccc66ddcccccc
33333333333333333333333333333333777777777777777777776666666dddddddddddddddcccccccccc666dddccccccc777777777cccccccccc6666ddcccccc
33333333333333333333333333333333777777777777777777766666666ddddddddddddddddcccccccc6666ddddcccc777777777777cccccccc66666dddcccc7
33333333333333333333b33333333333777777777777777777666d6666ddddddddddddddddddcccccc6666ddddddcc7777777777777ccccccc666d66ddddcc77
33333333333333333333bab33333333377777777777777777666d6666ddddddddddddddddddddcccc66d6ddddddddc77777777777777ccccc666d666dddddc77
3333333333333333333bbb333333333377777777777777776d6666666ddddddddddddddddddddddc66d66dddddddddd77777777777777ccc6d666666ddddddd7
333333333333333333333b33333333337777777777777776666666666666dddddddddddddddddddd6666dddddddddddd7777777777777cc666666666dddddddd
33333333333333333b33333333333333d777777777777766666666666666ddddddddddddddddddddd666ddddddddddddd77777777777776666666666dddddddd
33333333333333333333333333333333dd7777777777776666666666666ddddddddddddddddddddddd6d66dddddddddddd7777777777766dd66666dddddddddd
33333333333333333333333333333333dd7777777777666666666666666ddddddddddddddddddddddd66666ddddddddddd7777777777666ddd6666dddddddddd
33333333333333333333333333333333ddd777777776666666666666666dddddddddddddddddddddddd666ddddddddddddd777777776666ddddd6ddddddddddd
3333b333333333333333b33333333333dddd777777666d666666666666ddddddddddddddddddddddddd6dddddddddddddddd7777776666dddddddddddddddddd
3333bab3333333333333bab33339a333ddddd7777666d666666666666dddddddddddddddddddddddddddddddddddddddddddd777766d6ddddddddddddddddddd
333bbb3333333333333bbb33339a7a33ddddddd76d666666666666666dddddddddddddddddddddddddddddddddddddddddddddd766d66ddddddddddddddddddd
33333b333333333333333b333399a933dddddddd6666666666666666dddddddddddddddddddddddddddddddddddddddddddddddd66666666dddddddddddddddd
3b333333333333333b33333333399333dddddddd6666666666666666dddddddddddddddddddddddddddddddddddddddddddddddd66666666dddddddddddddddd
33333333333333333333333333333333ddddddddd66666ddd66666ddddddddddddddddddddddddddddddddddddddddddddddddddd66666dddddddddddddddddd
33333333333333333333333333333333dddddddddd6666dddd6666dddddddddddddddddddddddddddddddddddddddddddddddddddd6666dddddddddddddddddd
33333333333333333333333333333333dddddddddddd6ddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddd
3333333333333333333333333333b333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
3333333333333333333333333333bab3dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
333333333333333333333333333bbb33dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333b33dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
3333333333333333333333333b333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33333333333333333333333333333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
33133133331331333313313333133133dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
31311313313113133131131331311313dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
13111131131111311311113113111131dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
1d1d12224444d4d4ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777dddddddd
111d12224444d444dddddddddddddddddddddddddfdddfdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
d1dd1124444424dddddbdddddddddddddddddddddffffffddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
d1111222444424dddddbdddddd7d7ddddddddddddf1fff1ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd2eeeeeefdddddddd
dddd12224444ddddbddbdddddddedddddddddddddeffffedddddddddddddddddddddddddddddddddddddddddddddddddddd7dddddddddddd2eeeeeefdddddddd
dddd112444444ddddbdbddbddd737ddddddddddddd222ddddddddddddddddddddddddddddddddddddddddddddddddddddd7a7ddddddddddd2eeeeeefdddddddd
ddd12222244444dddbdbdbdddddbdddddddddddddd888dddddddddddddddddddddddddddddddddddddddddddddddddddddd7dddddddddddd2eeeeeefdddddddd
dd1111122444444ddbdbdbdddddbddddddddddddddfdfdddddddddddddddddddddddddddddddddddddddddddddddddddddd3dddddddddddd2222222ddddddddd
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333222333332223333322233333222333332223333322233333222333332223333322233333222333332223333322233333222333332223333322233333222
23332222233322222333222223332222233322222333222223332222233322222333222223332222233322222333222223332222233322222333222223332222
22224442222244422222444222224442222244422222444222224442222244422222444222224442222244422222444222224442222244422222444222224442
22244444222444442224444422244444222444442224444422244444222444442224444422244444222444442224444422244444222444442224444422244444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
22442244444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444464444444444444
44224424444444444444444444444444444444444444224444444444444444444444444444444444444444444444444444444444444444444666d44444444444
2442244444444444444444444444444444444444422442244444444444444444444444444444444444444444444444444444444444444444422d666444444444
22442244444444444444444444444444444444444422444444444444444444444444444444444444444444444444444444444444444444444442262444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444444224444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444446644442244224444444444224422442244224422442244444444444444444444444444224422442244224444444444444444444444444444444444
4444444442d674444224422444444444422442244224422442244224444444444444444444444444422442244224422444422444444444444444444444444444
4444444422dd66444422442444444444442244244422442444224424444444444444444444444444442244244422442444442244444444444444444444444444
4444444422ddd6642442244444444444244224442442244424422444444444444444444444444444244224442442244442244224444444444444444444444444
4444444422dddd642244224444444444224422442244224422442244444444444444444444444444224422442244224444224444444444444444444444444444
44444444222222444224422444444444422442244224422442244224444444444444444444444444422442244224422444422444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444

__gff__
00020202000012020202000000000202020200000000020100000202000000000202020202000000004204040c000202124202020202424200000c0c0200020260706060700000000000000000000000200220006000000004040c0c04200000a0000060040404040000000000000000a0000808b0000000000000000000000c
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d09000900090009430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002828
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000909070809090909090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000392828
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000090a0a0a0a0a0a0a0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018282828
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090a0a0a440a0a0a0b0000000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000043003928282828
43000000000000000000000000000000000000000000000000000036292929293700000000003629293700000000000000000000000005000000000000000009700a440a440a0b0d0000000000000000430000000000000000000000000000000000000000000000443044000000000000000000000000700000002828282828
292929370000000000000000000000000000000000000100000000282728272627000000000027282627000000000000000025170000140000000000000000090a0a0a440a0b0d0d0000000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000018002728282828
282726270000000000000000000000000000000000000000000000272628282728000006000027282728000000740000000003030303030000000000000000090a0a0a0a0b0d0d0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005000027392828412828
282828280000000000000000000000000000000000430000000000282827282726000000000028272827000000000000391802210202023939180000000000090a0a0a0b0d0d0c090000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000014180027282828282826
282827280000000000000000000000000000000630060000000000262828282827000000000038383838003918391839282802020224022828283939180000090708090907080909170000050000000000000000000000000000000000000000000000000000140000000000000000000000000000003928002828380e0e0e38
2728272600000000000000000000000000000006060600000000003838383838380000000000001213703938063038382828202020202028282728282818000303030303030303030300391400000000000000000000000000000000000000000500000000001405000000000000000004000000251828281803030303030303
2828282700000000000000000000000000000000000000000000000000121300000070000003030303030303030303032828282828282827282728282828392002232020202002200239273900000000000000000000000630000000000005001405000000051414000000000000000014180000142828282802020202020202
3838383800000000000000000000000000000500000000000000030303030303030303030302020202020202020202022828282828282728272828282828280606062828282828282827282818030303030300000070000606000000050014001414000000141414000000000000000039270000392827280602202002022002
1213172500480000000000000400060000001425000000700017020220200202020202020202022002020202202302023838383838383838383838383838380606063870387038703870383838020202020203030303030303007000140414001414000404141414005200000000001738383917383838300602022002240202
0303030303030303030303030303030303030303030303030303020202020202020202020202022320020220200202020303030303030303030303030303030303030303030303030303030303020202020202022002020202030303030303030303030303030303030303030303030303030303030303030302022320020202
2002020202210202020202020202220202020202020220200221020202022002200202230202020202020202200202020220020202020202020202020202020202020202020202020202020202200202200202020202230202020202020202022002020223020202020202022002020202022002022020200202020202202002
0223200220202002020220202102020202200202020202202002020202020202202002022120022102020202022420020202020202020202020202202002022002020220200220200202202020022002200202020202020202022302020202200202020202020202020202230202020202020202020202200202020220200202
0000000000000000000000000000080808000000000000000000000000081400140000000000000000140014000014000014140000140014000014000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000080808307373000000000000000000000000081400140000000000000000140014000014000014140000140014000014000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000080000307000000000000000000000000000081400140000000000000000000014000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000080000080808080808080808080808000000080000140000000000000000000014000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000080000000800000000000000000000000008080000140000000000000000000000000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000008000000000800000000000000000000000800000000000000000000000000000000000014000014140000000014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000008000000000800000000000070007000080000000000000000000000000000000000000000000014000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000035000008000000000800000000080808080808000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1800000000000008080808000000000844001908000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2805000000000000000000000000000800000800000076000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2739180000000000000000000044440830300800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4828270017170400000000190044440000001900000000000000007600000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
292929002929291a1a1a29292908080808080808087000007000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010001010104000001010100080000000000080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020002200214050002020200080000410000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2002200002020214140002020200080808000808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000300000c540105301f540135301856016550135401353018560105501f54010530135601655013540135301a520105401f530105201a510135201f510165001a50013500135001a50010500215001050013505
01100000240452400528000280452b0450c005280450000529042240162d04500005307553c5252d000130052b0451f006260352b026260420c0052404500005230450c00521045230461f0450c0051c0421c025
01100000187451a7001c7001c7451d745187001c7451f7001a745247001d7451d70021745277002470023745217451f7001d7001d7451a7451b7001c7451f7001a745227001c7451b70018745187001f7451f700
01100000305453c52500600006003e625006000c30318600355250050000600006003e625006000060018600295263251529515006003e625006000060018600305250050018600006003e625246040060000600
01100000004000c40018400004000a400004000a4000c400004000a4000c400004000a4000c4001140013400004000c4000a400004000a400004000a4000c400004000c40016400004001640018400114000c400
01100000270752607724075200721f0751b0771a0751b075180721806218052180421803500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000c30018300243001f3001b3001a300193001b300183001830017300163001530014300133001830014300143001830018300003000030000300003000030000300003000030000300003000030000300
011000000c37300300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000000001e0701f070220702a020340103f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002b7602e7503a73033740377302e75033730337303372035710377103a710337103a7103c7103c7003f700007000070000700007000070000700007000070000700007000070000700007000070000700
000200002965021630136301e63012620126301322017630176300b6301361012110116100d1100a6100a61008610106000d60004600116000e6001160012600116000a600066000960003600026000260002600
000100002257524575275652455527555275552b54524525225352252527525275252b5252e515305152e515305052e505305052e5053050530505335052b5052e5052b5052e5052e5053350530505335052e505
000200002005325043160231002304013030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102000013571165731b5751d5711157313575165711b5731b575225711b573185751b5711f573245751b5711f57324565295611f563185611d555245532b5552b5412b5433053137535335333a5212b5252e513
000100002b571275711b57118571105710b57106571045710457106561035510454103531015210153105531035210a5210f5200c5200f72016510167101d5101d510245102b5100050000500005000050000500
010200002e17029170171731a171231631d16111143141610c1230a11107110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
01040000185702257024570225701f5701d5701f5701d57018570165701857016570135701157013570115700c5700d570135701457018560195501f550205302453024520225202452022510245102251024500
00030000281602a1502c14029440220301f030220301b0201d0201d020160200f02013020130100c010110100f5100a5100a5100c5100c51007510075100a5100501003010375003b7003050034700375003b700
000200001557015570165701657017560185401a5401c5301f5202251029510005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000200001f07018060110400e0300c020160201602016010180101b01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011c00000c7550070013755007001175500700007000070013755007001475513755117550070000700007000d755007000070011755137550070011755007000d75500700117550d75513755007001175500700
000200001c17023170201701317012170161600d0600c0500b0400b0400c0300a0200802007010060100400003000020000100001000000000000000000000000000000000000000000000000000000000000000
000100001057015510195701c51021570235202350000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
010100001b07017020190701a0101f0301e0102506021000260001e03027000210000e000210300e0000e0000e000270100e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e000
01080000185461c5361f526215161f54621536245262851624546285362b5262f5162b5463053634526375161f50024500285002b5001f50024500285002b5000000000000000000000000000000000000000000
00020000125501455017550195501c550235502a55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000023570215701f5601d5501b540115400f5300d5100a1100c1100d1100f1101351000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00020000251602215020160181501d1301b1501b5401f5301f520183101b5301f5301b53016530185201652011520165201651013510115100f5100c5100c5100a51007510075100551000500005000050000500
01020000395503b5513b5213b51100500005000050000500005000050000500005003b5503d5513f5513f5203f500375003050037500305003750030500005003f51037530305313753130521375213051100500
0106000014472154411b4712347127566157610e5560b1410b5412a23632531385223f5213f426225111921115516155111651218411195161b5111c5161f1112041619311107110f5160f211101111241100701
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011c00000c7550070013755007001175500700007000070013755007001475513755117550070000700007000d755007000070011755137550070011755007000d75500700117550d75513755007001175500700
011c00000c7550070011755007001375500700007000070018755007001475518755137550070011755007000d755007000070011755137550070011755007000d75500700117550d75511755007001375500700
011c000018024180201d0311d0351f0321f0311f0221f012200322002124035200321f0321f0351d0311d03519030190301d0321d032190311903219025180321603216032180351d03519032190321803216032
011c000018024180201d0311d0251f0321f0321f0221f015200322002124032200351f0321f0321d0311d0351952019520195251d522195321953218532185321952219115195251d51519522185221952216512
011c0000180061d0061f72622716180061d1161f11622006180001d0001f00022000180061d1161f11622006190061d0061f72622716190061d1161f11622006190061d0061f72622716190061d1161f11622006
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000000145000450c0050c0050c6450000000145000450000000000011450c0001862500000000000000500145000450c0050c0050c645000000014500045011050110518625011451860524615011450c145
01180000187461b7361f72622716187461b7361f726227160070000700007000070000700007000070000700197461d7362072624716197461d73620726247160070000700007000070000700007000070000700
01100000187251a7251b7251f725187251a7251b7251f7251a7251b7251f725227251a7251b7251f72524725197251d7251f72522725197251d7251f72522725197251d7251f72522725197251d7251f72522725
0110000024525295252450524515295152b52500000000000000000000000000000020525225262453527525295222b5222e522295262952529525275252750527525255252050525525245251f5052452522525
011000002450522525245251f525000001f5251d525185250000020505000002250522525245052953524505295022b5052e5051d525295251f5252b5250000027525255252050525525295251f505295252b525
__music__
01 01434144
00 02434144
00 01034244
02 02034244
01 20644144
00 21634144
00 20644144
00 21634144
00 20244144
00 21244144
00 20226444
00 21236444
00 20222444
00 21232444
00 20244144
02 21244144
01 28696a6b
00 28696a6b
00 28692a6b
00 28692a6c
00 28692a2b
00 28692a2c
00 28692a6b
02 28692a2c
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144
00 41414144

