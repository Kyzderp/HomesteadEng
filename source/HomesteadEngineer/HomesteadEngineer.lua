HomesteadEng={};
HE=HomesteadEng;
HE.name="HomesteadEngineer"; --If this doesn't match what's in the .txt file, stuff will break...
HE.a={};

local HISTORY_VALID=1.0;
local TR=HomesteadEngTransform;

function HE.Log(data)
  table.insert(HE.a,data)
end

function HE.CheckTarget()
  if GetHousingEditorMode()~=HOUSING_EDITOR_MODE_SELECTION 
      or not HousingEditorCanSelectTargettedFurniture() then
    return nil;
  end
  HousingEditorSelectTargettedFurniture();
  local furnId=HousingEditorGetSelectedFurnitureId();
  HousingEditorRequestSelectedPlacement();
  return furnId;
end

local function CheckHistory(myCache,frameIdx,x,y,z)
  local curLoc;
  if myCache.history then
    --Process the history to determine our progress and ultimately determine if we should use the cached value
    for i=1,#myCache.history-1 do
      --History entries older than HISTORY_VALID should be discarded
      if (frameIdx-myCache.history[i][1])<=HISTORY_VALID then
        if myCache.history[i][2]==x and myCache.history[i][3]==y and myCache.history[i][4]==z then
          --We found the first history item matching the reported position.
          curLoc=i;
          break;
        end
      end
    end
    --Remove all entries before our current location
    if curLoc then
      for i=1,curLoc-1 do
        table.remove(myCache.history,1);
      end
    else
      myCache.history=nil;
    end
  end
  return curLoc~=nil;
end

function HE.GetItemPos(furnId)
  local furnKey=zo_getSafeId64Key(furnId);
  local x,y,z=HousingEditorGetFurnitureWorldPosition(furnId);
  if HE.itemCache[furnKey] then
    local myCache=HE.itemCache[furnKey];
    local frameIdx=GetFrameTimeSeconds();
    if CheckHistory(myCache,frameIdx,x,y,z) or (myCache.last[2]==x and myCache.last[3]==y and myCache.last[4]==z) then
      x=myCache.use.x;
      y=myCache.use.y;
      z=myCache.use.z;
    else
      --d("no match "..string.format("%.3f",myCache.last[1])..","..tostring(myCache.last[2])..","..tostring(myCache.last[3])..","..tostring(myCache.last[4]).." "..string.format("%.3f",frameIdx)..","..tostring(x)..","..tostring(y)..","..tostring(z));
      HE.itemCache[furnKey]=nil;
    end
  end
  return x,y,z,HousingEditorGetFurnitureOrientation(furnId);
end

local function FinishSetItemPos()
  HE.grouperPlacing=false;
  FurnitureGrouper_Mover.Placed();
end

function HE.SetItemPos(furnId,x,y,z,p,w,r)
  local doPlace=false;
  --Don't do this if in placement mode
  if HE.lock then
    return;
  end
  --Furniture Grouper integration -- pick up
  if FurnitureGrouper_Mover and FurnitureGrouper_Mover.PickedUp and FurnitureGrouper_Mover.Placed then
    doPlace=true;
    if not HE.grouperPlacing then
      FurnitureGrouper_Mover.PickedUp(furnId);
      HE.grouperPlacing=0;
    end
  end
  local furnKey=zo_getSafeId64Key(furnId);
  local frameIdx=GetFrameTimeSeconds();
  HE.itemCache[furnKey]=HE.itemCache[furnKey] or {};
  local myCache=HE.itemCache[furnKey];
  --d("p"..string.format("%.3f",frameIdx).." "..string.format("%.3f",x)..","..string.format("%.3f",y)..","..string.format("%.3f",z));
  --We know that coordinates will be truncated to ints, so round to closest and store for later comparison
  local reqpos={frameIdx,math.floor(x+.5),math.floor(y+.5),math.floor(z+.5)};
  local curpos={frameIdx,HousingEditorGetFurnitureWorldPosition(furnId)};
  --If we're not currently tracking a history of movements, or our history is used up, start the history with the current position
  CheckHistory(myCache,curpos[1],curpos[2],curpos[3],curpos[4]);
  if not myCache.history then
    myCache.history={};
    table.insert(myCache.history,curpos);
  end
  --Add the requested position to the history of movements
  table.insert(myCache.history,reqpos);
  --Then store the last requested position and the high resolution coordinates to use
  myCache.last=reqpos;
  myCache.use={x=x,y=y,z=z};
  HousingEditorRequestChangePositionAndOrientation(furnId,reqpos[2],reqpos[3],reqpos[4],p,w,r);
  --Furniture Grouper integration -- place 
  if doPlace then
    local idx=HE.grouperPlacing+1;
    HE.grouperPlacing=idx;
    zo_callLater(function () if HE.grouperPlacing==idx then FinishSetItemPos(); end end,250);
  end
end

