ESX = nil
local pos_before_assist,assisting,assist_target,last_assist,IsFirstSpawn = nil, false, nil, nil, true

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	SetNuiFocus(false, false)
end)

function GetIndexedPlayerList()
	local players = {}
	for k,v in ipairs(GetActivePlayers()) do
		players[tostring(GetPlayerServerId(v))]=GetPlayerName(v)..(v==PlayerId() and " (Khodam)" or "")
	end
	return json.encode(players)
end

RegisterNUICallback("ban", function(data,cb)
	if not data.target or not data.reason then return end
	ESX.TriggerServerCallback("fzadmin:ban",function(success,reason)
		if success then ESX.ShowNotification("~g~Successfully banned player") else ESX.ShowNotification(reason) end -- dont ask why i did it this way, im a bit retarded
	end, data.target, data.reason, data.length, data.offline)
end)

RegisterNUICallback("warn", function(data,cb)
	if not data.target or not data.message then return end
	ESX.TriggerServerCallback("fzadmin:warn",function(success)
		if success then ESX.ShowNotification("~g~Successfully warned player") else ESX.ShowNotification("~r~Something went wrong") end
	end, data.target, data.message, data.anon)
end)

RegisterNUICallback("unban", function(data,cb)
	if not data.id then return end
	ESX.TriggerServerCallback("fzadmin:unban",function(success)
		if success then ESX.ShowNotification("~g~Successfully unbanned player") else ESX.ShowNotification("~r~Something went wrong") end
	end, data.id)
end)

RegisterNUICallback("getListData", function(data,cb)
	if not data.list or not data.page then cb(nil); return end
	ESX.TriggerServerCallback("fzadmin:getListData",function(data)
		cb(data)
	end, data.list, data.page)
end)

RegisterNUICallback("hidecursor", function(data,cb)
	SetNuiFocus(false, false)
end)

AddEventHandler("playerSpawned", function(spawn)
    if IsFirstSpawn and Config.backup_kick_method then
        TriggerServerEvent("fzadmin:backupcheck")
        IsFirstSpawn = false
    end
end)

RegisterNetEvent("fzadmin:gotBanned")
AddEventHandler("fzadmin:gotBanned",function(rsn)
	Citizen.CreateThread(function()
		local scaleform = RequestScaleformMovie("mp_big_message_freemode")
		while not HasScaleformMovieLoaded(scaleform) do Citizen.Wait(0) end
		BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
		PushScaleformMovieMethodParameterString("~r~BANNED")
		PushScaleformMovieMethodParameterString(rsn)
		PushScaleformMovieMethodParameterInt(5)
		EndScaleformMovieMethod()
		PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS")
		ClearDrawOrigin()
		ESX.UI.HUD.SetDisplay(0)
		while true do
			Citizen.Wait(0)
			DisableAllControlActions(0)
			DisableFrontendThisFrame()
			local ped = GetPlayerPed(-1)
			ESX.UI.Menu.CloseAll()
			SetEntityCoords(ped, 0, 0, 0, 0, 0, 0, false)
			FreezeEntityPosition(ped, true)
			DrawRect(0.0,0.0,2.0,2.0,0,0,0,255)
			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
		end
		SetScaleformMovieAsNoLongerNeeded(scaleform)
	end)
end)

RegisterNetEvent("fzadmin:receiveWarn")
AddEventHandler("fzadmin:receiveWarn",function(sender,message)
	TriggerEvent("chat:addMessage",{color={255,255,0},multiline=true,args={"NewAge City","Shoma "..(sender~="" and " Az "..sender or "").." Warn Daryaft Kardid Be Dalile\n-> "..message}})
	Citizen.CreateThread(function()
		local scaleform = RequestScaleformMovie("mp_big_message_freemode")
		while not HasScaleformMovieLoaded(scaleform) do Citizen.Wait(0) end
		BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
		PushScaleformMovieMethodParameterString("~y~WARNING")
		PushScaleformMovieMethodParameterString(message)
		PushScaleformMovieMethodParameterInt(5)
		EndScaleformMovieMethod()
		PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS")
		local drawing = true
		Citizen.SetTimeout((Config.warning_screentime * 1000),function() drawing = false end)
		while drawing do
			Citizen.Wait(0)
			DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
		end
		SetScaleformMovieAsNoLongerNeeded(scaleform)
	end)
end)

