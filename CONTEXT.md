# AI Context & Living Specification — OneStorageBank

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageBank
- **Current Version**: 0.0.10
- **Suite**: Part of the **OneSuite** family (OneStorage Inventory Suite)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageBank
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OneStorageBank/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneStorageBank-latest.zip` on push to `main`
- **Dependencies**: `OneStorageUtils`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Replace the Blizzard bank UI with a unified, metal-styled master bank window featuring sub-tabs for Main Bank and Reagents, live search filtering, bank bag slot purchasing, and customizable layout modes.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneStorageBank.toc`: Manifest, declares dependency on `OneStorageUtils`, SavedVariables (`OneStorageBankDB`).
- `Core.lua`: Master bank canvas creation, sub-tabs (`selectedTab`), button grid generation, search filter highlighter, bank bag purchase confirmation dialog (`CONFIRM_BUY_BANK_TAB`) and routines using modern Camelot `C_Bank` APIs, bank equipment container (`Enum.BagIndex.Characterbanktab` / -2), cleanup sorting, and slash commands (`/onebank`, `/osbank`).
- `Hooks.lua`: Intercepts native Blizzard bank frame events (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`, `BankFrame_Open`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`, `BAG_CONTAINER_UPDATE`) and suppresses the default `BankFrame` safely offscreen.

### Global State & Database Schema (`OneStorageBankDB`)
```lua
OneStorageBankDB = {
    columns = 12,                      -- Column count (6 to 18)
    separateBags = true,               -- Display row dividers per bank bag
    showBagBar = false,                -- Expand bank bag drawer
    selectedTab = 1,                   -- 1: Main Bank, 2: Reagents
    position = {                       -- Saved window position
        point = "TOPLEFT",
        x = 60,
        y = -100
    }
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/onebank` or visiting a Banker.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.10
- **Eliminated `UseContainerItem` Action Blocked Taint**: Fixed Blizzard UI blocked action error (`Forbidden function call: AddOn 'OneStorageBank' attempted to call 'UNKNOWN()'`) when right-clicking recipes, consumables, or items in bags while NPC windows (such as trainer, merchant, or dialog frames) are open.
  - Eliminated `tinyParent`, frame reparenting, and `SetScript("OnHide", ...)` overrides on Blizzard's `BankFrame`, preserving native frame hierarchy and script handlers without UI taint.
  - Removed `hooksecurefunc("UpdateUIPanelPositions")` to prevent execution taint from propagating during Blizzard UIPanel management.
  - Ensured `BankPanel:Hide()` is strictly invoked on `PLAYER_LOGIN` and upon bank session termination (`OnBankClosed` and `CloseBankSession`), guaranteeing `BankFrame:GetActiveBankType()` short-circuits and returns `nil` when the player is away from a banker.
  - Suppressed `BankFrame` during open bank sessions using alpha zero, mouse disabled, and offscreen positioning without altering native object properties or templates.

### Spin 0.0.9
- **Persistent Bank Bag Drawer Visibility**: Fixed issue where the bank bag drawer (`showBagBar`) failed to persist across `/reload` and game sessions.
  - Updated `OneStorageBank:ToggleBagBar()` and options checkbox to immediately persist user preferences to `OneStorageBankDB.showBagBar`.
  - Added preference synchronization during `ADDON_LOADED`, `CreateFrame()`, and `Show()`, ensuring the bank drawer and canvas layout dynamically restore their expanded/collapsed state upon loading.
  - Added `/onebank bagbar`, `/onebank drawer`, and `/onebank bags` slash commands for toggling bank drawer visibility.

### Spin 0.0.8
- **Camelot Bank Tab Architecture Alignment**: Realigned bank bag containers and purchase logic with the WoW Forever Beta (Interface 16001, Camelot) engine:
  - Base bank vault is container 6 (`Enum.BagIndex.CharacterBankTab_1`, 40 slots).
  - Extra bank bags are containers 7 through 12 (`Enum.BagIndex.CharacterBankTab_2` through `CharacterBankTab_7`).
  - Corrected `GetBankBagIDs()` to strictly return `{ 7, 8, 9, 10, 11, 12 }`, eliminating duplicate container 6 injection that previously created 40 duplicate empty slots on top of the bank grid.
