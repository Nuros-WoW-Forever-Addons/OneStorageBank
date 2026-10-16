# Changelog — OneStorageBank

All notable changes to **OneStorageBank** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.4] - 2026-10-15
### Fixed
- **Bank Slot Purchase Execution Taint (`ADDON_ACTION_FORBIDDEN`)**: Eliminated the Lua error `Forbidden function call: AddOn 'OneStorageBank' attempted to call 'PurchaseBankTab()'` caused by third-party execution taint on `StaticPopup_Show("CONFIRM_BUY_BANK_TAB")`.
- **Untainted Native Blizzard Button Delegation**: Dynamically anchors Blizzard's native `BankFrame.BankPanel.PurchaseButton` directly onto `OneStorageBankBar` in the drawer without reparenting, preserving Blizzard's native untainted execution context when clicked.
- **Offscreen BankFrame Transparency**: Removed `SetAlpha(0)` on `BankFrame` to allow child elements anchored to our drawer to render at full opacity while `BankFrame` remains invisible offscreen at `(2000, 2000)`.
- **Drawer & Tab Synchronization**: Properly manages native purchase button visibility across bag bar drawer toggle, tab switches (Main Bank vs. Reagents), and window hide/close events.

---

## [0.0.3] - 2026-10-14
### Fixed
- **Banker NPC Interaction**: Resolved issue where interacting with a banker NPC did nothing. Integrated modern `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` / `HIDE` handlers for `Banker`, `CharacterBanker`, and `AccountBanker`, hooked `BankFrame_Open`, and safely suppressed native `BankFrame` offscreen with zero alpha and mouse disabled without prematurely terminating the session.
- **Camelot `C_Bank` Purchase Engine**: Wired bank tab/slot purchasing to modern `C_Bank.PurchaseBankTab`, `C_Bank.FetchNextPurchasableBankTabData`, and native `CONFIRM_BUY_BANK_TAB` popup dialog (with Classic `GetNumBankSlots` / `PurchaseSlot` fallback).
- **Dynamic Bank Bag Bar Synchronization**: Registered `BANK_TABS_CHANGED`, `BANK_BAG_SLOT_FLAGS_UPDATED`, and `PLAYER_MONEY` to automatically re-evaluate purchased bank slots, capacities, and costs in real time.

---

## [0.0.2] - 2026-10-14
### Fixed
- **Bank Bag Slot Purchasing**: Fixed bank slot purchase button doing nothing by implementing the confirmation dialog (`ONE_STORAGE_BUY_BANK_SLOT`), passing accurate slot costs, and wiring both the "Buy Slot" button and unpurchased bag slot icons directly to the purchase workflow.
- **Bank Slot Capacity State**: "Buy Slot" button now updates dynamically to "Maxed" and disables when all bank bag slots are purchased.
- **Unpurchased Slot Interaction**: Clicking unpurchased bank bag slots in the drawer now initiates the purchase confirmation flow with interactive cost tooltips.

---

## [0.0.1] - 2026-10-10
### Added
- **Unified Master Bank Window**: Consolidated bank container interface with Blizzard Metal theming.
- **Sub-Tab Navigation**: Clean switching between Main Bank and Reagent Bank tabs.
- **Search Filtering Engine**: Real-time slot search with visual opacity dimming.
- **Bank Bag Slot Purchasing**: Drawer displaying purchasable bank bag slots and costs.
- **Interaction Hooks**: Event listeners for `BANKFRAME_OPENED` and `BANKFRAME_CLOSED`.
