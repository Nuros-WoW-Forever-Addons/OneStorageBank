--[[
    OneStorageBank - Core.lua
    Master all-in-one bank window featuring authentic Blizzard Metal styling,
    silver sub-tabs (Main Bank / Reagents), bank bag purchasing, and live search filtering.
--]]

local addonName, addonTable = ...
_G.OneStorageBank = _G.OneStorageBank or addonTable
local OneStorageBank = _G.OneStorageBank

local Utils = _G.OneStorageUtils
local FrameHelper = Utils and Utils.FrameHelper
local ContainerHelper = Utils and Utils.ContainerHelper

OneStorageBank.buttons = {}
OneStorageBank.bankBarButtons = {}
OneStorageBank.currentSearch = ""
OneStorageBank.selectedTab = 1 -- 1: Main Bank, 2: Reagent Bank
OneStorageBank.isBagBarShown = false

local defaultDB = {
    columns = 12,
    separateBags = true,
    showBagBar = false,
    showMainBank = false,
}

function OneStorageBank:GetOption(key)
    if _G.OneStorageBankDB and _G.OneStorageBankDB[key] ~= nil then
        return _G.OneStorageBankDB[key]
    end
    return defaultDB[key]
end

function OneStorageBank:SetOption(key, val)
    _G.OneStorageBankDB = _G.OneStorageBankDB or {}
    _G.OneStorageBankDB[key] = val
end

-------------------------------------------------------------------------------
-- Window Title & Capacity Badges
-------------------------------------------------------------------------------

function OneStorageBank:UpdateTitle()
    if not self.frame then return end
    
    local free, total = 0, 0
    if self.selectedTab == 1 then
        local bagList = {}
        local showMain = OneStorageBankDB and OneStorageBankDB.showMainBank
        if showMain then
            local baseSlots = ContainerHelper:GetNumSlots(ContainerHelper.BANK_CONTAINER)
            if baseSlots and baseSlots > 0 then
                table.insert(bagList, ContainerHelper.BANK_CONTAINER)
            end
        end
        for _, bID in ipairs(ContainerHelper.BANK_BAG_IDS) do
            local numSlots = ContainerHelper:GetNumSlots(bID)
            if numSlots and numSlots > 0 then
                table.insert(bagList, bID)
            end
        end
        free, total = ContainerHelper:GetFreeSlotCount(bagList)
    else
        free, total = ContainerHelper:GetFreeSlotCount({ ContainerHelper.REAGENTBANK_CONTAINER })
    end
    
    local tabTitle = (self.selectedTab == 1) and "Bank" or "Reagents"
    local titleText = string.format("|cffffffff%s|r  |cff888888(%d/%d Free)|r", tabTitle, free, total)
    
    local titleTarget = (self.frame.TitleContainer and self.frame.TitleContainer.TitleText) 
        or self.frame.TitleText or self.frame.Title
    if titleTarget then
        titleTarget:SetText(titleText)
    end
end

-------------------------------------------------------------------------------
-- Item Slot Button Creation & Pooling
-------------------------------------------------------------------------------

function OneStorageBank:GetBagParentFrame(bagID)
    self.bagFrames = self.bagFrames or {}
    if not self.bagFrames[bagID] then
        local f = CreateFrame("Frame", "OneStorageBank_Bag" .. tostring(bagID):gsub("-", "neg"), self.frame.ContentArea)
        f:SetID(bagID)
        f:SetAllPoints(self.frame.ContentArea)
        f:Show()
        self.bagFrames[bagID] = f
    end
    return self.bagFrames[bagID]
end

local function OnItemEnter(self)
    local bag = self.bag or (self:GetParent() and self:GetParent():GetID())
    local slot = self.slot or self:GetID()
    if not bag or not slot then return end
    
    -- Clear Blizzard NewItem overlay if present
    if C_NewItems and C_NewItems.RemoveNewItem then
        C_NewItems.RemoveNewItem(bag, slot)
    end
    if self.NewItemTexture then self.NewItemTexture:Hide() end
    if self.BattlepayItemTexture then self.BattlepayItemTexture:Hide() end
    if self.flashAnim and self.flashAnim:IsPlaying() then self.flashAnim:Stop() end
    if self.newitemglowAnim and self.newitemglowAnim:IsPlaying() then self.newitemglowAnim:Stop() end

    OneStorageBank:HighlightBankBarButton(bag)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    
    if GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(bag, slot)
    else
        local isMainBank = (bag == ContainerHelper.BANK_CONTAINER or bag == -1)
        local invID = isMainBank and BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(slot, false)
        if invID and GameTooltip.SetInventoryItem then
            GameTooltip:SetInventoryItem("player", invID)
        else
            local link = ContainerHelper:GetItemLink(bag, slot)
            if link then
                GameTooltip:SetHyperlink(link)
            end
        end
    end
    GameTooltip:Show()
    
    if self.hasItem then
        ContainerHelper:ShowItemCursor(bag, slot, self.isReadable)
        self:SetScript("OnUpdate", function(s)
            if GameTooltip:IsOwned(s) then
                ContainerHelper:ShowItemCursor(bag, slot, s.isReadable)
            end
        end)
    else
        ContainerHelper:ResetItemCursor()
    end
end

local function OnItemLeave(self)
    self:SetScript("OnUpdate", nil)
    OneStorageBank:ClearBankBarHighlight()
    GameTooltip:Hide()
    ContainerHelper:ResetItemCursor()
end