- **Fixed "Purchase Again" and Slot Cost Counting**: Replaced non-existent `GetNumBankSlots()` and `GetBankSlotCost()` with `C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)` and `C_Bank.FetchNextPurchasableBankTabData`. Accurately recognizes purchased bank tabs (`numPurchasedBags = math.max(0, numPurchasedTabs - 1)`), correctly displaying previously bought bag slots as purchased rather than prompting to repurchase.
- **Native `CONFIRM_BUY_BANK_TAB` Purchase Flow**: Fixed nil error crash in `GameDialogDefs.lua` when confirming purchases. Replaced nonexistent `PurchaseSlot()` call with native `StaticPopup_Show("CONFIRM_BUY_BANK_TAB", nil, nil, { bankType = Enum.BankType.Character })`, correctly displaying dynamic cost and transacting via `C_Bank.PurchaseBankTab`.
- **Equipping and Viewing Bank Bags via `Characterbanktab`**: Mapped drawer bank bag sockets directly to container `Enum.BagIndex.Characterbanktab` (-2) at slots 2..7 (`bagSlotID = socketIndex + 1`), leveraging native `C_Container.PickupContainerItem` and `C_Container.GetContainerItemInfo` for bag equipping, dragging, and live item/icon/quality display.
- **Dynamic Bank Bag Updates**: Registered `BAG_CONTAINER_UPDATE` on hook frame to automatically refresh bank layout, drawer icons, and capacity titles immediately upon equipping or removing bank bags.

### Spin 0.0.7
- **Resolved Immediate Open/Close Loop**: Fixed bank and bags closing immediately upon opening. Eliminated `hiddenParent` reparenting and timer delays which were prematurely firing Blizzard's `BankFrameBaseMixin:OnHide` and calling `CloseBankFrame()`.
- **Eliminated `FetchMaxNumBankTabs` Nil Crash**: Fixed Lua error on subsequent banker interactions by keeping `BankPanel` intact and parented to `BankFrame`, ensuring `self:GetActiveBankType()` reliably returns `Enum.BankType.Character`.
- **Native `OnHide` Hook Suppression**: Followed BagBrother's `uiOverrides` pattern by temporarily disabling `BankFrame:GetScript("OnHide")` while `BankFrame` is suppressed in the persistent `tinyParent` frame (`scale 0.0001`, `alpha 0`), restoring it cleanly on actual session termination.
- **Removed Unknown Event Registration**: Removed non-existent event `PLAYERBANKBAGSLOTS_CHANGED` from `Hooks.lua` and `Core.lua`.

### Spin 0.0.6
- **Corrected Bank Bag Containers (5..11)**: Realigned bank bag IDs from erroneous 6..12 back to `{ 5, 6, 7, 8, 9, 10, 11 }`. Bank bag socket 1 corresponds directly to container 5 (inventory slot 68), resolving the issue where socket 1 showed the default bank box from container 6 (`CharacterBankTab_1`).
- **Equipping & Displaying Bank Bags**: Mapped bank bag sockets directly to inventory slots 68..74 via `BankButtonIDToInvSlotID(socketIndex, true)`. Players can equip bags by clicking or dragging onto drawer sockets without "No equipment slot available" errors, and equipped bags accurately display in the bank drawer.
- **Bagnon-Style Native BankFrame Suppression**: Implemented tiny-frame reparenting (`scale 0.0001`, `alpha 0`) and hidden parent hooks in `Hooks.lua` across `ShowUIPanel`, `UpdateUIPanelPositions`, `BankFrame_Open`, and bank interaction events so Blizzard's `BankFrame` is permanently suppressed.
- **Fixed Purchase Dialog & "Buy Slot" Button**: Rewired "Buy Slot" button using `UIPanelButtonTemplate` to invoke `PurchaseBankSlot()` directly, setting `BankFrame.nextSlotCost` so native confirmation dialog renders correct cost without opening `BankFrame`.
- **Eliminated Ghost 40-Slot Grid Container**: Removed unpurchased/empty containers from canvas layout so bank capacity displays cleanly.

### Spin 0.0.5
- **Suppressed Default BankFrame on Slot Purchase**: Permanently kept Blizzard's `BankFrame` invisible by setting `SetAlpha(0)`, hooking `UpdateUIPanelPositions`, and re-invoking `SuppressNativeBank()` on `BANK_TABS_CHANGED` and `PLAYERBANKSLOTS_CHANGED`.
- **Aligned Bank Bag Container Slots**: Updated container indices from `5..11` to `6..12` (`NUM_TOTAL_EQUIPPED_BAG_SLOTS + 1` through `NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS`), preventing container 5 (character reagent bag) from colliding with bank bag sockets.
- **Fixed Bag Equipping & Drag/Drop**: Solved `"No equipment slot is available for that item"` error by properly mapping bank bag equip and drag operations (`PutItemInBag` / `PickupBagFromSlot`) to valid bank bag equipment inventory slots (slots 68..74).
- **Equipped Bag Visibility & Quality Glows**: Added live detection of equipped bank bags via `GetInventoryItemTexture("player", invID)` and quality borders via `GetInventoryItemQuality`, accurately reflecting equipped containers in the bank drawer.
- **Purchased Slot Tracking via `GetNumBankSlots()`**: Aligned purchased slot counting and next slot cost queries with `GetNumBankSlots()` and `GetBankSlotCost()`, properly distinguishing unlocked bag slots from purchasable padlock slots.

