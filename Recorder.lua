local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Verificação de compatibilidade do executor
if not hookmetamethod or not getnamecallmethod then
    local missingFunctions = {}
    if not hookmetamethod then table.insert(missingFunctions, "hookmetamethod") end
    if not getnamecallmethod then table.insert(missingFunctions, "getnamecallmethod") end
    
    local errorMsg = string.format(
        "RECORDER ERROR: Your executor is NOT compatible!\n\n" ..
        "Missing: %s\n\n" ..
        "You need an executor with metamethod hooking support.",
        table.concat(missingFunctions, ", ")
    )
    
    -- Mostra notificação na tela
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "❌ Recorder Error";
            Text = "Executor not compatible! Check console (F9) for details.";
            Duration = 10;
        })
    end)
    
    -- Também mostra no console
    warn(string.rep("=", 60))
    warn("[RECORDER ERROR]")
    warn("Your executor is NOT compatible with this recorder!")
    warn("")
    warn("Missing functions:", table.concat(missingFunctions, ", "))
    warn("")
    warn("This recorder requires metamethod hooking support.")
    warn(string.rep("=", 60))
    
    error(errorMsg)
end

-- Verificação de ambiente spoofed
local SpoofEvent = {}
if GameSpoof then
    function SpoofEvent:InvokeServer(...)
        print("InvokeServer",...)
    end
    function SpoofEvent:FireServer(...)
        print("FireServer",...)
    end
end

-- Helper function to find objects safely
local function SafeWaitForChild(Parent, Name, Timeout)
    local success, result = pcall(function()
        return Parent:WaitForChild(Name, Timeout or 10)
    end)
    if success then
        return result
    else
        warn("[Recorder] Could not find " .. Name .. " in " .. tostring(Parent))
        return nil
    end
end

-- Inicialização segura dos RemoteFunction/Event
local RemoteFunction = if not GameSpoof then SafeWaitForChild(ReplicatedStorage, "RemoteFunction") else SpoofEvent
local RemoteEvent = if not GameSpoof then SafeWaitForChild(ReplicatedStorage, "RemoteEvent") else SpoofEvent

-- Inicialização segura do State
local StateFolder = SafeWaitForChild(ReplicatedStorage, "State")
local RSTimer, RSMode, RSDifficulty, RSMap, RSWave

if StateFolder then
    -- Timer está em State/Timer/Time
    local TimerFolder = StateFolder:FindFirstChild("Timer")
    if TimerFolder then
        RSTimer = SafeWaitForChild(TimerFolder, "Time")
    end
    
    RSMode = SafeWaitForChild(StateFolder, "Mode")
    RSDifficulty = SafeWaitForChild(StateFolder, "Difficulty")
    RSMap = SafeWaitForChild(StateFolder, "Map")
    RSWave = SafeWaitForChild(StateFolder, "Wave")  -- Wave é IntValue em State!
else
    warn("[Recorder] StateFolder not found! Recorder may not work properly.")
end

-- Também pega a GUI da wave (para display visual, mas não é essencial)
local GameWaveGUI = nil
local function InitGameWaveGUI()
    pcall(function()
        local gui = SafeWaitForChild(LocalPlayer.PlayerGui, "ReactGameTopGameDisplay", 5)
        if gui then
            local frame = SafeWaitForChild(gui, "Frame", 3)
            if frame then
                local wave = SafeWaitForChild(frame, "wave", 3)
                if wave then
                    local container = SafeWaitForChild(wave, "container", 3)
                    if container then
                        GameWaveGUI = SafeWaitForChild(container, "value", 3)
                    end
                end
            end
        end
    end)
end

-- Inicializa GameWave GUI (opcional, só para visual)
task.spawn(InitGameWaveGUI)

getgenv().WriteFile = function(check,name,location,str)
    if not check then
        return
    end
    if type(name) == "string" then
        if not type(location) == "string" then
            location = ""
        end
        if not isfolder(location) then
            makefolder(location)
        end
        if type(str) ~= "string" then
            error("Argument 4 must be a string got " .. tostring(number))
        end
        writefile(location.."/"..name..".txt",str)
    else
        error("Argument 2 must be a string got " .. tostring(number))
    end
