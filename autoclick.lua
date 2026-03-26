local Batata = _G.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()

if Batata.Modules.AutoController then
    return Batata.Modules.AutoController
end

local clickModule = Batata.Modules.AutoClick or Batata.Util.LoadFile(Batata.Paths.Click)
local sellModule = Batata.Modules.AutoSell or Batata.Util.LoadFile(Batata.Paths.Sell)

local Module = {}

function Module:SetAutoClick(enabled)
    clickModule:SetEnabled(enabled)
    self.AutoClickEnabled = clickModule.Enabled == true
end

function Module:ToggleAutoClick()
    self.AutoClickEnabled = clickModule:Toggle()
    return self.AutoClickEnabled
end

function Module:SetAutoSell(enabled)
    sellModule:SetEnabled(enabled)
    self.AutoSellEnabled = sellModule.Enabled == true
end

function Module:ToggleAutoSell()
    self.AutoSellEnabled = sellModule:Toggle()
    return self.AutoSellEnabled
end

function Module:GetState()
    return {
        AutoClickEnabled = clickModule.Enabled == true,
        AutoSellEnabled = sellModule.Enabled == true,
        Running = (clickModule.Running == true) and (sellModule.Running == true),
    }
end

function Module:Stop()
    if type(clickModule.Stop) == "function" then
        clickModule:Stop()
    end
    if type(sellModule.Stop) == "function" then
        sellModule:Stop()
    end
    self.AutoClickEnabled = false
    self.AutoSellEnabled = false
    if Batata.Modules.AutoController == self then
        Batata.Modules.AutoController = nil
    end
end

Module.AutoClickEnabled = clickModule.Enabled == true
Module.AutoSellEnabled = sellModule.Enabled == true

Batata.Modules.AutoController = Module

return Module
