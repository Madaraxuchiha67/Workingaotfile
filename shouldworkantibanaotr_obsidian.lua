local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil

-- ============================================================
--  OBSIDIAN UI (deividcomsono/Obsidian)
--  A small helper layer below maps Tabs.X:AddToggle / AddSlider /
--  AddDropdown ... onto Obsidian groupboxes.
-- ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local ObsidianWindow = Library:CreateWindow({
    Title = "Aotr:update5",
    Footer = "Attack on Titan: Revolution",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(640, 480),
    Center = true,
    AutoShow = true,
})

local Notifier = {}
function Notifier:Notify(o)
    pcall(function()
        Library:Notify({
            Title = o.Title or "",
            Description = o.Content or "",
            Time = o.Duration or 4,
        })
    end)
end

-- Tab wrapper -> Obsidian tab. Each AddSection() starts a new groupbox,
-- alternating left/right. Controls added before any section go in a groupbox
-- named after the tab.
local function MakeTab(rawTab, title)
    local tab = { _tab = rawTab, _count = 0, _box = nil }

    local function newBox(name)
        tab._count += 1
        if tab._count % 2 == 1 then
            tab._box = rawTab:AddLeftGroupbox(name)
        else
            tab._box = rawTab:AddRightGroupbox(name)
        end
        return tab._box
    end
    local function box() return tab._box or newBox(title) end
    local function note(o)
        if o.Description and o.Description ~= "" then box():AddLabel(o.Description, true) end
    end

    function tab:AddSection(name) newBox(name) end

    function tab:AddToggle(idx, o)
        local t = box():AddToggle(idx, { Text = o.Title, Default = o.Default or false, Callback = o.Callback })
        note(o)
        return t
    end

    function tab:AddSlider(idx, o)
        local s = box():AddSlider(idx, {
            Text = o.Title, Default = o.Default, Min = o.Min, Max = o.Max,
            Rounding = o.Rounding or 0, Callback = o.Callback,
        })
        note(o)
        return s
    end

    function tab:AddDropdown(idx, o)
        local multi = o.Multi == true
        local info = { Text = o.Title, Values = o.Values or {}, Multi = multi, Callback = o.Callback }
        if not multi then info.Default = o.Default end
        local dd = box():AddDropdown(idx, info)
        if multi and type(o.Default) == "table" then
            local map = {}
            for k, v in pairs(o.Default) do
                if type(k) == "number" then map[v] = true elseif v then map[k] = true end
            end
            if next(map) then pcall(function() dd:SetValue(map) end) end
        end
        note(o)
        return dd
    end

    function tab:AddInput(idx, o)
        return box():AddInput(idx, {
            Text = o.Title, Default = o.Default or "", Placeholder = o.Placeholder or "",
            Numeric = o.Numeric or false, Finished = o.Finished or false, Callback = o.Callback,
        })
    end

    function tab:AddButton(o)
        local b = box():AddButton({ Text = o.Title, Func = o.Callback })
        note(o)
        return b
    end

    function tab:AddColorpicker(idx, o)
        local lbl = box():AddLabel(o.Title or "Color")
        local picker = lbl:AddColorPicker(idx, { Default = o.Default or Color3.new(1, 1, 1), Title = o.Title })
        local wrap = { _p = picker }
        function wrap:OnChanged(fn)
            pcall(function() picker:OnChanged(fn) end)
        end
        function wrap:SetValueRGB(c)
            local ok = pcall(function() picker:SetValueRGB(c) end)
            if not ok then
                pcall(function() picker:SetValue({ Color3.toHSV(c) }) end)
            end
        end
        return wrap
    end

    -- Paragraph -> wrapped label (keeps :SetDesc / .DescLabel for the Account tab).
    function tab:AddParagraph(o)
        local ttl, content = o.Title or "", o.Content or ""
        local function render(c)
            if ttl == "" then return c end
            if c:find("\n") or #c > 40 then return ttl .. "\n" .. c end
            return ttl .. ": " .. c
        end
        local lbl = box():AddLabel(render(content), true)
        local p = { DescLabel = lbl and lbl.TextLabel }
        function p:SetDesc(c) pcall(function() lbl:SetText(render(tostring(c))) end) end
        function p:SetTitle(t) ttl = t end
        return p
    end

    return tab
end

local Window = {}
Window.Root = setmetatable({}, {
    __index = function(_, k) if k == "Visible" then return Library.Toggled end end,
    __newindex = function(_, k, v)
        if k == "Visible" and Library.Toggled ~= v then pcall(function() Library:Toggle() end) end
    end,
})
function Window:AddTab(o)
    local raw
    local icon = (o.Icon and o.Icon ~= "") and o.Icon or nil
    local ok = pcall(function() raw = ObsidianWindow:AddTab(o.Title, icon) end)
    if not ok or not raw then raw = ObsidianWindow:AddTab(o.Title) end
    return MakeTab(raw, o.Title)
end
function Window:Minimize(force)
    pcall(function()
        if force == true then
            if Library.Toggled then Library:Toggle() end
        else
            Library:Toggle()
        end
    end)
end
function Window:SelectTab(tab) pcall(function() tab._tab:Show() end) end

local TrayIcon = {}
TrayIcon.isVisible = true
TrayIcon.connection = nil

function TrayIcon:CreateIcon()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrayIconGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "TrayIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(1, -60, 0, 10)
    iconFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.Position = UDim2.new(0, 0, 0, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "A"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame

    local hoverTween = nil
    iconFrame.MouseEnter:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(16, 110, 190)}
        )
        hoverTween:Play()
    end)

    iconFrame.MouseLeave:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(0, 120, 212)}
        )
        hoverTween:Play()
    end)

    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = iconFrame

    clickDetector.MouseButton1Click:Connect(function()
        self:ToggleUI()
        local clickTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(0, 45, 0, 45)}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local returnTween = TweenService:Create(iconFrame,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            returnTween:Play()
        end)
    end)

    self.gui = screenGui
    self.frame = iconFrame
    self.text = iconText
    self:CreateTooltip()
end

function TrayIcon:CreateTooltip()
    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 30)
    tooltip.Position = UDim2.new(1, -210, 0.5, -15)
    tooltip.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.Parent = self.frame

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 5)
    tooltipCorner.Parent = tooltip

    local tooltipText = Instance.new("TextLabel")
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = "Click to toggle UI visibility"
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.TextScaled = true
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.Parent = tooltip

    self.frame.MouseEnter:Connect(function() tooltip.Visible = true end)
    self.frame.MouseLeave:Connect(function() tooltip.Visible = false end)
end

function TrayIcon:ToggleUI()
    if self.isVisible then self:HideUI() else self:ShowUI() end
end

function TrayIcon:HideUI()
    if Window and Window.Root then
        Window.Root.Visible = false
        self.isVisible = false
        self.text.Text = "H"
        self.frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        Notifier:Notify({ Title = "UI Hidden", Content = "Click the tray icon to show UI again", Duration = 3 })
    end
end