RegisterNetEvent("fzadmin:requestedAssist")
AddEventHandler("fzadmin:requestedAssist",function(t)
	--SendNUIMessage({show=true,window="assistreq",data=Config.popassistformat:format(GetPlayerName(GetPlayerFromServerId(t)),t)})
	last_assist=t
end)

RegisterNetEvent("fzadmin:acceptedAssist")
AddEventHandler("fzadmin:acceptedAssist",function(t)
	if assisting then return end
	local target = GetPlayerFromServerId(t)
	if target then
		local ped = GetPlayerPed(-1)
		pos_before_assist = GetEntityCoords(ped)
		assisting = true
		assist_target = t
	end
end)

RegisterNetEvent("fzadmin:assistDone")
AddEventHandler("fzadmin:assistDone",function()
	if assisting then
		assisting = false
		if pos_before_assist~=nil then pos_before_assist = nil end
		assist_target = nil
	end
end)

RegisterNetEvent("fzadmin:hideAssistPopup")
AddEventHandler("fzadmin:hideAssistPopup",function(t)
	SendNUIMessage({hide=true})
	last_assist=nil
end)

RegisterNetEvent("fzadmin:showWindow")
AddEventHandler("fzadmin:showWindow",function(win)
	if win=="ban" or win=="warn" then
		SendNUIMessage({show=true,window=win,players=GetIndexedPlayerList()})
	elseif win=="banlist" or win=="warnlist" then
		SendNUIMessage({loading=true,window=win})
		ESX.TriggerServerCallback(win=="banlist" and "fzadmin:getBanList" or "fzadmin:getWarnList",function(list,pages)
			SendNUIMessage({show=true,window=win,list=list,pages=pages})
		end)
	end
	SetNuiFocus(true, true)
end)

RegisterCommand("dreport",function(a,b,c)
	TriggerEvent("fzadmin:hideAssistPopup")
end, false)

if Config.assist_keys.enable then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)
			if IsControlJustPressed(0, Config.assist_keys.accept) then
				if not NetworkIsPlayerActive(GetPlayerFromServerId(last_assist)) then
					last_assist = nil
				else
					TriggerServerEvent("fzadmin:acceptAssistKey",last_assist)
				end
			end
			if IsControlJustPressed(0, Config.assist_keys.decline) then
				TriggerEvent("fzadmin:hideAssistPopup")
			end
		end
	end)
end

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/dreport', 'Penhan Kardan Report Ha Dar Safe',{})
    TriggerEvent('chat:addSuggestion', '/report', 'Darkhaste Report',{{name="Reason", help="Dalil Darkhast?"}})
    TriggerEvent('chat:addSuggestion', '/creport', 'Cancel Kardan Report',{})
	TriggerEvent('chat:addSuggestion', '/fr', 'Bastan Report',{})
	TriggerEvent('chat:addSuggestion', '/unpause', 'Unpause Kardan Rppause',{})
	TriggerEvent('chat:addSuggestion', '/rppause', {{name="Zone Size", help="For Example 5"}})
    TriggerEvent('chat:addSuggestion', '/ar', 'Accept Kardan Darkhast Report', {{name="Player ID", help="ID Player"}})
end)

--- Config ---
misTxtDis = "~r~~h~Dar yek mantaghe az map RP pause ast lotfan vared mantaghe nashavid." -- Use colors from: https://gist.github.com/leonardosnt/061e691a1c6c0597d633

