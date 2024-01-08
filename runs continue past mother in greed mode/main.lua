local mod = RegisterMod('Runs Continue Past Mother in Greed Mode', 1)
local game = Game()

-- some of this is re-implemented from the cathedral in greed mode
mod.cath = nil -- nil, false, true
mod.timer = 0

function mod:onGameExit()
  mod.cath = nil
  mod.timer = 0
end

function mod:onNewRoom()
  if game:IsGreedMode() and not mod:isAnyChallenge() then
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local stage = level:GetStage()
    local stageType = level:GetStageType()
    
    if level:GetCurrentRoomIndex() == level:GetStartingRoomIndex() and room:IsFirstVisit() and mod:getCurrentDimension() == 0 and
       stage == LevelStage.STAGE5_GREED and stageType == StageType.STAGETYPE_ORIGINAL
    then
      if mod.cath == false then -- sheol
        mod.cath = nil
        -- corpse seed is re-used when going from corpse to sheol/cathedral
        -- it feels bad to play the same seed two floors in a row
        Isaac.ExecuteCommand('reseed')
      elseif mod.cath == true then -- cathedral
        mod.cath = nil
        Isaac.ExecuteCommand('stage 5a')
        Isaac.ExecuteCommand('reseed')
        mod.timer = 4
      end
    end
    
    mod.cath = nil
  end
end

-- filtered to PICKUP_BIGCHEST
function mod:onPickupInit(pickup)
  if game:IsGreedMode() and not mod:isAnyChallenge() and mod:isMother() then
    local room = game:GetRoom()
    local trapdoorIdx = 36
    local heavenDoorIdx = 38
    
    for _, v in ipairs(Isaac.FindByType(EntityType.ENTITY_MOTHER, 0, -1, false, false)) do
      -- v.Color on the head also affects the hands
      -- sprite.Color allows us to set everything separately
      local sprite = v:GetSprite()
      
      if v.SubType == 0 or v.SubType == 1 then -- head/body
        sprite.Color = Color(1, 1, 1, 0, 0, 0, 0) -- invisible
      end
    end
    
    local trapdoor = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, room:GetGridPosition(trapdoorIdx), true)
    if trapdoor:GetType() ~= GridEntityType.GRID_TRAPDOOR then
      mod:removeGridEntity(trapdoorIdx, 0, false, true)
      Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, room:GetGridPosition(trapdoorIdx), true)
    end
    
    if gcath then
      Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, room:GetGridPosition(heavenDoorIdx), Vector.Zero, nil)
    else
      Isaac.GridSpawn(GridEntityType.GRID_SPIDERWEB, 0, room:GetGridPosition(heavenDoorIdx), true)
    end
  end
end

function mod:onPlayerUpdate(player)
  if game:IsGreedMode() and not mod:isAnyChallenge() then
    if mod:isMother() then
      if game:IsPaused() and mod.cath == nil then
        local room = game:GetRoom()
        local sprite = player:GetSprite()
        local playerIdx = room:GetGridIndex(player.Position)
        
        if sprite:IsPlaying('Trapdoor') then
          local gridEntity = room:GetGridEntity(playerIdx)
          if gridEntity and gridEntity:GetType() == GridEntityType.GRID_TRAPDOOR then
            mod.cath = false
          end
        elseif sprite:IsPlaying('LightTravel') then
          for _, v in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, false, false)) do
            if playerIdx == room:GetGridIndex(v.Position) then
              mod.cath = true
              break
            end
          end
        end
      end
    else
      if mod.timer == 1 then
        local hud = game:GetHUD()
        local level = game:GetLevel()
        local levelName = 'Cathedral'
        local curseName = level:GetCurseName()
        
        if curseName ~= '' then
          hud:ShowItemText(levelName, curseName, true)
        else
          hud:ShowItemText(levelName, nil, false)
        end
      end
      
      if mod.timer > 0 then
        mod.timer = mod.timer - 1
      end
    end
  end
end

function mod:removeGridEntity(gridIdx, pathTrail, keepDecoration, update)
  local room = game:GetRoom()
  
  if REPENTOGON then
    room:RemoveGridEntityImmediate(gridIdx, pathTrail, keepDecoration)
  else
    room:RemoveGridEntity(gridIdx, pathTrail, keepDecoration)
    if update then
      room:Update()
    end
  end
end

function mod:getCurrentDimension()
  local level = game:GetLevel()
  return mod:getDimension(level:GetCurrentRoomDesc())
end

function mod:getDimension(roomDesc)
  local level = game:GetLevel()
  local ptrHash = GetPtrHash(roomDesc)
  
  -- 0: main dimension
  -- 1: secondary dimension, used by downpour mirror dimension and mines escape sequence
  -- 2: death certificate dimension
  for i = 0, 2 do
    if ptrHash == GetPtrHash(level:GetRoomByIdx(roomDesc.SafeGridIndex, i)) then
      return i
    end
  end
  
  return -1
end

-- otherwise you still see the boss bar for a second when you go to sheol/cathedral which looks weird
function mod:doEnhancedBossBarsOverride()
  if not HPBars then
    return
  end
  
  local ignoreMotherOld = HPBars.BossIgnoreList['912.0'] -- mother
  
  if type(ignoreMotherOld) == 'function' then
    HPBars.BossIgnoreList['912.0'] = function(entity)
      -- IsFinished lines up with dropping the chest, otherwise you can use GetAnimation
      if game:IsGreedMode() and entity:GetSprite():IsFinished('Death') then
        return true
      end
      
      return ignoreMotherOld(entity)
    end
  end
end

-- greed mother
function mod:isMother()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  
  return stage == LevelStage.STAGE4_GREED and
         (stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B) and
         roomDesc.Data.Type == RoomType.ROOM_BOSS and
         roomDesc.Data.Shape == RoomShape.ROOMSHAPE_1x1 and
         roomDesc.Data.Variant == 6000 and
         roomDesc.Data.Name == 'Mother' and
         roomDesc.GridIndex == GridRooms.ROOM_DEBUG_IDX
end

function mod:isAnyChallenge()
  return Isaac.GetChallenge() ~= Challenge.CHALLENGE_NULL
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_BIGCHEST)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.onPlayerUpdate)

mod:doEnhancedBossBarsOverride()