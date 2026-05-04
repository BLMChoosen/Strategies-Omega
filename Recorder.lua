local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- FIX: Aguarda RemoteFunction estar disponível
if not ReplicatedStorage:FindFirstChild("RemoteFunction") then
    local timeout = 0
    repeat 
        task.wait(0.5)
        timeout = timeout + 0.5
    until ReplicatedStorage:FindFirstChild("RemoteFunction") or timeout > 10
    
    if not ReplicatedStorage:FindFirstChild("RemoteFunction") then
        error("[Recorder] RemoteFunction não encontrado! Certifique-se de estar no jogo TDS.")
        return
    end
end

local RemoteFunction = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteFunction") else SpoofEvent
local RemoteEvent = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteEvent") else SpoofEvent

-- FIX CRÍTICO: State só existe em partida, não no lobby! Usar FindFirstChild com fallback
local State = ReplicatedStorage:FindFirstChild("State")
local RSTimer = State and State:FindFirstChild("Timer") and State.Timer:FindFirstChild("Time")
local RSMode = State and State:FindFirstChild("Mode")
local RSDifficulty = State and State:FindFirstChild("Difficulty")
local RSMap = State and State:FindFirstChild("Map")
local RSWave = State and State:FindFirstChild("Wave") -- Wave é um IntValue!

-- FIX: GameWave pode não existir se player estiver no lobby - usar carregamento lazy
local GameWave = nil

getgenv().WriteFile = function(check,name,location,str)
    if not check then
        return false
    end
    if type(name) ~= "string" then
        warn("[WriteFile] Nome inválido: " .. tostring(name))
        return false
    end
    
    if type(location) ~= "string" then
        location = ""
    end
    
    if not isfolder(location) and location ~= "" then
        makefolder(location)
    end
    
    if type(str) ~= "string" then
        warn("[WriteFile] Conteúdo inválido (esperado string, recebido " .. type(str) .. ")")
        return false
    end
    
    local filepath = location == "" and name..".txt" or location.."/"..name..".txt"
    local success, err = pcall(function()
        writefile(filepath, str)
    end)
    
    if not success then
        warn("[WriteFile] Erro ao escrever: " .. tostring(err))
        return false
    end
    
    return true
end

getgenv().AppendFile = function(check,name,location,str)
    if not check then
        return false
    end
    
    if type(name) ~= "string" then
        warn("[AppendFile] Nome inválido: " .. tostring(name))
        return false
    end
    
    if type(location) ~= "string" then
        location = ""
    end
    
    if type(str) ~= "string" then
        warn("[AppendFile] Conteúdo inválido (esperado string, recebido " .. type(str) .. ")")
        return false
    end
    
    local filepath = location == "" and name..".txt" or location.."/"..name..".txt"
    
    if not isfile(filepath) then
        return WriteFile(check, name, location, str)
    end
    
    local success, err = pcall(function()
        appendfile(filepath, str)
    end)
    
    if not success then
        warn("[AppendFile] Erro ao adicionar: " .. tostring(err))
        return false
    end
    
    return true
end
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
        
        -- FIX: Protege contra erros na escrita
        local success, err = pcall(function()
            return WriteFile(true, LocalPlayer.Name.."'s strat", "StrategiesX/TDS/Recorder", tostring(Text).."\n")
        end)
        
        if not success then
            warn("[Recorder] Erro ao escrever arquivo: " .. tostring(err))
        end
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
        
        -- FIX: Protege contra erros na escrita
        local success, err = pcall(function()
            return AppendFile(true, LocalPlayer.Name.."'s strat", "StrategiesX/TDS/Recorder", tostring(Text).."\n")
        end)
        
        if not success then
            warn("[Recorder] Erro ao adicionar ao arquivo: " .. tostring(err))
        end
    end)
end
getgenv().Recorder = {
    Troops = {
        Golden = {},
    },
    TowersList = {},
    SecondMili = 0, -- FIX: Inicializa aqui para evitar nil
}
getgenv().TowersList = Recorder.TowersList
local TowerCount = 0
local GetMode = nil