function TrayIcon:ShowUI()
    if Window and Window.Root then
        Window.Root.Visible = true
        self.isVisible = true
        self.text.Text = "A"
        self.frame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
        Notifier:Notify({ Title = "UI Shown", Content = "UI is now visible", Duration = 2 })
    end
end

TrayIcon:CreateIcon()

--//==============================\\--
--||         TABS SETUP           ||--
--\\==============================//--

local EarlyAccountTab = Window:AddTab({ Title = "Account", Icon = "user" })

local Tabs = {
    Main          = Window:AddTab({ Title = "Main(Risky)",               Icon = "swords" }),
    AutoJoin      = Window:AddTab({ Title = "Auto Join",                 Icon = "door-open" }),
    Servers       = Window:AddTab({ Title = "Servers",                   Icon = "server" }),
    Misc          = Window:AddTab({ Title = "Misc",                      Icon = "wrench" }),
    Esp           = Window:AddTab({ Title = "Titans Esp",                Icon = "eye" }),
    Webhook       = Window:AddTab({ Title = "Webhook",                   Icon = "webhook" }),
    Settings      = Window:AddTab({ Title = "Settings",                  Icon = "settings" }),
}

--//==============================\\--
--||         SETTINGS TAB         ||--
--\\==============================//--

Tabs.Settings:AddToggle("TrayIconToggle", {
    Title = "Show Tray Icon",
    Description = "Show/Hide the system tray icon",
    Default = true,
    Callback = function(state)
        if TrayIcon.gui then TrayIcon.gui.Enabled = state end
    end
})

Tabs.Settings:AddParagraph({
    Title = "Tray Icon Usage",
    Content = "• The tray icon appears in the top-right corner\n• Click it to hide/show the UI\n• Red icon = UI hidden, Blue icon = UI visible\n• Ctrl+H (keyboard) or double-tap the screen (mobile) also toggles the UI"
})

--//==============================\\--
--||       MAINMENU (PlaceId)     ||--
--\\==============================//--

local allowedPlaceId = 13379208636
if game.PlaceId == allowedPlaceId then
    Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "house" })
    Tabs.Mainmenu:AddToggle("AutoRollToggle", {
        Title = "Auto Roll",
        Default = false,
        Callback = function(state) ENABLED = state end
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        TrayIcon:ToggleUI()
    end
end)

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player and TrayIcon.gui then TrayIcon.gui:Destroy() end
end)

--------------------------------------------------------------------------

local HttpService     = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput    = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local isFlying   = false
local bodyPos
local LocalPlayer = Players.LocalPlayer
local startDelay  = 0
local flyHeight   = 250

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService    = game:GetService("TweenService"),
    CoreGui         = game:GetService("CoreGui")
}

local Player = {
    self      = Services.Players.LocalPlayer,
    character = nil,
    hrp       = nil,
    gui       = nil
}

local Config = {
    flySpeed              = 250,
    canHit                = true,
    isFlying              = false,
    moveMode              = "Teleportation",
    notificationsEnabled  = true,
    startDelay            = 0,
    loadDelay             = 10,    -- seconds to wait AFTER the game/loading screen is done before farming starts
    maxRange              = 3000,  -- max studs the farm may move from where it started (keeps you inside the map)
    flyHeight             = 250,
    titanKillCount        = 0,
    autoRefill            = false,
    lastBladesEmpty       = false,
    lastSpearsEmpty       = false
}

local Data = {
    notified    = {},
    activeNotifs = {},
    POST        = nil,
    refill      = nil
}

Player.character = Player.self.Character or Player.self.CharacterAdded:Wait()
Player.hrp       = Player.character:WaitForChild("HumanoidRootPart")
Player.gui       = Player.self:WaitForChild("PlayerGui")

task.spawn(function()
    local success2, result2 = pcall(function()
        return Services.ReplicatedStorage:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)
    end)
    Data.POST = success2 and result2 or nil
end)

