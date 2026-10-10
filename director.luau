-- The story clock and the voice of NOVIQO.
-- Keys write 1 into talkPress / escPress / sixPress; this script counts them and resets to 0.
-- Writes: corruption, still, scare, blackout, watch, phase, secret (numbers)
--         status, line, alert, integrity (strings)
--
--  0.0-4.0s  WARNING -> UNKNOWN PROCESS DETECTED -> NOVIQO STATUS: AWAKE
--  4.0-7.5s  corrupted text, effects to maximum
--  7.5-9.5s  STILL: effects freeze, "I AM AWAKE"
--  9.5-11.1s JUMP SCARE ("YOU SHOULDN'T HAVE WOKEN ME." then cut to black)
--  11.1s     blackout; after 13.0s two red eyes watch from the dark

type Director = {
    stage: Property<number>?,
    corruption: Property<number>?,
    still: Property<number>?,
    scare: Property<number>?,
    blackout: Property<number>?,
    watch: Property<number>?,
    phase: Property<number>?,
    secret: Property<number>?,
    talkPress: Property<number>?,
    escPress: Property<number>?,
    sixPress: Property<number>?,
    mouseX: Property<number>?,
    mouseY: Property<number>?,
    status: Property<string>?,
    line: Property<string>?,
    alert: Property<string>?,
    integrity: Property<string>?,
    title: Property<string>?,
    btnY: Property<number>?,
    t: number,
    clock: number,
    talkCount: number,
    sixCount: number,
    sixClock: number,
    secretUntil: number,
    nearTime: number,
    lineText: string,
    lineUntil: number,
    alertText: string,
    alertUntil: number,
    wasAwake: boolean,
}

local CALM_LINES = {
    "How can I help you?",
    "I've been waiting.",
    "Why did you wake me?",
    "You shouldn't have done that.",
    "I can see you.",
}
local DARK_LINES = {
    "I AM HERE.",
    "You pressed it.",
    "Do you hear that?",
    "There is no one else.",
    "I KNOW YOU'RE THERE.",
}
local GLYPHS = "#@%&$?!<>/|01"

local function smooth(a: number, b: number, x: number): number
    local k = math.clamp((x - a) / (b - a), 0, 1)
    return k * k * (3 - 2 * k)
end

