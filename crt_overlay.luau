-- Renders shaders/crt.wgsl (CRT overlay) on a small GPU canvas and draws it over the scene.
-- Low-res canvas scaled up, which also gives the pixels a CRT feel. Strength follows `corruption`.

local RESX = 360
local RESY = 240

type Glitch = {
    size: Vector,
    time: number,
    canvas: GPUCanvas?,
    pipeline: GPUPipeline?,
    ubo: GPUBuffer?,
    bindGroup: GPUBindGroup?,
    data: buffer,
    sampler: ImageSampler,
    corruption: Property<number>?,
    still: Property<number>?,
}

function init(self: Glitch, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.corruption = vm:getNumber('corruption')
        self.still = vm:getNumber('still')
    end

    -- init runs twice; build the GPU objects once.
    if self.canvas ~= nil then
        return true
    end
    local canvas = context:gpuCanvas({ width = RESX, height = RESY })
    local shader = context:shader('crt')
    if canvas == nil or shader == nil then
        -- No GPU here: the scene still works, just without fog.
        return true
    end
    local pipeline = GPUPipeline.new({
        vertex = shader,
        fragment = shader,
        vertexLayout = {},
        colorTargets = { { format = canvas.format } },
    })
    local ubo = GPUBuffer.new({ size = 16, usage = 'uniform' })
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

function resize(self: Glitch, size: Vector)
    self.size = size
end

function advance(self: Glitch, seconds: number): boolean
    -- Dead stillness: the whole world stops.
    if self.still ~= nil and self.still.value > 0.5 then
        return true
    end
    self.time += seconds
    return true
end

function draw(self: Glitch, renderer: Renderer)
    local canvas = self.canvas
    local pipeline = self.pipeline
    local ubo = self.ubo
    local bindGroup = self.bindGroup
    if canvas == nil or pipeline == nil or ubo == nil or bindGroup == nil then
        return
    end

    local strength = 0.08
    if self.corruption ~= nil then
        strength = 0.08 + self.corruption.value * 0.92
    end

    -- Uniforms: time, strength, resolution (vec2) = 16 bytes.
    buffer.writef32(self.data, 0, self.time)
    buffer.writef32(self.data, 4, strength)
    buffer.writef32(self.data, 8, RESX)
    buffer.writef32(self.data, 12, RESY)
    ubo:write(self.data)

    local pass = canvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 0 } } },
    })
    pass:setPipeline(pipeline)
    pass:setBindGroup(0, bindGroup)
    pass:draw(3)
    pass:finish()

    local w = 900
    local h = 600
    renderer:save()
    renderer:transform(Mat2D.withScale(w / RESX, h / RESY))
    renderer:drawImage(canvas.image, self.sampler, 'srcOver', 1)
    renderer:restore()
end

return function(context: Context): Layout<Glitch>
    return {
        size = Vector.xy(0, 0),
        time = 0,
        canvas = nil,
        pipeline = nil,
        ubo = nil,
        bindGroup = nil,
        data = buffer.create(16),
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        corruption = nil,
        still = nil,
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
    }
end
