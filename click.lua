local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoClick then
    return Batata.Modules.AutoClick
end

local remotes = Batata.Util.EnsureRemotes()
local clickRemote = remotes.PerformClick

local CLICK_DELAY = 0.1

local Module = {
    Running = true,
    Enabled = false,
    Delay = CLICK_DELAY,
}

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.02 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.ClickDelay)
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function Module:Toggle()
    self.Enabled = not self.Enabled
    return self.Enabled
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    if Batata.Modules.AutoClick == self then
        Batata.Modules.AutoClick = nil
    end
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled and clickRemote then
            pcall(function()
                clickRemote:FireServer()
            end)
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoClick = Module

return Module
