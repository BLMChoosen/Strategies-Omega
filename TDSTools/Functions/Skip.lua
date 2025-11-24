local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RemoteFunction = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteFunction") else SpoofEvent
local RemoteEvent = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteEvent") else SpoofEvent
--[[{
    ["Wave"] = number,
    ["Minute"] = number,
    ["Second"] = number,
}]]
return function(self, p1)
    local tableinfo = p1--ParametersPatch("Skip",...)
    local Wave,Min,Sec,InWave = tableinfo["Wave"] or 0, tableinfo["Minute"] or 0, tableinfo["Second"] or 0, tableinfo["InBetween"] or false
    if not CheckPlace() then
        return
    end
    
    -- VoteGUI com proteção
    local VoteGUI
    pcall(function()
        VoteGUI = LocalPlayer.PlayerGui:WaitForChild("ReactOverridesVote",5):WaitForChild("Frame"):WaitForChild("votes"):WaitForChild("vote")
    end)
    
    if not VoteGUI then
        ConsoleWarn("[Skip] VoteGUI not available - skip may not work properly")
        return
    end
    
    SetActionInfo("Skip","Total")
    task.spawn(function()
        if not TimeWaveWait(Wave, Min, Sec, InWave, tableinfo["Debug"]) then
            return
        end
        local SkipCheck
        if VoteGUI:WaitForChild("count").Text ~= `0/{#Players:GetChildren()} Required` then
            repeat
                task.wait()
            until VoteGUI:WaitForChild("count").Text == `0/{#Players:GetChildren()} Required`
        end
        if VoteGUI.Position ~= UDim2.new(0.5, 0, 0.5, 0) then --UDim2.new(scale_x, offset_x, scale_y, offset_y)
            return
        end
        repeat
            if VoteGUI:WaitForChild("prompt").Text ~= "Skip Wave?" then
                return
            end
            
            -- Tenta método moderno primeiro (Network.Channel)
            local voteSuccess = pcall(function()
                local Network = require(ReplicatedStorage.Resources.Universal.Network)
                local VotingChannel = Network.Channel("Voting")
                SkipCheck = VotingChannel:InvokeServer("Skip")
            end)
            
            -- Fallback para método antigo
            if not voteSuccess or not SkipCheck then
                SkipCheck = RemoteFunction:InvokeServer("Voting", "Skip")
            end
            
            task.wait()
        until SkipCheck or VoteGUI:WaitForChild("count").Text ~= `0/{#Players:GetChildren()} Required`
        SetActionInfo("Skip")
        ConsoleInfo(`Skipped Wave {Wave} (Min: {Min}, Sec: {Sec}, InBetween: {InWave})`)
    end)
end