end
getgenv().AppendFile = function(check,name,location,str)
    if not check then
        return
    end
    if type(name) == "string" then
        if not type(location) == "string" then
            location = ""
        end
        if not isfolder(location) then
            WriteFile(check,name,location,str)
        end
        if type(str) ~= "string" then
            error("Argument 4 must be a string got " .. tostring(number))
        end
        if isfile(location.."/"..name..".txt") then
            appendfile(location.."/"..name..".txt",str)
        else
            WriteFile(check,name,location,str)
        end
    else
        error("Argument 2 must be a string got " .. tostring(number))
    end
end
-- Nome do arquivo de estratégia (sanitizado)
local StratFileName = "RecordedStrat"

local writestrat = function(...)
    local TableText = {...}
    task.spawn(function()
        if not game:GetService("Players").LocalPlayer then
            repeat task.wait() until game:GetService("Players").LocalPlayer
        end
        for i,v in next, TableText do
            if type(v) ~= "string" then
                TableText[i] = tostring(v)
            end
        end
        local Text = table.concat(TableText, " ")
        print(Text)
        return WriteFile(true, StratFileName, "StrategiesX/TDS/Recorder", tostring(Text).."\n")
    end)
end
local appendstrat = function(...)
    local TableText = {...}
    task.spawn(function()
        if not game:GetService("Players").LocalPlayer then
            repeat task.wait() until game:GetService("Players").LocalPlayer
        end
        for i,v in next, TableText do
            if type(v) ~= "string" then
                TableText[i] = tostring(v)
            end
        end
        local Text = table.concat(TableText, " ")
        print(Text)
        return AppendFile(true, StratFileName, "StrategiesX/TDS/Recorder", tostring(Text).."\n")
    end)
end
getgenv().Recorder = {
    Troops = {
        Golden = {},
    },
    TowersList = {},
}
getgenv().TowersList = Recorder.TowersList
local TowerCount = 0
local GetMode = nil

-- Carrega UILibrary com tratamento de erro e verificação de rate limit
local UILibrary = getgenv().UILibrary
if not UILibrary then
    local code
    local success, err = pcall(function()
        code = game:HttpGet("https://raw.githubusercontent.com/Sigmanic/ROBLOX/main/ModificationWallyUi")
    end)
    
    if not success then
        error("[Recorder] Failed to download UILibrary: " .. tostring(err))
    end
    
    -- Verifica se recebeu erro 429 (rate limit) ou outro erro HTTP
    if code:match("^%d+:") or code:match("Too Many Requests") then
        error("[Recorder] GitHub rate limit! Wait a few minutes and try again.\nError: " .. code:sub(1, 100))
    end
    
    -- Tenta compilar o código
    local loadFunc, loadErr = loadstring(code)
    if not loadFunc then
        error("[Recorder] Failed to compile UILibrary: " .. tostring(loadErr))
    end
    
    -- Executa o código compilado
    local execSuccess, library = pcall(loadFunc)
    if not execSuccess then
        error("[Recorder] Failed to execute UILibrary: " .. tostring(library))
    end
    
    UILibrary = library
    getgenv().UILibrary = library
end

if not UILibrary then
    error("[Recorder] UILibrary is nil - cannot continue")
end

UILibrary.options = UILibrary.options or {}
UILibrary.options.toggledisplay = 'Fill'

local mainwindow = UILibrary:CreateWindow('Recorder')
if UILibrary.container and UILibrary.container.Parent then
    UILibrary.container.Parent.Parent = LocalPlayer.PlayerGui
end
Recorder.Status = mainwindow:Section("Initializing...")

local timeSection = mainwindow:Section("Time Passed: ")
task.spawn(function()
    function TimeConverter(v)
        if v <= 9 then
            local conv = "0" .. v
            return conv
        else
            return v
        end
    end
    local startTime = os.time()

    while task.wait(0.1) do
        local t = os.time() - startTime
        local seconds = t % 60
        local minutes = math.floor(t / 60) % 60
        timeSection.Text = "Time Passed: " .. TimeConverter(minutes) .. ":" .. TimeConverter(seconds)
    end
end)

mainwindow:Toggle('Auto Skip', {flag = "autoskip"})
mainwindow:Section("\\/ LAST WAVE \\/")
mainwindow:Toggle('Auto Sell Farms', {default = true, flag = "autosellfarms"})

local function SetStatus(string)
    Recorder.Status.Text = string