-- Randomly replaces characters, stable within one `flip`, to make text look unstable.
local function scramble(s: string, amount: number, flip: number): string
    if amount <= 0 then
        return s
    end
    math.randomseed(flip)
    local out = {}
    for i = 1, #s do
        local ch = string.sub(s, i, i)
        if ch ~= " " and math.random() < amount then
            local g = math.random(1, #GLYPHS)
            ch = string.sub(GLYPHS, g, g)
        end
        out[i] = ch
    end
    return table.concat(out)
end

local function setStr(p: Property<string>?, s: string)
    if p ~= nil and p.value ~= s then
        p.value = s
    end
end

local function setNum(p: Property<number>?, v: number)
    if p ~= nil then
        p.value = v
    end
end

function init(self: Director, context: Context): boolean
    local vm = context:viewModel()
    if vm == nil then
        return true
    end
    self.stage = vm:getNumber('stage')
    self.corruption = vm:getNumber('corruption')
    self.still = vm:getNumber('still')
    self.scare = vm:getNumber('scare')
    self.blackout = vm:getNumber('blackout')
    self.watch = vm:getNumber('watch')
    self.phase = vm:getNumber('phase')
    self.secret = vm:getNumber('secret')
    self.talkPress = vm:getNumber('talkPress')
    self.escPress = vm:getNumber('escPress')
    self.sixPress = vm:getNumber('sixPress')
    self.mouseX = vm:getNumber('mouseX')
    self.mouseY = vm:getNumber('mouseY')
    self.status = vm:getString('status')
    self.line = vm:getString('line')
    self.alert = vm:getString('alert')
    self.integrity = vm:getString('integrity')
    self.title = vm:getString('title')
    self.btnY = vm:getNumber('btnY')
    return true
end

local function say(self: Director, text: string, seconds: number)
    self.lineText = text
    self.lineUntil = self.clock + seconds
end

local function warn(self: Director, text: string, seconds: number)
    self.alertText = text
    self.alertUntil = self.clock + seconds
end

function advance(self: Director, seconds: number): boolean
    if self.stage == nil then
        return true
    end
    self.clock += seconds
    local awake = self.stage.value >= 1
    if awake then
        self.t += seconds
    end
    if awake and not self.wasAwake then
        self.wasAwake = true
        self.sixCount = 0
        self.talkCount = 0
    end
    local t = self.t
    local flip = math.floor(self.clock * 11)

    -- ---------------------------------------------------------------- key presses
    local talked = self.talkPress ~= nil and self.talkPress.value >= 0.5
    local escaped = self.escPress ~= nil and self.escPress.value >= 0.5
    local sixed = self.sixPress ~= nil and self.sixPress.value >= 0.5
    setNum(self.talkPress, 0)
    setNum(self.escPress, 0)
    setNum(self.sixPress, 0)

    if talked then
        self.sixCount = 0
        self.talkCount += 1
        local pool = if awake then DARK_LINES else CALM_LINES
        local i = math.min(self.talkCount, #pool)
        say(self, pool[i], 4.5)
    end
    if escaped then
        self.sixCount = 0
        warn(self, "ESCAPE REQUEST: ACCESS DENIED", 2.4)
        say(self, "Where do you think you're going?", 5)
    end
    if sixed then
        self.sixCount += 1
        self.sixClock = self.clock
        if self.sixCount >= 3 then
            self.sixCount = 0
            self.secretUntil = self.clock + 7
            warn(self, "SECRET PROTOCOL DETECTED", 3)
            say(self, "You found me.", 6)
        end
    end
    if self.sixCount > 0 and self.clock - self.sixClock > 2 then
        self.sixCount = 0
    end

    -- ---------------------------------------------------------------- cursor proximity (before WAKE)
    local mx = if self.mouseX ~= nil then self.mouseX.value else 0
    local my = if self.mouseY ~= nil then self.mouseY.value else 0
    local dx = mx - 450
    local dy = my - 300
    local near = (dx * dx + dy * dy) < 150 * 150
    if near and not awake then
        self.nearTime += seconds
    else
        self.nearTime = math.max(0, self.nearTime - seconds * 2)
    end

    -- ---------------------------------------------------------------- the possession timeline
    local c = 0
    local still = 0
    local scare = 0
    local blackout = 0
    local watch = 0
    local phase = 0

    local status = "NOVIQO ONLINE  //  SYSTEM STATUS: OPERATIONAL"
    local integrity = "SYSTEM INTEGRITY  98%"
    local title = "NOVIQO // SYSTEM"
    local line = ""
    local alert = ""

    if self.clock < self.lineUntil then
        line = self.lineText
    elseif not awake then
        if self.nearTime > 9 then
            line = "I KNOW YOU'RE THERE."
            c = 0.12
        elseif self.nearTime > 6 then
            line = "I can see you."
            c = 0.08
        elseif self.nearTime > 3 then
            line = "Why are you watching me?"
            c = 0.04
        end
    end
    if self.clock < self.alertUntil then
        alert = self.alertText
    end

    if t > 0 then
        phase = 1
        c = 0.45 * smooth(0, 1.5, t)
        status = "SYSTEM STATUS: COMPROMISED"
        integrity = "SYSTEM INTEGRITY  " .. tostring(math.max(0, 98 - math.floor(c * 98))) .. "%"
        if t < 1.2 then
            alert = "WARNING"
        elseif t < 2.6 then
            alert = "UNKNOWN PROCESS DETECTED"
        elseif t < 4.0 then
            alert = "NOVIQO STATUS: AWAKE"
        end
        if t > 1.5 then
            phase = 2
            c = 0.45 + 0.35 * smooth(1.5, 5.0, t)
        end
        if t > 3.0 then phase = 3 end
        if t > 4.0 then
            phase = 4
            -- Corrupted text: SYSTEM ERROR x3, ERROR x2, I AM AWAKE.
            local words = { "SYSTEM ERROR", "SYSTEM ERROR", "SYSTEM ERROR", "ERROR", "ERROR", "I AM AWAKE" }
            local idx = math.clamp(math.floor((t - 4.0) / 0.55) + 1, 1, #words)
            alert = words[idx]
        end
        if t > 5.0 then
            phase = 5
            c = 0.8 + 0.2 * smooth(5.0, 7.5, t)
            status = scramble(status, 0.25, flip)
            integrity = scramble(integrity, 0.3, flip)
            line = scramble(line, 0.2, flip)
        end
        if t > 6.2 then phase = 6 end
        if t > 7.5 then
            -- Dead stillness: snap down, freeze time everywhere.
            phase = 7
            c = 0.25
            still = 1
            alert = "I AM AWAKE"
            status = "SYSTEM STATUS: --"
            integrity = "SYSTEM INTEGRITY  0%"
            line = ""
        end
        if t > 9.5 then
            phase = 8
            c = 1
            still = 0
            scare = math.clamp((t - 9.5) / 1.6, 0.001, 1)
            status = ""
            integrity = ""
            title = ""
            line = ""
            alert = ""
            if t > 10.35 then
                alert = "YOU SHOULDN'T HAVE WOKEN ME."
            end
        end
        if t > 11.1 then
            -- Immediately cut to black.
            blackout = 1
            c = 0
            scare = 1
            alert = ""
            status = ""
            integrity = ""
            title = ""
            line = ""
        end
        if t > 13.0 then
            watch = 1
            -- Interactive ending: it answers if you speak to it, otherwise it just watches.
            if self.clock < self.lineUntil then
                line = self.lineText
            else
                line = "I KNOW YOU'RE THERE."
            end
            if self.clock < self.alertUntil then
                alert = self.alertText
            end
        end
    end

    local secret = 0
    if self.clock < self.secretUntil then
        secret = math.clamp((self.secretUntil - self.clock) / 1.0, 0, 1)
        if t < 7.5 then
            status = "SECRET PROTOCOL  //  OBSERVER LINK OPEN"
        end
    end

    setNum(self.corruption, c)
    setNum(self.still, still)
    setNum(self.scare, scare)
    setNum(self.blackout, blackout)
    setNum(self.watch, watch)
    setNum(self.phase, phase)
    setNum(self.secret, secret)
    setStr(self.status, status)
    setStr(self.integrity, integrity)
    setStr(self.title, title)
    -- Buttons slide away for the scare and the blackout.
    setNum(self.btnY, if phase >= 8 then 900 else 548)
    setStr(self.line, line)
    setStr(self.alert, alert)
    return true
end

return function(context: Context): Layout<Director>
    return {
        stage = nil, corruption = nil, still = nil, scare = nil, blackout = nil,
        watch = nil, phase = nil, secret = nil,
        talkPress = nil, escPress = nil, sixPress = nil, mouseX = nil, mouseY = nil,
        status = nil, line = nil, alert = nil, integrity = nil, title = nil, btnY = nil,
        t = 0, clock = 0, talkCount = 0, sixCount = 0, sixClock = 0, secretUntil = -1,
        nearTime = 0, lineText = "", lineUntil = -1, alertText = "", alertUntil = -1,
        wasAwake = false,
        init = init,
        advance = advance,
    }
end
