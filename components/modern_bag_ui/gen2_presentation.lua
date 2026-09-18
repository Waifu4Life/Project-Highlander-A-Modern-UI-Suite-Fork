-- The Gen 1 Bag composition, fed by the native Gen 2 PACK controller.
return function(mod, source)
  local G=love.graphics
  local Palette=require('src.render.PaletteFX')
  local Font=require('src.render.Font')
  local Menu=require('src.ui.Menu')
  local touch=mod.suite and mod.suite.touch
  local palettes={
    BLUEMON={{255,255,255},{72,168,255},{24,72,216},{8,8,16}},
    REDMON={{255,255,255},{255,112,56},{216,32,24},{16,8,8}},
    CYANMON={{255,255,255},{72,216,240},{16,140,204},{8,16,24}},
    BROWNMON={{255,255,255},{240,168,72},{176,88,24},{16,8,0}},
    GREENMON={{255,255,255},{80,216,80},{16,144,48},{8,16,8}},
    PURPLEMON={{255,255,255},{224,112,224},{160,40,184},{16,8,16}},
  }
  local category={ALL='all',ITEMS='items',MEDICINE='medicine',BALL='balls',TM_HM='machines',KEY_ITEM='key'}
  local owner
  local loaded=assert(load(assert(mod:read('screen.lua')),'@'..mod.path..'/screen.lua'))()(mod,{
    presentationSize=function(state) return state.width,state.height end,
    categoryFor=function(_,id) return category[source.category(owner,id)] or 'items' end,
    capacity=function(state)
      local used=#source.order(state.nativeBag)
      return ('%d/%d'):format(used, 255)
    end,
    description=function(state,id)
      if not id then return 'Return to the previous screen.' end
      local game=state.game
      local items=(state.nativeBag and state.nativeBag.items)
        or (game and game.data and game.data.items)
      local def=type(items)=='table' and items[id] or nil
      local teaches=def and def.teaches
      local moves=game and game.data and game.data.moves
      local move=teaches and type(moves)=='table' and moves[teaches]
      if type(move)=='table' then
        local text=move.description or move.effect or move.text
        if type(text)=='string' and text~='' and text~='?' then
          return text:gsub('<NEXT>',' '):gsub('<PARA>',' ')
        end
        if move.name then
          return ('Teaches %s to a compatible POKeMON.'):format(tostring(move.name))
        end
      end
      if state.nativeBag and type(state.nativeBag.description)=='function' then
        local ok,text=pcall(function() return state.nativeBag:description() end)
        text=ok and text or nil
        if type(text)=='string' and text~='' and text~='?'
            and text~='A useful item for your journey.' then
          return text:gsub('<NEXT>',' ')
        end
      end
      if type(def)=='table' and type(def.description)=='string'
          and def.description~='' and def.description~='?' then
        return def.description:gsub('<NEXT>',' ')
      end
      return 'A useful item for your journey.'
    end,
    palette=function(_,name) return palettes[name] or palettes.BLUEMON end,
  })
  local api=loaded and loaded.presentation
  if not api then
    return { render=function() end }
  end
  local pocketByKey={}
  for _,pocket in ipairs(api.pockets) do pocketByKey[pocket.key]=pocket end
  local function size(menu)
    return menu.modernBagWideWidth or menu.modernBagLastWideWidth or 160,
      menu.modernBagWideHeight or menu.modernBagLastWideHeight or 144
  end
  local function stateFor(menu)
    local state=menu.modernGen2BagPresentation or {nativeBag=menu,game=menu.game}
    menu.modernGen2BagPresentation=state
    state.width,state.height=size(menu)
    state.modernBagPocket=menu.modernBagPocketIndex
    state.modernBagPockets={}
    for _,pocket in ipairs(menu.modernBagPockets or {}) do
      state.modernBagPockets[#state.modernBagPockets+1]=pocketByKey[pocket.key]
    end
    state.items={}
    for _,row in ipairs(menu.rows or {}) do
      local id=row.id
      if id and id~='CANCEL' and not row.cancel then
        state.items[#state.items+1]={value=id,
          label=row.tmhmLabel and (row.tmhmLabel..' '..tostring(row.teaches or row.name)) or row.name,
          right=row.showCount and ('x'..tostring(row.count or 0)) or ''}
      end
    end
    -- No CANCEL row. B leaves the bag, same as Gen 1.
    state.index,state.scroll=menu.index,menu.scroll
    local prompt=menu.message or menu.confirm and menu.confirm.prompt
    state.modernBagPrompt=prompt and table.concat(prompt,' '):gsub('{PLAYER}',menu:playerName()) or nil
    state.modernBagSwapId=menu.switching and menu.rows[menu.switching] and menu.rows[menu.switching].id
    state.modernBagDescriptionBlocked=menu.submenu or menu.qtyState or menu.modernBagSortMenu
    state.modernBagDescriptionScroll=menu.modernBagDescriptionScroll
    return state
  end
  local function layout(menu)
    return api.layout(stateFor(menu))
  end
  local function dialog(state,rows,index,opts)
    local menu=Menu.new(state.game,rows,opts)
    menu.index=index or 1
    local dx,dy=math.floor((state.width-160)/2),math.floor((state.height-144)/2)
    G.push('all');G.translate(dx,dy);menu:draw()
    if opts.title then G.setColor(0,0,0,1);Font.draw(opts.title,(menu.tx+1)*8,(menu.ty+1)*8) end
    G.pop()
    return {x=dx+menu.tx*8,y=dy+menu.ty*8,w=menu.tw*8,h=menu.th*8,colors=Palette.GRAYS}
  end
  local function overlays(menu,state,l)
    local zones={}
    if menu.modernBagSortMenu then
      local sort=menu.modernBagSortMenu
      zones[#zones+1]=dialog(state,sort.rows,sort.index,{tx=2,ty=3,tw=16,th=9,rowStep=1.5,title='SORT BY'})
    end
    if menu.submenu then
      local rows={}
      for _,id in ipairs(menu.submenu.rows) do rows[#rows+1]={label=source.labels[id] or id:upper()} end
      zones[#zones+1]=dialog(state,rows,menu.submenu.index,{tx=10,ty=2,tw=10})
    end
    if menu.confirm then
      zones[#zones+1]=dialog(state,{{label='YES'},{label='NO'}},menu.confirm.choice,{tx=14,ty=5,tw=6})
    end
    if menu.qtyState then
      local w,h=40,24
      local row=math.max(0,menu.index-menu.scroll-1)
      local x=l.showDetails and not l.stacked and (l.listX+l.listW-6) or (l.listX+l.listW-w-5)
      local y=math.max(l.contentY,math.min(l.footerY-h,l.listY+3+row*15-5))
      x=math.max(0,math.min(l.width-w,x))
      local q=Menu.new(state.game,{}, {tx=0,ty=0,tw=5,th=3})
      G.push('all');G.translate(x,y);q:draw();G.setColor(0,0,0,1)
      Font.draw('x'..('%02d'):format(menu.qtyState.qty or 1),8,8);G.pop()
      zones[#zones+1]={x=x,y=y,w=w,h=h,colors=Palette.GRAYS}
      menu.modernBagQuantityBounds={x=x,y=y,w=w,h=h}
    end
    return zones
  end
  local function render(menu)
    owner=menu
    local state=stateFor(menu)
    local l=api.layout(state)
    menu.modernBagVisibleRows=l.rows
    menu:ensureVisible()
    state.index,state.scroll=menu.index,menu.scroll
    local counts={}
    for _,id in ipairs((source.order and source.order(menu)) or {}) do
      local key=category[source.category(menu,id)] or 'items'
      counts.all=(counts.all or 0)+1;counts[key]=(counts[key] or 0)+1
    end
    local canvas=menu.modernGen2BagCanvas
    if not canvas or canvas:getWidth()~=l.width or canvas:getHeight()~=l.canvasHeight then
      if canvas and canvas.release then canvas:release() end
      canvas=G.newCanvas(l.width,l.canvasHeight);canvas:setFilter('nearest','nearest')
      menu.modernGen2BagCanvas=canvas
    end
    local previous=G.getCanvas()
    G.push('all');G.setCanvas(canvas);G.origin();G.setScissor();G.clear(0,0,0,0)
    pcall(api.draw,state,counts)
    local function ramp(name)
      return palettes[name] or palettes.BLUEMON
    end
    local paper={{255,255,255},{236,236,236},{64,64,64},{0,0,0}}
    local pocket=(state.modernBagPockets or {})[state.modernBagPocket or 1] or {}
    local accent=ramp(pocket.palette or 'BLUEMON')
    local zones
    if l.skin=='classic_pocket' then
      -- Black title / brown footer, blue woven rail, white item sheet.
      -- Do not tint the sheet with BLUEMON or the empty pocket turns solid blue.
      local headerH=l.headerH or 14
      local footerY=l.footerY or ((l.height or 144)-16)
      zones={
        {x=0,y=0,w=l.width,h=l.canvasHeight or l.height or 144,colors=paper},
        {x=0,y=0,w=l.width,h=headerH,colors=ramp('BROWNMON')},
        {x=l.railX or 0,y=l.railY or headerH,w=l.railW or 48,h=l.railH or 80,colors=ramp('CYANMON')},
        {x=l.listX or 48,y=l.listY or headerH,w=l.listW or 112,h=l.listH or 80,colors=paper},
        {x=0,y=footerY,w=l.width,h=(l.canvasHeight or l.height or 144)-footerY,colors=ramp('BROWNMON')},
      }
    else
      zones={
        {x=0,y=0,w=l.width,h=l.canvasHeight or l.height or 144,colors=ramp('BLUEMON')},
        {x=0,y=0,w=l.width,h=l.contentY or l.headerH or 16,colors=accent},
      }
      if l.showDetails and l.detailW then
        zones[#zones+1]={x=l.detailX or 0,y=l.detailY or 0,
          w=l.detailW,h=l.detailH or 40,colors=accent}
      end
      if state.items and #state.items>0 and l.listX then
        local row=math.max(0,(state.index or 1)-(state.scroll or 0)-1)
        zones[#zones+1]={
          x=(l.listX or 0)+4,
          y=(l.listY or 0)+3+row*15,
          w=math.max(8,(l.listW or 80)-8),h=13,colors=accent}
      end
    end
    for _,zone in ipairs(overlays(menu,state,l) or {}) do
      zone.colors=zone.colors or paper
      zones[#zones+1]=zone
    end
    G.setCanvas(previous);G.pop()
    G.push('all');G.setColor(1,1,1,1)
    local shader=Palette.shader();G.setShader(shader)
    for _,zone in ipairs(zones) do
      if shader then Palette.sendColors(shader,zone.colors) end
      G.draw(canvas,G.newQuad(zone.x,zone.y,zone.w,zone.h,l.width,l.canvasHeight),zone.x,zone.y)
    end
    G.pop()
    menu.modernBagDescriptionScroll=state.modernBagDescriptionScroll
    menu.modernBagHeaderCash,menu.modernBagHeaderBounds=state.modernBagHeaderCash,state.modernBagHeaderBounds
    if touch then
      touch.begin(menu,'window',function()return menu.qtyState or menu.message or menu.confirm or menu.submenu or menu.repeatSfx or menu.modernBagSortMenu or menu.tutorial end,
        function(key,press)press(menu,key)end)
      local pockets=state.modernBagPockets or {}
      local gap=l.width>=210 and 3 or 1
      if #pockets<1 then pockets={{key="items"}} end
      local tabW=math.floor((l.width-8-gap*(#pockets-1))/#pockets)
      local x0=math.floor((l.width-(tabW*#pockets+gap*(#pockets-1)))/2)
      for i,pocket in ipairs(pockets) do
        touch.add(menu,x0+(i-1)*(tabW+gap),l.tabsY,tabW,l.tabsH,'pocket:'..pocket.key,function()menu:switchPocket(i-menu.modernBagPocketIndex)end)
      end
      for row=1,l.rows do
        local i=menu.scroll+row
        if state.items[i] then touch.add(menu,l.listX,l.listY+4+(row-1)*15,l.listW,15,'item:'..tostring(state.items[i].value),
          function()menu.index=i;menu:ensureVisible()end,function()return menu.index==i end,true) end
      end
    end
  end
  return {render=render,layout=layout,qol=function(menu)return api.qol(stateFor(menu))end}
end
