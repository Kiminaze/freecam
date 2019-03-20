--------------------------------------------------
---- CINEMATIC CAM FOR FIVEM MADE BY KIMINAZE ----
--------------------------------------------------

--------------------------------------------------
------------------- VARIABLES --------------------
--------------------------------------------------

-- main variables
local cam = nil

local offsetRotX = 0.0
local offsetRotY = 0.0
local offsetRotZ = 0.0

local counter = 0
local precision = 1.0
local currPrecisionIndex
local precisions = {}
for i = Cfg.minPrecision, Cfg.maxPrecision + 0.01, Cfg.incrPrecision do
    table.insert(precisions, tostring(i))
    counter = counter + 1
    if (tostring(i) == "1.0") then
        currPrecisionIndex = counter
    end
end

local speed = 1.0

local currFilter = 1
local currFilterIntensity = 10
local filterInten = {}
for i=0.1, 2.01, 0.1 do table.insert(filterInten, tostring(i)) end

local isAttached = false
local entity
local camCoords

-- menu variables
local _menuPool = NativeUI.CreatePool()
local camMenu

local itemCamPrecision

local itemFilter
local itemFilterIntensity

local itemAttachCam

-- print error if no menu access was specified
if (not(Cfg.useButton or Cfg.useCommand)) then
    print(Cfg.strings.noAccessError)
end



--------------------------------------------------
---------------------- LOOP ----------------------
--------------------------------------------------
Citizen.CreateThread(function()
    local pressedCount = 0

    camMenu = NativeUI.CreateMenu(Cfg.strings.menuTitle, Cfg.strings.menuSubtitle)
	_menuPool:Add(camMenu)

    while true do
        Citizen.Wait(1)
        
        -- process menu
        if (_menuPool:IsAnyMenuOpen()) then
            _menuPool:ProcessMenus()
        end

        -- open / close menu on button press
        if (Cfg.useButton) then
            if (IsControlPressed(1, Cfg.controls.controller.openMenu)) then
                pressedCount = pressedCount + 1 
            elseif (IsControlJustReleased(1, Cfg.controls.controller.openMenu)) then
                pressedCount = 0
            end
            if (IsControlJustReleased(1, Cfg.controls.keyboard.openMenu) or pressedCount >= 60) then
                if (pressedCount >= 60) then pressedCount = 0 end
                if (camMenu:Visible()) then
                    camMenu:Visible(false)
                else
                    GenerateCamMenu()
                    camMenu:Visible(true)
                end
            end
        end

        -- process cam controls if cam exists
        if (cam) then
            ProcessCamControls()
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        if (camMenu:Visible() and cam) then
            local tempEntity = GetEntityInFrontOfCam()
            local txt = "-"
            if (DoesEntityExist(tempEntity)) then
                txt = tostring(GetEntityModel(tempEntity))
                if (IsEntityAVehicle(tempEntity)) then
                    txt = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(tempEntity)))
                end
            end
            itemAttachCam:RightLabel(txt)

            if (isAttached and not DoesEntityExist(entity)) then
                ClearFocus()
            end
        end
    end
end)



