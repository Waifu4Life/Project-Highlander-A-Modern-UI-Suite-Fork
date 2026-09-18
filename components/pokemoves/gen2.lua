-- Field learning uses the native Gen 2 dialogue/selection sequence (0.2.56).
return function(mod)
  local function on(key) return mod.options:enabled() and mod.options:get(key)==true end
  local Game2=require("src.core.Game2")
  local Screens=require("src.ui.Screens")
  local Strings=require("src.core.Strings")
  local TextBox=require("src.render.TextBox")
  local ModRuntime=require("src.mods.Runtime")
  local HM_MOVES={CUT=true,FLY=true,SURF=true,STRENGTH=true,FLASH=true,WATERFALL=true,WHIRLPOOL=true}
local function learnMoveOn(self, mon, moveId, onDone)
  local Mon = require("src.battle.gen2.Mon")
  local moveDef = (self.data.moves or {})[moveId]
  local moveName = (moveDef and moveDef.name) or moveId
  local name = mon.nickname or mon.name or mon.species or "?"
  local ok, reason, entry = Mon.learnMove(mon, moveId, self.data)
  local function finish(learned)
    if onDone then onDone(learned) end
  end
  if ok then
    -- data/text/common_3.asm:119
    return self:say(Strings("%s learned\n%s!", name, moveName),
      function() finish(true) end,
      TextBox.soundOpts(self, "Sfx_DexFanfare5079"))
  end
  if reason ~= "full" then return finish(false) end
  local askForget, pickMove, askStop
  -- DidNotLearnMoveText, then `ld b, 0` (learn.asm:110-113).
  local function decline()
    self:say(Strings("%s\ndid not learn\v%s.", name, moveName),
      function() finish(false) end)
  end
  -- ForgetMove's AskForgetMoveText + YesNoBox (learn.asm:123-127).
  askForget = function()
    self.stack:push(TextBox.new(self,
      Strings("%s is\ntrying to learn\v%s.\fBut %s\ncan't learn more\vthan four moves.\fDelete an older\nmove to make room\vfor %s?",
        name, moveName, name, moveName),
      nil, { choice = function(yes)
        if yes then return pickMove() end
        return askStop()
      end }))
  end
  -- StopLearningMoveText, whose NO is `jp c, .loop` (learn.asm:104-108).
  askStop = function()
    self.stack:push(TextBox.new(self,
      Strings("Stop learning\n%s?", moveName), nil,
      { choice = function(yes)
        if yes then return decline() end
        return askForget()
      end }))
  end
  -- engine/pokemon/learn.asm:135-166
  local function pushList()
    Screens.push(self, "Gen2MoveDeleter", {
      mon = mon,
      moves = self.data.moves,
      layout = "forget",
      onCancel = function()
        self.stack:pop() -- the move list
        self.stack:pop() -- the question it stood on
        askStop()
      end,
      onChoose = function(slot)
        local old = mon.moves[slot]
        self.stack:pop() -- the move list
        -- MoveCantForgetHMText, then `jr .loop` (learn.asm:183-197): the
        -- question stays up and the list comes back over it.
        if old and HM_MOVES[old.id] and not on("forgettable_hms") then
          return self:say(Strings("HM moves can't be\nforgotten now."), pushList)
        end
        self.stack:pop() -- the question the list stood on
        local oldDef = (self.data.moves or {})[old and old.id]
        local oldName = (oldDef and oldDef.name) or (old and old.id) or "?"
        mon.moves[slot] = entry
        -- The slot is written here rather than through Mon.learnMove, so
        -- pokemon.move_learned is raised here too.
        ModRuntime.emit("pokemon.move_learned", { mon = mon, moveId = moveId })
        -- engine/pokemon/learn.asm:225-229, data/text/common_3.asm:165-173
        self:say(Strings("1, 2 and…\1 Poof!\1\f%s forgot\n%s.\fAnd…\f%s learned\n%s!",
            name, oldName, name, moveName),
          function() finish(true) end,
          TextBox.soundOpts(self, "Sfx_DexFanfare5079",
            { pauseSounds = { "Sfx_SwitchPokemon" } }))
      end,
    })
  end
  -- MoveAskForgetText, a `done` text: the box stays while the list stands on
  -- it (learn.asm:136-137).
  pickMove = function()
    self.stack:push(TextBox.new(self, Strings("Which move should\nbe forgotten?"), nil,
      { stay = { onShown = pushList } }))
  end
  askForget()
