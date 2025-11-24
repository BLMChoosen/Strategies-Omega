-- SCRIPT DE DEBUG - Execute isso DENTRO DO JOGO TDS
-- Ele vai mostrar a estrutura atual do jogo no console E salvar em arquivo

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Buffer para guardar todas as linhas
local outputLines = {}
local function output(text)
    table.insert(outputLines, tostring(text))
    print(text)  -- Também mostra no console
end

output("========================================")
output("TDS STRUCTURE DEBUG")
output("========================================")

-- Função para printar hierarquia
local function PrintChildren(parent, indent)
    indent = indent or ""
    for _, child in ipairs(parent:GetChildren()) do
        local info = string.format("%s├─ %s (%s)", indent, child.Name, child.ClassName)
        
        -- Se for um Value object, mostra o valor
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
            pcall(function()
                info = info .. " = " .. tostring(child.Value)
            end)
        end
        
        output(info)
        
        -- Limita profundidade para não spammar
        if indent:len() < 12 then
            PrintChildren(child, indent .. "  ")
        end
    end
end

-- 1. Verificar ReplicatedStorage
output("\n[1] REPLICATED STORAGE:")
output("RemoteFunction existe? " .. tostring(ReplicatedStorage:FindFirstChild("RemoteFunction") ~= nil))
output("RemoteEvent existe? " .. tostring(ReplicatedStorage:FindFirstChild("RemoteEvent") ~= nil))

-- 2. Verificar State
output("\n[2] STATE FOLDER:")
local State = ReplicatedStorage:FindFirstChild("State")
if State then
    output("✅ State encontrado!")
    PrintChildren(State, "  ")
else
    output("❌ State NÃO encontrado!")
    output("Procurando por StateReplicators...")
    local StateReps = ReplicatedStorage:FindFirstChild("StateReplicators")
    if StateReps then
        output("✅ StateReplicators encontrado!")
        PrintChildren(StateReps, "  ")
    end
end

-- 3. Verificar PlayerGui
output("\n[3] PLAYER GUI:")
local gui = LocalPlayer.PlayerGui:FindFirstChild("ReactGameTopGameDisplay")
if gui then
    output("✅ ReactGameTopGameDisplay encontrado!")
    PrintChildren(gui, "  ")
else
    output("❌ ReactGameTopGameDisplay NÃO encontrado!")
    output("GUIs disponíveis:")
    for _, child in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if child.Name:match("React") or child.Name:match("Game") then
            output("  - " .. child.Name)
        end
    end
end

-- 4. Verificar votação
output("\n[4] VOTE GUI:")
local voteGui = LocalPlayer.PlayerGui:FindFirstChild("ReactOverridesVote")
if voteGui then
    output("✅ ReactOverridesVote encontrado!")
    PrintChildren(voteGui, "  ")
else
    output("❌ ReactOverridesVote NÃO encontrado (normal se não estiver votando)")
end

-- 5. Verificar Client modules
output("\n[5] CLIENT MODULES:")
local client = ReplicatedStorage:FindFirstChild("Client")
if client then
    output("✅ Client encontrado!")
    local modules = client:FindFirstChild("Modules")
    if modules then
        output("  Modules encontrado:")
        PrintChildren(modules, "    ")
    end
else
    output("❌ Client NÃO encontrado!")
end

output("\n========================================")
output("DEBUG COMPLETO!")
output("========================================")

-- Salvar em arquivo
if not isfolder("StrategiesX") then
    makefolder("StrategiesX")
end
if not isfolder("StrategiesX/TDS") then
    makefolder("StrategiesX/TDS")
end
if not isfolder("StrategiesX/TDS/Debug") then
    makefolder("StrategiesX/TDS/Debug")
end

local finalOutput = table.concat(outputLines, "\n")
writefile("StrategiesX/TDS/Debug/TDS_Structure.txt", finalOutput)

output("\n✅ Arquivo salvo em: StrategiesX/TDS/Debug/TDS_Structure.txt")
output("Copie esse arquivo e me mande!")
