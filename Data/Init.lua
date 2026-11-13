-- Professional built-in data tables (filled by the files that follow in the .toc)
CM_DATA = {
  recipes = {},      -- [profession] = { {n=name, s=spellId, l=learn, y=yellow, g=green, r=grey, i=item, rg={id,count,...}, ...}, ... }
  recipeItems = {},  -- [itemId] = { n=name, p=profession, v={[npc]=limit}, vp=price, d={[npc]=chance}, wd={min,max}, qu={quests}, ... }
  npcs = {},         -- [id] = "name|zone|x|y|faction|level"
  quests = {},       -- [id] = "name|minLevel|startNpc"
  objects = {},      -- [id] = "name|zone"
  zones = {},        -- [id] = "name"
  factions = {},     -- [id] = "name"
  items = {},        -- [id] = "name" ("|v" suffix = sold by vendors)
  ranks = {},
}
