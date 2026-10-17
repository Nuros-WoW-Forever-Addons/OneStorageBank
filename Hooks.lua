--[[
    OneStorageBank - Hooks.lua
    Suppresses native Blizzard BankFrame and coordinates bank window opening and closing
    across modern Camelot (11.x PlayerInteractionManager) and legacy bank events.
--]]

local addonName, addonTable = ...
local OneStorageBank = _G.OneStorageBank or addonTable

local hiddenParent = CreateFrame("Frame", "OneStorageBank_HiddenParent")
hiddenParent:Hide()

local tinyParent = CreateFrame("Frame", "OneStorageBank_TinyParent", UIParent)
tinyParent:SetScale(0.0001)
tinyParent:SetAlpha(0)
tinyParent:ClearAllPoints()
tinyParent:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)

local function IsBankInteraction(interactionType)
    if not interactionType then return false end
    local pit = Enum and Enum.PlayerInteractionType
    if not pit then return false end
    return interactionType == pit.Banker
        or interactionType == pit.CharacterBanker
        or interactionType == pit.AccountBanker
end

local function SuppressNativeBank()
    local bf = _G["BankFrame"]
    if bf then
        bf:SetAlpha(0)
        bf:EnableMouse(false)
        if bf:GetParent() ~= hiddenParent and bf:GetParent() ~= tinyParent then
            bf:SetParent(tinyParent)
        end
        bf:ClearAllPoints()
        bf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)
    end
    local bp = _G["BankPanel"]
    if bp then
        bp:SetAlpha(0)
        bp:EnableMouse(false)
        if bp:GetParent() ~= hiddenParent and bp:GetParent() ~= tinyParent then
            bp:SetParent(tinyParent)
        end
        bp:ClearAllPoints()
        bp:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)
    end
end

-- Securely hook ShowUIPanel (Bagnon technique: scale down to 0.0001 and then parent to hiddenParent)
if ShowUIPanel then
    hooksecurefunc("ShowUIPanel", function(panel)
        local bf = _G["BankFrame"]
        if panel and (panel == bf or (panel.GetName and panel:GetName() == "BankFrame")) then
            SuppressNativeBank()
            OneStorageBank:Show()
            C_Timer.After(0, function()
                local frame = _G["BankFrame"]
                if frame and frame:IsShown() then
                    frame:SetParent(hiddenParent)
                end
            end)
        end
    end)
end

-- Guard against Blizzard UIPanel manager resetting BankFrame position/alpha
if UpdateUIPanelPositions then
    hooksecurefunc("UpdateUIPanelPositions", function()
        local bf = _G["BankFrame"]
        if bf and (bf:IsShown() or bf:GetParent() == tinyParent or bf:GetParent() == hiddenParent) then
            SuppressNativeBank()
        end
    end)
end

-- Securely hook BankFrame_Open if present (Camelot / Modern engine entry point)
if BankFrame_Open then
    hooksecurefunc("BankFrame_Open", function()
        SuppressNativeBank()
        OneStorageBank:Show()
    end)
end

local function OnBankClosed()
    local bf = _G["BankFrame"]
    if bf then
        bf:SetParent(UIParent)
        bf:Hide()
    end
    local bp = _G["BankPanel"]
    if bp then
        bp:SetParent(UIParent)
        bp:Hide()
    end
    OneStorageBank:Hide()
end

-- Securely hook CloseBankFrame and C_Bank.CloseBankFrame
if CloseBankFrame then
    hooksecurefunc("CloseBankFrame", OnBankClosed)
end
if C_Bank and C_Bank.CloseBankFrame then
    hooksecurefunc(C_Bank, "CloseBankFrame", OnBankClosed)
end

local hookFrame = CreateFrame("Frame", "OneStorageBank_HookFrame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
hookFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
hookFrame:RegisterEvent("BANKFRAME_OPENED")
hookFrame:RegisterEvent("BANKFRAME_CLOSED")
hookFrame:RegisterEvent("BANK_TABS_CHANGED")
hookFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
hookFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

hookFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SuppressNativeBank()
        local bf = _G["BankFrame"]
        if bf and bf.HookScript then
            bf:HookScript("OnShow", function(s)
                SuppressNativeBank()
                OneStorageBank:Show()
                C_Timer.After(0, function()
                    if s and s:IsShown() then
                        s:SetParent(hiddenParent)
                    end
                end)
            end)
            bf:HookScript("OnHide", function()
                OnBankClosed()
            end)
            bf:HookScript("OnUpdate", function(s)
                if OneStorageBank and OneStorageBank.frame and OneStorageBank.frame:IsShown() then
                    if s:GetAlpha() > 0 then
                        s:SetAlpha(0)
                    end
                    if s:IsMouseEnabled() then
                        s:EnableMouse(false)
                    end
                end
            end)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if IsBankInteraction(interactionType) then
            SuppressNativeBank()
            OneStorageBank:Show()
            C_Timer.After(0, function()
                local bf = _G["BankFrame"]
                if bf and bf:IsShown() then
                    bf:SetParent(hiddenParent)
                end
            end)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" or event == "BANKFRAME_CLOSED" then
        local interactionType = ...
        if event == "BANKFRAME_CLOSED" or IsBankInteraction(interactionType) then
            OnBankClosed()
        end

    elseif event == "BANKFRAME_OPENED" then
        SuppressNativeBank()
        OneStorageBank:Show()
        C_Timer.After(0, function()
            local bf = _G["BankFrame"]
            if bf and bf:IsShown() then
                bf:SetParent(hiddenParent)
            end
        end)

    elseif event == "BANK_TABS_CHANGED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        SuppressNativeBank()
        if OneStorageBank and OneStorageBank.frame and OneStorageBank.frame:IsShown() then
            if OneStorageBank.UpdateBankBar then
                OneStorageBank:UpdateBankBar()
            end
            if OneStorageBank.RefreshLayout then
                OneStorageBank:RefreshLayout()
            end
            if OneStorageBank.UpdateTitle then
                OneStorageBank:UpdateTitle()
            end
        end
    end
end)