--------------------------------------------------
---------------------- MENU ----------------------
--------------------------------------------------
function GenerateCamMenu()
    _menuPool:Remove()
    _menuPool = NativeUI.CreatePool()
    collectgarbage()
    
    camMenu = NativeUI.CreateMenu(Cfg.strings.menuTitle, Cfg.strings.menuSubtitle)
    _menuPool:Add(camMenu)
    
    -- add additional control help
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 38, true), ""})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 44, true), Cfg.strings.ctrlHelpRoll})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 36, true), ""})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 21, true), ""})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 30, true), ""})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 31, true), Cfg.strings.ctrlHelpMove})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 2, true), ""})
    camMenu:AddInstructionButton({GetControlInstructionalButton(1, 1, true), Cfg.strings.ctrlHelpRotate})

    local itemToggleCam = NativeUI.CreateCheckboxItem(Cfg.strings.toggleCam, DoesCamExist(cam), Cfg.strings.toggleCamDesc)
    camMenu:AddItem(itemToggleCam)

    itemCamPrecision = NativeUI.CreateListItem(Cfg.strings.precision, precisions, currPrecisionIndex, Cfg.strings.precisionDesc)
    camMenu:AddItem(itemCamPrecision)

    local submenuFilter = _menuPool:AddSubMenu(camMenu, Cfg.strings.filter, Cfg.strings.filterDesc)
    camMenu.Items[#camMenu.Items]:SetLeftBadge(15)
    itemFilter = NativeUI.CreateListItem(Cfg.strings.filter, Cfg.filterList, currFilter, Cfg.strings.filterDesc)
    submenuFilter:AddItem(itemFilter)
    itemFilterIntensity = NativeUI.CreateListItem(Cfg.strings.filterInten, filterInten, currFilterIntensity, Cfg.strings.filterIntenDesc)
    submenuFilter:AddItem(itemFilterIntensity)
    local itemDelFilter = NativeUI.CreateItem(Cfg.strings.delFilter, Cfg.strings.delFilterDesc)
    submenuFilter:AddItem(itemDelFilter)
    
    local itemShowMap = NativeUI.CreateCheckboxItem(Cfg.strings.showMap, not IsRadarHidden(), Cfg.strings.showMapDesc)
    camMenu:AddItem(itemShowMap)

    itemAttachCam = NativeUI.CreateItem(Cfg.strings.attachCam, "")
    if (Cfg.detachOption) then
        camMenu:AddItem(itemAttachCam)
    end
    

    itemToggleCam.CheckboxEvent = function(menu, item, checked)
        ToggleCam(checked, GetGameplayCamFov())
    end

    itemCamPrecision.OnListChanged = function(menu, item, newindex)
        precision           = itemCamPrecision.Items[newindex]
        currPrecisionIndex  = newindex
    end

    itemShowMap.CheckboxEvent = function(menu, item, checked)
        ToggleUI(checked)
    end

    if (Cfg.detachOption) then
        camMenu.OnItemSelect = function(menu, item, index)
            if (item == itemAttachCam) then
                ToggleAttachMode()
            end
        end
    end

    itemFilter.OnListChanged = function(menu, item, newindex)
        ApplyFilter(newindex)
    end

    itemFilterIntensity.OnListChanged = function(menu, item, newindex)
        ChangeFilterIntensity(newindex)
    end

    submenuFilter.OnItemSelect = function(menu, item, index)
        if (item == itemDelFilter) then
            ResetFilter()
        end
    end


    _menuPool:ControlDisablingEnabled(false)
    _menuPool:MouseControlsEnabled(false)

    _menuPool:RefreshIndex()
end



--------------------------------------------------
------------------- FUNCTIONS --------------------
--------------------------------------------------

-- initialize camera
function StartFreeCam(fov)
    ClearFocus()

    local playerPed = PlayerPedId()
    
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(playerPed), 0, 0, 0, fov * 1.0)

    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)
    
    SetCamAffectsAiming(cam, false)

    if (isAttached and DoesEntityExist(entity)) then
        AttachCamToEntity(cam, entity, 0.0, 0.0, 0.0, true)
    end
end

-- destroy camera
function EndFreeCam()
    ClearFocus()

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    
    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0

    speed = 1.0

    currFov = GetGameplayCamFov()

    cam = nil
end

