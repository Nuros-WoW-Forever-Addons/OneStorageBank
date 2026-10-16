--[[
    OneStorageBank - Hooks.lua
    Suppresses native Blizzard BankFrame and coordinates bank window opening and closing
    across modern Camelot (11.x PlayerInteractionManager) and legacy bank events.
--]]

local addonName, addonTable = ...
local OneStorageBank = _G.OneStorageBank or addonTable

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
        bf:ClearAllPoints()
        bf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)
        if bf.EnableMouse then
            bf:EnableMouse(false)
        end
    end
    local bp = _G["BankPanel"]
    if bp then
        if bp.SetAlpha then bp:SetAlpha(0) end
        if bp.EnableMouse then bp:EnableMouse(false) end
    end
end

-- Guard against Blizzard UIPanel manager resetting BankFrame position/alpha
if UpdateUIPanelPositions then
    hooksecurefunc("UpdateUIPanelPositions", function()
        local bf = _G["BankFrame"]
        if bf and bf:IsShown() and OneStorageBank and OneStorageBank.frame and OneStorageBank.frame:IsShown() then
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

-- Securely hook CloseBankFrame and C_Bank.CloseBankFrame
if CloseBankFrame then
    hooksecurefunc("CloseBankFrame", function()
        OneStorageBank:Hide()
    end)
end
if C_Bank and C_Bank.CloseBankFrame then
    hooksecurefunc(C_Bank, "CloseBankFrame", function()
        OneStorageBank:Hide()
    end)
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
            bf:HookScript("OnShow", function()
                SuppressNativeBank()
                OneStorageBank:Show()
            end)
            bf:HookScript("OnHide", function()
                OneStorageBank:Hide()
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
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if IsBankInteraction(interactionType) then
            OneStorageBank:Hide()
        end

    elseif event == "BANKFRAME_OPENED" then
        SuppressNativeBank()
        OneStorageBank:Show()

    elseif event == "BANKFRAME_CLOSED" then
        OneStorageBank:Hide()

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