function OneStorageBank:CreateItemButton(index)
    local name = "OneStorageBankItem" .. index
    local parent = self.frame.ContentArea
    local ok, btn = pcall(CreateFrame, "ItemButton", name, parent, "ContainerFrameItemButtonTemplate")
    if not ok or not btn then
        btn = CreateFrame("Button", name, parent, "ContainerFrameItemButtonTemplate")
    end
    btn:SetSize(37, 37)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    
    -- Disable Blizzard's automatic template event updates; OneStorageBank manages updates
    btn:SetScript("OnEvent", nil)
    btn:SetScript("OnShow", nil)
    
    -- Suppress Blizzard template default glow / battlepay overlays
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.ExtendedSlot then btn.ExtendedSlot:Hide() end
    if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
    if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
    
    -- Ensure GetBagID method is present from Blizzard's template mixin
    if not btn.GetBagID then
        if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.GetBagID then
            btn.GetBagID = ContainerFrameItemButtonMixin.GetBagID
        else
            btn.GetBagID = function(s)
                return s.bag or (s:GetParent() and s:GetParent():GetID())
            end
        end
    end
    
    -- Slot Background Texture (Empty Slot art)
    local slotBg = btn:CreateTexture(nil, "BACKGROUND")
    slotBg:SetAllPoints(btn)
    slotBg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    slotBg:SetVertexColor(0.8, 0.8, 0.8, 0.35)
    btn.SlotBg = slotBg
    
    -- Item Icon
    local icon = _G[name .. "IconTexture"] or btn.icon
    if not icon then
        icon = btn:CreateTexture(nil, "BORDER")
        icon:SetAllPoints(btn)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = icon
    
    -- Item Count Label
    local count = _G[name .. "Count"] or btn.Count
    if not count then
        count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    end
    btn.Count = count
    
    -- Quality Border Ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Common\\WhiteIconFrame")
    border:SetAllPoints(btn)
    border:Hide()
    btn.QualityBorder = border
    
    -- Quest Indicator Border
    local quest = btn:CreateTexture(nil, "OVERLAY")
    quest:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
    quest:SetPoint("CENTER", btn, "CENTER", 0, 0)
    quest:SetSize(42, 42)
    quest:Hide()
    btn.QuestBorder = quest
    
    -- Junk / Scrap Badge
    local scrap = btn:CreateTexture(nil, "OVERLAY")
    scrap:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    scrap:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    scrap:SetSize(12, 12)
    scrap:Hide()
    btn.ScrapBadge = scrap
    
    -- Search Dimming Overlay
    local searchOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    searchOverlay:SetAllPoints(btn)
    searchOverlay:SetColorTexture(0, 0, 0, 0.75)
    searchOverlay:Hide()
    btn.SearchOverlay = searchOverlay
    
    -- Bag Hover Highlight (Gold glow & white/gold border)
    local bagHighlight = btn:CreateTexture(nil, "OVERLAY", nil, 5)
    bagHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    bagHighlight:SetBlendMode("ADD")
    bagHighlight:SetVertexColor(1, 0.85, 0.2, 0.6)
    bagHighlight:SetAllPoints(btn)
    bagHighlight:Hide()
    btn.BagHighlight = bagHighlight
    
    local bagHighlightBorder = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    bagHighlightBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    bagHighlightBorder:SetBlendMode("ADD")
    bagHighlightBorder:SetVertexColor(1, 0.85, 0.2, 1.0)
    bagHighlightBorder:SetAllPoints(btn)
    bagHighlightBorder:Hide()
    btn.BagHighlightBorder = bagHighlightBorder
    
    -- Cooldown Spiral
    local cd = _G[name .. "Cooldown"] or btn.Cooldown
    if not cd then
        local okCd, newCd = pcall(CreateFrame, "Cooldown", name .. "Cooldown", btn, "CooldownFrameTemplate")
        cd = (okCd and newCd) or CreateFrame("Cooldown", name .. "Cooldown", btn)
    end
    cd:SetAllPoints(btn)
    btn.Cooldown = cd
    
    btn:SetScript("OnEnter", OnItemEnter)
    btn:SetScript("OnLeave", OnItemLeave)
    
    return btn
end

-------------------------------------------------------------------------------
-- Bag Hover Highlight System
-------------------------------------------------------------------------------

function OneStorageBank:HighlightBagSlots(bagID)
    self.highlightedBagID = bagID
    for _, btn in ipairs(self.buttons) do
        local btnBag = btn.bag or (btn:GetParent() and btn:GetParent():GetID())
        if btn:IsShown() and btnBag ~= nil then
            if btnBag == bagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.25)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        end
    end
end

function OneStorageBank:ClearBagHighlights()
    self.highlightedBagID = nil
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            self:UpdateButton(btn)
        end
    end
end

function OneStorageBank:HighlightBankBarButton(bagID)
    if not self.bankBarButtons then return end
    for _, btn in ipairs(self.bankBarButtons) do
        if btn:GetID() == bagID then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
end

function OneStorageBank:ClearBankBarHighlight()
    if not self.bankBarButtons then return end
    for _, btn in ipairs(self.bankBarButtons) do
        btn:UnlockHighlight()
    end
end

-------------------------------------------------------------------------------
-- Grid Layout & Refresh
-------------------------------------------------------------------------------