end

  local originalLearn=Game2.learnMoveOn
  Game2.learnMoveOn=function(self,...)
    if on("forgettable_hms") then return learnMoveOn(self,...) end
    return originalLearn(self,...)
  end
  local consume=Game2.consumeItem
  if consume then Game2.consumeItem=function(self,id,...)
    if on("tms_forever") and type(id)=="string" and id:match("^TM_") then return true end
    return consume(self,id,...)
  end end
  local Battle=require("src.ui.gen2.BattleState")
  local update=Battle.update
  Battle.update=function(self,...)
    local input=self.game.input
    if on("forgettable_hms") and self.phase=="choose-forget"
        and (self.messageTimer or 0)<=0 and input:wasPressed("a")
        and not input:wasPressed("b") and not input:wasPressed("up") and not input:wasPressed("down") then
      local learn=self.pendingLearn
      local mon=learn and self.battle.party[learn.index]
      local slot=mon and mon.moves[self.forgetIndex]
      if slot and HM_MOVES[slot.id] then
        self.battle:resolveForget(learn.index,self.forgetIndex,learn.move,learn.moveName)
        self.pendingLearn=nil;self.phase="resolving"
        self:pushFront(self.battle:takeEvents());self:advanceQueue()
        return
      end
    end
    return update(self,...)
  end
  -- Gen 2 already has contextual A field moves; add the SELECT utility list
  -- through its native registered-item action, after its standing/busy gates.
  pcall(function()
    if Game2._suiteSkipHmSay or type(Game2.say)~="function" then return end
    Game2._suiteSkipHmSay=true
    local say=Game2.say
    local flavor={CUT=true,SURF=true,STRENGTH=true,FLASH=true,FLY=true,
      WHIRLPOOL=true,WATERFALL=true,DIG=true,TELEPORT=true,
      HEADBUTT=true,["ROCK SMASH"]=true,ROCK_SMASH=true,["SWEET SCENT"]=true}
    local function isFlavor(text)
      local s=tostring(text or ""):upper()
      if type(text)=="table" then
        local parts={}
        for _,row in ipairs(text) do parts[#parts+1]=tostring(row) end
        s=table.concat(parts," "):upper()
      end
      s=s:gsub("[\nvrft]"," ")
      return s:find("HEADBUTT",1,true) or s:find("ROCK SMASH",1,true)
        or s:find("ROCKSMASH",1,true) or s:find("CUT",1,true)
        or s:find("SURF",1,true) or s:find("STRENGTH",1,true)
        or s:find("FLASH",1,true) or s:find("WHIRLPOOL",1,true)
        or s:find("WATERFALL",1,true) or s:find("SWEET SCENT",1,true)
    end
    function Game2:say(text,onDone,opts)
      local s=tostring(text or ""):upper()
      local rock=s:find("ROCK SMASH",1,true) or s:find("ROCKSMASH",1,true)
      if on("instant_tmhm") and isFlavor(text) and not rock then
        local choice=type(opts)=="table" and opts.choice
        if type(choice)=="function" then pcall(choice,true) end
        if type(onDone)=="function" then pcall(onDone) end
        return self
      end
      return say(self,text,onDone,opts)
    end
  end)
  local selectMenu=Game2.useSelectItem
  if selectMenu then Game2.useSelectItem=function(self,...)
    if not on("instant_tmhm") then return selectMenu(self,...) end
    local F=require("src.world.gen2.FieldMoves")
    local world=self.world
    if not world or world:busy() or world.battleActive then return selectMenu(self,...) end
    local items={}
    local labels={
      SWEET_SCENT="SWEET SCENT", SWEETSCENT="SWEET SCENT",
      ROCK_SMASH="ROCK SMASH", ROCKSMASH="ROCK SMASH",
    }
    local function addMove(move)
      local mon=F.partyMoveUser(self.save.party,move,world:fieldContext())
      if not mon then return end
      items[#items+1]={label=labels[move] or move,onSelect=function()
        world:useFieldMove(move,mon)
      end}
    end
    for _,move in ipairs({
      "FLASH","FLY","DIG","TELEPORT",
      "SWEET_SCENT","SWEETSCENT",
    }) do
      addMove(move)
    end
    -- Drop duplicate labels if both SWEET_SCENT and SWEETSCENT resolved.
    local seen={}
    local uniq={}
    for _,row in ipairs(items) do
      if not seen[row.label] then
        seen[row.label]=true
        uniq[#uniq+1]=row
      end
    end
    items=uniq
    if #items==0 then return selectMenu(self,...) end
    items[#items+1]={label="CANCEL"}
    local widest=6
    for _,row in ipairs(items) do
      widest=math.max(widest,#tostring(row.label or ""))
    end
    self.stack:push(require("src.ui.Menu").new(self,items,{
      tx=6, ty=1, tw=widest+2, th=#items*2+2,
    }))
  end end
  pcall(function()
    local F=require("src.world.gen2.FieldMoves")
    if type(F)~="table" or type(F.partyMoveUser)~="function" or F._suiteNoLearnField then return end
    F._suiteNoLearnField=true
    local orig=F.partyMoveUser
    function F.partyMoveUser(party,move,ctx)
      local mon=orig(party,move,ctx)
      if mon then return mon end
      if not on("no_learn_hms") then return nil end
      local game=require("src.core.Game")
      if type(mod.exports.firstLearner)=="function" then
        return mod.exports.firstLearner(game.data, game.save, move)
      end
      return nil
    end
  end)

  pcall(function()
    if Game2._suiteSmashSkip then return end
    Game2._suiteSmashSkip=true
    local function boxText(top)
      if type(top)~="table" then return "" end
      for _,k in ipairs({"text","str","message","msg","src","raw","body","label"}) do
        local v=top[k]
        if type(v)=="string" and v~="" then return v end
        if type(v)=="table" then
          local parts={}
          for _,row in ipairs(v) do parts[#parts+1]=tostring(row) end
          if #parts>0 then return table.concat(parts," ") end
        end
      end
      return ""
    end
    local function isSmash(top)
      local s=boxText(top):upper()
      return s:find("ROCK SMASH",1,true) or s:find("ROCKSMASH",1,true)
        or (s:find("SMASH",1,true) and (s:find("ROCK",1,true) or s:find("WANT",1,true) or s:find("USE",1,true)))
    end
    local function runCont(top)
      if type(top)~="table" then return end
      local choice=(type(top.opts)=="table" and top.opts.choice) or top.choice
      if type(choice)=="function" then pcall(choice,true) return end
      if type(top.onDone)=="function" then pcall(top.onDone) end
    end
    local function skipSmash(game)
      if not on("instant_tmhm") or not game or not game.stack or not game.stack.top then return end
      local n=0
      while n<4 do
        local top=game.stack:top()
        if type(top)~="table" or not isSmash(top) then break end
        n=n+1
        pcall(game.stack.pop, game.stack)
        runCont(top)
      end
    end
    pcall(function()
      mod.hooks:wrap("core.update", function(nextFn, game, dt)
        local r=nextFn(game, dt)
        skipSmash(game)
        return r
      end)
    end)
  end)

end