--- Code ---
local blips = {}
local coordsformarker = {}
function missionTextDisplay(text, time)
    ClearPrints()
    SetTextEntry_2("STRING")
    AddTextComponentString(text)
    DrawSubtitleTimed(time, 1)
end
alredypause = true
RegisterNetEvent('fzadmin:AdminAreaSet')
AddEventHandler("fzadmin:AdminAreaSet", function(blip, s)
    if s ~= nil then
        src = s
        coords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(src)))
    else
        coords = blip.coords
    end 
    coordsformarker[blip.index] =  coords
    if not blips[blip.index] then
        blips[blip.index] = {}
    end

    if not givenCoords then
        TriggerServerEvent('AdminArea:setCoords', tonumber(blip.index), coords)
    end


    blips[blip.index]["blip"] = AddBlipForCoord(coords.x, coords.y, coords.z)
    blips[blip.index]["radius"] = AddBlipForRadius(coords.x, coords.y, coords.z, blip.radius)
    SetBlipSprite(blips[blip.index].blip, blip.id)
    SetBlipAsShortRange(blips[blip.index].blip, true)
    SetBlipColour(blips[blip.index].blip, blip.color)
    SetBlipScale(blips[blip.index].blip, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blip.name)
    EndTextCommandSetBlipName(blips[blip.index].blip)
    blips[blip.index]["coords"] = coords
    blips[blip.index]["radius2"] = blip.radius
    SetBlipAlpha(blips[blip.index]["radius"], 80)
    SetBlipColour(blips[blip.index]["radius"], blip.color)

    missionTextDisplay(misTxtDis, 8000)
	blips[blip.index]["active"] = true
	while blips[blip.index]["active"] do
	Wait(0)
	if blips[blip.index] ~= nil then
	local coords = GetEntityCoords(GetPlayerPed(-1))
    local coords2 = blips[blip.index]["coords"]
    local distance = math.floor(GetDistanceBetweenCoords(coords.x, coords.y, coords.z, coords2.x, coords2.y, coords2.z,1))
	if distance > blips[blip.index]["radius2"] - 1 then
	DrawMarker(28, blips[blip.index]["coords"], 0.0, 0.0, 0.0, 0, 0.0, 0.0, blip.radius, blip.radius, blip.radius, 0,0,0, 255, false, true, 2, false, false, false, false)
	else
		rgb = RGBRainbow(1)
	DrawMarker(28, blips[blip.index]["coords"], 0.0, 0.0, 0.0, 0, 0.0, 0.0, blip.radius, blip.radius, blip.radius, rgb.r,rgb.g,rgb.b, 100, false, true, 2, false, false, false, false)
	end
	end
	end
end)

function RGBRainbow(frequency)
    local result = {}
    local curtime = GetGameTimer() / 1000

    result.r = math.floor(math.sin(curtime * frequency + 0) * 127 + 128)
    result.g = math.floor(math.sin(curtime * frequency + 2) * 127 + 128)
    result.b = math.floor(math.sin(curtime * frequency + 4) * 127 + 128)

    return result
end

RegisterNetEvent('fzadmin:AdminAreaClear')
AddEventHandler("fzadmin:AdminAreaClear", function(blipID)
    if blips[blipID] then
	blips[blipID]["active"] = false
        RemoveBlip(blips[blipID].blip)
        RemoveBlip(blips[blipID].radius)
        blips[blipID] = nil
        missionTextDisplay("RP Dar mantaghe ~o~Admin Area(" .. blipID .. ")~r~ unpause ~w~shod!", 5000)
    else
        print("There was a issue with removing blip: " .. tostring(blipID))
    end
end)

function SafeZoneText(x,y,z, text,scl) 

    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
 
    local scale = (1/dist)*scl
    local fov = (1/GetGameplayCamFov())*100
    local scale = scale*fov
   
    if onScreen then
        SetTextScale(0.0*scale, 1.1*scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString("~a~"..text)
        DrawText(_x,_y)
    end
end