local vshader = love.graphics.newShader(
[[
	uniform float dt_cpf;
	uniform vec2 f;
	uniform Image ovTexture;
	uniform Image depthTexture;
	vec4 effect(vec4 color, Image ozTexture, vec2 tc, vec2 screen_coords)
	{	
		float dx = 1.0/f.x;
		float dy = 1.0/f.y;
		
		float z_center = Texel(ozTexture, tc)[0];
		float z_up = Texel(ozTexture, tc-vec2(0, dy))[0];
		float z_down = Texel(ozTexture, tc+vec2(0, dy))[0];
		float z_left = Texel(ozTexture, vec2(mod(tc.x-dx, 1.0), tc.y))[0];
		float z_right = Texel(ozTexture, vec2(mod(tc.x+dx, 1.0), tc.y))[0];
		
		float dz_dx = (z_right - z_center)/dx;
		float dz_dy = (z_down - z_center)/dy;
		float d2z_dx2 = (z_right - 2*z_center + z_left)/(dx*dx);
		float d2z_dy2 = (z_down - 2*z_center + z_up)/(dy*dy);
		
		float h_center = Texel(depthTexture, tc)[0];
		float h_down = Texel(depthTexture, tc+vec2(0, dy))[0];
		float h_right = Texel(depthTexture, vec2(mod(tc.x+dx, 1.0), tc.y))[0];
		
		float dh_dx = (h_right - h_center)/dx;
		float dh_dy = (h_down - h_center)/dy;
		
		float g = 0.005;
		
		float distanceFromEquator = 85.0/90.0*2.0*abs(tc.y-0.5);
		float circumference = sqrt(1 - distanceFromEquator*distanceFromEquator);
		float widthHeightCorrection = f.y/f.x;
		float angle = asin(distanceFromEquator);
		float coriolis = -0.0*distanceFromEquator;
		vec2 vector = vec2(1.0/circumference*widthHeightCorrection, 1.0);
		
		float acc = g*(dh_dx*vector[0]*dz_dx + 
					   h_center*vector[0]*d2z_dx2 + 
					   dh_dy*vector[1]*dz_dy +
					   h_center*vector[1]*d2z_dy2);
	
		float ov = Texel(ovTexture, tc)[0];
		float nv = ov + acc*dt_cpf;
		
		float attrition = (1.0-exp(-8.0*h_center))/(1.0-exp(-8.0));
		nv *= pow(attrition, dt_cpf);
		
		return vec4(nv, 0.0, 0.0, 1.0);
		
		
	}
]])

local zshader = love.graphics.newShader( 
[[
	uniform float dt_cpf;
	uniform Image nvTexture;
	vec4 effect(vec4 color, Image ozTexture, vec2 tc, vec2 screen_coords)
	{	
		float nv = Texel(nvTexture, tc)[0];
		float oz = Texel(ozTexture, tc)[0];
		float nz = oz + nv*dt_cpf;
		
		return vec4(nz, 0.0, 0.0, 1.0);
	}
]])

local dshader = love.graphics.newShader( 
[[
	vec4 effect(vec4 color, Image nzTexture, vec2 tc, vec2 screen_coords)
	{	
		float nz = Texel(nzTexture, tc)[0];
		float c = nz/2.0 + 0.5;
		c = (c-0.5)*100.0 + 0.6;
		return vec4(c/4.0, c/2.0, c, 1.0);
	}
]])

local clearShader = love.graphics.newShader( 
[[
	uniform vec3 color;
	vec4 effect(vec4 c, Image Img, vec2 tc, vec2 screen_coords)
	{
		return vec4(color, 1.0);
	}
]])

local depthShader = love.graphics.newShader( 
[[
	vec4 effect(vec4 color, Image depthTexture, vec2 tc, vec2 screen_coords)
	{	
		float depth = Texel(depthTexture, tc)[0];
		return vec4(depth, depth, depth, 1.4-step(0.049, depth));
	}
]])

local maxShader = love.graphics.newShader( 
[[
	uniform Image nzTexture;
	vec4 effect(vec4 color, Image oldMaxTexture, vec2 tc, vec2 screen_coords)
	{	
		float nz = Texel(nzTexture, tc)[0];
		float oldMax = Texel(oldMaxTexture, tc)[0];
		return vec4(max(abs(nz), oldMax), 0.0, 0.0, 1.0);
	}
]])


local fw, fh = 640, 302
vshader:send("f", {fw, fh})
local calculationsPerFrame = 10
local circleRadius = 1

local white = love.graphics.newCanvas(fw, fh)
love.graphics.setCanvas(white)
love.graphics.clear(1, 1, 1)
love.graphics.setCanvas()
local function clearCanvas(canvas, color)
	--canvas:setFilter("nearest", "nearest")
	if color then
		love.graphics.setShader(clearShader)
		love.graphics.setCanvas(canvas)
		love.graphics.setColor(1, 1, 1)
		clearShader:send("color", color)
		love.graphics.draw(white)
		love.graphics.setCanvas()
		love.graphics.setShader()
	end