function HE.GetItemPosLoc(furnId)
  return TR.TransformToCoord(TR.FwdTransform(TR.CoordToTransform(HE.GetItemPos(furnId)),HE.locTr));
end

function HE.SetItemPosLoc(furnId,x,y,z,p,w,r)
  if HE.lock then
    return;
  end
  HE.SetItemPos(furnId,TR.TransformToCoord(TR.RevTransform(TR.CoordToTransform(x,y,z,p,w,r),HE.locTr)));
end

function HE.MoveItemRel(furnId,x,y,z)
  HE.SetItemPos(furnId,TR.TransformToCoord(TR.RevTransform(TR.CoordToTransform(x,y,z,0,0,0),TR.CoordToTransform(HE.GetItemPos(furnId)))));
end

function HE.RotItemRel(furnId,p,w,r)
  HE.SetItemPos(furnId,TR.TransformToCoord(TR.RevTransform(TR.CoordToTransform(0,0,0,p,w,r),TR.CoordToTransform(HE.GetItemPos(furnId)))));
end

function HE.C2L(x,y,z,p,w,r)
  return {x,y,z,p,w,r};
end

function HE.L2C(list)
  return list[1],list[2],list[3],list[4],list[5],list[6];
end

function HE.SelectPrimary()
  local targetFurn=HE.CheckTarget();
  if targetFurn then
    HE.primaryTarget=targetFurn;
    HE.Wnd.ItemAdj:SetItem(targetFurn);
  end
end

function HE.SetLocalTransform(x,y,z,p,w,r)
  if not HE.locTrC or x~=HE.locTrC[1] or y~=HE.locTrC[2] or z~=HE.locTrC[3] or p~=HE.locTrC[4] or w~=HE.locTrC[5] or r~=HE.locTrC[6] then
    HE.locTrC={x,y,z,p,w,r};
    HE.locTr=TR.CoordToTransform(HE.L2C(HE.locTrC));
    HE.Wnd.ItemAdj:LocalChanged();
  end
end

function HE.OnAddOnLoaded(event,addonName)
  if(addonName==HE.name) then
    ZO_CreateStringId("SI_BINDING_NAME_HOMESTEAD_ENG_SELECT_PRIMARY","Select furniture");
    HE.Wnd={};
    HE.Wnd.ItemAdj=HomesteadEngItemAdj;
    HE.Log("OnAddOnLoaded");
    HE.lock=false;
    HE.itemCache={};
    
    HE.SetLocalTransform(0,0,0,0,0,0);
    
    EVENT_MANAGER:UnregisterForEvent(HE.name,EVENT_ADD_ON_LOADED);
  end
end

function HE.OnZone(event)
  HE.primaryTarget=nil;
  HE.Wnd.ItemAdj:SetItem(nil);
  HE.Wnd.ItemAdj:SetHidden(true);
end

function HE.ModeChanged(event,oldMode,newMode)
  if HE.lock and newMode~=HOUSING_EDITOR_MODE_PLACEMENT then
    HE.Wnd.ItemAdj:SetLock(false);
    HE.lock=false;
  end
  
  if not HE.lock and newMode==HOUSING_EDITOR_MODE_PLACEMENT then
    HE.Wnd.ItemAdj:SetLock(true);
    HE.lock=true;
  end
end

function HE.FurnRemoved(event,furnId)
  local furnKey=zo_getSafeId64Key(furnId);
  
  if HE.primaryTarget==furnId then
    HE.primaryTarget=nil;
  end
  HE.itemCache[furnKey]=nil;
  
  HE.Wnd.ItemAdj:OnFurnRemoved(furnId);
end

EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_ADD_ON_LOADED,HE.OnAddOnLoaded);
EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_PLAYER_ACTIVATED,HE.OnZone);
EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_HOUSING_EDITOR_MODE_CHANGED,HE.ModeChanged);
EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_HOUSING_FURNITURE_REMOVED,HE.FurnRemoved);

--###############--

function HomesteadEngEdit_Initialize(self)
  HE.Log("HomesteadEngEdit_Initialize "..tostring(self));
  local edit=self:GetNamedChild("Edit");
  edit:SetHandler("OnEscape",function () edit:LoseFocus();end);
end

--###############--

function HomesteadEngLEdit_Initialize(self)
  local label;
  local edit;

  for i=1,self:GetNumChildren() do
    local lvl1=self:GetChild(i);
    local lvl1Type=lvl1:GetType();
    if lvl1Type==CT_EDITBOX then
      if not edit then
        edit=lvl1;
      end
    elseif lvl1Type==CT_LABEL then
      if not label then
        label=lvl1;
      end
    else
      for j=1,lvl1:GetNumChildren() do
        local lvl2=lvl1:GetChild(j);
        local lvl2Type=lvl2:GetType();
        if lvl2Type==CT_EDITBOX then
          if not edit then
            edit=lvl2;
          end
        elseif lvl2Type==CT_LABEL then
          if not label then
            label=lvl2;
          end
        else
        end
      end
    end
  end
  self.label=label;
  self.edit=edit;
end

--###############--