local UILibrary = getgenv().UILibrary or loadstring(game:HttpGet("https://raw.githubusercontent.com/Sigmanic/ROBLOX/main/ModificationWallyUi", true))()
UILibrary.options.toggledisplay = 'Fill'

local mainwindow = UILibrary:CreateWindow('Recorder')
UILibrary.container.Parent.Parent = LocalPlayer.PlayerGui
Recorder.Status = mainwindow:Section("Initializing...")

-- FIX: Define SetStatus ANTES de usar
local function SetStatus(string)
    if Recorder.Status then
        Recorder.Status.Text = string
    end
end

-- FIX: Atualiza status após inicialização
task.delay(1, function()
    SetStatus("Ready - Waiting for match...")
end)

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

local function ConvertTimer(number : number)
   return math.floor(number/60), number % 60
end

local TimerCheck = false
local function CheckTimer(bool)
    return (bool and TimerCheck) or true
end

-- FIX: Só conecta RSTimer se existir (só em partida)
if RSTimer then
    RSTimer.Changed:Connect(function(time)
        if time == 5 then
            TimerCheck = true
        elseif time and time > 5 then
            TimerCheck = false
        end
    end)
end

getgenv().GetTimer = function()
    -- FIX: Retorna valores padrão se não estiver em partida
    if not RSTimer then
        return {0, 0, 0, "false"}
    end
    
    local Min, Sec = ConvertTimer(RSTimer.Value)
    local Wave = "0"
    
    -- FIX: Lazy load GameWave apenas quando necessário
    if not GameWave then
        local success = pcall(function()
            GameWave = LocalPlayer.PlayerGui:FindFirstChild("ReactGameTopGameDisplay")
            if GameWave then
                GameWave = GameWave:FindFirstChild("Frame")
                if GameWave then
                    GameWave = GameWave:FindFirstChild("wave")
                    if GameWave then
                        GameWave = GameWave:FindFirstChild("container")
                        if GameWave then
                            GameWave = GameWave:FindFirstChild("value")
                        end
                    end
                end
            end
        end)
    end
    
    if GameWave then
        Wave = GameWave.Text
    end
    
    -- FIX: Garante que SecondMili nunca seja nil
    local secondMili = Recorder.SecondMili or 0
    return {tonumber(Wave), Min, Sec + secondMili, tostring(TimerCheck)}
end

