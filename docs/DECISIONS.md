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

## 2026-10-19: Skills are SkillData resources built from effects
- **Decision:** A skill is a `SkillData` resource with `id`, `display_name`, `description`, `activation` (`PASSIVE` or `ACTIVE`), `action_cost` (`ACTION` or `FREE`, only for active skills), `uses_per_fight` (0 means unlimited) and a list of `effects`. Effects are `EffectData` building blocks, one subclass per effect type, and their rules live in `scripts/core/`. The first types are `StatModifierEffect` (`ATTACK`, `MELEE_DAMAGE`, `ARMOR_CLASS`) and `HealEffect`. Tiers, categories, conditions, cooldowns and triggers are added later as new fields or new effect types.
- **Reason:** Most new skills are pure data, and only genuinely new mechanics need a new effect type. Rejected: one script per skill (puts logic into content) and one flat `SkillData` with every possible field (unwieldy for 66+ skills).

## 2026-10-19: Second Wind is once per fight
- **Decision:** The brief's "once per room" for Second Wind is implemented as once per fight.
- **Reason:** Every room has exactly one fight.

## 2026-10-19: Second Wind is a free action
- **Decision:** Second Wind heals 1d10 + level and does not use the turn, so the player can still attack afterwards (like a 5e bonus action).
- **Reason:** It keeps the 5e model, and the player's choice is about timing. A simulation of 200,000 fights (Warrior with Weapon Master and Second Wind against two goblins) gave 87% wins with Second Wind as a free action and 79% if it cost the turn.

## 2026-10-19: Two goblins as placeholder encounter
- **Decision:** Milestone 4 uses a placeholder encounter of two goblins, named "Goblin 1" and "Goblin 2", until the room sequence of milestone 7.
- **Reason:** It makes target selection playable. Room 1 is temporarily hard (about 13% defeats in the simulation). Balancing follows in milestones 7 and 12.

## 2026-10-19: Target selection by marking an enemy
- **Decision:** Clicking an enemy marks it, and Attack hits the marked enemy. At the start of a fight the first living enemy is marked. When the marked enemy is defeated, the next living enemy is marked automatically.
- **Reason:** Follow-up attacks need fewer clicks than with "choose the action first, then the target".

## 2026-10-19: Texts of the starting skills
- **Decision:** Second Wind: "Once per fight, heal 1d10 + your level. Does not use your turn." Weapon Master: "+1 damage with melee weapons."
- **Reason:** These are direct translations of the brief's working texts.

## 2026-10-19: Fullscreen at the screen's resolution by default
- **Decision:** The game starts in borderless fullscreen at the screen's native resolution instead of a 1280x720 window. The UI is still designed for 1280x720 and scales to the screen; on screens that are not 16:9 the container layouts expand to fill the screen.
- **Reason:** Like in most other games, the default follows the screen settings.

## 2026-10-19: Choice fields in data default to UNSET
- **Decision:** Every enum field in the data classes (for example `SkillData.activation`, `SkillData.action_cost`, `StatModifierEffect.stat`) gets an extra member `UNSET = -1` as its default. The data test reports any content that leaves a required choice on `UNSET`.
- **Reason:** Godot omits values equal to the default from `.tres` files. With a neutral default every real value is written explicitly, and a later change of a default cannot silently shift content.
