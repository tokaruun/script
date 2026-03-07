
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")
local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")
local ShootGunEvent = Net:WaitForChild("RE/ShootGunEvent")
local GunValidator = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")

local LocalPlayer = Players.LocalPlayer
local Net = require(ReplicatedStorage.Modules.Net)

local Remotes = {}
local Assets = ReplicatedStorage:WaitForChild("Assets")


-- Initialize Remotes
for _, child in ipairs(ReplicatedStorage:WaitForChild("Remotes"):GetChildren()) do
    if child:IsA("RemoteEvent") then
        local id = child:GetAttribute("Id")
        if id then
            Remotes[id] = child
        end
    end
end

ReplicatedStorage.Remotes.ChildAdded:Connect(function(child)
    if child:IsA("RemoteEvent") then
        local id = child:GetAttribute("Id")
        if id then
            Remotes[id] = child
        end
    end
end)

local function GetClosestEnemy()
    local Characterss = LocalPlayer.Characterss
    if not Characterss then return nil end
    
    local rootPart = Characterss:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local closestEnemy = nil
    local shortestDistance = 15 -- Max range

    for _, enemy in ipairs(workspace.Enemies.Charactersss:GetChildren()) do
        local humanoid = enemy:FindFirstChild("Humanoid")
        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
        
        if humanoid and humanoid.Health > 0 and enemyRoot then
            local distance = (rootPart.Position - enemyRoot.Position).Magnitude
            if distance < shortestDistance then
                closestEnemy = enemy
                shortestDistance = distance
            end
        end
    end
    return closestEnemy
end

local function Attack()
    local Characterss = LocalPlayer.Characterss
    if not Characterss then return end
    
    local tool = Characterss:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Melee" then return end

    local enemy = GetClosestEnemy()
    if enemy then
        local enemyHead = enemy:FindFirstChild("Head")
        if enemyHead then
            -- Register attack and hit via network modules
            Remotes["RE/RegisterAttack"]:FireServer()
            Remotes["RE/RegisterHit"]:FireServer(enemy, enemyHead)
            Net:RemoteEvent("RegisterHit"):FireServer(enemy, enemyHead)
        end
    end
end


task.spawn(function()
    while true do
        Attack()
        task.wait() -- CHỈNH: Chờ tối thiểu để lặp nhanh nhất
    end
end)

local function GetBladeHits()
    local targets = {}
    local function GetDistance(v)
        return (v.Position - game.Players.LocalPlayer.Characterss.HumanoidRootPart.Position).Magnitude
    end
    
    for _, part in pairs({game.Workspace.Enemies, game.Workspace.Charactersss}) do
        for _, v in pairs(part:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Head") and v:FindFirstChild("Humanoid") then
                if GetDistance(v.HumanoidRootPart) < 60 then
                    table.insert(targets, v)
                end
            end
        end
    end

    return targets
end

local function AttackAll()
    local player = game.Players.LocalPlayer
    local Characterss = player.Characterss
    if not Characterss then return end

    local equippedWeapon = Characterss:FindFirstChild("EquippedWeapon")
    if not equippedWeapon then return end


    local enemies = GetBladeHits()
    if #enemies > 0 then
        local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net")
        netModule:WaitForChild("RE/RegisterAttack"):FireServer(-math.huge)
        
        local args = {nil, {}}
        for i, v in pairs(enemies) do
            if not args[1] then
                args[1] = v.Head
            end
            args[2][i] = {v, v.HumanoidRootPart}
        end
        
        netModule:WaitForChild("RE/RegisterHit"):FireServer(unpack(args))
    end
end

spawn(function()
    while task.wait() do AttackAll() end
end)



local Config = {
    AttackDistance = 65,
    AttackMobs = true,
    AttackPlayers = true,
    AttackCooldown = 0, -- CHỈNH: Loại bỏ cooldown nội tại
    ComboResetTime = 0.4,
    MaxCombo = 4,
    HitboxLimbs = {"RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm", "RightHand", "LeftHand"},
    AutoClickEnabled = true
}

local FastAttack = {}
FastAttack.__index = FastAttack

function FastAttack.new()
    local self = setmetatable({
        Debounce = 0,
        ComboDebounce = 0,
        ShootDebounce = 0,
        M1Combo = 0,
        EnemyRootPart = nil,
        Connections = {},
        Overheat = {Dragonstorm = {MaxOverheat = 3, Cooldown = 0, TotalOverheat = 0, Distance = 350, Shooting = false}},
        ShootsPerTarget = {["Dual Flintlock"] = 2},
        SpecialShoots = {["Skull Guitar"] = "TAP", ["Bazooka"] = "Position", ["Cannon"] = "Position", ["Dragonstorm"] = "Overheat"}
    }, FastAttack)
    
    pcall(function()
        self.CombatFlags = require(Modules.Flags).COMBAT_REMOTE_THREAD
        self.ShootFunction = getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9)
        local LocalScript = Player:WaitForChild("PlayerScripts"):FindFirstChildOfClass("LocalScript")
        if LocalScript and getsenv then
            self.HitFunction = getsenv(LocalScript)._G.SendHitsToServer
        end
    end)
    
    return self
