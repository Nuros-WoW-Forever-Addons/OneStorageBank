# Changelog — OneStorageBank

All notable changes to **OneStorageBank** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.5] - 2026-10-15
### Fixed
- **Native BankFrame Suppression on Slot Purchase**: Permanently suppressed Blizzard's default UI `BankFrame` by setting `SetAlpha(0)`, hooking `UpdateUIPanelPositions`, and re-suppressing on `BANK_TABS_CHANGED` and `PLAYERBANKSLOTS_CHANGED` so the native frame never pops up when accepting slot purchases.
- **Bank Bag Container Slot Alignment**: Corrected bank bag container indices from `5..11` to `6..12` (`NUM_TOTAL_EQUIPPED_BAG_SLOTS + 1` through `NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS`), preventing container 5 (player reagent bag) from colliding with bank bag sockets.
- **Equipping & Swapping Bank Bags**: Resolved `"No equipment slot is available for that item"` error by properly routing bank bag equip and drag operations (`PutItemInBag` / `PickupBagFromSlot`) to valid bank bag equipment inventory slots (slots 68..74).
- **Equipped Bag Visibility & Quality Glows**: Added live detection of equipped bank bags via `GetInventoryItemTexture("player", invID)` and quality borders via `GetInventoryItemQuality`, accurately reflecting equipped containers in the bank drawer.
- **Purchased Slot Tracking via `GetNumBankSlots()`**: Aligned purchased slot counting and next slot cost queries with `GetNumBankSlots()` and `GetBankSlotCost()`, properly distinguishing unlocked bag slots from purchasable padlock slots.

---

## [0.0.4] - 2026-10-15
### Fixed
- **Bank Slot Purchase Execution Taint (`ADDON_ACTION_FORBIDDEN`)**: Eliminated the Lua error `Forbidden function call: AddOn 'OneStorageBank' attempted to call 'PurchaseBankTab()'` caused by third-party execution taint on `StaticPopup_Show("CONFIRM_BUY_BANK_TAB")`.
- **Native Blizzard Button Template Integration**: Implemented Blizzard's `BankPanelPurchaseButtonScriptTemplate` on the "Buy Slot" button in the bank drawer (`OneStorageBankBuySlotButton`) with `overrideBankType = Enum.BankType.Character`, allowing user hardware clicks to trigger the native `CONFIRM_BUY_BANK_TAB` static popup without third-party Lua taint.
- **Drawer Buy Slot Button Visibility**: Ensured the "Buy Slot" button is consistently visible and styled in the drawer, dynamically toggling to `"Maxed"` (disabled) when all bank bag slots are purchased.
- **Strict WoW Forever Beta Runtime Alignment**: Removed multi-client legacy fallback bloat, aligning runtime code strictly with Interface 16001 and Camelot `C_Bank` APIs.

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
