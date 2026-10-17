--[[
    OneStorageBank - Hooks.lua
    Suppresses native Blizzard BankFrame and coordinates bank window opening and closing
    across modern Camelot (11.x PlayerInteractionManager) and bank events without UI taint.
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
        bf:EnableMouse(false)
        bf:ClearAllPoints()
        bf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)
    end
end

local isRestoringBank = false
local function RestoreNativeBank()
    if isRestoringBank then return end
    isRestoringBank = true
    
    local bf = _G["BankFrame"]
    if bf then
        bf:SetAlpha(1)
        bf:EnableMouse(true)
        bf:ClearAllPoints()
        bf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        if bf.IsShown and bf:IsShown() then
            bf:Hide()
        end
    end
    
    -- Crucial: Hiding BankPanel ensures BankFrame:GetActiveBankType() short-circuits
    -- and returns nil when away from the bank, preventing UseContainerItem taint.
    local bp = _G["BankPanel"]
    if bp and bp.Hide then
        bp:Hide()
    end
    
    isRestoringBank = false
end

local function OnBankClosed()
    RestoreNativeBank()
    if OneStorageBank and OneStorageBank.frame and OneStorageBank.frame:IsShown() then
        OneStorageBank.frame:Hide()
    end
    if OneStorageBank and OneStorageBank.optionsFrame and OneStorageBank.optionsFrame:IsShown() then
        OneStorageBank.optionsFrame:Hide()
    end
end

-- Securely hook ShowUIPanel to suppress BankFrame cleanly when opened
if ShowUIPanel then
    hooksecurefunc("ShowUIPanel", function(panel)
        local bf = _G["BankFrame"]
        if panel and (panel == bf or (panel.GetName and panel:GetName() == "BankFrame")) then
            SuppressNativeBank()
            OneStorageBank:Show()
        end
    end)
end

-- Securely hook HideUIPanel
if HideUIPanel then
    hooksecurefunc("HideUIPanel", function(panel)
        local bf = _G["BankFrame"]
        if panel and (panel == bf or (panel.GetName and panel:GetName() == "BankFrame")) then
            OnBankClosed()
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
hookFrame:RegisterEvent("BAG_CONTAINER_UPDATE")

hookFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Guarantee BankPanel and BankFrame start completely hidden on login
        local bp = _G["BankPanel"]
        if bp and bp.Hide then
            bp:Hide()
        end
        local bf = _G["BankFrame"]
        if bf and bf.Hide then
            bf:Hide()
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if IsBankInteraction(interactionType) then
            SuppressNativeBank()
            OneStorageBank:Show()
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" or event == "BANKFRAME_CLOSED" then
        local interactionType = ...
        if event == "BANKFRAME_CLOSED" or IsBankInteraction(interactionType) then
            OnBankClosed()
        end

    elseif event == "BANKFRAME_OPENED" then
        SuppressNativeBank()
        OneStorageBank:Show()

    elseif event == "BANK_TABS_CHANGED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "BAG_CONTAINER_UPDATE" then
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