function OneStorageBank:RefreshLayout()
    if not self.frame or not self.frame.ContentArea then return end
    
    local cols = self:GetOption("columns")
    local separateBags = self:GetOption("separateBags")
    local btnSize = 37
    local spacing = 4
    local bagGap = 8
    
    local slotList = {}
    local contentH = 0
    
    if self.selectedTab == 1 then
        local showMain = OneStorageBankDB and OneStorageBankDB.showMainBank
        if separateBags then
            local activeBags = {}
            if showMain then
                local baseSlots = ContainerHelper:GetNumSlots(ContainerHelper.BANK_CONTAINER)
                if baseSlots and baseSlots > 0 then
                    table.insert(activeBags, { bagID = ContainerHelper.BANK_CONTAINER, numSlots = baseSlots })
                end
            end
            for _, bagID in ipairs(ContainerHelper:GetBankBagIDs()) do
                local numSlots = ContainerHelper:GetNumSlots(bagID)
                if numSlots and numSlots > 0 then
                    table.insert(activeBags, { bagID = bagID, numSlots = numSlots })
                end
            end
            
            local currentRow = 0
            local numActiveBags = #activeBags
            for bagIdx, bagData in ipairs(activeBags) do
                local bagID = bagData.bagID
                local numSlots = bagData.numSlots
                local bagRows = math.ceil(numSlots / cols)
                
                for slotID = 1, numSlots do
                    local col = (slotID - 1) % cols
                    local localRow = math.floor((slotID - 1) / cols)
                    local row = currentRow + localRow
                    local x = col * (btnSize + spacing)
                    local y = -(row * (btnSize + spacing) + (bagIdx - 1) * bagGap)
                    
                    table.insert(slotList, {
                        bagID  = bagID,
                        slotID = slotID,
                        x      = x,
                        y      = y,
                    })
                end
                
                currentRow = currentRow + bagRows
            end
            
            local totalRows = math.max(1, currentRow)
            contentH = (totalRows * btnSize) + ((totalRows - 1) * spacing) + (math.max(0, numActiveBags - 1) * bagGap)
        else
            -- Merged continuous grid for Main Bank
            if showMain then
                local baseSlots = ContainerHelper:GetNumSlots(ContainerHelper.BANK_CONTAINER)
                if baseSlots and baseSlots > 0 then
                    for s = 1, baseSlots do
                        table.insert(slotList, { bagID = ContainerHelper.BANK_CONTAINER, slotID = s })
                    end
                end
            end
            for _, bagID in ipairs(ContainerHelper:GetBankBagIDs()) do
                local numSlots = ContainerHelper:GetNumSlots(bagID)
                if numSlots and numSlots > 0 then
                    for s = 1, numSlots do
                        table.insert(slotList, { bagID = bagID, slotID = s })
                    end
                end
            end
            
            local totalSlots = #slotList
            local rows = math.max(1, math.ceil(totalSlots / cols))
            contentH = (rows * btnSize) + ((rows - 1) * spacing)
            for i, slotData in ipairs(slotList) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                slotData.x = col * (btnSize + spacing)
                slotData.y = -row * (btnSize + spacing)
            end
        end
    else
        -- Reagent Bank container (-3)
        local numSlots = ContainerHelper:GetNumSlots(ContainerHelper.REAGENTBANK_CONTAINER)
        for s = 1, numSlots do
            table.insert(slotList, { bagID = ContainerHelper.REAGENTBANK_CONTAINER, slotID = s })
        end
        local totalSlots = #slotList
        local rows = math.max(1, math.ceil(totalSlots / cols))
        contentH = (rows * btnSize) + ((rows - 1) * spacing)
        for i, slotData in ipairs(slotList) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            slotData.x = col * (btnSize + spacing)
            slotData.y = -row * (btnSize + spacing)
        end
    end
    
    local totalSlots = #slotList
    local contentW = (cols * btnSize) + ((cols - 1) * spacing)
    local frameW = math.max(480, contentW + 32)
    local headerH = self.isBagBarShown and 90 or 58
    local footerH = 44
    local frameH = contentH + headerH + footerH + 16
    
    self.frame:SetSize(frameW, frameH)
    self.frame.ContentArea:SetSize(contentW, contentH)
    
    -- Anchor ContentArea
    self.frame.ContentArea:ClearAllPoints()
    if self.isBagBarShown and self.selectedTab == 1 then
        self.frame.ContentArea:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -92)
    else
        self.frame.ContentArea:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -60)
    end
    
    -- Position Item Slots
    for i = 1, math.max(totalSlots, #self.buttons) do
        local btn = self.buttons[i]
        if i <= totalSlots then
            if not btn then
                btn = self:CreateItemButton(i)
                self.buttons[i] = btn
            end
            
            local slotData = slotList[i]
            local bagParent = self:GetBagParentFrame(slotData.bagID)
            if btn:GetParent() ~= bagParent then
                btn:SetParent(bagParent)
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.frame.ContentArea, "TOPLEFT", slotData.x, slotData.y)
            
            btn:SetID(slotData.slotID)
            btn.bag = slotData.bagID
            btn.slot = slotData.slotID
            btn.bagID = nil
            btn.slotID = nil
            if not btn.GetBagID then
                if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.GetBagID then
                    btn.GetBagID = ContainerFrameItemButtonMixin.GetBagID
                else
                    btn.GetBagID = function(s)
                        return s.bag or (s:GetParent() and s:GetParent():GetID())
                    end
                end
            end
            btn:Show()
            
            self:UpdateButton(btn)
        else
            if btn then
                btn.bag = nil
                btn.slot = nil
                btn.bagID = nil
                btn.slotID = nil
                btn:Hide()
            end
        end
    end
    
    self:UpdateTitle()
    self:UpdateBankBar()
    if self.optionsFrame and self.optionsFrame:IsShown() then
        self:DockOptions()
    end
end

function OneStorageBank:UpdateButton(btn)
    local bagID = btn.bag or (btn:GetParent() and btn:GetParent():GetID())
    local slotID = btn.slot or btn:GetID()
    if not bagID or not slotID then return end
    
    -- Suppress Blizzard template default glow / battlepay overlays
    if btn.BattlepayItemTexture then btn.BattlepayItemTexture:Hide() end
    if btn.NewItemTexture then btn.NewItemTexture:Hide() end
    if btn.ExtendedSlot then btn.ExtendedSlot:Hide() end
    if btn.flashAnim and btn.flashAnim:IsPlaying() then btn.flashAnim:Stop() end
    if btn.newitemglowAnim and btn.newitemglowAnim:IsPlaying() then btn.newitemglowAnim:Stop() end
    
    local info = ContainerHelper:GetItemInfo(bagID, slotID)
    
    if info and info.icon then
        btn.hasItem = true
        btn.isReadable = info.readable
        btn.Icon:SetTexture(info.icon)
        btn.Icon:Show()
        btn.SlotBg:Hide()
        
        -- Locked Item Desaturation
        if info.locked then
            if SetItemButtonDesaturated then
                SetItemButtonDesaturated(btn, true)
            elseif btn.Icon.SetDesaturated then
                btn.Icon:SetDesaturated(true)
            end
        else
            if SetItemButtonDesaturated then
                SetItemButtonDesaturated(btn, false)
            elseif btn.Icon.SetDesaturated then
                btn.Icon:SetDesaturated(false)
            end
        end
        
        -- Stack Count
        if info.count and info.count > 1 then
            btn.Count:SetText(info.count)
            btn.Count:Show()
        else
            btn.Count:Hide()
        end
        
        -- Cooldown
        local start, duration, enable = ContainerHelper:GetItemCooldown(bagID, slotID)
        if start and duration and duration > 0 and enable == 1 then
            btn.Cooldown:SetCooldown(start, duration)
            btn.Cooldown:Show()
        else
            btn.Cooldown:Hide()
        end
        
        -- Quality Border
        if info.quality and info.quality > 1 then
            local r, g, b = ContainerHelper:GetQualityColor(info.quality)
            btn.QualityBorder:SetVertexColor(r, g, b, 1.0)
            btn.QualityBorder:Show()
        else
            btn.QualityBorder:Hide()
        end
        
        -- Junk / Scrap Coin Badge
        if ContainerHelper:IsJunk(bagID, slotID) then
            btn.ScrapBadge:Show()
        else
            btn.ScrapBadge:Hide()
        end
        
        -- Bag Hover Highlight / Search Filtering
        if self.highlightedBagID ~= nil then
            if bagID == self.highlightedBagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.25)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        elseif self.currentSearch and self.currentSearch ~= "" then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            local matches = ContainerHelper:MatchesSearch(bagID, slotID, self.currentSearch)
            if matches then
                btn.SearchOverlay:Hide()
                btn:SetAlpha(1.0)
            else
                btn.SearchOverlay:Show()
                btn:SetAlpha(0.3)
            end
        else
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Hide()
            btn:SetAlpha(1.0)
        end
    else
        btn.hasItem = false
        btn.isReadable = nil
        -- Empty Slot
        btn.Icon:Hide()
        btn.Count:Hide()
        btn.Cooldown:Hide()
        btn.QualityBorder:Hide()
        btn.QuestBorder:Hide()
        btn.ScrapBadge:Hide()
        
        if bagID == ContainerHelper.BANK_CONTAINER or bagID == -1 then
            btn.SlotBg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            btn.SlotBg:SetVertexColor(0.8, 0.8, 0.8, 0.35)
        else
            btn.SlotBg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            btn.SlotBg:SetVertexColor(0.4, 0.4, 0.4, 0.5)
        end
        btn.SlotBg:Show()
        
        if self.highlightedBagID ~= nil then
            if bagID == self.highlightedBagID then
                if btn.BagHighlight then btn.BagHighlight:Show() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Show() end
                btn:LockHighlight()
                btn:SetAlpha(1.0)
                if btn.SearchOverlay then btn.SearchOverlay:Hide() end
            else
                if btn.BagHighlight then btn.BagHighlight:Hide() end
                if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
                btn:UnlockHighlight()
                btn:SetAlpha(0.2)
                if btn.SearchOverlay then btn.SearchOverlay:Show() end
            end
        elseif self.currentSearch and self.currentSearch ~= "" then
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Show()
            btn:SetAlpha(0.2)
        else
            if btn.BagHighlight then btn.BagHighlight:Hide() end
            if btn.BagHighlightBorder then btn.BagHighlightBorder:Hide() end
            btn:UnlockHighlight()
            btn.SearchOverlay:Hide()
            btn:SetAlpha(1.0)
        end
    end