end

function FastAttack:IsEntityAlive(entity)
    local humanoid = entity and entity:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

function FastAttack:CheckStun(Characterss, Humanoid, ToolTip)
    local Stun = Characterss:FindFirstChild("Stun")
    local Busy = Characterss:FindFirstChild("Busy")
    if Humanoid.Sit and (ToolTip == "Sword" or ToolTip == "Melee" or ToolTip == "Blox Fruit") then
        return false
    elseif Stun and Stun.Value > 0 or Busy and Busy.Value then
        return false
    end
    return true
end

function FastAttack:GetBladeHits(Characterss, Distance)
    local Position = Characterss:GetPivot().Position
    local BladeHits = {}
    Distance = Distance or Config.AttackDistance
    
    local function ProcessTargets(Folder, CanAttack)
        for _, Enemy in ipairs(Folder:GetChildren()) do
            if Enemy ~= Characterss and self:IsEntityAlive(Enemy) then
                local BasePart = Enemy:FindFirstChild(Config.HitboxLimbs[math.random(#Config.HitboxLimbs)]) or Enemy:FindFirstChild("HumanoidRootPart")
                if BasePart and (Position - BasePart.Position).Magnitude <= Distance then
                    if not self.EnemyRootPart then
                        self.EnemyRootPart = BasePart
                    else
                        table.insert(BladeHits, {Enemy, BasePart})
                    end
                end
            end
        end
    end
    
    if Config.AttackMobs then ProcessTargets(Workspace.Enemies) end
    if Config.AttackPlayers then ProcessTargets(Workspace.Charactersss, true) end
    
    return BladeHits
end

function FastAttack:GetClosestEnemy(Characterss, Distance)
    local BladeHits = self:GetBladeHits(Characterss, Distance)
    local Closest, MinDistance = nil, math.huge
    
    for _, Hit in ipairs(BladeHits) do
        local Magnitude = (Characterss:GetPivot().Position - Hit[2].Position).Magnitude
        if Magnitude < MinDistance then
            MinDistance = Magnitude
            Closest = Hit[2]
        end
    end
    return Closest
end

function FastAttack:GetCombo()
    local Combo = (tick() - self.ComboDebounce) <= Config.ComboResetTime and self.M1Combo or 0
    Combo = Combo >= Config.MaxCombo and 1 or Combo + 1
    self.ComboDebounce = tick()
    self.M1Combo = Combo
    return Combo
end

function FastAttack:ShootInTarget(TargetPosition)
    local Characterss = Player.Characterss
    if not self:IsEntityAlive(Characterss) then return end
    
    local Equipped = Characterss:FindFirstChildOfClass("Tool")
    if not Equipped or Equipped.ToolTip ~= "Gun" then return end
    
    local Cooldown = 0 -- CHỈNH: Ép cooldown súng về 0
    if (tick() - self.ShootDebounce) < Cooldown then return end
    
    local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
    if ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
        Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
        GunValidator:FireServer(self:GetValidator2())
        
        if ShootType == "TAP" then
            Equipped.RemoteEvent:FireServer("TAP", TargetPosition)
        else
            ShootGunEvent:FireServer(TargetPosition)
        end
        self.ShootDebounce = tick()
    else
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait() -- CHỈNH: Giảm delay click súng
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        self.ShootDebounce = tick()
    end
end

function FastAttack:GetValidator2()
    local v1 = getupvalue(self.ShootFunction, 15)
    local v2 = getupvalue(self.ShootFunction, 13)
    local v3 = getupvalue(self.ShootFunction, 16)
    local v4 = getupvalue(self.ShootFunction, 17)
    local v5 = getupvalue(self.ShootFunction, 14)
    local v6 = getupvalue(self.ShootFunction, 12)
    local v7 = getupvalue(self.ShootFunction, 18)
    
    local v8 = v6 * v2
    local v9 = (v5 * v2 + v6 * v1) % v3
    v9 = (v9 * v3 + v8) % v4
    v5 = math.floor(v9 / v3)
    v6 = v9 - v5 * v3
    v7 = v7 + 1
    
    setupvalue(self.ShootFunction, 15, v1)
    setupvalue(self.ShootFunction, 13, v2)
    setupvalue(self.ShootFunction, 16, v3)
    setupvalue(self.ShootFunction, 17, v4)
    setupvalue(self.ShootFunction, 14, v5)
    setupvalue(self.ShootFunction, 12, v6)
    setupvalue(self.ShootFunction, 18, v7)
    
    return math.floor(v9 / v4 * 16777215), v7
end

function FastAttack:UseNormalClick(Characterss, Humanoid, Cooldown)
    self.EnemyRootPart = nil
    local BladeHits = self:GetBladeHits(Characterss)
    
    if self.EnemyRootPart then
        RegisterAttack:FireServer(0) -- CHỈNH: Gửi cooldown 0 lên server
        if self.CombatFlags and self.HitFunction then
            self.HitFunction(self.EnemyRootPart, BladeHits)
        else
            RegisterHit:FireServer(self.EnemyRootPart, BladeHits)
        end
    end
end

function FastAttack:UseFruitM1(Characterss, Equipped, Combo)
    local Targets = self:GetBladeHits(Characterss)
    if not Targets[1] then return end
    
    local Direction = (Targets[1][2].Position - Characterss:GetPivot().Position).Unit
    Equipped.LeftClickRemote:FireServer(Direction, Combo)
end

function FastAttack:Attack()
    -- CHỈNH: Loại bỏ kiểm tra tick() để đánh liên tục
    local Characterssss = Player.Character
    if not Characterssss or not self:IsEntityAlive(Characterss) then return end
    
    local Humanoid = Characterss.Humanoid
    local Equipped = Characterss:FindFirstChildOfClass("Tool")
    if not Equipped then return end
    
    local ToolTip = Equipped.ToolTip
    if not table.find({"Melee", "Blox Fruit", "Sword", "Gun"}, ToolTip) then return end
    
    -- CHỈNH: Cooldown nội tại ép về 0
    local Cooldown = 0 
    if not self:CheckStun(Characterss, Humanoid, ToolTip) then return end
    
    local Combo = self:GetCombo()
    -- CHỈNH: Loại bỏ cộng thêm giây khi đạt MaxCombo
    self.Debounce = tick()
    
    if ToolTip == "Blox Fruit" and Equipped:FindFirstChild("LeftClickRemote") then
        self:UseFruitM1(Characterss, Equipped, Combo)
    elseif ToolTip == "Gun" then
        local Target = self:GetClosestEnemy(Characterss, 120)
        if Target then
            self:ShootInTarget(Target.Position)
        end
    else
        self:UseNormalClick(Characterss, Humanoid, Cooldown)
    end
end

local AttackInstance = FastAttack.new()
table.insert(AttackInstance.Connections, RunService.Stepped:Connect(function()
    AttackInstance:Attack()
end))

for _, v in pairs(getgc(true)) do
    if typeof(v) == "function" and iscclosure(v) then
        local name = debug.getinfo(v).name
        if name == "Attack" or name == "attack" or name == "RegisterHit" then
            hookfunction(v, function(...)
                AttackInstance:Attack()
                return v(...)
            end)
        end
    end
end
