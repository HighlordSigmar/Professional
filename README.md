# Professional

A profession window replacement for the 1.12 client (made for OctoWoW). It replaces the default trade skill and craft windows, and addons like TradeSkillWindow2, with one bigger window that has five tabs.

## Features

**Recipes**
- Every recipe you know, coloured by difficulty, grouped by category (headers fold), or sorted by difficulty, name or skill level
- Search by recipe name or reagent name, "Have mats" and "Skill-ups only" filters
- Detail pane: skill-up levels (orange / yellow / green / grey) and your chance of a point, reagents with counts in bags, bank and on alts, tools, cooldowns
- Create, Create All, a craft count, and Add to queue
- Shift-click to link, Ctrl-click to preview, right-click to queue one

**Missing**
- Every recipe of the profession you don't know yet, with where to get it: trainers (with zone and coordinates), vendors (price, limited stock), drops (mob, level, drop chance), world drops, quests, reputation and seasonal events
- Colour shows if you can learn it now, soon, later, or if something blocks it (specialization, class, level)
- Filters: learnable now, source type, other faction

**Skill-up**
- The best recipes you already know for skill points at your current skill
- A leveling plan from your skill to any target: which recipe to craft for each stretch, about how many crafts, where to train the next rank, total learning cost and total reagents
- Options to use vendor recipes and drop / quest / reputation recipes
- Queue one step or the whole plan

**Queue & Shopping**
- A craft queue per character; "Craft next" crafts the first queued recipe the open window can make
- Shopping list of every reagent the queue needs, compared with your bags (and bank), with hints when a vendor sells it or when you can craft it yourself
- Click a reagent to see which alts hold it

**Alts**
- All your characters on the realm with their professions, skill and recipe counts
- "Who can craft..." search across all characters
- Browse any alt's recipes or missing recipes

**Tooltips**
- Recipe items show which of your characters already know them, can learn them now, or need more skill
- Reagents show which professions use them, what your queue needs, and how many each alt holds

## Recipe data

Professional ships with the full vanilla recipe list for Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Leatherworking, Mining (smelting), Poisons and Tailoring: learn levels, skill-up levels, reagents and sources.

It also learns as you play. It records recipes and sources it doesn't know when you visit trainers and vendors and when you loot recipe items, and it saves every recipe it sees in a profession window, account-wide. That covers custom OctoWoW recipes and professions, and lets alts see recipes found by your other characters.

## Commands

- `/prof` or `/professional`: open or close the window
- `/prof blizzard`: switch between Professional and the default profession windows
- `/prof scale 0.9`, `/prof reset`: window size and position
- `/prof tooltip`: recipe info in tooltips on/off
- `/prof alts`: alt item counts in tooltips on/off
- `/prof delete Name`: forget a character
- `/prof forget`: clear recipe sources recorded while playing

## Install

Put the `Professional` folder in `Interface\AddOns`, or add this repository's GitHub link to the Wuddle launcher. Turn off TradeSkillWindow2, Missing Crafts or any other profession window addon so they don't both try to replace the window.

Log in on each character and open each profession once so Professional can read what they know. Visit a bank once per character to include bank items.

## Credits

The built-in data was compiled from these projects: MissingTradeSkillsList (recipe sources, trainers, learn levels), TradeskillInfo (reagents, skill-up levels), Skillet-Classic (skill-up levels for recipes TradeskillInfo lacks) and pfQuest (NPC locations, vendor stock, drop chances and names; MIT licence).
