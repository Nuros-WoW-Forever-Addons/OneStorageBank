# AI Context & Living Specification — OneStorageBank

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageBank
- **Current Version**: 0.0.3
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
- `Core.lua`: Master bank canvas creation, sub-tabs (`selectedTab`), button grid generation, search filter highlighter, bank bag purchase confirmation dialog (`CONFIRM_BUY_BANK_TAB` / `ONE_STORAGE_BUY_BANK_SLOT`) and routines using modern `C_Bank` + Classic `PurchaseSlot`, cleanup sorting, and slash commands (`/onebank`, `/osbank`).
- `Hooks.lua`: Intercepts native Blizzard bank frame events (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`, `BankFrame_Open`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`) and suppresses the default `BankFrame` safely offscreen.

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