-- process camera controls
function ProcessCamControls()
    local playerPed = PlayerPedId()

    -- disable 1st person as the 1st person camera can cause some glitches
    DisableFirstPersonCamThisFrame()

    -- block weapon wheel (reason: scrolling)
    BlockWeaponWheelThisFrame()

    -- keyboard
    if (IsInputDisabled(0)) then
        if (IsDisabledControlPressed(1, Cfg.controls.keyboard.hold)) then
            -- hotkeys for speed
            if (IsDisabledControlPressed(1, Cfg.controls.keyboard.speedUp)) then
                if ((speed + 0.1) < Cfg.maxSpeed) then
                    speed = speed + 0.1
                else
                    speed = Cfg.maxSpeed
                end
            elseif (IsDisabledControlPressed(1, Cfg.controls.keyboard.speedDown)) then
                if ((speed - 0.1) > Cfg.minSpeed) then
                    speed = speed - 0.1
                else
                    speed = Cfg.minSpeed
                end
            end
        else
            -- hotkeys for FoV
            if (IsDisabledControlPressed(1, Cfg.controls.keyboard.zoomOut)) then
                ChangeFov(1.0)
            elseif (IsDisabledControlPressed(1, Cfg.controls.keyboard.zoomIn)) then
                ChangeFov(-1.0)
            end
        end
    else
        if (GetDisabledControlNormal(1, 228) ~= 0.0) then
            if (not IsDisabledControlPressed(1, Cfg.controls.controller.hold)) then
                ChangeFov(GetDisabledControlNormal(1, 228))
            else
                local newSpeed = speed - (0.1 * GetDisabledControlNormal(1, 228))
                if (newSpeed > Cfg.minSpeed) then
                    speed = newSpeed
                else
                    speed = Cfg.minSpeed
                end
            end
        end
        if (GetDisabledControlNormal(1, 229) ~= 0.0) then
            if (not IsDisabledControlPressed(1, Cfg.controls.controller.hold)) then
                ChangeFov(- GetDisabledControlNormal(1, 229))
            else
                local newSpeed = speed + (0.1 * GetDisabledControlNormal(1, 229))
                if (newSpeed < Cfg.maxSpeed) then
                    speed = newSpeed
                else
                    speed = Cfg.maxSpeed
                end
            end
        end
    end

    -- control anything related to the menu being open
    if (_menuPool:IsAnyMenuOpen() or not isAttached) then
        -- disable character/vehicle controls
        for k, v in pairs(Cfg.disabledControls) do
            DisableControlAction(0, v, true)
        end

        -- camera rotation
        if (IsInputDisabled(0)) then
            -- keyboard
            offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
            offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)
        else
            -- controller
            offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision)
            offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision)
        end
        if (offsetRotX > 90.0) then offsetRotX = 90.0 elseif (offsetRotX < -90.0) then offsetRotX = -90.0 end
        if (offsetRotY > 90.0) then offsetRotY = 90.0 elseif (offsetRotY < -90.0) then offsetRotY = -90.0 end
        if (offsetRotZ > 360.0) then offsetRotZ = offsetRotZ - 360.0 elseif (offsetRotZ < -360.0) then offsetRotZ = offsetRotZ + 360.0 end

        -- calculate coord and rotation offset of cam
        if (isAttached) then
            local offsetCoords = GetOffsetFromEntityGivenWorldCoords(entity, GetCamCoord(cam))

            local newPos = ProcessNewPosition(offsetCoords.x, offsetCoords.y, offsetCoords.z)

            -- set coords of cam
            AttachCamToEntity(cam, entity, newPos.x, newPos.y, newPos.z, true)
            
            SetFocusEntity(entity)

            -- reset coords of cam if too far from entity
            if (Vdist(0.0, 0.0, 0.0, newPos.x, newPos.y, newPos.z) > Cfg.maxDistance) then
                AttachCamToEntity(cam, entity, offsetCoords.x, offsetCoords.y, offsetCoords.z, true)
            end
        else
            local camCoords = GetCamCoord(cam)

            local newPos = ProcessNewPosition(camCoords.x, camCoords.y, camCoords.z)

            SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
            SetCamCoord(cam, newPos.x, newPos.y, newPos.z)
        end
    end
    
    -- set rotation of cam
    if (isAttached) then
        local entityRot = GetEntityRotation(entity, 2)
        SetCamRot(cam, entityRot.x + offsetRotX, entityRot.y + offsetRotY, entityRot.z + offsetRotZ, 2)
    else
        SetCamRot(cam, offsetRotX, offsetRotY, offsetRotZ, 2)
    end
end

function ProcessNewPosition(x, y, z)
    local _x = x
    local _y = y
    local _z = z

    -- keyboard
    if (IsInputDisabled(0)) then
        if (IsDisabledControlPressed(1, Cfg.controls.keyboard.forwards)) then
            local multX = Sin(offsetRotZ)
            local multY = Cos(offsetRotZ)

            _x = _x - (0.1 * speed * multX)
            _y = _y + (0.1 * speed * multY)
        end
        if (IsDisabledControlPressed(1, Cfg.controls.keyboard.backwards)) then
            local multX = Sin(offsetRotZ)
            local multY = Cos(offsetRotZ)

            _x = _x + (0.1 * speed * multX)
            _y = _y - (0.1 * speed * multY)
        end
        if (IsDisabledControlPressed(1, Cfg.controls.keyboard.left)) then
            local multX = Sin(offsetRotZ + 90.0)
            local multY = Cos(offsetRotZ + 90.0)

            _x = _x - (0.1 * speed * multX)
            _y = _y + (0.1 * speed * multY)
        end
        if (IsDisabledControlPressed(1, Cfg.controls.keyboard.right)) then
            local multX = Sin(offsetRotZ + 90.0)
            local multY = Cos(offsetRotZ + 90.0)

            _x = _x + (0.1 * speed * multX)
            _y = _y - (0.1 * speed * multY)
        end
    -- controller
    else
        local multX = Sin(offsetRotZ)
        local multY = Cos(offsetRotZ)
        _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 32))
        _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 32))
        
        _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 33))
        _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 33))
        
        multX = Sin(offsetRotZ + 90.0)
        multY = Cos(offsetRotZ + 90.0)
        _x = _x - (0.1 * speed * multX * GetDisabledControlNormal(1, 34))
        _y = _y + (0.1 * speed * multY * GetDisabledControlNormal(1, 34))
        
        _x = _x + (0.1 * speed * multX * GetDisabledControlNormal(1, 35))
        _y = _y - (0.1 * speed * multY * GetDisabledControlNormal(1, 35))
    end
    if ((IsInputDisabled(0) and IsDisabledControlPressed(1, Cfg.controls.keyboard.up)) or IsDisabledControlPressed(1, Cfg.controls.controller.up)) then
        _z = _z + (0.1 * speed)
    end
    if ((IsInputDisabled(0) and IsDisabledControlPressed(1, Cfg.controls.keyboard.down)) or IsDisabledControlPressed(1, Cfg.controls.controller.down)) then
        _z = _z - (0.1 * speed)
    end
    if ((IsInputDisabled(0) and IsDisabledControlPressed(1, Cfg.controls.keyboard.rollLeft)) or IsDisabledControlPressed(1, Cfg.controls.controller.rollLeft)) then
        offsetRotY = offsetRotY - precision
    end
    if ((IsInputDisabled(0) and IsDisabledControlPressed(1, Cfg.controls.keyboard.rollRight)) or IsDisabledControlPressed(1, Cfg.controls.controller.rollRight)) then
        offsetRotY = offsetRotY + precision
    end

    return {x = _x, y = _y, z = _z}
