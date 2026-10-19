# Design Decisions

Decisions approved by the user, oldest first. Each entry has a date, the decision and the reason.

## 2026-10-19: Working title "Bonecrown"
- **Decision:** The game's working title is "Bonecrown".
- **Reason:** Not recorded.

## 2026-10-19: English everywhere
- **Decision:** In-game text, code, comments and docs are English. German names in the brief are working names and get translated when they are implemented.
- **Reason:** Not recorded.

## 2026-10-19: Every crit hits
- **Decision:** Every crit always hits, including a 19 in the Luck-extended crit range. A natural 20 additionally earns a special reward, and a natural 1 is an automatic miss with an additional special penalty.
- **Reason:** Not recorded.

## 2026-10-19: Natural 20 and natural 1 effects come later
- **Decision:** For now, natural 20 and natural 1 are only flagged on the attack roll. Their extra effects are decided once skills exist (milestone 5 or 6).
- **Reason:** The effects interact with skills such as Bloodlust and Riposte and with the Luck crit range, so they are easier to balance together.

## 2026-10-19: Natural 20 and natural 1 effects apply to enemies
- **Decision:** The extra effects of natural 20 and natural 1 apply to enemies as well as to the player.
- **Reason:** One rule for everyone is easier to follow, and it makes bosses a bit more dangerous.

## 2026-10-19: Crits roll twice as many damage dice
- **Decision:** A crit rolls twice as many damage dice as normal (longsword: 2d8 + bonus). The flat bonus is added once. "Double damage dice" means the same thing everywhere, for example for the power attack skill.
- **Reason:** This follows 5e and has less variance than doubling the rolled result. The average is the same.

## 2026-10-19: Every hit deals at least 1 damage
- **Decision:** A hit deals at least 1 damage after all modifiers.
- **Reason:** Damage reduction stays strong but can never cancel a hit completely. Otherwise a defensive build could become immune to weak enemies.

## 2026-10-19: Game data as Resource classes with .tres files
- **Decision:** Classes, items, enemies and all later content are `Resource` classes under `scripts/data/` with `.tres` instances.
- **Reason:** Typed fields catch wrong field names at load time, and the values can be edited in the Godot editor.

## 2026-10-19: Scope of milestone 3
- **Decision:** Milestone 3 has one fight against a single goblin, with only the Attack action. The Warrior's starting skills (Second Wind, Weapon Master), enemy groups and target selection follow in milestone 4.
- **Reason:** Second Wind needs the action bar from milestone 4, and target selection belongs to the battle scene built there.

## 2026-10-19: First English display names
- **Decision:** Warrior (`warrior`), Longsword (`longsword`, "Langschwert"), Chain Mail (`chain_mail`, "Kettenhemd") and Goblin (`goblin`). Reserved for milestone 4: Second Wind ("Zweiter Atem") and Weapon Master ("Waffenmeister").
- **Reason:** These are direct translations of the working names.