end

local v1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local v2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local z1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local z2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
clearCanvas(v1, {0, 0, 0})
clearCanvas(v2, {0, 0, 0})
clearCanvas(z1, {0, 0, 0})
clearCanvas(z2, {0, 0, 0})
local currentNewZ = 1
local nz, oz, nv, ov = z1, z2, v1, v2

local t, Dt = 0, 1/60
local cameraX, cameraV = 0, 1
function love.update(dt)
	if love.keyboard.isDown("escape") then
		love.event.quit()
	end
	if love.keyboard.isDown("left") then
		cameraX = (cameraX - cameraV*dt)%1
	end
	if love.keyboard.isDown("right") then
		cameraX = (cameraX + cameraV*dt)%1
	end
	if dt > 1/20 then dt = 1/20 end
	vshader:send("dt_cpf", dt/calculationsPerFrame)
	zshader:send("dt_cpf", dt/calculationsPerFrame)
	t = t + dt
	Dt = dt
end

local depthFile = io.open("monde/640.txt", "r")
local depth = {}
local depthWidth = 640
local depthHeight = 302
for y = 1, depthHeight do
	local line = depthFile:read()
	depth[y] = {}
	for number in string.gmatch(line, "%g+") do
		depth[y][#depth[y]+1] = tonumber(number)
	end
end

local depthTexture = love.graphics.newCanvas(depthWidth, depthHeight, {format="r32f"})
clearCanvas(depthTexture)
love.graphics.setCanvas(depthTexture)
for y = 1, depthHeight do
	for x = 1, depthWidth do
		local c = -depth[y][x]/12000+0.05
		love.graphics.setColor(c, 0, 0)
		love.graphics.points(x, y)
	end
end
love.graphics.setColor(1, 1, 1)
love.graphics.setCanvas()

local depthLayer = love.graphics.newCanvas(depthWidth, depthHeight)
clearCanvas(depthLayer)
love.graphics.setShader(depthShader)
love.graphics.setCanvas(depthLayer)
love.graphics.draw(depthTexture)
love.graphics.setCanvas()
love.graphics.setShader()

local maxTexture1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local maxTexture2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local newMaxTexture, oldMaxTexture = maxTexture1, maxTexture2
clearCanvas(maxTexture1, {-100, 0, 0})

local sw, sh = love.graphics.getDimensions()
function love.draw()
	local mx, my = love.mouse.getPosition()
	mx, my = math.ceil(((mx/sw+cameraX)%1)*fw), math.ceil(my/sh*fh)
	local mDown = love.mouse.isDown(1)
	
	for i = 1, calculationsPerFrame do
		if mDown then
			love.graphics.setShader(clearShader)
			clearShader:send("color", {0.5, 0, 0})
			love.graphics.setCanvas(oz)
			love.graphics.circle("fill", mx, my, circleRadius)
		end
		
		love.graphics.setShader(vshader)
		love.graphics.setCanvas(nv)
		vshader:send("ovTexture", ov)
		vshader:send("depthTexture", depthTexture)
		love.graphics.draw(oz)
		
		love.graphics.setShader(zshader)
		love.graphics.setCanvas(nz)
		zshader:send("nvTexture", nv)
		love.graphics.draw(oz)
		
		love.graphics.setShader(maxShader)
		love.graphics.setCanvas(newMaxTexture)
		maxShader:send("nzTexture", nz)
		love.graphics.draw(oldMaxTexture)
			
		if currentNewZ == 1 then
			currentNewZ = 2
			nz = z2
			oz = z1
			nv = v2
			ov = v1
			newMaxTexture = maxTexture2
			oldMaxTexture = maxTexture1
		elseif currentNewZ == 2 then
			currentNewZ = 1
			nz = z1
			oz = z2
			nv = v1
			ov = v2
			newMaxTexture = maxTexture1
			oldMaxTexture = maxTexture2
		end
	end
    
	love.graphics.setShader(dshader)
	love.graphics.setCanvas()
	--love.graphics.draw(nz, -sw*(cameraX-1), 0, 0, sw/fw, sh/fh)
	--love.graphics.draw(nz, -sw*cameraX, 0, 0, sw/fw, sh/fh)
	love.graphics.draw(newMaxTexture, -sw*(cameraX-1), 0, 0, sw/fw, sh/fh)
	love.graphics.draw(newMaxTexture, -sw*cameraX, 0, 0, sw/fw, sh/fh)
	
	love.graphics.setShader()
	love.graphics.draw(depthLayer, -sw*(cameraX-1), 0, 0, sw/depthWidth, sh/depthHeight)
	love.graphics.draw(depthLayer, -sw*cameraX, 0, 0, sw/depthWidth, sh/depthHeight)
	--love.graphics.print(1/Dt)
end