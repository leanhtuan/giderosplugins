--helper function from Andy Bower
function Sprite:isVisibleDeeply()
	-- Answer true only if the sprite and all it's a parents are visible. Normally, isVisible() will
	-- return true even if a sprite is actually not visible on screen by wont of one of it's parents
	-- being made invisible.
	--
	local try=self
	while (try) do
		local scaleX, scaleY = try:getScale()
		if  not(try:isVisible() and try:getAlpha()>0 and scaleX > 0 and scaleY > 0) then
			return false
		end
		try = try:getParent()
	end
	return true
end

function Sprite:isOnStage()
	local parent = self:getParent()
	while parent do
		if parent == stage then return true end
		parent = parent:getParent()
	end
	return false
end

OUYALayer = Core.class(Sprite)

function OUYALayer:init()
	-- Settings
	self.__conf = {
		fill = {Shape.SOLID, 0x0000ff, 0.3},
		line = {1, 0xffff00}
	}
	if not ouya then
		require "ouya"
	end
	self.__disabled = false
	self.__hoverActive = true
	self.__defaultHover = Shape.new()
	if GTween then
		self.__tweener = GTween.new(self.__defaultHover, 0.1, {})
	end
	self.__objects = {}
	self.__selected = 1
	self.__prev = 0
	self:addEventListener(Event.ADDED_TO_STAGE, self.__added, self)
	self:addEventListener(Event.REMOVED_FROM_STAGE, self.__removed, self)
	self:addEventListener(Event.ENTER_FRAME, self.__frame, self)
end

function OUYALayer:setFillStyle(...)
	self.__conf.fill = arg
end

function OUYALayer:setLineStyle(...)
	self.__conf.line = arg
end

function OUYALayer:addObject(sprite, id)
	sprite.__id = id
	if sprite:isOnStage() then
		if sprite.__id ~= nil then
			table.insert(self.__objects, sprite.__id, sprite)
		else
			table.insert(self.__objects, sprite)
		end
	end
	sprite:addEventListener(Event.REMOVED_FROM_STAGE, function(sprite)
		for i = 1, #self.__objects do
			if sprite == self.__objects[i] then
				table.remove(self.__objects, i)
				break
			end
		end
	end, sprite)
	
	sprite:addEventListener(Event.ADDED_TO_STAGE, function(sprite)
		if sprite.__id ~= nil then
			table.insert(self.__objects, sprite.__id, sprite)
		else
			table.insert(self.__objects, sprite)
		end
	end, sprite)
end

function OUYALayer:__handleKeys(e)
	if not self.__disabled then
		if e.keyCode == KeyCode.BUTTON_O then
			if self.__objects[self.__selected] then
				local sprite = self.__objects[self.__selected]
				local x, y, _, _ = sprite:getBounds(self) --get global coordinates
				local offset = 10
				x, y = self:localToGlobal(x + offset, y + offset)
				if sprite:hasEventListener(Event.MOUSE_DOWN) then
					local event = Event.new(Event.MOUSE_DOWN)
					event.x = x
					event.y = y
					sprite:dispatchEvent(event)
				end
				if sprite:hasEventListener(Event.MOUSE_UP) then
					local event = Event.new(Event.MOUSE_UP)
					event.x = x
					event.y = y
					sprite:dispatchEvent(event)
				end
				if sprite:hasEventListener(Event.TOUCHES_BEGIN) then
					local event = Event.new(Event.TOUCHES_BEGIN)
					event.touch = {}
					event.touch.x = x
					event.touch.y = y
					event.touch.rx = x
					event.touch.ry = y
					event.touch.id = 1
					event.allTouches = {event.touch}
					sprite:dispatchEvent(event)
				end
				if sprite:hasEventListener(Event.TOUCHES_END) then
					local event = Event.new(Event.TOUCHES_END)
					event.touch = {}
					event.touch.x = x
					event.touch.y = y
					event.touch.rx = x
					event.touch.ry = y
					event.touch.id = 1
					event.allTouches = {event.touch}
					sprite:dispatchEvent(event)
				end
			end
		elseif e.keyCode == KeyCode.BUTTON_A then
			if self.back then
				self:back()
			end
		elseif e.keyCode == KeyCode.BUTTON_DPAD_DOWN then
			self:__goDown()
		elseif e.keyCode == KeyCode.BUTTON_DPAD_LEFT then
			self:__goLeft()
		elseif e.keyCode == KeyCode.BUTTON_DPAD_RIGHT then
			self:__goRight()
		elseif e.keyCode == KeyCode.BUTTON_DPAD_UP then
			self:__goUp()
		end
	end
end

function OUYALayer:__handleJoystick(e)
	local angle = math.deg(e.angle)
	if not self.__isDirty and e.strength >= 0.9 then
		self.__skip = 5
		self.__isDirty = true
		if angle >= 0 and angle < 45 then
			self:__goRight()
		elseif angle >= 45 and angle < 135 then
			self:__goDown()
		elseif angle >= 135 and angle < 225 then
			self:__goLeft()
		elseif angle >= 225 and angle < 315 then
			self:__goUp()
		elseif angle >= 315 and angle <= 360 then
			self:__goRight()
		end
	elseif e.strength < 0.9 then
		self.__isDirty = false
	end
