--
-- TogglableBaleWrapper
--

TogglableBaleWrapper = {};

function TogglableBaleWrapper.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(BaleWrapper, specializations)
end

function TogglableBaleWrapper:load(savegame)
    self.isBaleWrapperDisabled = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key .. "#isBaleWrapperDisabled"), false)
    self.isWrappingForced = Utils.getNoNil(getXMLFloat(savegame.xmlFile, savegame.key.."#wrapperTime"),0) ~= 0 -- If wrapping is in progress, disabling of wrapper is overridden
    
    self.setWrapperDisabled = TogglableBaleWrapper.setWrapperDisabled
    self.doStateChange      = Utils.overwrittenFunction(self.doStateChange,     TogglableBaleWrapper.doStateChange)
    self.pickupWrapperBale  = Utils.overwrittenFunction(self.pickupWrapperBale, TogglableBaleWrapper.pickupWrapperBale)

    --install dryGrass_windrow as wrappable if grass_windrow is present
    for _,baleCategory in pairs({"roundBaleWrapper", "squareBaleWrapper"}) do
        local grassBaleType     = self[baleCategory].allowedBaleTypes[FillUtil.FILLTYPE_GRASS_WINDROW]
        local dryGrassBaleType  = self[baleCategory].allowedBaleTypes[FillUtil.FILLTYPE_DRYGRASS_WINDROW]
        
        if grassBaleType ~= nil and dryGrassBaleType == nil then
            self[baleCategory].allowedBaleTypes[FillUtil.FILLTYPE_DRYGRASS_WINDROW] = grassBaleType
        end
    end
end

function TogglableBaleWrapper:getSaveAttributesAndNodes(nodeIdent)
    return ' isBaleWrapperDisabled="'..tostring(self.isBaleWrapperDisabled)..'"', nil
end

function TogglableBaleWrapper:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isBaleWrapperDisabled)
end

function TogglableBaleWrapper:readStream(streamId, connection)
    self.isBaleWrapperDisabled = streamReadBool(streamId)
end

function TogglableBaleWrapper:delete()
end

function TogglableBaleWrapper:mouseEvent(posX, posY, isDown, isUp, button)
end

function TogglableBaleWrapper:keyEvent(unicode, sym, modifier, isDown)
end

function TogglableBaleWrapper:update(dt)
    if self.isClient and self:getIsActiveForInput() and InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA4) then
        self:setWrapperDisabled(not self.isBaleWrapperDisabled)
    end
end

function TogglableBaleWrapper:draw()
    local statusText = not self.isBaleWrapperDisabled and g_i18n:getText("TGWP_ISENABLED") or g_i18n:getText("TGWP_ISDISABLED")

    if self.isClient and self:getIsActiveForInput() then 
        g_currentMission:addHelpButtonText(statusText, InputBinding.IMPLEMENT_EXTRA4, nil, GS_PRIO_HIGH);
    end
end

function TogglableBaleWrapper:doStateChange(superFunc, id, nearestBaleServerId)
    if id == BaleWrapper.CHANGE_WRAPPING_START and self.isBaleWrapperDisabled and not self.isWrappingForced then
        self.baleWrapperState = BaleWrapper.STATE_WRAPPER_FINSIHED
    else
        superFunc(self, id, nearestBaleServerId)
    end  
end

function TogglableBaleWrapper:pickupWrapperBale(superFunc, bale, baleType)
    self.isWrappingForced = false -- This bale is not forced to wrap

    if self.isBaleWrapperDisabled then 
        g_server:broadcastEvent(BaleWrapperStateEvent:new(self, BaleWrapper.CHANGE_GRAB_BALE, networkGetObjectId(bale)), true, nil, self)
    else
        superFunc(self, bale, baleType)
    end
end

function TogglableBaleWrapper:setWrapperDisabled(disable, noEventSend)
    if self.isBaleWrapperDisabled ~= disable then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(disableWrapperEvent:new(self, disable), nil, nil, self)
            else
                g_client:getServerConnection():sendEvent(disableWrapperEvent:new(self, disable))
            end
        end
        
        self.isBaleWrapperDisabled = disable
        
        -- Wrapping should start if wrapper was enabled and we have a unwrapped bale on wrapper table
        if not self.isBaleWrapperDisabled and self.isServer then
            local bale = networkGetObject(self.currentWrapper.currentBale)
            if bale ~= nil and bale.wrappingState == 0 and self.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
                self:moveBaleToWrapper(bale)
            end
        end
    end
end

-- Enable wrapper event
disableWrapperEvent = {}
disableWrapperEvent_mt = Class(disableWrapperEvent, Event)

InitEventClass(disableWrapperEvent, "toggleWrapperEvent")

function disableWrapperEvent:emptyNew()
    local self = Event:new(disableWrapperEvent_mt)
    self.className = "disableWrapperEvent"
    
    return self
end

function disableWrapperEvent:new(object, disabled)
    local self = disableWrapperEvent:emptyNew()
    self.object = object
    self.disabled = disabled
    
    return self
end

function disableWrapperEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.disabled = streamReadBool(streamId)
    self:run(connection)
end

function disableWrapperEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.disabled)
end

function disableWrapperEvent:run(connection)
    self.object:setWrapperDisabled(self.disabled, true)
    
    if not connection:getIsServer() then 
        g_server:broadcastEvent(disableWrapperEvent:new(self.object, self.disabled), nil, connection, self.object)
    end
end