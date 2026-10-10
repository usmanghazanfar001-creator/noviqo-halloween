-- Renders shaders/horror.wgsl (orb flicker, jump scare, blackout) over the scene.
-- Reads corruption, scare, blackout, still, watch from the view model; the director writes them.

local RESX = 360
local RESY = 240

type Horror = {
    time: number,
    canvas: GPUCanvas?,
    pipeline: GPUPipeline?,
    ubo: GPUBuffer?,
    bindGroup: GPUBindGroup?,
    data: buffer,
    sampler: ImageSampler,
    corruption: Property<number>?,
    scare: Property<number>?,
    blackout: Property<number>?,
    still: Property<number>?,
    watch: Property<number>?,
    secret: Property<number>?,
}

function init(self: Horror, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.corruption = vm:getNumber('corruption')
        self.scare = vm:getNumber('scare')
        self.blackout = vm:getNumber('blackout')
        self.still = vm:getNumber('still')
        self.watch = vm:getNumber('watch')
        self.secret = vm:getNumber('secret')
    end

    if self.canvas ~= nil then
        return true
    end
    local canvas = context:gpuCanvas({ width = RESX, height = RESY })
    local shader = context:shader('horror')
    if canvas == nil or shader == nil then
        return true
    end
    local pipeline = GPUPipeline.new({
        vertex = shader,
        fragment = shader,
        vertexLayout = {},
        colorTargets = { { format = canvas.format } },
    })
    local ubo = GPUBuffer.new({ size = 48, usage = 'uniform' })
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

local function val(p: Property<number>?, default: number): number
    if p ~= nil then
        return p.value
    end
    return default
end

function advance(self: Horror, seconds: number): boolean
    -- The orb light keeps flickering through the scare; it only freezes via `still` in the shader.
    self.time += seconds
    return true
end

function draw(self: Horror, renderer: Renderer)
    local canvas = self.canvas
    local pipeline = self.pipeline
    local ubo = self.ubo
    local bindGroup = self.bindGroup
    if canvas == nil or pipeline == nil or ubo == nil or bindGroup == nil then
        return
    end

    buffer.writef32(self.data, 0, self.time)
    buffer.writef32(self.data, 4, val(self.corruption, 0))
    buffer.writef32(self.data, 8, val(self.scare, 0))
    buffer.writef32(self.data, 12, val(self.blackout, 0))
    buffer.writef32(self.data, 16, RESX)
    buffer.writef32(self.data, 20, RESY)
    buffer.writef32(self.data, 24, val(self.still, 0))
    buffer.writef32(self.data, 28, val(self.watch, 0))
    buffer.writef32(self.data, 32, val(self.secret, 0))
    buffer.writef32(self.data, 36, 0)
    buffer.writef32(self.data, 40, 0)
    buffer.writef32(self.data, 44, 0)
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

return function(context: Context): Layout<Horror>
    return {
        time = 0,
        canvas = nil,
        pipeline = nil,
        ubo = nil,
        bindGroup = nil,
        data = buffer.create(48),
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        corruption = nil,
        scare = nil,
        blackout = nil,
        still = nil,
        watch = nil,
        secret = nil,
        init = init,
        advance = advance,
        draw = draw,
    }
end