### Spin 0.0.4
- Eliminated `ADDON_ACTION_FORBIDDEN` / `Forbidden function call: AddOn 'OneStorageBank' attempted to call 'PurchaseBankTab()'`.
- Inherited Blizzard's `BankPanelPurchaseButtonScriptTemplate` on `OneStorageBankBuySlotButton` with `overrideBankType = Enum.BankType.Character`, leveraging Blizzard's native XML `OnClick` script to trigger `CONFIRM_BUY_BANK_TAB` with zero Lua execution taint.
- Ensured the "Buy Slot" button is consistently visible and styled in the drawer, automatically disabling and displaying `"Maxed"` when all bank bag slots are purchased.
- Cleaned multi-client legacy code out of `Core.lua`, aligning runtime strictly and cleanly with WoW Forever Beta (v1.60.1 / Interface 16001).

### Spin 0.0.3
- Fixed banker interaction not opening the bank: Added `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` / `HIDE` handling for `Enum.PlayerInteractionType.Banker`, `CharacterBanker`, and `AccountBanker`, and hooked `BankFrame_Open`.
- Safely suppressed native `BankFrame` offscreen with zero alpha and mouse disabled without hiding it, preserving the active `C_Bank` server session.
- Implemented modern `C_Bank.PurchaseBankTab`, `C_Bank.FetchNextPurchasableBankTabData`, and native `CONFIRM_BUY_BANK_TAB` popup confirmation for bank bag purchasing on WoW Forever Beta (Camelot engine).
- Added `BANK_TABS_CHANGED`, `BANK_BAG_SLOT_FLAGS_UPDATED`, and `PLAYER_MONEY` event listeners for live dynamic bank bar updates.

### Spin 0.0.2
- Fixed bank bag slot purchase doing nothing by implementing the confirmation dialog (`ONE_STORAGE_BUY_BANK_SLOT`) with accurate cost pass-through.
- Wired unpurchased bank bag buttons in the drawer to directly trigger the slot purchase confirmation with detailed cost tooltips.
- Added dynamic button state to "Buy Slot" button: automatically disables and displays "Maxed" when all bank slots are purchased.
- Prevented options panel from resizing dynamically with main bank frame.

### Spin 0.0.1
- Master bank canvas window with Blizzard Metal borders and tab switching.
- Reagent bank integration with deposit-all reagents button.
- Real-time search filter with slot dimming.
- Bank bag purchasing drawer with slot cost calculator.
- Event hooks on `BANKFRAME_OPENED` and `BANKFRAME_CLOSED`.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **Offline Bank Cache**: Cache bank contents on close to enable browsing bank items away from a banker.
- [ ] **Item Quality Color Glows**: Render rarity border tints on bank slots.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Deposit All Reagents Quick Button**: Enhanced button in header for 1-click dumping of crafting materials.
- [ ] **Warband / Account Bank Tab**: Support for Warband bank tabs on Modern WoW 11.0+.

### Priority 3: Low Priority / Exploration
- [ ] **Bank Search Cross-Highlight**: Search query syncing with `OneStorageBag` so matching items highlight across both bags and bank simultaneously.

---

## 🧪 Testing & Verification Guide

- **Visit Banker**: Talk to a Banker NPC — confirm OneStorageBank opens automatically and default BankFrame is hidden.
- **Buy Slot**: Click "Buy Slot" or click an unpurchased bank bag slot — confirm confirmation popup appears with exact cost, and accepting purchases the slot and updates the UI.
- **Sub-Tabs**: Click "Reagents" tab — confirm view switches cleanly to reagent bank slots.
- **Bag Bar**: Click bank bag icon — confirm drawer opens and shows purchasable slots with costs.
- **Search**: Type item name in search — confirm matching items stay lit.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Bank Slot Access Outside Bank**: Querying bank item APIs when away from a Banker returns invalid results on older clients. View-only mode must use cached snapshot data when `BankFrame` is not open.
- **Slot Purchasing Confirmation**: In WoW, purchasing a bank slot requires `StaticPopup_Show` with slot cost data set before `PurchaseSlot()` can be transacted by the server.