end

-- Mostrar que está pronto logo após criar a GUI
SetStatus("Ready - Initializing recorder...")

-- Função para sanitizar strings (evitar caracteres especiais que quebram Lua)
local function SanitizeString(str)
    if type(str) ~= "string" then
        return tostring(str)
    end
    -- Remove ou escapa caracteres problemáticos
    str = str:gsub('"', '\\"')  -- Escapa aspas duplas
    str = str:gsub("'", "\\'")  -- Escapa aspas simples
    return str
end

-- ⚠️ StateReplicators OBSOLETO - Código removido
-- Estado agora disponível em ReplicatedStorage.State.*

local function ConvertTimer(number : number)
   return math.floor(number/60), number % 60
end

local TimerCheck = false
local function CheckTimer(bool)
    return (bool and TimerCheck) or true
end

-- Conecta ao Timer apenas se ele existir
if RSTimer then
    RSTimer.Changed:Connect(function(time)
        if time == 5 then
            TimerCheck = true
        elseif time and time > 5 then
            TimerCheck = false
        end
    end)
else
    warn("[Recorder] RSTimer not available - Timer checks disabled")
end

-- Tenta pegar o Timer de forma global para garantir que o hook o encontre
getgenv().GetTimer = function()
    if not RSTimer then
        warn("[Recorder] RSTimer not available")
        return {0, 0, 0, "false"}
    end
    
    local success, timerValue = pcall(function() return RSTimer.Value end)
    if not success or not timerValue then
        warn("[Recorder] Could not get RSTimer.Value")
        return {0, 0, 0, "false"}
    end
    
    local Min, Sec = ConvertTimer(timerValue)
    
    -- Pega Wave do State (é um IntValue!)
    local Wave = 0
    if RSWave then
        local waveSuccess, waveValue = pcall(function() return RSWave.Value end)
        if waveSuccess then
            Wave = waveValue or 0
        end
    end
    
    return {tonumber(Wave) or 0, Min, Sec + (Recorder.SecondMili or 0), tostring(TimerCheck)}
end

Recorder.SecondMili = 0

-- Conecta ao RSTimer apenas se ele existir
if RSTimer then
    RSTimer.Changed:Connect(function()
        Recorder.SecondMili = 0
        for i = 1,9 do
            task.wait(0.09)
            Recorder.SecondMili += 0.1
        end
    end)
end

