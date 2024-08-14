local SPIDER_WEB_WEPID = 0
local SPIDER_WEB_DISTANCE = 300
local SPIDER_WEB_LENGTH = 50
local SPIDER_WEB_DURATION = 500

local spiderRayEnabled = true
local spiderRayTimer
local spiderRayHit

function getSpiderRay()
    local vStart = Vector3(getPedTargetStart(localPlayer))
    local vEnd = Vector3(getPedTargetEnd(localPlayer))
    local spiderRayDir = Vector3(vEnd - vStart):getNormalized()
    local spiderRayStart = Vector3(getPedBonePosition(localPlayer, 34))

    return spiderRayStart, spiderRayDir, SPIDER_WEB_DISTANCE
end

function getSpiderWebHit()
    local spiderRayStart, spiderRayDir = getSpiderRay()
    local spiderRayEnd = spiderRayStart + spiderRayDir * SPIDER_WEB_DISTANCE

    -- process ray
    local sx, sy, sz = spiderRayStart.x, spiderRayStart.y, spiderRayStart.z
    local ex, ey, ez = spiderRayEnd.x, spiderRayEnd.y, spiderRayEnd.z
    local hit, hitX, hitY, hitZ = processLineOfSight(sx, sy, sz, ex, ey, ez, true, true, false, true, false, false)

    if hit then
        spiderRayHit = Vector3(hitX, hitY, hitZ)
    end

    return spiderRayHit
end

function getSpiderWeb(hitPosition)
    local vStart = Vector3(getPedTargetStart(localPlayer))
    local vEnd = hitPosition

    local spiderRayStart = Vector3(getPedBonePosition(localPlayer, 34))
    local spiderRayOffset = Vector3(vEnd - vStart)
    local spiderRayDistance = spiderRayOffset:getLength()
    local spiderRayDir = spiderRayOffset:getNormalized()

    local vLeft, _, _, _ = unpack(getElementMatrix(localPlayer))
    vLeft = Vector3(unpack(vLeft))
    local spiderRayDirNorm = vLeft:cross(spiderRayDir)

    return spiderRayStart, spiderRayDir, spiderRayDirNorm, spiderRayDistance
end

function getSpiderWebVelocity(spiderRayDir, spiderRayDirNorm, spiderRayDistance)
    local ucoeff = 0.08
    local uucoeff = 0.008

    local fv = spiderRayDir * math.max(0.75, math.min(1, spiderRayDistance - SPIDER_WEB_LENGTH) / spiderRayDistance)
    local uv = spiderRayDirNorm
    local uuv = Vector3(0, 0, -1)

    local px, py, pz = getElementPosition(localPlayer)
    local hpz = getGroundPosition(px, py, pz)

    -- upwards velocity when low
    -- if (pz - hpz < 10) then
    --     uucoeff = -0.8
    -- else
    --     uucoeff = 0.008
    -- end

    return fv + uv * ucoeff + uuv * uucoeff
end

function setSpiderManRotation(spiderRayDir)
    local left, _, _, position = unpack(getElementMatrix(localPlayer))

    local lx, ly, lz, lw = unpack(left)
    left = Vector3(lx, ly, lz)
    local up = left:cross(spiderRayDir)

    local fx, fy, fz, fw = spiderRayDir.x, spiderRayDir.y, spiderRayDir.z, 0
    local ux, uy, uz, uw = up.x, up.y, up.z, 0

    setElementMatrix(localPlayer, {
        {lx, ly, lz, lw},
        {fx, fy, fz, fw},
        {ux, uy, uz, uw},
        position
    })
end

function shootSpiderWeb()
    local weaponId = getPedWeapon(localPlayer)

    if weaponId ~= SPIDER_WEB_WEPID then
        return
    end

    spiderRayHit = getSpiderWebHit()

    if spiderRayHit and isPedOnGround(localPlayer) then
        setElementVelocity(localPlayer, 0, 0, 0.5)
    end

    -- Debugging
    -- Expire ray after 1 second
    -- if isTimer(spiderRayTimer) then
    --     killTimer(spiderRayTimer)
    -- end

    -- spiderRayTimer = setTimer(function ()
    -- end, SPIDER_WEB_DURATION, 1)
end

bindKey("aim_weapon", "both", function (_, keyState)
    iprint("aim_weapon", keyState)
    if keyState == "down" then
        bindKey("fire", "down", shootSpiderWeb)
    else
        unbindKey("fire", "down", shootSpiderWeb)
        spiderRayHit = nil
    end
end)

addEventHandler("onClientPreRender", root, function (dt)
    if not (spiderRayHit) then
        return
    end

    local _, spiderRayDir, spiderRayDirNorm, spiderRayDistance = getSpiderWeb(spiderRayHit)
    local spiderRayVelocity = getSpiderWebVelocity(spiderRayDir, spiderRayDirNorm, spiderRayDistance) * ((2 * dt)/1000)
    local vx, vy, vz = getElementVelocity(localPlayer)
    local nvx, nvy, nvz = spiderRayVelocity.x, spiderRayVelocity.y, spiderRayVelocity.z

    setElementVelocity(localPlayer, vx + nvx, vy + nvy, vz + nvz)
    setSpiderManRotation(spiderRayDir)
end)

addEventHandler("onClientRender", root, function ()
    -- Draw aim crosshair
    if getControlState("aim_weapon") and getPedWeapon(localPlayer) == SPIDER_WEB_WEPID then
        local spiderRayStart, spiderRayDir, spiderRayLength = getSpiderRay()
        local hx, hy, hz = spiderRayStart + spiderRayDir * spiderRayLength
        local hsx, hsy = getScreenFromWorldPosition(hx, hy, hz)

        if hsx and hsy then
            dxDrawCircle(hsx, hsy, 5)
        end
    end

    -- Draw spiderweb
    if not (spiderRayHit) then
        return
    end

    local spiderRayStart, spiderRayDir, spiderRayDirNorm, spiderRayDistance = getSpiderWeb(spiderRayHit)
    local spiderRayEnd = spiderRayStart + spiderRayDir * spiderRayDistance
    local sx, sy, sz = spiderRayStart.x, spiderRayStart.y, spiderRayStart.z
    local ex, ey, ez = spiderRayEnd.x, spiderRayEnd.y, spiderRayEnd.z

    local color = tocolor(255, 255, 255)
    dxDrawLine3D(sx, sy, sz, ex, ey, ez, color)
end)

addEventHandler("onClientPlayerDamage", root, function (_, cause)
    if not (spiderRayEnabled) then
        return
    end

    if cause == 54 then
        cancelEvent()
    end
end)
