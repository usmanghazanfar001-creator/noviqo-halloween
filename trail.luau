-- Keeps a short history of cursor positions and renders shaders/ghost.wgsl with it.
-- Positions come from the view model (mouseX/mouseY, artboard coordinates), written by track.luau.

local RESX = 360
local RESY = 240
local POINTS = 8
local STEP = 0.035 -- seconds between history samples

type Trail = {
    size: Vector,
    time: number,
    clock: number,
    canvas: GPUCanvas?,
    pipeline: GPUPipeline?,
    ubo: GPUBuffer?,
    bindGroup: GPUBindGroup?,
    data: buffer,
    sampler: ImageSampler,
    corruption: Property<number>?,
    still: Property<number>?,
    mouseX: Property<number>?,
    mouseY: Property<number>?,
    xs: { number },
    ys: { number },
}

function init(self: Trail, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.corruption = vm:getNumber('corruption')
        self.still = vm:getNumber('still')
        self.mouseX = vm:getNumber('mouseX')
        self.mouseY = vm:getNumber('mouseY')
    end

    if self.canvas ~= nil then
        return true
    end
    local canvas = context:gpuCanvas({ width = RESX, height = RESY })
    local shader = context:shader('ghost')
    if canvas == nil or shader == nil then
        return true
    end
    local pipeline = GPUPipeline.new({
        vertex = shader,
        fragment = shader,
        vertexLayout = {},
        colorTargets = { { format = canvas.format } },
    })
    -- 16-byte header + 8 * vec4 = 144 bytes.
    local ubo = GPUBuffer.new({ size = 16 + POINTS * 16, usage = 'uniform' })
    local bindGroup = GPUBindGroup.new({
        layout = pipeline:getBindGroupLayout(0),
        ubos = { { slot = 0, buffer = ubo } },
    })
    self.canvas = canvas
    self.pipeline = pipeline
    self.ubo = ubo
    self.bindGroup = bindGroup
    return true
end

function resize(self: Trail, size: Vector)
    self.size = size
end

function advance(self: Trail, seconds: number): boolean
    -- Dead stillness: the whole world stops.
    if self.still ~= nil and self.still.value > 0.5 then
        return true
    end
    self.time += seconds
    self.clock += seconds
    if self.clock >= STEP then
        self.clock = 0
        local mx = if self.mouseX ~= nil then self.mouseX.value else 450
        local my = if self.mouseY ~= nil then self.mouseY.value else 300
        -- Artboard coords -> uv (y flipped: uv 0 is the bottom).
        table.insert(self.xs, 1, mx / 900)
        table.insert(self.ys, 1, 1 - my / 600)
        if #self.xs > POINTS then
            table.remove(self.xs)
            table.remove(self.ys)
        end
    end
    return true
end

function draw(self: Trail, renderer: Renderer)
    local canvas = self.canvas
    local pipeline = self.pipeline
    local ubo = self.ubo
    local bindGroup = self.bindGroup
    if canvas == nil or pipeline == nil or ubo == nil or bindGroup == nil then
        return
    end

    local strength = 0
    if self.corruption ~= nil then
        strength = self.corruption.value
    end

    buffer.writef32(self.data, 0, self.time)
    buffer.writef32(self.data, 4, strength)
    buffer.writef32(self.data, 8, RESX)
    buffer.writef32(self.data, 12, RESY)
    for i = 1, POINTS do
        local base = 16 + (i - 1) * 16
        -- Until history fills, reuse the oldest known point.
        local x = self.xs[math.min(i, #self.xs)]
        local y = self.ys[math.min(i, #self.ys)]
        buffer.writef32(self.data, base, x)
        buffer.writef32(self.data, base + 4, y)
        buffer.writef32(self.data, base + 8, 0)
        buffer.writef32(self.data, base + 12, 0)
    end
    ubo:write(self.data)

    local pass = canvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 0 } } },
    })
    pass:setPipeline(pipeline)
    pass:setBindGroup(0, bindGroup)
    pass:draw(3)
    pass:finish()

    renderer:save()
    renderer:transform(Mat2D.withScale(900 / RESX, 600 / RESY))
    renderer:drawImage(canvas.image, self.sampler, 'srcOver', 1)
    renderer:restore()
end

return function(context: Context): Layout<Trail>
    return {
        size = Vector.xy(0, 0),
        time = 0,
        clock = 0,
        canvas = nil,
        pipeline = nil,
        ubo = nil,
        bindGroup = nil,
        data = buffer.create(16 + POINTS * 16),
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        corruption = nil,
        still = nil,
        mouseX = nil,
        mouseY = nil,
        xs = { 0.5 },
        ys = { 0.5 },
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
    }
end