end

-------------------------------------------------------------------------------
-- Search Handler
-------------------------------------------------------------------------------

function OneStorageBank:OnSearchChanged(text)
    self.currentSearch = text or ""
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            self:UpdateButton(btn)
        end
    end
end

-------------------------------------------------------------------------------
-- Collapsible Bank Bag Bar (Equipped Bank Bags & Purchase Slot)
-------------------------------------------------------------------------------

if StaticPopupDialogs and not StaticPopupDialogs["ONE_STORAGE_BUY_BANK_SLOT"] then
    StaticPopupDialogs["ONE_STORAGE_BUY_BANK_SLOT"] = {
        text = CONFIRM_BUY_BANK_SLOT or "Do you want to purchase a bank slot for:",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(self, data)
            local bankType = (data and data.bankType) or (Enum and Enum.BankType and Enum.BankType.Character) or 0
            if C_Bank and C_Bank.PurchaseBankTab then
                C_Bank.PurchaseBankTab(bankType)
            elseif PurchaseSlot then
                PurchaseSlot()
            end
        end,
        OnShow = function(self, data)
            local cost = (data and data.cost) or (type(self.data) == "table" and self.data.cost) or self.data or (_G.BankFrame and _G.BankFrame.nextSlotCost) or (OneStorageBank and OneStorageBank.nextSlotCost) or 0
            if MoneyFrame_Update and self.moneyFrame then
                MoneyFrame_Update(self.moneyFrame, cost)
            end
        end,
        hasMoneyFrame = 1,
        timeout = 0,
        hideOnEscape = 1,
    }
end

function OneStorageBank:GetBankSlotInfo()
    local bankType = (Enum and Enum.BankType and Enum.BankType.Character) or 0
    local numPurchased = 0
    local full = false
    local nextCost = nil
    
    -- 1. Modern C_Bank API (WoW Forever Beta / Camelot engine)
    if C_Bank and (C_Bank.FetchNumPurchasedBankTabs or C_Bank.FetchPurchasedBankTabData) then
        local maxTabs = (C_Bank.FetchMaxNumBankTabs and C_Bank.FetchMaxNumBankTabs(bankType)) or 7
        local purchasedTabs = (C_Bank.FetchNumPurchasedBankTabs and C_Bank.FetchNumPurchasedBankTabs(bankType)) or 0
        full = (C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(bankType)) or (purchasedTabs >= maxTabs)
        numPurchased = math.max(0, purchasedTabs - 1) -- Tab 1 is base bank container
        
        local tabData = C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(bankType)
        if tabData then
            nextCost = tabData.tabCost
        end
    -- 2. Classic / Legacy WoW API Fallback
    elseif GetNumBankSlots then
        numPurchased, full = GetNumBankSlots()
        if not full and GetBankSlotCost then
            nextCost = GetBankSlotCost(numPurchased)
        end
    end
    
    return numPurchased, full, nextCost
end

function OneStorageBank:PurchaseBankSlot()
    local bankType = (Enum and Enum.BankType and Enum.BankType.Character) or 0
    
    -- 1. Modern C_Bank API (WoW Forever Beta / Camelot)
    if C_Bank and (C_Bank.PurchaseBankTab or C_Bank.FetchNextPurchasableBankTabData) then
        local maxTabs = (C_Bank.FetchMaxNumBankTabs and C_Bank.FetchMaxNumBankTabs(bankType)) or 7
        local purchasedTabs = (C_Bank.FetchNumPurchasedBankTabs and C_Bank.FetchNumPurchasedBankTabs(bankType)) or 0
        local isMaxed = (C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(bankType)) or (purchasedTabs >= maxTabs)
        
        local tabData = C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(bankType)
        if isMaxed or not tabData then
            print("|cff00ccff[OneStorageBank]|r All bank bag slots have already been purchased.")
            return
        end
        
        local cost = tabData.tabCost or 0
        if tabData.canAfford == false or (GetMoney and GetMoney() < cost) then
            local costStr = ContainerHelper and ContainerHelper.FormatMoney and ContainerHelper:FormatMoney(cost) or tostring(cost)
            print("|cffff0000[OneStorageBank]|r Not enough gold to purchase a bank slot (" .. costStr .. " required).")
            return
        end
        
        if _G.BankFrame then
            _G.BankFrame.nextSlotCost = cost
        end
        self.nextSlotCost = cost
        
        PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or 856)
        
        if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_BUY_BANK_TAB"] and StaticPopup_Show then
            StaticPopup_Show("CONFIRM_BUY_BANK_TAB", nil, nil, { bankType = bankType })
        elseif StaticPopupDialogs and StaticPopupDialogs["ONE_STORAGE_BUY_BANK_SLOT"] and StaticPopup_Show then
            StaticPopup_Show("ONE_STORAGE_BUY_BANK_SLOT", nil, nil, { bankType = bankType, cost = cost })
        elseif C_Bank.PurchaseBankTab then
            C_Bank.PurchaseBankTab(bankType)
        end
        return
    end
    
    -- 2. Classic / Legacy Bank API Fallback
    if GetNumBankSlots and GetBankSlotCost then
        local numSlots, full = GetNumBankSlots()
        if full then
            print("|cff00ccff[OneStorageBank]|r All bank bag slots have already been purchased.")
            return
        end
        
        local cost = GetBankSlotCost(numSlots)
        if GetMoney and GetMoney() < cost then
            local costStr = ContainerHelper and ContainerHelper.FormatMoney and ContainerHelper:FormatMoney(cost) or tostring(cost)
            print("|cffff0000[OneStorageBank]|r Not enough gold to purchase a bank slot (" .. costStr .. " required).")
            return
        end
        
        if _G.BankFrame then
            _G.BankFrame.nextSlotCost = cost
        end
        self.nextSlotCost = cost
        
        PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or 856)
        
        if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_BUY_BANK_SLOT"] and StaticPopup_Show then
            StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
        elseif StaticPopupDialogs and StaticPopupDialogs["ONE_STORAGE_BUY_BANK_SLOT"] and StaticPopup_Show then
            StaticPopup_Show("ONE_STORAGE_BUY_BANK_SLOT", nil, nil, { cost = cost })
        elseif PurchaseSlot then
            PurchaseSlot()
        end
    end