end

function OUYALayer:setHoverActive(bool)
	self.__hoverActive = bool
end

function OUYALayer:__hoverNext()
	local sprite = self.__objects[self.__selected]
	if sprite then
		if self.__selected ~= self.__prev then
			self.__prev = self.__selected
			local event = Event.new("selected")
			event.object = sprite
			sprite:dispatchEvent(event)
		end
		if self.__hoverActive then
			local x, y, width, height = sprite:getBounds(self)
	
			if width + self.__conf.line[1] ~= self.__defaultHover:getWidth() or height + self.__conf.line[1] ~= self.__defaultHover:getHeight() then
				self.__defaultHover:clear()
				self.__defaultHover:setLineStyle(unpack(self.__conf.line))
				self.__defaultHover:setFillStyle(unpack(self.__conf.fill))
				self.__defaultHover:beginPath()
				self.__defaultHover:moveTo(0, 0)
				self.__defaultHover:lineTo(width, 0)
				self.__defaultHover:lineTo(width, height)
				self.__defaultHover:lineTo(0, height)
				self.__defaultHover:closePath()
				self.__defaultHover:endPath()
			end
			if x ~= self.__defaultHover:getX() or y ~= self.__defaultHover:getY() then
				if self.__tweener then
					self.__tweener:resetValues({x = x, y = y})
				else
					self.__defaultHover:setPosition(x, y)
				end
			end
			self:addChild(self.__defaultHover)
		end
	end
end

function OUYALayer:__goUp()
	local t = {}
	local empty = true
	local sprite = self.__objects[self.__selected]
	if sprite then
		local x, y, width, height = sprite:getBounds(self) --get global coordinates
		for i = 1, #self.__objects do
			if i ~= self.__selected then
				sprite = self.__objects[i]
				if sprite and self:__checkObject(i) then
					local nx, ny, nwidth, nheight = sprite:getBounds(self) --get global coordinates
					if ((nx >= x and nx <= x + width) or (nx + nwidth >= x and nx + nwidth <= x + width) or (x >= nx and x <= nx + nwidth) or (x + width >= nx and x + width <= nx + nwidth)) and ny < y then
						t[i] = sprite
						empty = false
					end
				end
			end
		end
		if empty then
			t = self.__objects
		end
		local id = 0
		local curPos = 10000000000
		local smallest = 10000000000000
		for i, val in pairs(t) do
			if i ~= self.__selected then
				if val then
					local nx, ny, _, _ = val:getBounds(self) --get global coordinates
					if ny < y and smallest > math.abs(y-ny) then
						id = i
						curPos = math.abs(x - nx)
						smallest = math.abs(y-ny)
					elseif ny < y and smallest == math.abs(y-ny) and curPos > math.abs(x - nx) then
						id = i
						curPos = math.abs(x - nx)
						smallest = math.abs(y-ny)
					end
				end
			end
		end
		if id ~= 0 then
			self.__selected = id
		end
	end
end

function OUYALayer:__goDown()
	local t = {}
	local empty = true
	local sprite = self.__objects[self.__selected]
	if sprite then
		local x, y, width, height = sprite:getBounds(self) --get global coordinates
		for i = 1, #self.__objects do
			if i ~= self.__selected then
				sprite = self.__objects[i]
				if sprite and self:__checkObject(i) then
					local nx, ny, nwidth, nheight = sprite:getBounds(self) --get global coordinates
					if ((nx >= x and nx <= x + width) or (nx + nwidth >= x and nx + nwidth <= x + width) or (x >= nx and x <= nx + nwidth) or (x + width >= nx and x + width <= nx + nwidth)) and ny > y then
						t[i] = sprite
						empty = false
					end
				end
			end
		end
		if empty then
			t = self.__objects
		end
		local id = 0
		local curPos = 10000000000
		local smallest = 10000000000000
		for i, val in pairs(t) do
			if i ~= self.__selected then
				if val and self:__checkObject(i) then
					local nx, ny, _, _ = val:getBounds(self) --get global coordinates
					if ny > y and smallest > math.abs(y-ny) then
						id = i
						curPos = math.abs(x - nx)
						smallest = math.abs(y-ny)
					elseif ny > y and smallest == math.abs(y-ny) and curPos > math.abs(x - nx) then
						id = i
						curPos = math.abs(x - nx)
						smallest = math.abs(y-ny)
					end
				end
			end
		end
		if id ~= 0 then
			self.__selected = id
		end
	end
end

