local fw, fh = 300, 300
local calculationsPerFrame = 200
local circleRadius = 4
local circleK = 40000
local initialK = 800

local zshader = love.graphics.newShader( 
[[
	uniform float dt;
	uniform float cpf;
	uniform vec2 f;
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
		
		float k = 100.0;
		float result = k*laplacian*dt/cpf + center;
	    
		return vec4(result, 0.0, 0.0, 1.0);
	}
]])

local circleShader = love.graphics.newShader( 
[[
	uniform float circleK;
	vec4 effect(vec4 color, Image nzTexture, vec2 tc, vec2 screen_coords)
	{
		return vec4(circleK, 0.0, 0.0, 1.0);
	}
]])

local dshader = love.graphics.newShader( 
[[
	vec4 effect(vec4 color, Image nzTexture, vec2 tc, vec2 screen_coords)
	{	
		float nz = Texel(nzTexture, tc)[0];
		
		float Red, Green, Blue;
		float Temperature = nz / 100.0;
		
		//Calculate Red:
	
		if(Temperature <= 66.0){
			Red = 255.0;
		}else{
			Red = Temperature - 60.0;
			Red = 329.698727446 * pow(Red, -0.1332047592);
			if(Red < 0.0) Red = 0.0;
			if(Red > 255.0) Red = 255.0;
		}
		
		//Calculate Green:
	
		if(Temperature <= 66.0){
			Green = Temperature;
			Green = 99.4708025861 * log(Green) - 161.1195681661;
			if(Green < 0.0) Green = 0.0;
			if(Green > 255.0) Green = 255.0;
		}else{
			Green = Temperature - 60.0;
			Green = 288.1221695283 * pow(Green, -0.0755148492);
			if(Green < 0.0) Green = 0.0;
			if(Green > 255.0) Green = 255.0;
		}
		
		//Calculate Blue:
	
		if(Temperature >= 66.0){
			Blue = 255.0;
		}else{
			if(Temperature <= 19.0){
				Blue = 0.0;
			}else{
				Blue = Temperature - 10.0;
				Blue = 138.5177312231 * log(Blue) - 305.0447927307;
				if(Blue < 0) Blue = 0.0;
				if(Blue > 255) Blue = 255.0;
			}
		}
		
		return vec4(Red/255.0, Green/255.0, Blue/255.0, 1.0);
	}
]])

zshader:send("f", {fw, fh})
zshader:send("cpf", calculationsPerFrame)
circleShader:send("circleK", circleK)

local z1 = love.graphics.newCanvas(fw, fh, {format="r32f"})
local z2 = love.graphics.newCanvas(fw, fh, {format="r32f"})
love.graphics.setCanvas(z1)
love.graphics.clear(initialK, 0, 0)
love.graphics.setCanvas(z2)
love.graphics.clear(initialK, 0, 0)
love.graphics.setCanvas()
love.graphics.setShader()
local currentNewZ = 1
local nz, oz = z1, z2

local mouse = 0
function love.update(dt)
	if love.keyboard.isDown("escape") then
		love.event.quit()
	end
	mouse = love.mouse.isDown(1)
	zshader:send("dt", dt)
end

local sw, sh = love.graphics.getDimensions()
function love.draw()
	if mouse then
		local mx, my = love.mouse.getPosition()
		mx, my = math.ceil(mx/sw*fw), math.ceil(my/sh*fh)
		love.graphics.setCanvas(oz)
		love.graphics.setShader(circleShader)
		love.graphics.circle("fill", mx, my, circleRadius)
	end
	
	for i = 1, calculationsPerFrame do
		love.graphics.setShader(zshader)
		love.graphics.setCanvas(nz)
		love.graphics.draw(oz)
			
		if currentNewZ == 1 then
			currentNewZ = 2
			nz = z2
			oz = z1
		else
			currentNewZ = 1
			nz = z1
			oz = z2
		end
	end
    
	love.graphics.setShader(dshader)
	love.graphics.setCanvas()
	love.graphics.draw(nz, 0, 0, 0, sw/fw, sh/fh)
end