--[[
    OneStorageBank - Hooks.lua
    Suppresses native Blizzard BankFrame and ReagentBankFrame,
    and coordinates bank window opening and closing.
--]]

local addonName, addonTable = ...
local OneStorageBank = _G.OneStorageBank or addonTable

local function SuppressNativeBank()
    local bf = _G["BankFrame"]
    if bf then
        bf:SetAlpha(0)
        bf:ClearAllPoints()
        bf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 2000, 2000)
    end
end

local hookFrame = CreateFrame("Frame", "OneStorageBank_HookFrame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:RegisterEvent("BANKFRAME_OPENED")
hookFrame:RegisterEvent("BANKFRAME_CLOSED")

hookFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        SuppressNativeBank()
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
        local bf = _G["BankFrame"]
        if bf and bf.HookScript then
            bf:HookScript("OnHide", function()
                OneStorageBank:Hide()
            end)
        end
    elseif event == "BANKFRAME_OPENED" then
        SuppressNativeBank()
        OneStorageBank:Show()
    elseif event == "BANKFRAME_CLOSED" then
        OneStorageBank:Hide()
    end
end)