function OUYALayer:__goLeft()
	local t = {}
	local empty = true
	local sprite = self.__objects[self.__selected]
	if sprite then
		local x, y, width, height = sprite:getBounds(self) --get global coordinates
		for i = 1, #self.__objects do
			if i ~= self.__selected then
				sprite = self.__objects[i]
				if sprite and self:__checkObject(i) then
					local nx, ny, nwidth, nheight = sprite:getBounds(self) --get global coordinates
					if ((ny >= y and ny <= y + height) or (ny + nheight >= y and ny + nheight <= y + height) or (y >= ny and y <= ny + nheight) or (y + height >= ny and y + height <= ny + nheight)) and nx < x then
						t[i] = sprite
						empty = false
					end
				end
			end
		end
		if empty then
			t = self.__objects
		end
		local id = 0
		local smallest = 10000000000000
		local curPos = 10000000000
		for i, val in pairs(t) do
			if i ~= self.__selected then
				if val and self:__checkObject(i) then
					local nx, ny, _, _ = val:getBounds(self) --get global coordinates
					if nx < x and smallest > math.abs(x-nx) then
						id = i
						curPos = math.abs(y - ny)
						smallest = math.abs(x-nx)
					elseif nx < x and smallest == math.abs(x-nx) and curPos > math.abs(y - ny) then
						id = i
						curPos = math.abs(y - ny)
						smallest = math.abs(x-nx)
					end
				end
			end
		end
		if id ~= 0 then
			self.__selected = id
		end
	end
end

function OUYALayer:__goRight()
	local t = {}
	local empty = true
	local sprite = self.__objects[self.__selected]
	if sprite then
		local x, y, width, height = sprite:getBounds(self) --get global coordinates
		for i = 1, #self.__objects do
			if i ~= self.__selected then
				sprite = self.__objects[i]
				if sprite and self:__checkObject(i) then
					local nx, ny, nwidth, nheight = sprite:getBounds(self) --get global coordinates
					if ((ny >= y and ny <= y + height) or (ny + nheight >= y and ny + nheight <= y + height) or (y >= ny and y <= ny + nheight) or (y + height >= ny and y + height <= ny + nheight)) and nx > x then
						t[i] = sprite
						empty = false
					end
				end
			end
		end
		if empty then
			t = self.__objects
		end
		local id = 0
		local smallest = 10000000000000
		local curPos = 10000000000
		for i, val in pairs(t) do
			if i ~= self.__selected then
				if val and self:__checkObject(i) then
					local nx, ny, _, _ = val:getBounds(self) --get global coordinates
					if nx > x and smallest > math.abs(x-nx) then
						id = i
						curPos = math.abs(y - ny)
						smallest = math.abs(x-nx)
					elseif nx > x and smallest == math.abs(x-nx) and curPos > math.abs(y - ny) then
						id = i
						curPos = math.abs(y - ny)
						smallest = math.abs(x-nx)
					end
				end
			end
		end
		if id ~= 0 then
			self.__selected = id
		end
	end
end

function OUYALayer:__checkObject(id)
	local sprite = self.__objects[id]
	if sprite then
		return sprite:isVisibleDeeply()
	end
	return false
end

function OUYALayer:__proxyEvent(event)
	if not self.__disabled then
		self:dispatchEvent(event)
	end
end

function OUYALayer:__added()
	ouya:addEventListener(Event.KEY_DOWN, OUYALayer.__handleKeys, self)
	ouya:addEventListener(Event.LEFT_JOYSTICK, OUYALayer.__handleJoystick, self)
	ouya:addEventListener(Event.KEY_DOWN, OUYALayer.__proxyEvent, self)
	ouya:addEventListener(Event.KEY_UP, OUYALayer.__proxyEvent, self)
	ouya:addEventListener(Event.RIGHT_JOYSTICK, OUYALayer.__proxyEvent, self)
	ouya:addEventListener(Event.LEFT_JOYSTICK, OUYALayer.__proxyEvent, self)
	ouya:addEventListener(Event.RIGHT_TRIGGER, OUYALayer.__proxyEvent, self)
	ouya:addEventListener(Event.LEFT_TRIGGER, OUYALayer.__proxyEvent, self)
end

function OUYALayer:__removed()
	ouya:removeEventListener(Event.KEY_DOWN, OUYALayer.__handleKeys, self)
	ouya:removeEventListener(Event.LEFT_JOYSTICK, OUYALayer.__handleJoystick, self)
	ouya:removeEventListener(Event.KEY_DOWN, OUYALayer.__proxyEvent, self)
	ouya:removeEventListener(Event.KEY_UP, OUYALayer.__proxyEvent, self)
	ouya:removeEventListener(Event.RIGHT_JOYSTICK, OUYALayer.__proxyEvent, self)
	ouya:removeEventListener(Event.LEFT_JOYSTICK, OUYALayer.__proxyEvent, self)
	ouya:removeEventListener(Event.RIGHT_TRIGGER, OUYALayer.__proxyEvent, self)
	ouya:removeEventListener(Event.LEFT_TRIGGER, OUYALayer.__proxyEvent, self)
end

function OUYALayer:__frame()
	if not self.__disabled then
		self:__hoverNext()
	end
end

function OUYALayer:disable()
	self.__disabled = true
	self.__defaultHover:setVisible(false)
end

function OUYALayer:enable()
	self.__disabled = false
	self.__defaultHover:setVisible(true)
end