end

function OneStorageBank:UpdateBankBar()
    if not self.bankBar or not self.bankBarButtons then return end
    
    local numPurchased, full, nextCost = self:GetBankSlotInfo()
    
    for idx, btn in ipairs(self.bankBarButtons) do
        local bagID = btn:GetID()
        local isPurchased = (idx <= numPurchased)
        
        if isPurchased then
            local texture = ContainerHelper:GetBagTexture(bagID)
            if texture then
                btn.icon:SetTexture(texture)
                btn.icon:SetVertexColor(1, 1, 1, 1)
                
                local quality = ContainerHelper:GetBagQuality(bagID)
                if quality and quality > 1 and btn.QualityBorder then
                    local r, g, b = ContainerHelper:GetQualityColor(quality)
                    btn.QualityBorder:SetVertexColor(r, g, b, 1)
                    btn.QualityBorder:Show()
                elseif btn.QualityBorder then
                    btn.QualityBorder:Hide()
                end
            else
                btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                btn.icon:SetVertexColor(0.4, 0.4, 0.4, 0.8)
                if btn.QualityBorder then btn.QualityBorder:Hide() end
            end
        else
            btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            btn.icon:SetVertexColor(0.2, 0.2, 0.2, 0.4)
            if btn.QualityBorder then btn.QualityBorder:Hide() end
        end
    end
    
    if self.bankBar.BuyButton then
        if full then
            self.bankBar.BuyButton:Disable()
            self.bankBar.BuyButton:SetText("Maxed")
        else
            self.bankBar.BuyButton:Enable()
            self.bankBar.BuyButton:SetText("Buy Slot")
        end
    end
end

