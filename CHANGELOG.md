# Changelog — OneStorageBank

All notable changes to **OneStorageBank** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
