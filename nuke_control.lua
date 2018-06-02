local Event = require "utils.event"
local UserGroups = require "user_groups"
local Utils = require "utils.utils"

function allowed_to_nuke(player)
  if type(player) == "table" then
  return player.admin or UserGroups.is_regular(player.name) or ((player.online_time / 216000) > global.scenario.config.nuke_min_time_hours)
  elseif type(player) == "number" then
    return allowed_to_nuke(game.players[player])
  end
end

local function ammo_changed(event)
  local player = game.players[event.player_index]
    if allowed_to_nuke(player) then return end
  local nukes = player.remove_item({name="atomic-bomb", count=1000})
  if nukes > 0 then
    game.print(player.name .. " tried to use a nuke, but instead dropped it on his foot.")
    player.character.health = 0
  end
end

local function on_player_deconstructed_area(event)
  local player = game.players[event.player_index]
    if allowed_to_nuke(player) then return end
    local nukes = player.remove_item({name="deconstruction-planner", count=1000})

    --Make them think they arent noticed
    Utils.print_except(player.name .. " tried to deconstruct something, but instead deconstructed himself.", player)
    player.print("Only regulars can mark things for deconstruction, if you want to deconstruct something you may ask an admin to promote you.")

    player.character.health = 0
    local entities = player.surface.find_entities_filtered{area = event.area, force = player.force}
    if #entities > 1000 then
      Utils.print_admins("Warning! " .. player.name .. " just tried to deconstruct " .. tostring(#entities) .. " entities!")
    end
    for _,entity in pairs(entities) do
      if entity.valid and entity.to_be_deconstructed(game.players[event.player_index].force) then
        entity.cancel_deconstruction(game.players[event.player_index].force)
      end
    end
end

local function item_not_sanctioned(item)
  local name = item.name
  return (
    name:find("capsule") or
    name == "cliff-explosives" or
    name == "raw-fish" or
    name == "discharge-defense-remote"
  )
end

local function entity_allowed_to_bomb(e)
  local name = entity.name
  return (
    name:find("turret") or
    name:find("rail") or
    name.find("ghost") or
    name == "player" or
    name == "stone-wall" or
    entity.type == "electric-pole"
  )
end
global.players_warned = {}
local function on_capsule_used(event)
  if item_not_sanctioned(event.item) then return nil end
  local player = game.players[event.player_index]
  if (not allowed_to_nuke(player)) then
    local area = {{event.position.x-5, event.position.y-5}, {event.position.x+5, event.position.y+5}}
    local count = 0
    local entities = player.surface.find_entities_filtered{force=player.force, area=area}
    for _,e in pairs(entities) do
      if not entity_allowed_to_bomb(e) then count = count + 1 end
    end
    if count > 8 then
      if global.players_warned[event.player_index] then
        game.ban_player(player, string.format("Damaged %i entities with %s. This action was performed automatically. If you want to contest this ban please visit redmew.com/discord.", count, event.item.name))
      else
        global.players_warned[event.player_index] = true
        game.kick_player(player, string.format("Damaged %i entities with %s -Antigrief", count, event.item.name))
      end
    end
  end
end

Event.add(defines.events.on_player_ammo_inventory_changed, ammo_changed)
Event.add(defines.events.on_player_deconstructed_area, on_player_deconstructed_area)
--Event.add(defines.events.on_player_mined_entity, on_player_mined_item)
Event.add(defines.events.on_player_used_capsule, on_capsule_used)