function OneStorageBank:CreateBankBar()
    if self.bankBar then return self.bankBar end
    
    local bar = CreateFrame("Frame", "OneStorageBankBar", self.frame)
    bar:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -58)
    bar:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -16, -58)
    bar:SetHeight(32)
    bar:Hide()
    self.bankBar = bar
    
    local bankBagSlots = ContainerHelper:GetBankBagIDs()
    local xOffset = 0
    for idx, bagID in ipairs(bankBagSlots) do
        local btn = CreateFrame("Button", "OneStorageBankBarButton" .. bagID, bar)
        btn:SetSize(28, 28)
        btn:SetPoint("LEFT", bar, "LEFT", xOffset, 0)
        btn:SetID(bagID)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")
        
        -- Slot Background Texture
        local slotBg = btn:CreateTexture(nil, "BACKGROUND")
        slotBg:SetAllPoints(btn)
        slotBg:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        slotBg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
        btn.slotBg = slotBg
        
        local icon = btn:CreateTexture(nil, "BORDER")
        icon:SetAllPoints(btn)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = icon
        
        local qualityBorder = btn:CreateTexture(nil, "OVERLAY")
        qualityBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        qualityBorder:SetAllPoints(btn)
        qualityBorder:Hide()
        btn.QualityBorder = qualityBorder
        
        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetAllPoints(btn)
        highlight:SetBlendMode("ADD")
        btn.Highlight = highlight
        
        btn:SetScript("OnClick", function(s, button)
            local numPurchased = OneStorageBank:GetBankSlotInfo()
            if idx > numPurchased then
                OneStorageBank:PurchaseBankSlot()
                return
            end
            
            local invID = ContainerHelper:GetBagInventoryID(bagID)
            if invID then
                if CursorHasItem and CursorHasItem() then
                    PutItemInBag(invID)
                else
                    PickupInventoryItem(invID)
                end
            end
        end)
        btn:SetScript("OnDragStart", function(s)
            local invID = ContainerHelper:GetBagInventoryID(bagID)
            if invID then
                PickupInventoryItem(invID)
            end
        end)
        btn:SetScript("OnReceiveDrag", function(s)
            local invID = ContainerHelper:GetBagInventoryID(bagID)
            if invID then
                PutItemInBag(invID)
            end
        end)
        
        btn:SetScript("OnEnter", function(s)
            OneStorageBank:HighlightBagSlots(bagID)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            local numPurchased, full, nextCost = OneStorageBank:GetBankSlotInfo()
            if idx > numPurchased then
                GameTooltip:SetText("Unpurchased Bank Bag Slot", 1, 0.8, 0)
                if idx == (numPurchased + 1) and nextCost then
                    GameTooltip:AddLine("Cost: " .. ContainerHelper:FormatMoney(nextCost), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("Click to purchase this slot.", 0.2, 1.0, 0.2)
                else
                    GameTooltip:AddLine("Must purchase previous slots first.", 0.7, 0.7, 0.7)
                end
            else
                local invID = ContainerHelper:GetBagInventoryID(bagID)
                local hasItem = ContainerHelper:GetBagTexture(bagID)
                if invID and hasItem and GameTooltip.SetInventoryItem then
                    GameTooltip:SetInventoryItem("player", invID)
                else
                    GameTooltip:SetText("Empty Bank Bag Slot", 1, 1, 1)
                    GameTooltip:AddLine("Drag a bag here to expand bank storage.", 0.8, 0.8, 0.8)
                end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            OneStorageBank:ClearBagHighlights()
            GameTooltip:Hide()
        end)
        
        table.insert(self.bankBarButtons, btn)
        xOffset = xOffset + 32
    end
    
    -- Purchase Bank Slot Button
    local buyBtn = FrameHelper:CreateSilverButton(bar, "OneStorageBankBuySlotButton", "Buy Slot")
    buyBtn:SetSize(80, 22)
    buyBtn:SetPoint("LEFT", bar, "LEFT", xOffset + 8, 0)
    buyBtn:SetScript("OnClick", function()
        OneStorageBank:PurchaseBankSlot()
    end)
    buyBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Purchase Bank Bag Slot", 1, 1, 1)
        local numPurchased, full, nextCost = OneStorageBank:GetBankSlotInfo()
        if not full and nextCost then
            GameTooltip:AddLine("Cost: " .. ContainerHelper:FormatMoney(nextCost), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Click to purchase next slot.", 0.2, 1.0, 0.2)
        elseif full then
            GameTooltip:AddLine("All bank bag slots purchased.", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    buyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.BuyButton = buyBtn
    
    self:UpdateBankBar()
    return bar
end

function OneStorageBank:ToggleBagBar()
    self.isBagBarShown = not self.isBagBarShown
    if not self.bankBar then
        self:CreateBankBar()
    end
    
    if self.isBagBarShown and self.selectedTab == 1 then
        self.bankBar:Show()
    else
        self.bankBar:Hide()
    end
    
    self:RefreshLayout()
end

-------------------------------------------------------------------------------
-- Silver Tabs (Main Bank / Reagents)
-------------------------------------------------------------------------------

function OneStorageBank:SelectTab(tabIndex)
    self.selectedTab = tabIndex
    
    if self.tab1 then self.tab1:SetSelected(tabIndex == 1) end
    if self.tab2 then self.tab2:SetSelected(tabIndex == 2) end
    
    if self.depositBtn then
        if tabIndex == 2 then
            self.depositBtn:Show()
        else
            self.depositBtn:Hide()
        end
    end
    
    if self.bankBar then
        if tabIndex == 1 and self.isBagBarShown then
            self.bankBar:Show()
        else
            self.bankBar:Hide()
        end
    end
    
    self:RefreshLayout()
end

-------------------------------------------------------------------------------
-- Position Persistence (Save & Restore)
-------------------------------------------------------------------------------

function OneStorageBank:SavePosition()
    if not self.frame then return end
    local point, _, relPoint, xOfs, yOfs = self.frame:GetPoint(1)
    if point then
        _G.OneStorageBankDB = _G.OneStorageBankDB or {}
        _G.OneStorageBankDB.position = {
            point = point,
            relativePoint = relPoint or point,
            x = math.floor(xOfs + 0.5),
            y = math.floor(yOfs + 0.5),
        }
    end
end

function OneStorageBank:RestorePosition()
    if not self.frame then return end
    local pos = _G.OneStorageBankDB and _G.OneStorageBankDB.position
    self.frame:ClearAllPoints()
    if pos and pos.point and pos.x and pos.y then
        self.frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
    else
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -100)
    end
end

-------------------------------------------------------------------------------
-- Master Window Creation
-------------------------------------------------------------------------------

function OneStorageBank:CreateFrame()
    if self.frame then return self.frame end
    
    local frame = CreateFrame("Frame", "OneStorageBankFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(520, 500)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    local function StartMoving()
        if not InCombatLockdown or not InCombatLockdown() then
            frame:StartMoving()
        end
    end
    local function StopMoving()
        frame:StopMovingOrSizing()
        OneStorageBank:SavePosition()
    end
    
    frame:SetScript("OnDragStart", StartMoving)
    frame:SetScript("OnDragStop", StopMoving)
    frame:Hide()
    
    self.frame = frame
    self:RestorePosition()
    
    -- Esc key close
    if FrameHelper then
        FrameHelper:RegisterEscClose("OneStorageBankFrame")
        FrameHelper:ApplyHiResFrame(frame)
    end
    
    -- Enable dragging on TitleContainer if present
    if frame.TitleContainer then
        frame.TitleContainer:EnableMouse(true)
        frame.TitleContainer:RegisterForDrag("LeftButton")
        frame.TitleContainer:SetScript("OnDragStart", StartMoving)
        frame.TitleContainer:SetScript("OnDragStop", StopMoving)
    end
    
    -- Top-Left Portrait Icon (Bank Chest)
    local portrait = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait
    if portrait then
        portrait:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
        portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        portrait:Show()
    end
    
    local portraitBtn = CreateFrame("Button", "OneStorageBankPortraitHoverButton", frame)
    portraitBtn:SetSize(60, 60)
    portraitBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 7)
    portraitBtn:SetFrameLevel(frame:GetFrameLevel() + 50)
    portraitBtn:EnableMouse(true)
    portraitBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    portraitBtn:RegisterForDrag("LeftButton")
    portraitBtn:SetScript("OnDragStart", StartMoving)
    portraitBtn:SetScript("OnDragStop", StopMoving)
    portraitBtn:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            OneStorageBank:ToggleOptions()
        end
    end)
    portraitBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bank Vault", 1, 1, 1)
        GameTooltip:AddLine("Main bank storage vault.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Right-Click|r to open Options", 0.2, 1.0, 0.2)
        GameTooltip:Show()
    end)
    portraitBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Header Action: Search Box
    local search = FrameHelper:CreateSearchBox(frame, "OneStorageBankSearchBox", function(s, text)
        OneStorageBank:OnSearchChanged(text)
    end)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -36)
    search:SetWidth(160)
    frame.SearchBox = search
    
    -- Header Action: Sort Broom Button
    local sortBtn = CreateFrame("Button", "OneStorageBankSortButton", frame)
    sortBtn:SetSize(20, 20)
    sortBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -36)
    
    local sortIcon = sortBtn:CreateTexture(nil, "OVERLAY")
    sortIcon:SetAllPoints(sortBtn)
    sortIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    sortBtn.Icon = sortIcon
    
    sortBtn:SetScript("OnClick", function()
        if OneStorageBank.selectedTab == 1 then
            ContainerHelper:SortBankBags()
        else
            ContainerHelper:SortReagentBankBags()
        end
    end)
    sortBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sort Bank", 1, 1, 1)
        GameTooltip:AddLine("Clean up and consolidate bank stacks.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.SortButton = sortBtn
    
    -- Header Action: Toggle Bank Bag Bar Button (Right-click opens Options)
    local bagBarBtn = CreateFrame("Button", "OneStorageBankBarToggleButton", frame)
    bagBarBtn:SetSize(20, 20)
    bagBarBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)
    
    local bagBarIcon = bagBarBtn:CreateTexture(nil, "OVERLAY")
    bagBarIcon:SetAllPoints(bagBarBtn)
    bagBarIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    bagBarBtn.Icon = bagBarIcon
    
    bagBarBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bagBarBtn:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            OneStorageBank:ToggleOptions()
        else
            OneStorageBank:ToggleBagBar()
        end
    end)
    bagBarBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle Bank Bag Bar", 1, 1, 1)
        GameTooltip:AddLine("Show or hide equipped bank bags.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cff00ff00Right-Click|r to open Options", 0.2, 1.0, 0.2)
        GameTooltip:Show()
    end)
    bagBarBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.BagBarButton = bagBarBtn
    
    -- Content Area for Item Grid
    local contentArea = CreateFrame("Frame", "OneStorageBankContentArea", frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -60)
    contentArea:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.ContentArea = contentArea
    
    -- Footer Silver Tabs
    local tab1 = FrameHelper:CreateSilverTab(frame, "OneStorageBankTab1", 1, "Bank")
    tab1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 8)
    tab1:SetScript("OnClick", function() OneStorageBank:SelectTab(1) end)
    self.tab1 = tab1
    
    local tab2 = FrameHelper:CreateSilverTab(frame, "OneStorageBankTab2", 2, "Reagents")
    tab2:SetPoint("LEFT", tab1, "RIGHT", -4, 0)
    tab2:SetScript("OnClick", function() OneStorageBank:SelectTab(2) end)
    self.tab2 = tab2
    
    -- Deposit All Reagents Action Button
    local depositBtn = FrameHelper:CreateSilverButton(frame, "OneStorageBankDepositReagentsButton", "Deposit Reagents")
    depositBtn:SetSize(130, 24)
    depositBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
    depositBtn:SetScript("OnClick", function()
        if C_Container and C_Container.DepositReagentBank then
            pcall(C_Container.DepositReagentBank)
        elseif DepositReagentBank then
            pcall(DepositReagentBank)
        end
    end)
    depositBtn:Hide()
    self.depositBtn = depositBtn
    
    -- Close Button (exits bank session completely)
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function()
            OneStorageBank:Hide()
        end)
    end
    
    -- Sound effects on Open / Close (Native Bank / Main Menu sounds)
    local function PlayOpenSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN) or 846
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igMainMenuOpen")
        end
    end

    local function PlayCloseSound()
        local sound = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE) or 847
        local ok = pcall(PlaySound, sound)
        if not ok then
            pcall(PlaySound, "igMainMenuClose")
        end
    end

    local function OnBankShow()
        PlayOpenSound()
    end

    local function OnBankHide()
        PlayCloseSound()
        if OneStorageBank.optionsFrame and OneStorageBank.optionsFrame:IsShown() then
            OneStorageBank.optionsFrame:Hide()
        end
        OneStorageBank:CloseBankSession()
    end

    if frame.HookScript then
        frame:HookScript("OnShow", OnBankShow)
        frame:HookScript("OnHide", OnBankHide)
    else
        frame:SetScript("OnShow", OnBankShow)
        frame:SetScript("OnHide", OnBankHide)
    end
    
    self:SelectTab(1)
    
    return frame