local GenerateFunction = {
    Place = function(Args, Timer, RemoteCheck)
        if typeof(RemoteCheck) ~= "Instance" then
            return
        end
        local TowerName = Args[3]
        local Data = Args[4]
        if not TowerName or not Data or not Data.Position then
             warn("Recorder: Invalid Place arguments")
             return
        end
        local Position = Data.Position
        local Rotation = Data.Rotation or CFrame.new()
        local RotateX,RotateY,RotateZ = Rotation:ToEulerAnglesYXZ()
        TowerCount += 1
        RemoteCheck.Name = TowerCount
        TowersList[TowerCount] = {
            ["TowerName"] = TowerName,
            ["Instance"] = RemoteCheck,
            ["Position"] = Position,
            ["Rotation"] = Rotation,
        }
        
        -- Tenta selecionar a tropa (pode falhar se o módulo mudou)
        pcall(function()
            local upgradeHandler = require(ReplicatedStorage.Client.Modules.Game.Interface.Elements.Upgrade.upgradeHandler)
            if upgradeHandler and upgradeHandler.selectTroop then
                 upgradeHandler:selectTroop(RemoteCheck)
            end
        end)
        
        SetStatus(string.format("Placed %s", TowerName))
        
        -- Timer é uma tabela {wave, min, sec, inwave}, precisa desempacotar
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        local safeName = SanitizeString(TowerName)
        
        -- Corrigido: incluindo RotateZ
        appendstrat(string.format('TDS:Place("%s", %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)', 
            safeName, Position.X, Position.Y, Position.Z, Wave, Min, Sec, InWave, RotateX, RotateY, RotateZ))
    end,
    Upgrade = function(Args, Timer, RemoteCheck)
        local Data = Args[4]
        if not Data or not Data.Troop then return end
        local TowerIndex = Data.Troop.Name;
        local PathTarget = Data.Path or 1
        if RemoteCheck ~= true then
            SetStatus(string.format("Upgrade Failed ID: %s", TowerIndex))
            print(string.format("Upgrade Failed ID: %s", TowerIndex), RemoteCheck)
            return
        end
        SetStatus(string.format("Upgraded ID: %s", TowerIndex))
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        
        appendstrat(string.format('TDS:Upgrade(%s, %s, %s, %s, %s, %s)', 
            TowerIndex, Wave, Min, Sec, InWave, PathTarget))
    end,
    Sell = function(Args, Timer, RemoteCheck)
        local Data = Args[3]
        if not Data or not Data.Troop then return end
        local TowerIndex = Data.Troop.Name;
        if not RemoteCheck or (TowersList[tonumber(TowerIndex)] and TowersList[tonumber(TowerIndex)].Instance:FindFirstChild("HumanoidRootPart")) then
            SetStatus(string.format("Sell Failed ID: %s", TowerIndex))
            print(string.format("Sell Failed ID: %s", TowerIndex), RemoteCheck)
            return
        end
        SetStatus(string.format("Sold TowerIndex %s", TowerIndex))
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        
        appendstrat(string.format('TDS:Sell(%s, %s, %s, %s, %s)', 
            TowerIndex, Wave, Min, Sec, InWave))
    end,
    Target = function(Args, Timer, RemoteCheck)
        local Data = Args[4]
        if not Data or not Data.Troop then return end
        local TowerIndex = Data.Troop.Name
        local Target = Data.Target
        if RemoteCheck ~= true then
            SetStatus(string.format("Target Failed ID: %s", TowerIndex))
            print(string.format("Target Failed ID: %s", TowerIndex), RemoteCheck)
        end
        SetStatus(string.format("Changed Target ID: %s", TowerIndex))
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        local safeTarget = SanitizeString(Target)
        
        appendstrat(string.format('TDS:Target(%s, "%s", %s, %s, %s, %s)', 
            TowerIndex, safeTarget, Wave, Min, Sec, InWave))
    end,
    Abilities = function(Args, Timer, RemoteCheck)
        local Data = Args[4]
        if not Data or not Data.Troop then return end
        local TowerIndex = Data.Troop.Name
        local AbilityName = Data.Name
        local AbilityData = Data.Data
        if RemoteCheck ~= true then
            SetStatus(string.format("Ability Failed ID: %s", TowerIndex))
            print(string.format("Ability Failed ID: %s", TowerIndex), RemoteCheck)
            return
        end
        local function formatData(Data)
            local formattedData = {}
            for key, value in pairs(Data) do
                if key == "directionCFrame" then
                    table.insert(formattedData, string.format('["%s"] = CFrame.new(%s)', key, tostring(value)))
                elseif key == "position" then
                    table.insert(formattedData, string.format('["%s"] = Vector3.new(%s)', key, tostring(value)))
                else
                    table.insert(formattedData, string.format('["%s"] = %s', key, tostring(value)))
                end
            end
            return "{" .. table.concat(formattedData, ", ") .. "}"
        end
        local formattedData = formatData(AbilityData)
        SetStatus(string.format("Used Ability On TowerIndex %s", TowerIndex))
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        local safeName = SanitizeString(AbilityName)
        
        appendstrat(string.format('TDS:Ability(%s, "%s", %s, %s, %s, %s, %s)', 
            TowerIndex, safeName, Wave, Min, Sec, InWave, formattedData))
    end,
    Option = function(Args, Timer, RemoteCheck)
        local Data = Args[4]
        if not Data or not Data.Troop then return end
        local TowerIndex = Data.Troop.Name;
        local OptionName = Data.Name
        local Value = Data.Value
        if RemoteCheck ~= true then
            SetStatus(string.format("Option Failed ID: %s", TowerIndex))
            print(string.format("Option Failed ID: %s", TowerIndex), RemoteCheck)
            return
        end
        SetStatus(string.format("Used Option On TowerIndex %s", TowerIndex))
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        local safeName = SanitizeString(OptionName)
        local safeValue = SanitizeString(Value)
        
        appendstrat(string.format('TDS:Option(%s, "%s", "%s", %s, %s, %s, %s)', 
            TowerIndex, safeName, safeValue, Wave, Min, Sec, InWave))
    end,
    Skip = function(Args, Timer, RemoteCheck)
        SetStatus("Skipped Wave")
        
        -- Timer é uma tabela {wave, min, sec, inwave}
        local Wave, Min, Sec, InWave = Timer[1], Timer[2], Timer[3], Timer[4]
        
        appendstrat(string.format('TDS:Skip(%s, %s, %s, %s)', Wave, Min, Sec, InWave))
    end,
    Vote = function(Args, Timer, RemoteCheck)
        local Difficulty = Args[3]
        local DiffTable = {
            ["Easy"] = "Easy",
            ["Casual"] = "Casual",
            ["Intermediate"] = "Intermediate",
            ["Molten"] = "Molten",
            ["Fallen"] = "Fallen"
        }
        GetMode = DiffTable[Difficulty] or Difficulty
        SetStatus(string.format("Vote %s", GetMode))
    end,
}

