# LookingFor — Product Requirements Document

**Version:** 1.0.0
**Author:** metinmayi
**Date:** 2026-05-24
**Status:** v1 implemented

## 1. Purpose

A World of Warcraft (retail) addon that plays a sound alert when an applicant of a chosen class signs up to the user's active Premade Group Finder listing. Targets group leaders who are leading their own listings and need an audible signal that a player of interest has applied, so they can shift attention back to the LFG window without continuously watching it.

## 2. Problem statement

When hosting an LFG listing in WoW, applicants can arrive at any time — sometimes minutes apart, sometimes in bursts. Leaders typically AFK or alt-tab while waiting, missing fast-acting applicants of the role/class they need. The default UI offers no audible filtered notification: it merely updates the applicant list silently. A leader wanting "any healer" or "any mage" has to keep visual attention on the LFG window.

## 3. Goals and non-goals

### Goals (v1)
- Play a single in-game sound when a new applicant of a user-selected class signs up.
- Per-character class selection persisted across sessions.
- Zero-config default behavior: addon enabled out of the box, all class toggles off.
- Minimal UI surface — one Blizzard interface options panel, one slash command.

### Non-goals (v1)
- Spec-level filtering (Holy Paladin vs Ret Paladin).
- Role-level filtering (Tank/Healer/DPS).
- Item-level / Mythic+ score thresholds.
- Configurable sound choice or volume.
- Per-class sound differentiation.
- Localization beyond English.
- Account-wide / cross-character profile sharing.
- Dungeon Finder / Raid Finder / PvP queue integration (Premade Group Finder only).
- Visual notifications (toast, flash, chat message).
- Notifications for applicants joining listings the user is a *member* of (only listings they *own*).

## 4. Users and scenarios

**Primary user:** WoW retail player leading their own Premade Group Finder listing.

**Scenario A — Tank seeking healer.**
User creates a Mythic+ listing as tank. Ticks "Priest, Druid, Monk, Paladin, Evoker, Shaman" in LookingFor. Tabs out to read patch notes. A holy paladin applies → sound plays → user tabs back and invites.

**Scenario B — Raid leader filling a specific class need.**
User creates a normal raid listing missing a warlock. Ticks only "Warlock". Three groups apply with no warlock — no sound. A warlock-containing group applies → sound plays.

**Scenario C — Listing turnover.**
User cancels the listing and creates a new one. Previously-seen applicants are forgotten; new applicants to the new listing trigger sounds normally.

## 5. Functional requirements

### 5.1 Filtering
- F1. The addon SHALL detect new applicants to the user's currently active LFG listing.
- F2. The addon SHALL match applicants on the locale-independent class token (e.g. `WARRIOR`, `DEATHKNIGHT`) returned by `C_LFGList.GetApplicantMemberInfo`.
- F3. An application matches if **any** of its 1–5 group members is of a class the user has selected.
- F4. The addon SHALL support all 13 retail classes: Death Knight, Demon Hunter, Druid, Evoker, Hunter, Mage, Monk, Paladin, Priest, Rogue, Shaman, Warlock, Warrior.

### 5.2 Sound
- F5. The addon SHALL play `PlaySound(8959)` (Ready Check) on a match.
- F6. The addon SHALL throttle to one sound per 1.5 seconds (coalesce window) regardless of match count.

### 5.3 Application tracking
- F7. The addon SHALL track applicant IDs already alerted on within the current listing instance.
- F8. The addon SHALL clear the seen-set when `C_LFGList.HasActiveEntryInfo()` returns false (listing ended/cancelled/expired).
- F9. On `/reload` or login mid-listing, the addon SHALL mark all currently-listed applicants as seen (silent), so only post-reload arrivals trigger sounds.

### 5.4 Configuration UI
- F10. The addon SHALL expose a Blizzard interface options panel under the Settings menu.
- F11. The panel SHALL contain:
  - A master "Enable alerts" toggle (boolean, full width).
  - A grouped block of 13 class toggles (alphabetical, two-column).
  - A "Test sound" execute button.
- F12. The slash command `/lookingfor` SHALL open the panel.
- F13. When the master toggle is off, no sounds SHALL play regardless of class selections.

### 5.5 Persistence
- F14. Settings SHALL be persisted per character via WoW SavedVariables and AceDB `char` namespace.
- F15. Default class selections SHALL all be `false` on first run; master toggle SHALL default to `true`.

## 6. Non-functional requirements

- N1. Addon SHALL declare `Ace3` as a required dependency in its TOC.
- N2. Addon SHALL load cleanly on retail patch matching `## Interface: 120005`.
- N3. Total source footprint SHALL remain a single `Core.lua` file plus TOC (~150 lines).
- N4. Addon SHALL produce zero output to default chat unless the user invokes a slash command.
- N5. Event handlers SHALL be safe to call when no active listing exists (early return).

## 7. Technical design

### 7.1 Framework
Ace3 subset, loaded via `LibStub`:
- `AceAddon-3.0` — lifecycle (`OnInitialize`, `OnEnable`)
- `AceEvent-3.0` — event mixin
- `AceConsole-3.0` — slash command registration
- `AceDB-3.0` — SavedVariables management with `char` namespace
- `AceConfig-3.0` + `AceConfigDialog-3.0` — declarative options table → Blizzard panel
- `AceGUI-3.0` — transitively required by AceConfigDialog

### 7.2 WoW API touchpoints
- Events: `LFG_LIST_APPLICANT_LIST_UPDATED`, `LFG_LIST_ACTIVE_ENTRY_UPDATE`
- Queries: `C_LFGList.HasActiveEntryInfo`, `C_LFGList.GetApplicants`, `C_LFGList.GetApplicantInfo` (struct form), `C_LFGList.GetApplicantMemberInfo`
- Sound: `PlaySound(8959)`
- Settings panel: `Settings.OpenToCategory` (retail Settings API)

### 7.3 Data model
```lua
LookingForDB = {
  char = {
    <characterKey> = {
      enabled = true,
      classes = {
        WARRIOR = false, MAGE = true, ...  -- 13 entries
      },
    },
  },
}
```

### 7.4 File layout
```
LookingFor/
├── LookingFor.toc
├── Core.lua
└── PRD.md           (this document)
```

## 8. Out-of-scope deferred features (v2 candidates)

- Spec-level filtering (4× larger config surface).
- Configurable sound via LibSharedMedia-3.0.
- Per-class sound differentiation.
- Group-composition matching (e.g. "alert only if applicant group fills two slots I need").
- Item-level / score thresholds.
- Localization via AceLocale-3.0.
- Profile system (account-wide, copy-from-character) via AceDBOptions-3.0.

## 9. Open questions

- Retail Interface version drift: TOC will need bumping each patch cycle. No automated mechanism in v1.
- `Settings.OpenToCategory` API stability: Blizzard refactored the settings system in Dragonflight; further refactors could break the slash-command panel-open behavior.

## 10. Acceptance criteria

- [ ] Addon loads with no Lua errors on a current-retail client with Ace3 installed.
- [ ] `/lookingfor` opens the LookingFor options panel.
- [ ] Toggling class checkboxes persists across `/reload` and re-login on the same character.
- [ ] Different characters maintain independent class selections.
- [ ] "Test sound" button plays Ready Check sound.
- [ ] Creating a listing and receiving a new application of a ticked class plays the sound exactly once.
- [ ] Receiving a new application of an unticked class plays no sound.
- [ ] Receiving 3 matching applications within 0.5s plays exactly one sound.
- [ ] Cancelling and recreating a listing resets seen-tracking (sounds fire for new applicants).
- [ ] Master toggle off → no sound on any match.