function showKillNotification(count)
    if not Config.notificationsEnabled then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TN_" .. tick()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Services.CoreGui
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 190, 0, 75)
    frame.Position = UDim2.new(1, 20, 0, 10 + (#Data.activeNotifs * 80))
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Successfully\nHit:"
    label.TextColor3 = Color3.fromRGB(184, 164, 101)
    label.Font = Enum.Font.Fantasy
    label.TextScaled = true
    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(0, 60, 0.5, 0)
    counter.Position = UDim2.new(1, -65, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = tostring(count)
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.Font = Enum.Font.Fantasy
    counter.TextScaled = true
    table.insert(Data.activeNotifs, gui)
    Services.TweenService:Create(frame, TweenInfo.new(0.35), {
        Position = UDim2.new(1, -210, 0, 10 + ((#Data.activeNotifs - 1) * 80))
    }):Play()
    task.delay(5, function()
        gui:Destroy()
        for i, v in ipairs(Data.activeNotifs) do
            if v == gui then table.remove(Data.activeNotifs, i) break end
        end
    end)
end

local TITAN_PRIORITY = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

local function napeOf(titan)
    local hb = titan:FindFirstChild("Hitboxes")
    local hit = hb and hb:FindFirstChild("Hit")
    return hit and hit:FindFirstChild("Nape")
end

local function isAlive(titan)
    local h = titan:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

-- keep the character reference fresh after respawn (the old code kept a dead HRP)
Player.self.CharacterAdded:Connect(function(c)
    Player.character = c
    Player.hrp = c:WaitForChild("HumanoidRootPart")
end)

local targetList, lastScan = {}, 0

local function scanTargets()
    table.clear(targetList)
    local folder = workspace:FindFirstChild("Titans")
    if not folder or not Player.hrp then return end
    local pos = Player.hrp.Position
    for _, name in ipairs(TITAN_PRIORITY) do
        local t = folder:FindFirstChild(name)
        if t and isAlive(t) then
            local n = napeOf(t)
            if n then targetList[#targetList + 1] = n end
        end
    end
    local others = {}
    for _, t in ipairs(folder:GetChildren()) do
        if not table.find(TITAN_PRIORITY, t.Name) and isAlive(t) then
            local n = napeOf(t)
            if n then others[#others + 1] = { n, (pos - n.Position).Magnitude } end
        end
    end
    table.sort(others, function(a, b) return a[2] < b[2] end)
    for _, o in ipairs(others) do targetList[#targetList + 1] = o[1] end
end

-- target list is rebuilt at most 10x/second instead of every frame
function getClosestValidNape()
    local first = targetList[1]
    if os.clock() - lastScan > 0.1 or not first or not first.Parent then
        scanTargets()
        lastScan = os.clock()
    end
    return targetList[1]
end

Config.hitCooldown = 0.12   -- seconds between hit bursts (was 0.25)
Config.multiHit    = 8      -- napes hit per burst (was 3)
Config.hitAll      = false  -- true = every alive titan gets hit in the same burst

local killConnection
local killStartAt = 0

-- ===== LOAD GATE: don't farm while the loading screen is up =====
local farmReadyAt, farmAnchor = nil, nil

local function loadingScreenVisible()
    local pg = Player.gui
    if not pg then return true end
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and g.Name:lower():find("load") then
            return true
        end
    end
    return false
end

local function gameReady()
    if not game:IsLoaded() then return false end
    local hrp = Player.hrp
    if not hrp or not hrp.Parent then return false end
    local hum = Player.character and Player.character:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not workspace:FindFirstChild("Titans") then return false end
    if loadingScreenVisible() then return false end
    return true
end

-- true once everything is loaded AND loadDelay seconds have passed
local function farmGateOpen()
    if not gameReady() then
        farmReadyAt, farmAnchor = nil, nil -- screen came back (new mission/retry): wait again
        return false
    end
    if not farmReadyAt then
        farmReadyAt = os.clock() + Config.loadDelay
        farmAnchor  = Player.hrp.Position
    end
    return os.clock() >= farmReadyAt
end

-- keeps the target finite, above the void and inside maxRange of the start point
local function clampTarget(pos)
    if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z
        or math.abs(pos.X) == math.huge or math.abs(pos.Y) == math.huge or math.abs(pos.Z) == math.huge then
        return nil
    end
    local a = farmAnchor or Player.hrp.Position
    local off = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
    if off.Magnitude > Config.maxRange then
        off = off.Unit * Config.maxRange
    end
    local minY = workspace.FallenPartsDestroyHeight + 100
    local maxY = a.Y + Config.flyHeight + 100
    return Vector3.new(a.X + off.X, math.clamp(pos.Y, minY, maxY), a.Z + off.Z)
end

function killFromAbove()
    killStartAt = os.clock() + Config.startDelay
    if killConnection then return end -- one connection only (old code stacked a new one on every toggle)
    killConnection = Services.RunService.Heartbeat:Connect(function()
        if not Config.isFlying or Config.missionDone or os.clock() < killStartAt then return end
        if not farmGateOpen() then return end
        local hrp = Player.hrp
        if not hrp or not hrp.Parent then return end
        local nape = getClosestValidNape()
        if not nape then return end
        local targetPos = clampTarget(nape.Position + Vector3.new(0, Config.flyHeight, 0))
        if not targetPos then return end
        if Config.moveMode == "Gliding" then
            local delta = targetPos - hrp.Position
            if delta.Magnitude > 1 then hrp.AssemblyLinearVelocity = delta.Unit * Config.flySpeed end
        else
            hrp.CFrame = CFrame.new(targetPos)
        end
        if Config.canHit and (hrp.Position - nape.Position).Magnitude <= 1520 then
            Config.canHit = false
            task.spawn(function()
                local post = Data.POST
                local count = Config.hitAll and #targetList or math.min(Config.multiHit, #targetList)
                for i = 1, count do
                    local n = targetList[i]
                    if n and n.Parent then
                        if post then
                            post:FireServer("Hitboxes", "Register", n, math.random(200, 300), math.random(20, 30) / 100)
                            post:FireServer("Attacks", "Slash", true)
                        end
                        local id = tostring(n:GetDebugId())
                        if not Data.notified[id] then
                            Data.notified[id] = true
                            Config.titanKillCount = Config.titanKillCount + 1
                            showKillNotification(Config.titanKillCount)
                        end
                    end
                end
                if Config.onKillBurst then task.spawn(Config.onKillBurst) end
                task.wait(Config.hitCooldown)
                Config.canHit = true
            end)
        end
    end)
end

--//==============================\\--
--||   👑 REFILL / RELOAD SYSTEM  ||--
--\\==============================//--

local BladeUI_S2       = nil
local Gradient_S2      = nil
local SetsLabel_S2     = nil
local autoBladeRunning = false

pcall(function()
    BladeUI_S2    = player.PlayerGui.Interface.HUD.Main.Top["7"].Blades
    Gradient_S2   = BladeUI_S2.Inner.Bar.Gradient
    SetsLabel_S2  = BladeUI_S2.Sets
end)

local function TweenTo_S2(cf, speed)
    local charRef = player.Character if not charRef then return end
    local hrpRef  = charRef:FindFirstChild("HumanoidRootPart")
    local humRef  = charRef:FindFirstChild("Humanoid")
    if not hrpRef or not humRef or humRef.Health <= 0 then return end
    local distance = (hrpRef.Position - cf.Position).Magnitude
    local t        = distance / speed
    local tween    = TweenService:Create(hrpRef, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local refillParts, refillScanAt = nil, 0

local function FindRefillPart()
    -- scan the whole workspace once, then only re-check the cached parts
    local stale = os.clock() - refillScanAt
    if not refillParts or stale > 30 or (#refillParts == 0 and stale > 3) then
        refillParts = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("refill") or name:find("fill") then
                    refillParts[#refillParts + 1] = v
                end
            end
        end
        refillScanAt = os.clock()
    end
    for _, v in ipairs(refillParts) do
        if v.Parent then
            local display = v:FindFirstChild("Display")
            if display then
                local ok, title = pcall(function() return display.Main.Top.Title.Text end)
                if ok and title ~= "REFILLS: 0 / 3 [R]" then return v end
            end
        end
    end
    return nil
end

local function Refill_S2()
    local refillPart = FindRefillPart()
    if not refillPart then return end
    TweenTo_S2(refillPart.CFrame, 6000)
    pcall(function()
        ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", refillPart)
    end)
end

local function ChangeBlade_S2()
    pcall(function()
        ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Blades", "Reload")
    end)
end

local function CheckBlade_S2()
    if not Gradient_S2 then return false end
    local x = Gradient_S2.Offset.X
    if x < 0 then
        local bladeOk = false
        pcall(function()
            local rig = workspace.Characters[player.Name]["Rig_" .. player.Name]
            local blade = rig.LeftHand.Blade_1
            if blade.Transparency == 0 then bladeOk = true end
        end)
        if bladeOk then return false end
        if SetsLabel_S2 and SetsLabel_S2.Text == "0 / 3" then
            Refill_S2()
        else
            ChangeBlade_S2()
        end
        return true
    end
    return false
end

if Gradient_S2 then
    Gradient_S2:GetPropertyChangedSignal("Offset"):Connect(function()
        if autoBladeRunning then CheckBlade_S2() end
    end)
end

local bladeLoopToken = 0
local function StartBladeLoop()
    bladeLoopToken = bladeLoopToken + 1
    local my = bladeLoopToken
    autoBladeRunning = true
    task.spawn(function()
        while autoBladeRunning and bladeLoopToken == my do
            CheckBlade_S2()
            task.wait(0.2)
        end
    end)
end

Tabs.Main:AddSection("Auto Farm")

local BladeToggle = Tabs.Main:AddToggle("AutoBladeReload", {
    Title = "Auto Reload / Refill Blades",
    Description = "Switches blade sets automatically; teleports to refill station when all sets are empty",
    Default = true,
    Callback = function(state)
        if state then
            StartBladeLoop()
        else
            autoBladeRunning = false
            bladeLoopToken = bladeLoopToken + 1
        end
    end
})
-- callbacks don't fire on creation, so start it for the default-on state
if BladeToggle.Value then StartBladeLoop() end

--//==============================\\--
--||        👑 AUTO CLICK M1       ||--
--\\==============================//--

local autoM1Running = false
local autoM1Token   = 0
local M1_DELAY       = 0.25
local M1Toggle

local RESULT_TITLES_M1 = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

local function GuiVisibleM1(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function MissionCompleted()
    local ok, res = pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if RESULT_TITLES_M1[t:upper()] and GuiVisibleM1(d) then return true end
            end
        end
        return false
    end)
    return ok and res
end

--//==============================\\--
--||     SLOW LAND AFTER MISSION  ||--
--\\==============================//--

Config.missionDone = false
Config.landSpeed   = 15   -- studs per second (lower = slower)

do
    local landed = false

    -- watch for the MISSION / RAID COMPLETED screen (polled, not every frame)
    task.spawn(function()
        while true do
            local done = MissionCompleted()
            if done and not Config.missionDone then
                Config.missionDone = true
                landed = false
            elseif not done and Config.missionDone then
                Config.missionDone = false  -- new mission / retry: farm resumes
                landed = false
            end
            task.wait(0.5)
        end
    end)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    RunService.Heartbeat:Connect(function(dt)
        if not Config.missionDone or landed then return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
        if not hit then landed = true return end -- nothing below: let normal physics take over

        -- stand height = ground + hip height + half the root part (never lower than this = no clipping)
        local standY = hit.Position.Y + hum.HipHeight + hrp.Size.Y / 2 + 0.2
        local y = hrp.Position.Y

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        if y <= standY + 0.3 then
            landed = true
            return
        end

        local newY = math.max(standY, y - Config.landSpeed * dt)
        local pos  = hrp.Position
        hrp.CFrame = CFrame.new(pos.X, newY, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end

local cachedAttackBtn
local function FindAttackButton()
    if cachedAttackBtn and cachedAttackBtn.Parent and cachedAttackBtn.Visible then return cachedAttackBtn end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local n = d.Name:lower()
            if n == "attack" or n == "m1" or n == "slash" then cachedAttackBtn = d return d end
        end
    end
    return nil
end

local function ClickM1()
    -- real mouse click in the screen centre (M1)
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    -- on-screen attack button (mobile layout), if one exists
    pcall(function()
        local btn = FindAttackButton()
        if btn then
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            else
                local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.03)
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end
    end)
end

-- M1 no longer spams on its own: it only clicks when Auto Kill actually fires a hit burst
local M1Enabled = true
local lastM1 = 0

Config.onKillBurst = function()
    if not M1Enabled then return end
    if os.clock() - lastM1 < M1_DELAY then return end
    lastM1 = os.clock()
    ClickM1()
end

M1Toggle = Tabs.Main:AddToggle("AutoClickM1", {
    Title = "Auto Click M1 (only while killing)",
    Description = "Clicks M1 only when Auto Kill is hitting titans. Follows the Auto Kill switch",
    Default = true,
    Callback = function(state)
        M1Enabled = state and true or false
    end
})
if M1Toggle and M1Toggle.Value ~= nil then M1Enabled = M1Toggle.Value and true or false end

local KillToggle = Tabs.Main:AddToggle("AutoKillTitans", {
    Title = "Auto Kill Titans",
    Description = "Don't Finish the mission under 17 sec",
    Default = true,
    Callback = function(state)
        Config.isFlying = state
        if state then task.spawn(killFromAbove) end
        -- M1 setting turns on/off together with Auto Kill
        if M1Toggle and M1Toggle.SetValue then pcall(function() M1Toggle:SetValue(state and true or false) end) end
    end
})
if KillToggle.Value then Config.isFlying = true task.spawn(killFromAbove) end

Tabs.Main:AddDropdown("MoveMode", {
    Title = "Movement Mode",
    Values = {"Teleportation", "Gliding"},
    Default = 1,
    Callback = function(option) Config.moveMode = option end
})

Tabs.Main:AddSlider("StartDelaySlider", {
    Title = "Farm Delay",
    Description = "0 = start instantly. Raise it if the mission ends too early",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(value) Config.startDelay = value end
})

Tabs.Main:AddSlider("LoadDelaySlider", {
    Title = "Loading Screen Wait (sec)",
    Description = "Waits this long after the map finishes loading before farming starts",
    Default = 10,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.loadDelay = value end
})

Tabs.Main:AddSlider("LandSpeedSlider", {
    Title = "Landing Speed (after mission)",
    Description = "How slowly you descend once the mission is complete",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.landSpeed = value end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Gliding Speed",
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.flySpeed = value end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
    Title = "Float Height",
    Default = 250,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.flyHeight = value end
})

Tabs.Main:AddSlider("HitSpeedSlider", {
    Title = "Hit Interval (ms) - lower = faster",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.hitCooldown = value / 1000 end
})

Tabs.Main:AddSlider("MultiHitSlider", {
    Title = "Titans Hit Per Burst",
    Default = 8,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.multiHit = value end
})

Tabs.Main:AddToggle("HitAllTitans", {
    Title = "Hit All Titans At Once",
    Description = "Every alive titan gets hit in the same burst (ignores Titans Hit Per Burst)",
    Default = false,
    Callback = function(state) Config.hitAll = state end
})

local _Remotes = game:GetService("ReplicatedStorage").Assets.Remotes
local GET, POST = _Remotes.GET, _Remotes.POST

--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VIM = game:GetService("VirtualInputManager")

local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local rewards     = interface and interface:FindFirstChild("Rewards")
local rewardsMain = rewards and rewards:FindFirstChild("Main")
local retryBtn    = rewardsMain
    and rewardsMain:FindFirstChild("Info")
    and rewardsMain.Info:FindFirstChild("Main")
    and rewardsMain.Info.Main:FindFirstChild("Buttons")
    and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")

local autoRetryEnabled = false

local function showDebugDot(x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, x - 5, 0, y - 5)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.ZIndex = 10000
    dot.Name = "DebugDot"
    pcall(function() dot.Parent = game:GetService("CoreGui") end)
    game:GetService("Debris"):AddItem(dot, 2)
end

local function Retryshi()
    local pos  = retryBtn.AbsolutePosition
    local size = retryBtn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    showDebugDot(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function shouldClickRetry()
    return retryBtn
        and rewards and rewards.Visible
        and rewardsMain and rewardsMain.Visible
        and retryBtn.Visible
        and retryBtn.AbsoluteSize.Magnitude > 10
end

task.spawn(function()
    while true do
        if autoRetryEnabled and shouldClickRetry() then
            task.wait(0.3)
            if shouldClickRetry() then
                Retryshi()
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

Tabs.Main:AddSection("Utilities")

Tabs.Main:AddToggle("AutoRetryToggle", {
    Title = "Auto Retry",
    Default = false,
    Callback = function(state) autoRetryEnabled = state end
})

--//==============================\\--
--||     AUTO SKIP CUTSCENES      ||--
--\\==============================//--

local autoSkipRunning = false
local autoSkipToken   = 0
local skipClickedAt   = setmetatable({}, { __mode = "k" })

local function SkipGuiShown(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function LooksLikeSkip(btn)
    if btn.Name:lower():find("skip", 1, true) then return true end
    if btn:IsA("TextButton") then
        local t = btn.Text:gsub("<[^>]->", ""):lower()
        if t:find("skip", 1, true) then return true end
    end
    for _, c in ipairs(btn:GetChildren()) do -- label sitting inside an ImageButton
        if c:IsA("TextLabel") then
            local t = c.Text:gsub("<[^>]->", ""):lower()
            if t:find("skip", 1, true) then return true end
        end
    end
    return false
end

local function PressButton(btn)
    local fired = false
    if getconnections then
        for _, sig in ipairs({ btn.MouseButton1Down, btn.MouseButton1Up, btn.MouseButton1Click, btn.Activated }) do
            pcall(function()
                for _, c in ipairs(getconnections(sig)) do
                    c:Fire()
                    fired = true
                end
            end)
        end
    end
    if not fired and firesignal then
        pcall(function()
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
            fired = true
        end)
    end
    if not fired then -- last resort: a real click on the button
        local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end
end

local function SkipCutscenesOnce()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0
            and LooksLikeSkip(d) and SkipGuiShown(d) then
            local last = skipClickedAt[d]
            if not last or os.clock() - last > 1.5 then
                skipClickedAt[d] = os.clock()
                PressButton(d)
                return
            end
        end
    end
end

local function StartSkipLoop()
    autoSkipToken += 1
    local my = autoSkipToken
    autoSkipRunning = true
    task.spawn(function()
        while autoSkipRunning and autoSkipToken == my do
            pcall(SkipCutscenesOnce)
            task.wait(0.5)
        end
    end)
end

local SkipToggle = Tabs.Main:AddToggle("AutoSkipCutscenes", {
    Title = "Auto Skip Cutscenes",
    Description = "Presses the Skip button as soon as a cutscene shows one",
    Default = true,
    Callback = function(state)
        if state then
            StartSkipLoop()
        else
            autoSkipRunning = false
            autoSkipToken += 1
        end
    end
})
if SkipToggle.Value then StartSkipLoop() end

--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--

local escapeRunning    = false
local escapeThread     = nil
local cleanGUIThread   = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value
        if not Value then lastEscapeButton = nil return end
        escapeThread = task.spawn(function()
            local pg = player:WaitForChild("PlayerGui")
            while escapeRunning do
                local iface   = pg:FindFirstChild("Interface")
                local buttons = iface and iface:FindFirstChild("Buttons")
                if buttons then
                    local list = buttons:GetChildren()
                    if #list > 0 then
                        POST:FireServer("Attacks", "Slash_Escape")
                        for _, b in ipairs(list) do b:Destroy() end
                    end
                end
                task.wait(0.05)
            end
        end)
    end
})

--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--

local CLICK_DELAY = 0.2
local WAIT_DELAY  = 1
local ENABLED     = false

local function canClick(btn)
    return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    local Gui = player:WaitForChild("PlayerGui")
    while current and current ~= Gui do
        local success3, result3 = pcall(function() return current.Visible end)
        if success3 and not result3 then return false end
        current = current.Parent
    end
    return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
    if not btn then return false end
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    VIM:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function findButton(parent, buttonName)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj.Name == buttonName and obj:IsA("GuiButton") then return obj end
        for _, child in pairs(obj:GetChildren()) do
            local result4 = searchRecursive(child)
            if result4 then return result4 end
        end
        return nil
    end
    return searchRecursive(parent)
end

local function findButtonByText(parent, text)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj:IsA("GuiButton") or obj:IsA("TextButton") then
            local hasText = obj:FindFirstChild("Text") or obj.Text
            if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then return obj end
        end
        for _, child in pairs(obj:GetChildren()) do
            local result5 = searchRecursive(child)
            if result5 then return result5 end
        end
        return nil
    end
    return searchRecursive(parent)
end

task.spawn(function()
    local Gui = player:WaitForChild("PlayerGui")
    local interface2 = Gui:WaitForChild("Interface", 10)
    if not interface2 then return end
    local rollButton = nil
    local searchPaths = {"Customisation.Family.Buttons_2.Roll", "Roll", "RollButton"}
    for _, path in pairs(searchPaths) do
        local pathParts = string.split(path, ".")
        local current = interface2
        for _, part in pairs(pathParts) do
            if current then current = current:FindFirstChild(part) end
        end
        if current and current:IsA("GuiButton") then rollButton = current break end
    end
    if not rollButton then rollButton = findButton(interface2, "Roll") end
    if not rollButton then rollButton = findButtonByText(interface2, "roll") end
    if not rollButton then return end
    while true do
        if ENABLED then
            if canClick(rollButton) and isActuallyVisible(rollButton) then
                clickButton(rollButton)
                task.wait(CLICK_DELAY)
            else task.wait(WAIT_DELAY) end
        else task.wait(1) end
    end
end)

--//==============================\\--
--||        AUTO JOIN TAB         ||--
--\\==============================//--

local Difficulties      = {"Best For You","Easy","Normal","Hard","Severe","Aberrant"}
local DifficultiesRaids = {"Best For You","Hard","Severe","Aberrant"}
local ModifiersList     = {"No Perks","No Skills","No Memories","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}
local MissionMaps       = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess","Chapel"}
local MissionObjectives = {
    ["Shiganshina"]={"Skirmish","Breach","Random"},
    ["Trost"]      ={"Skirmish","Protect","Random"},
    ["Outskirts"]  ={"Skirmish","Escort","Random"},
    ["Forest"]     ={"Skirmish","Guard","Random"},
    ["Utgard"]     ={"Skirmish","Defend","Random"},
    ["Docks"]      ={"Skirmish","Stall","Random"},
    ["Stohess"]    ={"Skirmish","Random"},
    ["Chapel"]     ={"Skirmish","Random"},
}
local RaidMaps      = {"Shiganshina","Trost","Stohess"}
local RaidObjectives= {["Shiganshina"]={"Armored Titan","Colossal Titan"},["Trost"]={"Attack Titan"},["Stohess"]={"Female Titan"}}
local WaveMaps      = {"Trost"}

_G.AJ = {
    SelectMissionMap        = MissionMaps[1],
    SelectMissionObjective  = MissionObjectives[MissionMaps[1]][1],
    SelectMissionDifficulty = "Easy",
    SelectMissionModifiers  = {},
    SelectRaidMap           = RaidMaps[1],
    SelectRaidObjective     = RaidObjectives[RaidMaps[1]][1],
    SelectRaidDifficulty    = "Easy",
    SelectRaidModifiers     = {},
    SelectWaveMap           = WaveMaps[1],
    AutoJoinMission         = false,
    AutoJoinMissionBoost    = false,
    AutoJoinRaid            = false,
    AutoJoinWaves           = false,
}

local function PressButton(d)
    game:GetService("GuiService").SelectedObject = d
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local function CreateAndStart(data)
    if game.PlaceId == 14916516914 then
        local ok, res = pcall(function() return GET:InvokeServer("S_Missions","Create",data) end)
        if ok and typeof(res) == "Instance" then
            task.wait(1)
            pcall(function() return GET:InvokeServer("S_Missions","Start") end)
            return true
        end
        return false
    end
end

-- Mission section
Tabs.AutoJoin:AddSection("Auto Join Missions")

local MissionObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_MissionMap", {
    Title = "Select Map",
    Values = MissionMaps,
    Default = _G.AJ.SelectMissionMap,
    Callback = function(v)
        _G.AJ.SelectMissionMap = v
        local objs = MissionObjectives[v]
        if objs then _G.AJ.SelectMissionObjective = objs[1] end
        if MissionObjectiveDropdown2 then MissionObjectiveDropdown2:SetValues(MissionObjectives[v] or {}) end
    end
})

MissionObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_MissionObjective", {
    Title = "Select Objective",
    Values = MissionObjectives[_G.AJ.SelectMissionMap] or {},
    Default = _G.AJ.SelectMissionObjective,
    Callback = function(v) _G.AJ.SelectMissionObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionDifficulty", {
    Title = "Select Difficulty",
    Values = Difficulties,
    Default = _G.AJ.SelectMissionDifficulty,
    Callback = function(v) _G.AJ.SelectMissionDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectMissionModifiers,
    Callback = function(v) _G.AJ.SelectMissionModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMission", {
    Title = "Auto Join Mission",
    Description = "Automatically joins missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMission = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission then
            CreateAndStart({Name=_G.AJ.SelectMissionMap,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMissionBoost", {
    Title = "Auto Join Mission (Rewards Boost)",
    Description = "Automatically joins boosted missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMissionBoost = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMissionBoost then
            CreateAndStart({Name=game:GetService("Workspace"):GetAttribute("Boosted_Map"),Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

-- Raids section
Tabs.AutoJoin:AddSection("Auto Join Raids")

local RaidObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_RaidMap", {
    Title = "Select Raid Map",
    Values = RaidMaps,
    Default = _G.AJ.SelectRaidMap,
    Callback = function(v)
        _G.AJ.SelectRaidMap = v
        local objs = RaidObjectives[v]
        if objs then _G.AJ.SelectRaidObjective = objs[1] end
        if RaidObjectiveDropdown2 then RaidObjectiveDropdown2:SetValues(RaidObjectives[v] or {}) end
    end
})

RaidObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_RaidObjective", {
    Title = "Select Raid Boss",
    Values = RaidObjectives[_G.AJ.SelectRaidMap] or {},
    Default = _G.AJ.SelectRaidObjective,
    Callback = function(v) _G.AJ.SelectRaidObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidDifficulty", {
    Title = "Select Difficulty",
    Values = DifficultiesRaids,
    Default = _G.AJ.SelectRaidDifficulty,
    Callback = function(v) _G.AJ.SelectRaidDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectRaidModifiers,
    Callback = function(v) _G.AJ.SelectRaidModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinRaid", {
    Title = "Auto Join Raid",
    Description = "Automatically joins raids",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinRaid = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinRaid then
            CreateAndStart({Name=_G.AJ.SelectRaidMap,Type="Raids",Difficulty=_G.AJ.SelectRaidDifficulty,Objective=_G.AJ.SelectRaidObjective,Modifiers=_G.AJ.SelectRaidModifiers,Limit=8})
        end
    end
end)

-- Waves section
Tabs.AutoJoin:AddSection("Auto Join Waves")

Tabs.AutoJoin:AddDropdown("AJ_WaveMap", {
    Title = "Select Wave Map",
    Values = WaveMaps,
    Default = _G.AJ.SelectWaveMap,
    Callback = function(v) _G.AJ.SelectWaveMap = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinWaves", {
    Title = "Auto Join Waves",
    Description = "Automatically joins waves",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinWaves = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinWaves then
            CreateAndStart({Name=_G.AJ.SelectWaveMap,Type="Waves",Difficulty="Easy",Objective="Waves",Limit=8})
        end
    end
end)

-- Leave wrong mission auto-correct
spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission or _G.AJ.AutoJoinRaid or _G.AJ.AutoJoinWaves then
            for _, v in pairs(game:GetService("ReplicatedStorage").Missions:GetChildren()) do
                if v.Leader.Value == player.Name then
                    local Target = nil
                    if _G.AJ.AutoJoinMission then Target = _G.AJ.SelectMissionMap
                    elseif _G.AJ.AutoJoinMissionBoost then Target = game:GetService("Workspace"):GetAttribute("Boosted_Map")
                    elseif _G.AJ.AutoJoinRaid then Target = _G.AJ.SelectRaidMap
                    elseif _G.AJ.AutoJoinWaves then Target = _G.AJ.SelectWaveMap end
                    if v.Name ~= Target then
                        GET:InvokeServer("S_Missions","Leave")
                    end
                end
            end
        end
    end
end)

--//==============================\\--
--||        SERVERS TAB           ||--
--\\==============================//--

local TPS = TeleportService

Tabs.Servers:AddSection("Server")

Tabs.Servers:AddInput("JobIDInput", {
    Title = "JobID",
    Placeholder = "Paste Job ID here",
    Callback = function(x) _G.JobId_Textbox = x end
})

Tabs.Servers:AddToggle("AutoJoinJobID", {
    Title = "Auto Join JobID",
    Default = false,
    Callback = function(v)
        _G.AutoJoinJobID = v
        if v then
            task.spawn(function()
                while _G.AutoJoinJobID do
                    if _G.JobId_Textbox and _G.JobId_Textbox ~= "" then
                        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
                        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
                    else
                        warn("Please enter a JobID before enabling Auto Join JobID")
                        _G.AutoJoinJobID = false break
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Join JobID",
    Callback = function()
        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
    end
})

Tabs.Servers:AddButton({
    Title = "Copy JobID",
    Callback = function()
        setclipboard(game.JobId)
        Notifier:Notify({ Title="Aotr:update5", Content="Copied JobID!", Duration=3 })
    end
})

Tabs.Servers:AddSection("Basic")

Tabs.Servers:AddButton({
    Title = "Rejoin",
    Description = "Re-enter the same server",
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end
})

getgenv().ServerHop = function()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, v in ipairs(data.data or {}) do
        if v.playing < v.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer) return
        end
    end
end

Tabs.Servers:AddButton({
    Title = "Server Hop",
    Description = "Move to new server",
    Callback = function() getgenv().ServerHop() end
})

Tabs.Servers:AddSection("Smart Server")

Tabs.Servers:AddSlider("MaxPlayersFilter", {
    Title = "Max Players Filter",
    Min = 1,
    Max = 20,
    Default = 5,
    Rounding = 0,
    Callback = function(v) _G.SetP = v end
})

Tabs.Servers:AddButton({
    Title = "Smart Hop",
    Description = "Find server with fewest players",
    Callback = function()
        local limit = _G.SetP
        local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
        for _, v in ipairs(body.data or {}) do
            if v.playing <= limit then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, player) break end
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Low Ping Hop",
    Description = "Find lowest ping server",
    Callback = function()
        pcall(function()
            local bestServer, lowestPing = nil, math.random(50, 200)
            local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
            for _, v in ipairs(body.data or {}) do
                local ping = tonumber(v.ping)
                if ping and ping < lowestPing then lowestPing = ping bestServer = v.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(bestServer), player) end
        end)
    end
})

--//==============================\\--
--||           MISC TAB           ||--
--\\==============================//--

getgenv().AutoHideAfterDelay = false

Tabs.Misc:AddSection("Interface")

Tabs.Misc:AddToggle("AutoHideAfter10s", {
    Title = "Auto Hide UI (5s)",
    Default = false,
    Callback = function(state)
        getgenv().AutoHideAfterDelay = state
        if state then
            task.delay(5, function()
                if not getgenv().AutoHideAfterDelay then return end
                getgenv().AutoHideUI = true
                Window:Minimize(true)
            end)
        end
    end
})

local lastTap = 0
local function toggleUI()
    Window:Minimize()
end

UserInputService.TouchTap:Connect(function(_, gameProcessed)
    if gameProcessed then return end
    local now = tick()
    if now - lastTap <= 0.4 then toggleUI() end
    lastTap = now
end)

Tabs.Misc:AddToggle("ToggleNotifications", {
    Title = "Notifications",
    Default = false,
    Callback = function(value) Config.notificationsEnabled = value end
})

Tabs.Misc:AddSection("Game")

local delaySeconds = 180
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state
        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            end)
        end
    end
})

-- Auto Force Retry: fires 15s after the MISSION / RAID COMPLETED screen appears
do
    local AUTO_FORCE_RETRY_DELAY = 15
    local autoForceRetry = true
    Tabs.Misc:AddToggle("AutoForceRetry15", {
        Title = "Auto Force Retry (15s)",
        Description = "Automatically Force Retry 15 seconds after a mission is completed.",
        Default = true,
        Callback = function(state) autoForceRetry = state end
    })
    task.spawn(function()
        local shownAt, fired = nil, false
        while true do
            task.wait(0.5)
            if autoForceRetry and MissionCompleted() then
                shownAt = shownAt or os.clock()
                if not fired and os.clock() - shownAt >= AUTO_FORCE_RETRY_DELAY then
                    fired = true
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            else
                shownAt, fired = nil, false
            end
        end
    end)
end

-- Damage Text
local iface2 = player:WaitForChild("PlayerGui"):WaitForChild("Interface")
local damageConnection

Tabs.Misc:AddToggle("dmg", {
    Title = "Remove Dmg Text",
    Default = false,
    Callback = function(state)
        if state then
            for _, obj in pairs(iface2:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end
            damageConnection = iface2.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end)
        else
            if damageConnection then damageConnection:Disconnect() damageConnection = nil end
        end
    end
})

-- Teleport buttons
local lobbyPlaceId    = 14916516914
local mainMenuPlaceId = 13379208636

Tabs.Misc:AddSection("Teleport")

Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function() TeleportService:Teleport(lobbyPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function() TeleportService:Teleport(mainMenuPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        local ok, err = pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
        if not ok then warn(".") end
    end,
})

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--

local ESPEnabled = false
local ESPColor   = Color3.fromRGB(96, 205, 255)
local ESPSize    = Vector3.new(50, 50, 50)

local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name        = "NapeESP"
        esp.Adornee     = nape
        esp.AlwaysOnTop = true
        esp.ZIndex      = 5
        esp.Size        = ESPSize
        esp.Transparency = 0.5
        esp.Color3      = ESPColor
        esp.Parent      = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit  = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then createNapeESP(nape) end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then nape.NapeESP:Destroy() end
            end
        end
    end
end

local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then esp.Color3 = ESPColor end
                end
            end
        end
    end
end

local titansFolderEsp = workspace:FindFirstChild("Titans")
if titansFolderEsp then
    titansFolderEsp.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then createNapeESP(nape) end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then applyNapeESP() else removeAllNapeESP() end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))

-- ============================================================
--  Account / Webhook
--  Logic is copied verbatim from the original; only the UI layer is Obsidian.
-- ============================================================
do
local okMod, errMod = pcall(function()

-- ---------- compat layer (replaces Smooth Hub globals the extracted code expects) ----------
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IN_MENU = (game.PlaceId == 13379208636)
local modToken = {}
_G.AotrUpdate5ModToken = modToken
local function Alive() return _G.AotrUpdate5ModToken == modToken end
local SH = { DEV = false }
function SH.say(...) print("[Aotr:update5]", ...) end
function SH.dbg(...) if SH.DEV then print(...) end end
function SH.Guard(name, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    if not ok then warn("[Aotr:update5] block " .. tostring(name) .. " failed to load: " .. tostring(err)) end
end
function SH.PlayOn() return true end
local Farm = {}
SH.Farm = Farm
function Farm.CanUseHere()
    return not IN_MENU and game.PlaceId ~= 14916516914
end
local Cfg = {
    AutoFarmThunder = false,
    UseThunderSpears = false,
}
local function Save() end
-- thunder-spear counter (verbatim from Smooth Hub; the "stuck" detector belongs to its farm loop and is not included)
    local function SpearsLeft()
        local char = LocalPlayer.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end
Farm.SpearsLeft = SpearsLeft
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- tiny file store for the Webhook tab (own file, never mixed into configs)
local SettingsStore = {}
do
    local DIR = "Aotr_update5/" .. tostring(LocalPlayer.UserId)
    local function Path(file) return DIR .. "/" .. file .. ".json" end
    function SettingsStore.Load(file)
        local data = {}
        pcall(function()
            if isfile and readfile and isfile(Path(file)) then
                local d = HttpService:JSONDecode(readfile(Path(file)))
                if type(d) == "table" then data = d end
            end
        end)
        return data
    end
    function SettingsStore.Write(file, data)
        pcall(function()
            if not (writefile and makefolder) then return end
            if isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            if isfolder and not isfolder(DIR) then makefolder(DIR) end
            writefile(Path(file), HttpService:JSONEncode(data))
        end)
    end
    function SettingsStore.Restore(target, data)
        if type(data) ~= "table" then return end
        for k, v in pairs(data) do
            if target[k] ~= nil and type(target[k]) == type(v) then target[k] = v end
        end
    end
end

-- paragraph -> object with a .Text setter
local function MakeLabel(para)
    local obj = { __instance = para and para.DescLabel }
    return setmetatable(obj, { __newindex = function(_, k, v)
        if k == "Text" then pcall(function() para:SetDesc(tostring(v)) end) end
    end })
end


local AccountTab = EarlyAccountTab
local WebhookTab = Tabs.Webhook
Tabs.Account = AccountTab


-- ================== ACCOUNT TAB ==================
AccountTab:AddSection("📊 Account Overview")
AccountTab:AddParagraph({ Title = "Info", Content = "Read from your player data. N/A = this value was not found." })
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end
local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}
for _, f in ipairs(FIELDS) do
    local para = AccountTab:AddParagraph({ Title = f.title, Content = "..." })
    f.label = MakeLabel(para)
    f.last = nil
end
local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end
local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end
local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }
local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end
local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end
local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end
task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

-- ================== WEBHOOK (Rewards Logger) ==================
SH.Guard("webhook", function()

    local player = LocalPlayer

    local webhookURL = ""
    local sendWebhook = false
    local showUsername = true
    local thumbnailURL = "https://media.discordapp.net/attachments/1159475375752106086/1370816214242164836/image.png"

    -- Toggle to control whether webhook should be sent
    Tabs.Webhook:AddToggle("SendWebhookToggle", {
        Title = "Notify Webhook",
        Default = false,
        Callback = function(Value)
            sendWebhook = Value
        end
    })

    -- Toggle to display Roblox username
    Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
        Title = "Display Roblox Username",
        Default = true,
        Callback = function(Value)
            showUsername = Value
        end
    })

    -- Input for the webhook URL
    Tabs.Webhook:AddInput("WebhookInput", {
        Title = "Webhook",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = true,
        Callback = function(Value)
            webhookURL = Value
        end
    })

    -- Check visibility of GUI
    local function isActuallyVisible(instance)
        if not instance then return false end
        if not instance:IsDescendantOf(player.PlayerGui) then return false end
        while instance and instance ~= player.PlayerGui do
            if instance:IsA("GuiObject") and not instance.Visible then
                return false
            end
            instance = instance.Parent
        end
        return true
    end

    -- Get Retry button
    local function getRetryButton()
        local interface = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local rewardsMain = rewards and rewards:FindFirstChild("Main")
        local retryBtn = rewardsMain
            and rewardsMain:FindFirstChild("Info")
            and rewardsMain.Info:FindFirstChild("Main")
            and rewardsMain.Info.Main:FindFirstChild("Buttons")
            and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")
        return retryBtn
    end

    -- Get GUI text value
    local function getText(path)
        local node = player:FindFirstChild("PlayerGui")
        for _, part in ipairs(string.split(path, ".")) do
            if node then
                node = node:FindFirstChild(part)
            end
        end
        return node and node.Text or "0"
    end

    -- Get items and stats panels
    local function getItems()
        local gui = player:FindFirstChild("PlayerGui")
        local interface = gui and gui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local main = rewards and rewards:FindFirstChild("Main")
        local info = main and main:FindFirstChild("Info")
        local infoMain = info and info:FindFirstChild("Main")
        local items = infoMain and infoMain:FindFirstChild("Items")
        local stats = infoMain and infoMain:FindFirstChild("Stats")
        return items, stats
    end

    -- Loop check and send webhook
    local lastMissionTime = nil

    task.spawn(function()
        while Alive() do
            local retryBtn = getRetryButton()
            local items, stats = getItems()
            if isActuallyVisible(retryBtn) and stats and sendWebhook and webhookURL ~= "" then
                local currentTime = getText("Interface.Rewards.Main.Info.Main.Stats.Time_Taken.Amount")
                if currentTime ~= "0" and currentTime ~= lastMissionTime then
                    lastMissionTime = currentTime

                    local gold = getText("Interface.Rewards.Main.Info.Main.Items.Gold.Main.Inner.Quantity")
                    local xp = getText("Interface.Rewards.Main.Info.Main.Items.XP.Main.Inner.Quantity")
                    local bp_xp = getText("Interface.Rewards.Main.Info.Main.Items.BP_XP.Main.Inner.Quantity")
                    local gems = getText("Interface.Rewards.Main.Info.Main.Items.Gems.Main.Inner.Quantity")
                    local serum = getText("Interface.Rewards.Main.Info.Main.Items.Serum.Main.Inner.Quantity")
                    local common = getText("Interface.Rewards.Main.Info.Main.Items.Common_Perk.Main.Inner.Quantity")
                    local secret = getText("Interface.Rewards.Main.Info.Main.Items.Secret_Perk.Main.Inner.Quantity")
                    local epic = getText("Interface.Rewards.Main.Info.Main.Items.Epic_Perk.Main.Inner.Quantity")
                    local prestige = getText("Interface.Rewards.Main.Info.Main.Items.Prestige_Scroll.Main.Inner.Quantity")

                    local damage = getText("Interface.Rewards.Main.Info.Main.Stats.Damage_Dealt.Amount")
                    local kills = getText("Interface.Rewards.Main.Info.Main.Stats.Titans_Killed.Amount")
                    local crits = getText("Interface.Rewards.Main.Info.Main.Stats.Critical_Hits.Amount")

                    local timeString = os.date("%d-%b-%Y %I:%M %p")

                    local fields = {
                        {name = "**User:**", value = tostring(showUsername and player.Name or "Disabled"), inline = false},
                        {name = "**Stats:**", value = string.format(
                            "%s Time Taken\n%s Damage Dealt\n%s Titan Kills\n%s Critical Hits", currentTime, damage, kills, crits
                        ), inline = true},
                        {name = "**Rewards:**", value = string.format(
                            "%s Gold\n%s XP\n%s Gems", gold, xp, gems
                        ), inline = true},
                        {name = "**Drops:**", value = string.format(
                            "BP XP: %s\nCommon: %s\nSecret: %s\nEpic: %s\nPrestige: %s", bp_xp, common, secret, epic, prestige
                        ), inline = true},
                        {name = "**Special Rewards:**", value = string.format(
                            "Serum: %s", serum
                        ), inline = false}
                    }

                    local embed = {
                        title = "AOT:R Rewards Logger",
                        thumbnail = { url = thumbnailURL },
                        fields = fields,
                        footer = { text = "Sent at: " .. timeString }
                    }

                    local data = {
                        content = (tonumber(serum) or 0) > 0 and "@everyone" or nil,
                        embeds = {embed}
                    }

                    request({
                        Url = webhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode(data)
                    })
                end
            end
            task.wait(1)
        end
    end)
end)


end)
if not okMod then warn("[Aotr:update5] Account/Webhook/Refill module failed: " .. tostring(errMod)) end
end

--//==============================\\--
--||         SAVE / LOAD          ||--
--\\==============================//--

Window:SelectTab(Tabs.Main)

pcall(function()
    local menu = Tabs.Settings._tab:AddRightGroupbox("Menu")
    menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
        Default = "LeftControl", NoUI = true, Text = "Menu keybind",
    })
    Library.ToggleKeybind = Library.Options.MenuKeybind
end)

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[Aotr:update5] " .. name .. " failed: " .. tostring(err)) end
end

safe("ThemeManager", function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aotr_update5")
end)
safe("SaveManager", function()
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("Aotr_update5")
    SaveManager:BuildConfigSection(Tabs.Settings._tab)
end)
safe("ThemeTab", function() ThemeManager:ApplyToTab(Tabs.Settings._tab) end)
safe("Autoload", function() SaveManager:LoadAutoloadConfig() end)

Notifier:Notify({
    Title   = "Aotr:update5",
    Content = "Loaded successfully! Tap the tray icon to hide/show the UI.",
    Duration = 4,
})