end

-------------------------------------------------------------------------------
-- Visibility & Toggle API
-------------------------------------------------------------------------------

local isClosingBankSession = false
function OneStorageBank:CloseBankSession()
    if isClosingBankSession then return end
    isClosingBankSession = true
    
    -- Modern WoW API (TWW / Dragonflight / Classic 1.15+ engine)
    if C_Bank and C_Bank.CloseBankFrame then
        pcall(C_Bank.CloseBankFrame)
    end
    
    -- Classic / Legacy WoW API
    if CloseBankFrame then
        pcall(CloseBankFrame)
    end
    
    -- Interaction Manager (exits NPC banker dialog completely)
    if C_PlayerInteractionManager and C_PlayerInteractionManager.ClearInteraction and Enum and Enum.PlayerInteractionType then
        pcall(C_PlayerInteractionManager.ClearInteraction, Enum.PlayerInteractionType.Banker)
        if Enum.PlayerInteractionType.CharacterBanker then
            pcall(C_PlayerInteractionManager.ClearInteraction, Enum.PlayerInteractionType.CharacterBanker)
        end
        if Enum.PlayerInteractionType.AccountBanker then
            pcall(C_PlayerInteractionManager.ClearInteraction, Enum.PlayerInteractionType.AccountBanker)
        end
    end
    
    -- Native Blizzard BankFrame
    local bf = _G["BankFrame"]
    if bf and bf.IsShown and bf:IsShown() then
        pcall(function() bf:Hide() end)
    end
    
    isClosingBankSession = false
end

function OneStorageBank:Show()
    local f = self:CreateFrame()
    f:Show()
    self:RefreshLayout()
    self:UpdateBankBar()
end

function OneStorageBank:Hide()
    if self.optionsFrame and self.optionsFrame:IsShown() then
        self.optionsFrame:Hide()
    end
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
    self:CloseBankSession()
end

function OneStorageBank:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-------------------------------------------------------------------------------
-- Options Panel (Docked to Left of Master Window)
-------------------------------------------------------------------------------

function OneStorageBank:DockOptions()
    if not self.optionsFrame or not self.frame then return end
    self.optionsFrame:ClearAllPoints()
    self.optionsFrame:SetSize(230, 220)
    self.optionsFrame:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 0)
end

function OneStorageBank:CreateOptionsFrame()
    if self.optionsFrame then return self.optionsFrame end
    
    local parent = self.frame or self:CreateFrame()
    local opt = CreateFrame("Frame", "OneStorageBankOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    opt:SetSize(230, 220)
    opt:SetFrameStrata(parent:GetFrameStrata())
    opt:SetFrameLevel(math.max(1, parent:GetFrameLevel()))
    opt:SetClampedToScreen(true)
    opt:Hide()
    self.optionsFrame = opt
    
    -- Clean simple dialog frame styling without upper-left portrait ring
    if FrameHelper then
        FrameHelper:RegisterEscClose("OneStorageBankOptionsFrame")
        FrameHelper:ApplySimplePanel(opt, "Bank Options")
    end
    
    -- Draggable: Dragging docked options panel moves parent bank window smoothly
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", function()
        if parent:IsMovable() and (not InCombatLockdown or not InCombatLockdown()) then
            parent:StartMoving()
        end
    end)
    opt:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        OneStorageBank:SavePosition()
    end)
    
    -- UI Controls inside Options Panel
    local controls = {}
    local yOffset = -38
    local marginX = 16
    
    -- SECTION 1: Display & Layout
    local s1Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s1Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s1Header:SetText("|cffffcc00Display & Layout|r")
    yOffset = yOffset - 24
    
    -- Stepper: Columns
    local colStepper = FrameHelper:CreateStepper(
        opt,
        "OneStorageBankOptions_Columns",
        "Columns",
        6,
        18,
        function() return OneStorageBank:GetOption("columns") end,
        function(val)
            OneStorageBank:SetOption("columns", val)
            OneStorageBank:RefreshLayout()
        end
    )
    colStepper:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    colStepper:SetWidth(196)
    table.insert(controls, colStepper)
    yOffset = yOffset - 28
    
    -- Checkbox: Separate Bag Rows
    local sepCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBankOptions_SeparateBags",
        "Separate Bag Rows",
        "Group each bank bag into its own row(s) instead of one continuous merged grid.",
        function()
            return OneStorageBank:GetOption("separateBags")
        end,
        function(val)
            OneStorageBank:SetOption("separateBags", val)
            OneStorageBank:RefreshLayout()
        end
    )
    sepCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, sepCb)
    yOffset = yOffset - 26
    
    -- Checkbox: Show Bank Bag Bar
    local drawerCb = FrameHelper:CreateCheckbox(
        opt,
        "OneStorageBankOptions_ShowBagBar",
        "Show Bank Bag Bar",
        "Show or hide equipped bank bags and the bag purchase slot.",
        function()
            return OneStorageBank.isBagBarShown
        end,
        function(val)
            OneStorageBank.isBagBarShown = val
            if not OneStorageBank.bankBar then
                OneStorageBank:CreateBankBar()
            end
            if val and OneStorageBank.selectedTab == 1 then
                OneStorageBank.bankBar:Show()
            else
                OneStorageBank.bankBar:Hide()
            end
            OneStorageBank:RefreshLayout()
        end
    )
    drawerCb:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    table.insert(controls, drawerCb)
    yOffset = yOffset - 32
    
    -- SECTION 2: Window Settings
    local s2Header = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s2Header:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    s2Header:SetText("|cffffcc00Window Settings|r")
    yOffset = yOffset - 26
    
    local resetBtn = FrameHelper:CreateSilverButton(opt, "OneStorageBankOptions_ResetPosBtn", "Reset Position")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", opt, "TOPLEFT", marginX, yOffset)
    resetBtn:SetScript("OnClick", function()
        if _G.OneStorageBankDB then _G.OneStorageBankDB.position = nil end
        OneStorageBank:RestorePosition()
    end)
    
    opt.RefreshOptions = function()
        for _, c in ipairs(controls) do
            if c.Refresh then c:Refresh() end
        end
    end
    
    return opt