-- AutoSkip feature - vota automaticamente quando disponível
task.spawn(function()
    local success, err = pcall(function()
        -- Aguarda inicialização
        task.wait(2)
        
        -- Tenta obter o Network Channel como o jogo original faz
        local VotingChannel
        pcall(function()
            local Network = require(ReplicatedStorage.Resources.Universal.Network)
            VotingChannel = Network.Channel("Voting")
        end)
        
        if not VotingChannel then
            warn("[Recorder] VotingChannel not available for AutoSkip")
            return
        end
        
        -- Monitora mudanças na wave para detectar quando pode votar
        if not RSWave then
            warn("[Recorder] RSWave not available for AutoSkip")
            return
        end
        
        local lastVotedWave = 0
        
        RSWave.Changed:Connect(function(newWave)
            -- Aguarda um pouco para o voto ficar disponível
            task.wait(1)
            
            -- Verifica se AutoSkip está ativado
            if not mainwindow.flags.autoskip then return end
            
            -- Verifica se já votou nesta wave
            if newWave == lastVotedWave then return end
            if newWave == 0 then return end
            
            -- Tenta votar para skip como o jogo faz
            task.spawn(function()
                for tentativa = 1, 10 do
                    local voteSuccess, result = pcall(function()
                        return VotingChannel:InvokeServer("Skip")
                    end)
                    
                    if voteSuccess and result == true then
                        -- Voto bem sucedido, registra na estratégia
                        local Timer = GetTimer()
                        GenerateFunction.Skip({}, Timer, true)
                        lastVotedWave = newWave
                        SetStatus("AutoSkip: Voted wave " .. tostring(newWave))
                        break
                    end
                    
                    -- Aguarda antes de tentar novamente
                    task.wait(0.5)
                end
            end)
        end)
    end)
    
    if not success then
        warn("[Recorder] AutoSkip failed to initialize:", err)
    end
end)

-- AutoSellFarms feature
task.spawn(function()
    pcall(function()
        -- Aguarda State estar disponível
        repeat task.wait(1) until RSWave and RSDifficulty
        
        local FinalWaves = {
            ["Easy"] = 25,
            ["Casual"] = 30,
            ["Intermediate"] = 30,
            ["Molten"] = 35,
            ["Fallen"] = 40,
            ["Hardcore"] = 50
        }
        
        local FinalWave = FinalWaves[RSDifficulty.Value] or 40
        
        RSWave.Changed:Connect(function(newWave)
            if newWave ~= FinalWave then return end
            if not mainwindow.flags.autosellfarms then return end
            
            local towersFolder = Workspace:FindFirstChild("Towers")
            if not towersFolder then return end
            
            for _, v in ipairs(towersFolder:GetChildren()) do
                pcall(function()
                    local owner = v:FindFirstChild("Owner")
                    if owner and owner.Value == LocalPlayer.UserId then
                        local replicator = v:FindFirstChild("TowerReplicator")
                        if replicator and replicator:GetAttribute("Type") == "Farm" then
                            RemoteFunction:InvokeServer("Troops", "Sell", {["Troop"] = v})
                        end
                    end
                end)
            end
            SetStatus("Sold All Farms")
        end)
    end)
end)

-- Coleta informações das tropas equipadas
local InventorySuccess, InventoryResult = pcall(function()
    return RemoteFunction:InvokeServer("Session", "Search", "Inventory.Troops")
end)

