HomesteadEng={};
HE=HomesteadEng;
HE.name="HomesteadEngineer"; --If this doesn't match what's in the .txt file, stuff will break...
HE.a={};

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

function HE.GetItemPos(furnId)
  local x,y,z=HousingEditorGetFurnitureWorldPosition(furnId);
  return x,y,z,HousingEditorGetFurnitureOrientation(furnId);
end

function HE.GetItemPosLoc(furnId)
  return TR.TransformToCoord(TR.FwdTransform(TR.CoordToTransform(HE.GetItemPos(furnId)),HE.locTr));
end

local function FinishSetItemPos()
  HE.grouperPlacing=false;
  FurnitureGrouper_Mover.Placed();
end

function HE.SetItemPos(furnId,x,y,z,p,w,r)
  local doPlace=false;
  if HE.lock then
    return;
  end
  --d(tostring(x)..","..tostring(y)..","..tostring(z)..","..tostring(p)..","..tostring(w)..","..tostring(r));
  if FurnitureGrouper_Mover and FurnitureGrouper_Mover.PickedUp and FurnitureGrouper_Mover.Placed then
    doPlace=true;
    if not HE.grouperPlacing then
      FurnitureGrouper_Mover.PickedUp(furnId);
      HE.grouperPlacing=0;
    end
  end
  HousingEditorRequestChangePositionAndOrientation(furnId,x,y,z,p,w,r);
  if doPlace then
    local idx=HE.grouperPlacing+1;
    HE.grouperPlacing=idx;
    zo_callLater(function () if HE.grouperPlacing==idx then FinishSetItemPos(); end end,250);
  end
end

function HE.SetItemPosLoc(furnId,x,y,z,p,w,r)
  if HE.lock then
    return;
  end
  HE.SetItemPos(furnId,TR.TransformToCoord(TR.RevTransform(TR.CoordToTransform(x,y,z,p,w,r),HE.locTr)));
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

EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_ADD_ON_LOADED,HE.OnAddOnLoaded);
EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_PLAYER_ACTIVATED,HE.OnZone);
EVENT_MANAGER:RegisterForEvent(HE.name,EVENT_HOUSING_EDITOR_MODE_CHANGED,HE.ModeChanged)

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