end

function ToggleCam(flag, fov)
    if (flag) then
        StartFreeCam(fov)
        _menuPool:RefreshIndex()
    else
        EndFreeCam()
        _menuPool:RefreshIndex()
    end
end

function ChangeFov(changeFov)
    if (DoesCamExist(cam)) then
        local currFov   = GetCamFov(cam)
        local newFov    = currFov + changeFov

        if ((newFov >= Cfg.minFov) and (newFov <= Cfg.maxFov)) then
            SetCamFov(cam, newFov)
        end
    end
end

function ToggleUI(flag)
    DisplayRadar(flag)
end

function GetEntityInFrontOfCam()
    local camCoords = GetCamCoord(cam)
    local offset = {x = camCoords.x - Sin(offsetRotZ) * 100.0, y = camCoords.y + Cos(offsetRotZ) * 100.0, z = camCoords.z + Sin(offsetRotX) * 100.0}

    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, offset.x, offset.y, offset.z, 10, 0, 0)
    local a, b, c, d, entity = GetShapeTestResult(rayHandle)
    return entity
end

function ToggleAttachMode()
    if (not isAttached) then
        entity = GetEntityInFrontOfCam()

        if (DoesEntityExist(entity)) then
            Citizen.Wait(1)
            local camCoords = GetCamCoord(cam)
            AttachCamToEntity(cam, entity, GetOffsetFromEntityInWorldCoords(entity, camCoords.x, camCoords.y, camCoords.z), true)

            isAttached = true
        end
    else
        ClearFocus()

        DetachCam(cam)

        isAttached = false
    end
end

function ApplyFilter(filterIndex)
    SetTimecycleModifier(Cfg.filterList[filterIndex])
    currFilter = filterIndex
end

function ChangeFilterIntensity(intensityIndex)
    SetTimecycleModifier(Cfg.filterList[currFilter])
    SetTimecycleModifierStrength(tonumber(filterInten[intensityIndex]))
    currFilterIntensity = intensityIndex
end

function ResetFilter()
    ClearTimecycleModifier()
    itemFilter._Index   = 1
    currFilter          = 1
    itemFilterIntensity._Index  = 10
    currFilterIntensity         = 10
end



--------------------------------------------------
-------------------- COMMANDS --------------------
--------------------------------------------------

-- register command if specified in config
if (Cfg.useCommand) then
    RegisterCommand(Cfg.command, function(source, args, raw)
        if (not camMenu:Visible()) then
            GenerateCamMenu()
            camMenu:Visible(true)
        end
    end)
end

-- void POINT_CAM_AT_ENTITY(Cam cam, Entity entity, float p2, float p3, float p4, BOOL p5);
--void POINT_CAM_AT_COORD(Cam cam, float x, float y, float z);
--void GET_CAM_MATRIX(Cam camera, Vector3* rightVector, Vector3* forwardVector, Vector3* upVector, Vector3* position);

                --gegenkathete = x
                --ankathete = y
                --hypotenuse = 1
                --alpha = GetCamRot(cam).z