end

function OneStorageBank:ToggleOptions()
    if not self.frame or not self.frame:IsShown() then
        self:Show()
    end
    local opt = self.optionsFrame or self:CreateOptionsFrame()
    if opt:IsShown() then
        opt:Hide()
    else
        self:DockOptions()
        opt:RefreshOptions()
        opt:Show()
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------

local function SafeRegisterEvent(frame, eventName)
    pcall(function() frame:RegisterEvent(eventName) end)
end

local function IsBankInteraction(interactionType)
    if not interactionType then return false end
    local pit = Enum and Enum.PlayerInteractionType
    if not pit then return false end
    return interactionType == pit.Banker
        or interactionType == pit.CharacterBanker
        or interactionType == pit.AccountBanker
end

local eventFrame = CreateFrame("Frame", "OneStorageBank_EventFrame")
SafeRegisterEvent(eventFrame, "ADDON_LOADED")
SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")
SafeRegisterEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
SafeRegisterEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
SafeRegisterEvent(eventFrame, "BANKFRAME_OPENED")
SafeRegisterEvent(eventFrame, "BANKFRAME_CLOSED")
SafeRegisterEvent(eventFrame, "BANK_TABS_CHANGED")
SafeRegisterEvent(eventFrame, "BANK_BAG_SLOT_FLAGS_UPDATED")
SafeRegisterEvent(eventFrame, "PLAYERBANKSLOTS_CHANGED")
SafeRegisterEvent(eventFrame, "PLAYERBANKBAGSLOTS_CHANGED")
SafeRegisterEvent(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
SafeRegisterEvent(eventFrame, "BAG_CONTAINER_UPDATE")
SafeRegisterEvent(eventFrame, "BAG_UPDATE")
SafeRegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
SafeRegisterEvent(eventFrame, "REAGENTBANK_UPDATE")
SafeRegisterEvent(eventFrame, "PLAYER_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        _G.OneStorageBankDB = _G.OneStorageBankDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OneStorageBankDB[k] == nil then
                _G.OneStorageBankDB[k] = v
            end
        end
        _G.OneStorageBankDB.showMainBank = false
        
    elseif event == "PLAYER_LOGIN" then
        OneStorageBank:CreateFrame()
        
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if IsBankInteraction(arg1) then
            OneStorageBank:Show()
        end
        
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if IsBankInteraction(arg1) then
            OneStorageBank:Hide()
        end
        
    elseif event == "BANKFRAME_OPENED" then
        OneStorageBank:Show()
        
    elseif event == "BANKFRAME_CLOSED" then
        OneStorageBank:Hide()
        
    elseif event == "BANK_TABS_CHANGED" or event == "BANK_BAG_SLOT_FLAGS_UPDATED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_CONTAINER_UPDATE" or event == "BAG_UPDATE" or event == "REAGENTBANK_UPDATE" or event == "PLAYER_MONEY" then
        if OneStorageBank.frame and OneStorageBank.frame:IsShown() then
            OneStorageBank:RefreshLayout()
            OneStorageBank:UpdateBankBar()
        end
    end
end)

-- Slash Command Registry
SLASH_ONESTORAGEBANK1 = "/onebank"
SLASH_ONESTORAGEBANK2 = "/osbank"
SlashCmdList["ONESTORAGEBANK"] = function(msg)
    local cmd, arg = strsplit(" ", (msg or ""):lower(), 2)
    if cmd == "reset" then
        if _G.OneStorageBankDB then _G.OneStorageBankDB.position = nil end
        if OneStorageBank.frame then
            OneStorageBank.frame:ClearAllPoints()
            OneStorageBank.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -100)
        end
        print("|cff00ccff[OneStorageBank]|r Window position reset to default.")
    elseif cmd == "options" or cmd == "opt" or cmd == "config" then
        OneStorageBank:ToggleOptions()
    elseif cmd == "separate" or cmd == "group" or cmd == "mode" or cmd == "rows" then
        local current = OneStorageBank:GetOption("separateBags")
        OneStorageBank:SetOption("separateBags", not current)
        if OneStorageBank.frame and OneStorageBank.frame:IsShown() then
            OneStorageBank:RefreshLayout()
        end
        local modeStr = OneStorageBank:GetOption("separateBags") and "|cff00ff00Separated bag rows|r" or "|cffffcc00Merged continuous grid|r"
        print("|cff00ccff[OneStorageBank]|r Bank layout mode: " .. modeStr)
    elseif cmd == "cols" and tonumber(arg) then
        local c = math.max(6, math.min(18, tonumber(arg)))
        OneStorageBank:SetOption("columns", c)
        if OneStorageBank.frame and OneStorageBank.frame:IsShown() then
            OneStorageBank:RefreshLayout()
        end
        print("|cff00ccff[OneStorageBank]|r Column width set to " .. c)
    else
        OneStorageBank:Toggle()
    end
end
