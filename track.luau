-- Pointer -> eye offset, and the smoothed cursor position published for the ghost trail.
-- (Corruption now belongs to director.luau.)

type Track = {
    eyeX: Property<number>?,
    eyeY: Property<number>?,
    mouseX: Property<number>?,
    mouseY: Property<number>?,
    x: number,
    y: number,
    targetX: number,
    targetY: number,
}

function init(self: Track, context: Context): boolean
    -- init runs twice; the view model is absent the first time.
    local vm = context:viewModel()
    if vm == nil then
        return true
    end
    self.eyeX = vm:getNumber('eyeX')
    self.eyeY = vm:getNumber('eyeY')
    self.mouseX = vm:getNumber('mouseX')
    self.mouseY = vm:getNumber('mouseY')
    return true
end

function resize(self: Track, size: Vector)
end

function pointerMove(self: Track, event: PointerEvent)
    self.targetX = event.position.x
    self.targetY = event.position.y
end

function advance(self: Track, seconds: number): boolean
    local k = 1 - math.exp(-6 * seconds)
    self.x += (self.targetX - self.x) * k
    self.y += (self.targetY - self.y) * k

    -- Fixed artboard size: the layout's reported size is not the artboard's.
    local nx = math.clamp((self.x / 900) * 2 - 1, -1, 1)
    local ny = math.clamp((self.y / 600) * 2 - 1, -1, 1)

    if self.eyeX ~= nil then
        self.eyeX.value = 450 + nx * 16
    end
    if self.eyeY ~= nil then
        self.eyeY.value = 300 + ny * 10
    end
    if self.mouseX ~= nil then
        self.mouseX.value = self.x
    end
    if self.mouseY ~= nil then
        self.mouseY.value = self.y
    end
    return true
end

return function(context: Context): Layout<Track>
    return {
        eyeX = nil,
        eyeY = nil,
        mouseX = nil,
        mouseY = nil,
        x = 450,
        y = 300,
        targetX = 450,
        targetY = 300,
        init = init,
        resize = resize,
        pointerMove = pointerMove,
        advance = advance,
    }
end
