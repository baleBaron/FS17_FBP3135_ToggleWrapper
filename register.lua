
RegistrationHelper_FBPWRAP = {};
RegistrationHelper_FBPWRAP.isLoaded = false;

if SpecializationUtil.specializations['togglableWrapper'] == nil then
    SpecializationUtil.registerSpecialization('togglableWrapper', 'TogglableBaleWrapper', g_currentModDirectory .. 'TogglableWrapper.lua')
    RegistrationHelper_FBPWRAP.isLoaded = false;
end

function RegistrationHelper_FBPWRAP:loadMap(name)
    if not g_currentMission.registrationHelper_FBPWRAP_isLoaded then
        if not RegistrationHelper_FBPWRAP.isLoaded then
            self:register();
        end
        g_currentMission.registrationHelper_FBPWRAP_isLoaded = true
    else
        print("Error: FBP 3135 TogglableWrapper has been loaded already!");
    end
end

function RegistrationHelper_FBPWRAP:deleteMap()
    g_currentMission.registrationHelper_FBPWRAP_isLoaded = nil
end

function RegistrationHelper_FBPWRAP:keyEvent(unicode, sym, modifier, isDown)
end

function RegistrationHelper_FBPWRAP:mouseEvent(posX, posY, isDown, isUp, button)
end

function RegistrationHelper_FBPWRAP:update(dt)
end

function RegistrationHelper_FBPWRAP:draw()
end

function RegistrationHelper_FBPWRAP:register()
    for name, vehicle in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicle ~= nil and name == "pdlc_kuhnPack.balerWrapper" then
            table.insert(vehicle.specializations, SpecializationUtil.getSpecialization("togglableWrapper"))
        end
    end
    RegistrationHelper_FBPWRAP.isLoaded = true
end

addModEventListener(RegistrationHelper_FBPWRAP)