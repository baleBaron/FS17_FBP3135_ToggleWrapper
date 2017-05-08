--
-- TogglableBaleWrapper specialization
--
-- by: baron <mve.karlsson@gmail.com>
--

TogglableBaleWrapper = {};

function TogglableBaleWrapper.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(BaleWrapper, specializations)
end

function TogglableBaleWrapper:load(savegame)
    
    self.setWrapperDesired  = TogglableBaleWrapper.setWrapperDesired
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

    self.isBaleWrapperDesired = true -- user desired state
    self.isBaleWrapperEnabled = true -- bale wrapper action state

    if savegame ~= nil and not savegame.resetVehicles then
        self.isBaleWrapperDesired = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key .. "#isBaleWrapperDesired"), true)
        self.isBaleWrapperEnabled = Utils.getNoNil(getXMLFloat(savegame.xmlFile, savegame.key.."#wrapperTime"), self.isBaleWrapperDesired) ~= 0 -- set desired state, or force wrap if unfinished bale on wrapper
    end
end

function TogglableBaleWrapper:getSaveAttributesAndNodes(nodeIdent)
    return ' isBaleWrapperDesired="'..tostring(self.isBaleWrapperDesired)..'"', nil
end

function TogglableBaleWrapper:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isBaleWrapperDesired)
    streamWriteBool(streamId, self.isBaleWrapperEnabled)
end

function TogglableBaleWrapper:readStream(streamId, connection)
    self.isBaleWrapperDesired = streamReadBool(streamId)
    self.isBaleWrapperEnabled = streamReadBool(streamId)
end

function TogglableBaleWrapper:delete()
end

function TogglableBaleWrapper:mouseEvent(posX, posY, isDown, isUp, button)
end

function TogglableBaleWrapper:keyEvent(unicode, sym, modifier, isDown)
end

function TogglableBaleWrapper:update(dt)
    if self.isClient and self:getIsActiveForInput() and InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA4) then
        self:setWrapperDesired(not self.isBaleWrapperDesired)
    end
    
    -- toggle wrapper if desired and allowed
    if self.isBaleWrapperDesired ~= self.isBaleWrapperEnabled and self.baleToLoad == nil then
        if self.baleWrapperState < BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER or self.baleWrapperState >= BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
            self.isBaleWrapperEnabled = self.isBaleWrapperDesired
            
            -- Wrapping should start if wrapper was enabled and we have a unwrapped bale on wrapper table
            if self.isBaleWrapperEnabled and self.isServer then
                local bale = networkGetObject(self.currentWrapper.currentBale)
                if bale ~= nil and bale.wrappingState == 0 and self.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
                    self:moveBaleToWrapper(bale)
                end
            end
        end
    end
end

function TogglableBaleWrapper:draw()
    local statusText = self.isBaleWrapperDesired and g_i18n:getText("TGWP_ISENABLED") or g_i18n:getText("TGWP_ISDISABLED")

    if self.isClient and self:getIsActiveForInput() then 
        g_currentMission:addHelpButtonText(statusText, InputBinding.IMPLEMENT_EXTRA4, nil, GS_PRIO_HIGH);
    end
end

function TogglableBaleWrapper:doStateChange(superFunc, id, nearestBaleServerId)
    if id == BaleWrapper.CHANGE_WRAPPING_START and not self.isBaleWrapperEnabled then
        self.baleWrapperState = BaleWrapper.STATE_WRAPPER_FINSIHED
        return
    end
    
    superFunc(self, id, nearestBaleServerId)
end

function TogglableBaleWrapper:pickupWrapperBale(superFunc, bale, baleType)
    if not self.isBaleWrapperEnabled then 
        g_server:broadcastEvent(BaleWrapperStateEvent:new(self, BaleWrapper.CHANGE_GRAB_BALE, networkGetObjectId(bale)), true, nil, self)
    else
        superFunc(self, bale, baleType)
    end
end

function TogglableBaleWrapper:setWrapperDesired(desired, noEventSend)
    if self.isBaleWrapperDesired ~= desired then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(disableWrapperEvent:new(self, desired), nil, nil, self)
            else
                g_client:getServerConnection():sendEvent(disableWrapperEvent:new(self, desired))
            end
        end
        
        self.isBaleWrapperDesired = desired
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

function disableWrapperEvent:new(object, desired)
    local self = disableWrapperEvent:emptyNew()
    self.object = object
    self.desired = desired
    
    return self
end

function disableWrapperEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.desired = streamReadBool(streamId)
    self:run(connection)
end

function disableWrapperEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.desired)
end

function disableWrapperEvent:run(connection)
    self.object:setWrapperDesired(self.desired, true)
    
    if not connection:getIsServer() then 
        g_server:broadcastEvent(disableWrapperEvent:new(self.object, self.desired), nil, connection, self.object)
    end
end