Recorder.SecondMili = 0
-- FIX: Só conecta RSTimer se existir
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
        -- FIX: Pega o nome real da torre do TowerReplicator
        local replicator = RemoteCheck:FindFirstChild("TowerReplicator")
        if replicator then
            local realType = replicator:GetAttribute("Type")
            if realType then
                TowerName = realType
            end
        end
        
        local Position = Args[4].Position
        local Rotation = Args[4].Rotation
        local RotateX,RotateY,RotateZ = Rotation:ToEulerAnglesYXZ()
        TowerCount += 1
        RemoteCheck.Name = TowerCount
        TowersList[TowerCount] = {
            ["TowerName"] = TowerName,
            ["Instance"] = RemoteCheck,
            ["Position"] = Position,
            ["Rotation"] = Rotation,
        }
        
        pcall(function()
            local upgradeHandler = require(ReplicatedStorage.Client.Modules.Game.Interface.Elements.Upgrade.upgradeHandler)
            upgradeHandler:selectTroop(RemoteCheck)
        end)
        
        SetStatus(`Placed {TowerName}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Place("{TowerName}", {Position.X}, {Position.Y}, {Position.Z}, {TimerStr}, {RotateX}, {RotateY}, {RotateZ})`)
    end,
    Upgrade = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name;
        local PathTarget = Args[4].Path
        if RemoteCheck ~= true then
            SetStatus(`Upgraded Failed ID: {TowerIndex}`)
            print(`Upgraded Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Upgraded ID: {TowerIndex}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Upgrade({TowerIndex}, {TimerStr}, {PathTarget})`)
    end,
    Sell = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[3].Troop.Name;
        if not RemoteCheck or TowersList[tonumber(TowerIndex)].Instance:FindFirstChild("HumanoidRootPart") then
            SetStatus(`Sell Failed ID: {TowerIndex}`)
            print(`Sell Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Sold TowerIndex {TowerIndex}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Sell({TowerIndex}, {TimerStr})`)
    end,
    Target = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name
        local Target = Args[4].Target
        if RemoteCheck ~= true then
            SetStatus(`Target Failed ID: {TowerIndex}`)
            print(`Target Failed ID: {TowerIndex}`, RemoteCheck)
        end
        SetStatus(`Changed Target ID: {TowerIndex}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Target({TowerIndex}, "{Target}", {TimerStr})`)
    end,
    Abilities = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name
        local AbilityName = Args[4].Name
        local Data = Args[4].Data
        if RemoteCheck ~= true then
            SetStatus(`Ability Failed ID: {TowerIndex}`)
            print(`Ability Failed ID: {TowerIndex}`, RemoteCheck)
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
        local formattedData = formatData(Data)
        SetStatus(`Used Ability On TowerIndex {TowerIndex}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Ability({TowerIndex}, "{AbilityName}", {TimerStr}, {formattedData})`)
    end,
    Option = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name;
        local OptionName = Args[4].Name
        local Value = Args[4].Value
        if RemoteCheck ~= true then
            SetStatus(`Option Failed ID; {TowerIndex}`)
            print(`Option Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Used Option On TowerIndex {TowerIndex}`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Option({TowerIndex}, "{OptionName}", "{Value}", {TimerStr})`)
    end,
    Skip = function(Args, Timer, RemoteCheck)
        SetStatus(`Skipped Wave`)
        local TimerStr = table.concat(Timer, ", ")
        appendstrat(`TDS:Skip({TimerStr})`)
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
        SetStatus(`Vote {GetMode}`)
    end,
}

task.spawn(function()
    local VoteGUI = LocalPlayer.PlayerGui:WaitForChild("ReactOverridesVote", 10)
    if not VoteGUI then 
        warn("[Recorder] VoteGUI não encontrado após 10s (provavelmente a votação já acabou ou você está no lobby).")
        SetStatus("Ready - Vote GUI not found")
        return 
    end
    
    local Frame = VoteGUI:WaitForChild("Frame", 5)
    if not Frame then 
        warn("[Recorder] Frame não encontrado em VoteGUI")
        return 
    end
    
    local Votes = Frame:WaitForChild("votes", 5)
    if not Votes then 
        warn("[Recorder] Votes não encontrado em Frame")
        return 
    end
    
    local Vote = Votes:WaitForChild("vote", 5)
    if not Vote then 
        warn("[Recorder] Vote não encontrado em Votes")
        return 
    end

    SetStatus("Ready - Vote GUI connected")
    
    local Skipped = false
    Vote:GetPropertyChangedSignal("Position"):Connect(function()
        repeat task.wait() until mainwindow.flags.autoskip
        if Skipped or Vote:WaitForChild("count").Text ~= "0/1 Required" then
            return
        end
        
        -- FIX: Lazy load GameWave para skip
        if not GameWave then
            pcall(function()
                local gui = LocalPlayer.PlayerGui:FindFirstChild("ReactGameTopGameDisplay")
                if gui then
                    GameWave = gui:FindFirstChild("Frame")
                    if GameWave then GameWave = GameWave:FindFirstChild("wave") end
                    if GameWave then GameWave = GameWave:FindFirstChild("container") end
                    if GameWave then GameWave = GameWave:FindFirstChild("value") end
                end
            end)
        end
        
        local currentPrompt = Vote:WaitForChild("prompt").Text
        if currentPrompt == "Skip Wave?" and GameWave and tonumber(GameWave.Text) ~= 0 then
            Skipped = true
            local Timer = GetTimer()
            task.spawn(GenerateFunction["Skip"], true, Timer)
            ReplicatedStorage.RemoteFunction:InvokeServer("Voting", "Skip")
            task.wait(2.5)
            Skipped = false
        end
    end)
end)

task.spawn(function()
    -- FIX: Espera GameWave estar disponível antes de conectar
    local attempts = 0
    while not GameWave and attempts < 30 do
        task.wait(1)
        attempts += 1
        pcall(function()
            local gui = LocalPlayer.PlayerGui:FindFirstChild("ReactGameTopGameDisplay")
            if gui then
                GameWave = gui:FindFirstChild("Frame")
                if GameWave then GameWave = GameWave:FindFirstChild("wave") end
                if GameWave then GameWave = GameWave:FindFirstChild("container") end
                if GameWave then GameWave = GameWave:FindFirstChild("value") end
            end
        end)
    end
    
    if not GameWave then
        warn("[Recorder] GameWave não encontrado após 30 segundos. Auto-sell farms pode não funcionar.")
        return
    end
    
    -- FIX: Aguarda RSDifficulty estar disponível
    while not RSDifficulty do
        task.wait(1)
        State = ReplicatedStorage:FindFirstChild("State")
        RSDifficulty = State and State:FindFirstChild("Difficulty")
    end
    
    GameWave:GetPropertyChangedSignal("Text"):Wait()
    local FinalWaveAtDifferentMode = {
        ["Easy"] = 25,
        ["Casual"] = 30,
        ["Intermediate"] = 30,
        ["Molten"] = 35,
        ["Fallen"] = 40,
        ["Hardcore"] = 50
    }
    local FinalWave = FinalWaveAtDifferentMode[RSDifficulty.Value]
    GameWave:GetPropertyChangedSignal("Text"):Connect(function()
        if tonumber(GameWave.Text) == FinalWave then
            repeat task.wait() until mainwindow.flags.autosellfarms
            for i,v in ipairs(game.Workspace.Towers:GetChildren()) do
                if v.Owner.Value == LocalPlayer.UserId and v:WaitForChild("TowerReplicator"):GetAttribute("Type") == "Farm" then
                    ReplicatedStorage.RemoteFunction:InvokeServer("Troops", "Sell", {["Troop"] = v})
                end
            end
            SetStatus(`Sold All Farms`)
        end
    end)
end)

-- FIX: Move busca de inventário para depois de tudo estar inicializado
local inventorySuccess, inventoryError = pcall(function()
    -- FIX CRÍTICO: Primeiro argumento deve ser string, não boolean
    local inventoryData = ReplicatedStorage.RemoteFunction:InvokeServer("Session", "Search", "Inventory.Troops")
    
    if not inventoryData or type(inventoryData) ~= "table" then
        warn("[Recorder] Inventário retornou dados inválidos: " .. type(inventoryData))
        return
    end
    
    local count = 0
    for TowerName, Tower in pairs(inventoryData) do
        if type(Tower) == "table" and Tower.Equipped then
            table.insert(Recorder.Troops, TowerName)
            count = count + 1
            if Tower.GoldenPerks then
                table.insert(Recorder.Troops.Golden, TowerName)
            end
        end
    end
    
    print("[Recorder] Carregadas " .. count .. " torres do inventário")
end)

if not inventorySuccess then
    warn("[Recorder] Falha ao buscar inventário: " .. tostring(inventoryError))
    SetStatus("ERROR - Inventory fetch failed")
    -- Não retorna aqui, continua com loadout vazio
    Recorder.Troops = {}
    Recorder.Troops.Golden = {}
end

-- FIX: Protege escrita do arquivo de estratégia
pcall(function()
    writestrat("getgenv().StratCreditsAuthor = \"Optional\"")
    
    -- FIX: Só escreve se RSMap e RSMode existirem
    if not RSMap or not RSMode then
        warn("[Recorder] Não foi possível obter Map/Mode - você está no lobby?")
        SetStatus("Waiting for match to start...")
        return
    end
    
    local loadoutStr = "local TDS = loadstring(game:HttpGet(\"https://raw.githubusercontent.com/BLMChoosen/Strategies-Omega/main/MainSource.lua\", true))()\nTDS:Map(\""..
        RSMap.Value.."\", true, \""..RSMode.Value.."\")\nTDS:Loadout({\""
    
    if #Recorder.Troops > 0 then
        loadoutStr = loadoutStr .. table.concat(Recorder.Troops, `", "`)
    end
    
    if #Recorder.Troops.Golden > 0 then
        loadoutStr = loadoutStr .. "\", [\"Golden\"] = {\"".. table.concat(Recorder.Troops.Golden, `", "`).."\"}})"
    else
        loadoutStr = loadoutStr .. "\"})"
    end
    
    appendstrat(loadoutStr)
end)
task.spawn(function()
    local DiffTable = {
        ["Easy"] = "Easy",
        ["Casual"] = "Casual",
        ["Intermediate"] = "Intermediate",
        ["Molten"] = "Molten",
        ["Fallen"] = "Fallen"
    }
    
    -- FIX: Aguarda RSDifficulty estar disponível
    while not RSDifficulty do
        task.wait(1)
        State = ReplicatedStorage:FindFirstChild("State")
        RSDifficulty = State and State:FindFirstChild("Difficulty")
    end
    
    repeat task.wait() until GetMode ~= nil or RSDifficulty.Value ~= ""
    if GetMode then
        repeat task.wait() until GetMode == RSDifficulty.Value
        appendstrat(`TDS:Mode("{GetMode}")`)
    elseif DiffTable[RSDifficulty.Value] then
        appendstrat(`TDS:Mode("{DiffTable[RSDifficulty.Value]}")`)
    end
end)

-- FIX: Normaliza comando cirílico
local function NormalizeCommand(cmd)
    if type(cmd) ~= "string" then return cmd end
    return cmd:gsub(".", function(c)
        if c:byte() > 127 then return "a" end
        return c
    end)
end

-- SOLUÇÃO DEFINITIVA: Hook minimalista que NÃO toca nos resultados
local hookSuccess, hookError = pcall(function()
    local OldNamecall
    OldNamecall = hookmetamethod(game, '__namecall', function(...)
        local Method = getnamecallmethod()
        local Self = select(1, ...)
        
        -- Se NÃO for InvokeServer no RemoteFunction, passa direto
        if not (Method == "InvokeServer" and typeof(Self) == "Instance" and Self.Name == "RemoteFunction") then
            return OldNamecall(...)
        end
        
        -- Captura argumentos SEM modificar
        local arg1, arg2 = select(2, ...)
        
        -- Chama original e captura resultado
        local success, result = pcall(OldNamecall, ...)
        
        -- Se falhou, retorna erro original
        if not success then
            error(result)
        end
        
        -- Registra ação DEPOIS em background (se for Troops)
        if arg1 == "Troops" and arg2 then
            task.spawn(function()
                pcall(function()
                    local Command = NormalizeCommand(arg2)
                    if GenerateFunction[Command] then
                        local Timer = GetTimer()
                        local allArgs = {select(2, ...)}
                        GenerateFunction[Command](allArgs, Timer, result)
                    end
                end)
            end)
        end
        
        -- Retorna resultado original
        return result
    end)
end)

if not hookSuccess then
    warn("[Recorder] Falha ao aplicar hook: " .. tostring(hookError))
    SetStatus("ERROR - Hook failed")
else
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("[Recorder] ✅ FIXED! (v5.0 - Minimal Hook)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- FIX: Detecta se está em partida ou lobby
    task.delay(2, function()
        if not State or not RSTimer or not RSMap then
            SetStatus("✅ Ready")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🏠 [Recorder] LOBBY - Jogo normal")
            print("📝 Entre em partida para gravar")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        else
            SetStatus("✅ Recording")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎮 [Recorder] GRAVANDO!")
            print("📊 " .. (RSMap.Value or "N/A"))
            print("⚔️ " .. (RSMode.Value or "N/A"))
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        end
    end)
end
