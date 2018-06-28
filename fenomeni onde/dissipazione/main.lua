local fw, fh = 300, 300
local velocity = 5
local calculationsPerFrame = 40
local circleRadius = 1
local circleMaxValue = 1
local circleFrequency = 3
local initialValue = 0

local zshader = love.graphics.newShader( 
[[
	uniform float dt;
	uniform Image nvTexture;
	vec4 effect(vec4 color, Image ozTexture, vec2 tc, vec2 screen_coords)
	{	
		float nv = Texel(nvTexture, tc)[0];
		float oz = Texel(ozTexture, tc)[0];
		float nz = oz + nv*dt;
		return vec4(nz, 0.0, 0.0, 1.0);
	}
]])

local vshader = love.graphics.newShader(
[[
	uniform float v2_dt_cpf;
	uniform vec2 f;
	uniform Image ovTexture;
	vec4 effect(vec4 color, Image ozTexture, vec2 tc, vec2 screen_coords)
	{	
		float dx = 1.0/f.x;
		float dy = 1.0/f.y;
		
		float center = Texel(ozTexture, tc)[0];
		
		float up = Texel(ozTexture, vec2(tc.x, tc.y-dy))[0];
		float down = Texel(ozTexture, vec2(tc.x, tc.y+dy))[0];
		float left = Texel(ozTexture, vec2(tc.x-dx, tc.y))[0];
		float right = Texel(ozTexture, vec2(tc.x+dx, tc.y))[0];
		
		float der2x = (left - 2*center + right);
		float der2y = (up - 2*center + down);
		
		float laplacian = der2x + der2y;
		
		float ov = Texel(ovTexture, tc)[0];
		
		float nv = ov + v2_dt_cpf*laplacian;
		nv = nv*0.9995;
		return vec4(nv, 0.0, 0.0, 1.0);
	}
]])

local circleShader = love.graphics.newShader( 
[[
	uniform float value;
	vec4 effect(vec4 color, Image Img, vec2 tc, vec2 screen_coords)
	{
		float result = value;
		return vec4(result, 0.0, 0.0, 1.0);
	}
]])

local dshader = love.graphics.newShader( 
[[
	vec4 effect(vec4 color, Image nzTexture, vec2 tc, vec2 screen_coords)
	{	
		float nz = Texel(nzTexture, tc)[0];
		float c = nz+0.5;
		return vec4(c/4.0, c/2.0, c, 1.0);
	}
]])

local expShader = love.graphics.newShader( 
[[
	uniform vec2 m;
	uniform vec2 f;
	vec4 effect(vec4 color, Image nzTexture, vec2 tc, vec2 screen_coords)
	{	
		float value = exp(-distance(tc, m/f)*100.0);
		return vec4(value, 0.0, 0.0, 1.0);
	}
]])

vshader:send("f", {fw, fh})
expShader:send("f", {fw, fh})

local v1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local v2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local z1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local z2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
love.graphics.setCanvas(v1)
love.graphics.clear(0, 0, 0)
love.graphics.setCanvas(v2)
love.graphics.clear(0, 0, 0)
love.graphics.setCanvas(z1)
love.graphics.clear(initialValue, 0, 0)
love.graphics.setCanvas(z2)
love.graphics.clear(initialValue, 0, 0)
love.graphics.setCanvas()
love.graphics.setShader()
local currentNewZ = 1
local nz, oz, nv, ov = z1, z2, v1, v2

local red = love.graphics.newCanvas(fw, fh, {format="r32f"})
love.graphics.setCanvas(red)
love.graphics.clear(1, 0, 0)
love.graphics.setCanvas()

local t, Dt = 0, 1/60
function love.update(dt)
	if love.keyboard.isDown("escape") then
		love.event.quit()
	end
	vshader:send("v2_dt_cpf", velocity^2*dt/calculationsPerFrame)
	zshader:send("dt", dt)
	t = t + dt
	Dt = dt
end

--love.graphics.setShader(expShader)
--expShader:send("m", {fw/2, fh/2})
--love.graphics.setCanvas(oz)
--love.graphics.draw(red)
--love.graphics.setCanvas(ooz)
--love.graphics.draw(red)
--love.graphics.setCanvas()
--love.graphics.setShader()

local sw, sh = love.graphics.getDimensions()
function love.draw()
	local mx, my = love.mouse.getPosition()
	mx, my = math.ceil(mx/sw*fw), math.ceil(my/sh*fh)
	local mDown = love.mouse.isDown(1)
	
	for i = 1, calculationsPerFrame do
		if mDown then
			love.graphics.setShader(circleShader)
			local value = initialValue + circleMaxValue*math.sin((t+i/calculationsPerFrame*Dt)*circleFrequency*math.pi*2)
			circleShader:send("value", value)
			love.graphics.setCanvas(oz)
			love.graphics.circle("fill", mx, my, circleRadius)
		end
		
		love.graphics.setShader(vshader)
		love.graphics.setCanvas(nv)
		vshader:send("ovTexture", ov)
		love.graphics.draw(oz)
		
		love.graphics.setShader(zshader)
		love.graphics.setCanvas(nz)
		zshader:send("nvTexture", nv)
		love.graphics.draw(oz)
			
		if currentNewZ == 1 then
			currentNewZ = 2
			nz = z2
			oz = z1
			nv = v2
			ov = v1
		elseif currentNewZ == 2 then
			currentNewZ = 1
			nz = z1
			oz = z2
			nv = v1
			ov = v2
		end
	end
    
	love.graphics.setShader(dshader)
	love.graphics.setCanvas()
	love.graphics.draw(nz, 0, 0, 0, sw/fw, sh/fh)
	
	love.graphics.setShader()
	
	--love.graphics.print(1/Dt)
end