if InventorySuccess and type(InventoryResult) == "table" then
    for TowerName, Tower in pairs(InventoryResult) do
        if Tower and Tower.Equipped then
            table.insert(Recorder.Troops, TowerName)
            if Tower.GoldenPerks then
                table.insert(Recorder.Troops.Golden, TowerName)
            end
        end
    end
else
    warn("[Recorder] Could not get tower inventory")
end

-- Valores padrões seguros
local MapValue = (RSMap and RSMap.Value) or "Unknown"
local ModeValue = (RSMode and RSMode.Value) or "Unknown"

-- Inicializar o arquivo de estratégia de forma mais segura
task.spawn(function()
    -- Aguarda um pouco para garantir que tudo está inicializado
    task.wait(1)
    
    local success, err = pcall(function()
        writestrat("getgenv().StratCreditsAuthor = \"Optional\"")
        
        local troopsStr = ""
        if #Recorder.Troops > 0 then
            troopsStr = '\"' .. table.concat(Recorder.Troops, '", "') .. '\"'
        end
        
        local goldenStr = ""
        if #Recorder.Troops.Golden > 0 then
            goldenStr = ', [\"Golden\"] = {\"' .. table.concat(Recorder.Troops.Golden, '", "') .. '\"}'
        end
        
        local loadoutLine = string.format(
            "local TDS = loadstring(game:HttpGet(\"https://raw.githubusercontent.com/BLMChoosen/Strategies-Omega/main/MainSource.lua\"))()\nTDS:Map(\"%s\", true, \"%s\")\nTDS:Loadout({%s%s})",
            MapValue,
            ModeValue,
            troopsStr,
            goldenStr
        )
        
        appendstrat(loadoutLine)
    end)
    
    if success then
        SetStatus("Ready - Recording started!")
    else
        SetStatus("Error - Check console")
        warn("[Recorder] Error writing initial strategy file:", err)
    end
end)

task.spawn(function()
    local DiffTable = {
        ["Easy"] = "Easy",
        ["Casual"] = "Casual",
        ["Intermediate"] = "Intermediate",
        ["Molten"] = "Molten",
        ["Fallen"] = "Fallen"
    }
    
    -- Aguarda até que tenhamos o valor da dificuldade
    repeat 
        task.wait(0.5) 
    until GetMode ~= nil or (RSDifficulty and RSDifficulty.Value and RSDifficulty.Value ~= "")
    
    local ModeToUse = GetMode
    if not ModeToUse and RSDifficulty and RSDifficulty.Value then
        ModeToUse = DiffTable[RSDifficulty.Value] or RSDifficulty.Value
    end
    
    if ModeToUse then
        if GetMode then
            repeat task.wait(0.5) until GetMode == (RSDifficulty and RSDifficulty.Value)
        end
        appendstrat(string.format('TDS:Mode("%s")', ModeToUse))
    else
        warn("[Recorder] Could not determine game mode")
    end
end)

local OldNamecall
OldNamecall = hookmetamethod(game, '__namecall', function(...)
    local Self, Args = (...), ({select(2, ...)})
    local Method = getnamecallmethod()
    
    if Method == "InvokeServer" and Self and (Self.Name == "RemoteFunction" or Self:IsA("RemoteFunction")) then
        local thread = coroutine.running()
        
        coroutine.wrap(function(Args)
            -- Get Timer safely
            local Timer = {0, 0, 0, "false"} -- Default safe value
            
            local TimerFunc = getgenv().GetTimer
            if TimerFunc and type(TimerFunc) == "function" then
                local success, result = pcall(TimerFunc)
                if success and result then
                    Timer = result
                end
            end

            -- Call the original remote function
            local RemoteFired = OldNamecall(Self, unpack(Args))
            
            -- Debug: Print all intercepted calls
            if Args[1] == "Troops" and Args[2] then
                print("[Recorder Hook] Captured:", Args[1], Args[2])
            end
            
            -- Process the command
            local Command = Args[2]
            if type(Command) == "string" and GenerateFunction[Command] then
                pcall(function()
                    GenerateFunction[Command](Args, Timer, RemoteFired)
                end)
            end
            
            coroutine.resume(thread, RemoteFired)
        end)(Args)
        
        return coroutine.yield()
    end
    
    return OldNamecall(...)
end)

print("[Recorder] Initialization complete! Hook installed.")