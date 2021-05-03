ESX = nil
local blips = {}
local discord_webhook = "https://discord.com/api/webhooks/817996809392619530/jvpAYVlEatUz2U813bNTaJoYnME1D0aiWcGkUEWCd0y3UXpobgx-h6WBGnixcxpP5TCi" -- paste your discord webhook between the quotes if you want to enable discord logs.
local bancache,namecache = {},{}
local open_assists,active_assists = {},{}

function split(s, delimiter)result = {};for match in (s..delimiter):gmatch("(.-)"..delimiter) do table.insert(result, match) end return result end

Citizen.CreateThread(function() -- startup
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    while ESX==nil do Wait(0) end
    ESX.RegisterServerCallback("fzadmin:ban", function(source,cb,target,reason,length,offline)
        if not target or not reason then return end
        local xPlayer = ESX.GetPlayerFromId(source)
        local xTarget = ESX.GetPlayerFromId(target)
        if not xPlayer or (not xTarget and not offline) then cb(nil); return end
        if isAdmin(xPlayer) then
            local success, reason = banPlayer(xPlayer,offline and target or xTarget,reason,length,offline)
            cb(success, reason)
        else logUnfairUse(xPlayer); cb(false) end
    end)

    ESX.RegisterServerCallback("fzadmin:warn",function(source,cb,target,message,anon)
        if not target or not message then return end
        local xPlayer = ESX.GetPlayerFromId(source)
        local xTarget = ESX.GetPlayerFromId(target)
        if not xPlayer or not xTarget then cb(nil); return end
        if isAdmin(xPlayer) then
            warnPlayer(xPlayer,xTarget,message,anon)
            cb(true)
        else logUnfairUse(xPlayer); cb(false) end
    end)

    ESX.RegisterServerCallback("fzadmin:getWarnList",function(source,cb)
        local xPlayer = ESX.GetPlayerFromId(source)
        if isAdmin(xPlayer) then
            local warnlist = {}
            for k,v in ipairs(MySQL.Sync.fetchAll("SELECT * FROM fz_warnings LIMIT @limit",{["@limit"]=Config.page_element_limit})) do
                v.receiver_name=namecache[v.receiver]
                v.sender_name=namecache[v.sender]
                table.insert(warnlist,v)
            end
            cb(json.encode(warnlist),MySQL.Sync.fetchScalar("SELECT CEIL(COUNT(id)/@limit) FROM fz_warnings",{["@limit"]=Config.page_element_limit}))
        else logUnfairUse(xPlayer); cb(false) end
    end)

    ESX.RegisterServerCallback("fzadmin:getBanList",function(source,cb)
        local xPlayer = ESX.GetPlayerFromId(source)
        if isAdmin(xPlayer) then
            local data = MySQL.Sync.fetchAll("SELECT * FROM fz_bans LIMIT @limit",{["@limit"]=Config.page_element_limit})
            local banlist = {}
            for k,v in ipairs(data) do
                v.receiver_name = namecache[json.decode(v.receiver)[1]]
                v.sender_name = namecache[v.sender]
                table.insert(banlist,v)
            end
            cb(json.encode(banlist),MySQL.Sync.fetchScalar("SELECT CEIL(COUNT(id)/@limit) FROM fz_bans",{["@limit"]=Config.page_element_limit}))
        else logUnfairUse(xPlayer); cb(false) end
    end)

    ESX.RegisterServerCallback("fzadmin:getListData",function(source,cb,list,page)
        local xPlayer = ESX.GetPlayerFromId(source)
        if isAdmin(xPlayer) then
            if list=="banlist" then
                local banlist = {}
                for k,v in ipairs(MySQL.Sync.fetchAll("SELECT * FROM fz_bans LIMIT @limit OFFSET @offset",{["@limit"]=Config.page_element_limit,["@offset"]=Config.page_element_limit*(page-1)})) do
                    v.receiver_name = namecache[json.decode(v.receiver)[1]]
                    v.sender_name = namecache[v.sender]
                    table.insert(banlist,v)
                end
                cb(json.encode(banlist))
            else
                local warnlist = {}
                for k,v in ipairs(MySQL.Sync.fetchAll("SELECT * FROM fz_warnings LIMIT @limit OFFSET @offset",{["@limit"]=Config.page_element_limit,["@offset"]=Config.page_element_limit*(page-1)})) do
                    v.sender_name=namecache[v.sender]
                    v.receiver_name=namecache[v.receiver]
                    table.insert(warnlist,v)
                end
                cb(json.encode(warnlist))
            end
        else logUnfairUse(xPlayer); cb(nil) end
    end)

    ESX.RegisterServerCallback("fzadmin:unban",function(source,cb,id)
        local xPlayer = ESX.GetPlayerFromId(source)
        if isAdmin(xPlayer) then
            MySQL.Async.execute("UPDATE fz_bans SET unbanned=1 WHERE id=@id",{["@id"]=id},function(rc)
                local bannedidentifier = "N/A"
                for k,v in ipairs(bancache) do
                    if v.id==id then
                        bannedidentifier = v.receiver[1]
                        bancache[k].unbanned = true
                        break
                    end
                end
                logAdmin(("Admin ^1%s^7 unbanned ^1%s^7 (%s)"):format(xPlayer.getName(),(bannedidentifier~="N/A" and namecache[bannedidentifier]) and namecache[bannedidentifier] or "N/A",bannedidentifier))
                cb(rc>0)
            end)
        else logUnfairUse(xPlayer); cb(false) end
    end)
    MySQL.ready(function()
        refreshNameCache()
        refreshBanCache()
    end)
    
end)

RegisterServerEvent('fzadmin:backupcheck')
AddEventHandler('fzadmin:backupcheck', function()
    local identifiers = GetPlayerIdentifiers(source)
    local banned = isBanned(identifiers)
    if banned then
        DropPlayer(source, "Ban bypass detected, don’t join back!")
    end
end)

AddEventHandler("playerConnecting",function(name, setKick, def)
    local identifiers = GetPlayerIdentifiers(source)
    if #identifiers>0 and identifiers[1]~=nil then
        local banned, data = isBanned(identifiers)
        namecache[identifiers[1]]=GetPlayerName(source)
        if banned then
            print(("[^1"..GetCurrentResourceName().."^7] Banned player %s (%s) tried to join, their ban expires on %s (Ban ID: #%s)"):format(GetPlayerName(source),data.receiver[1],data.length and os.date("%Y-%m-%d %H:%M",data.length) or "PERMANENT",data.id))
            local kickmsg = Config.banformat:format(data.reason,data.length and os.date("%Y-%m-%d %H:%M",data.length) or "PERMANENT",data.sender_name,data.id)
            if Config.backup_kick_method then DropPlayer(source,kickmsg) else def.done(kickmsg) end
        else
            local data = {["@name"]=GetPlayerName(source)}
            for k,v in ipairs(identifiers) do
                data["@"..split(v,":")[1]]=v
            end
            if not data["@steam"] then
	        if Config.kick_without_steam then
		    print("[^1"..GetCurrentResourceName().."^7] Player connecting without steamid, removing player from server.")
		    def.done("You need to have steam open to play on this server.")
		else
                    print("[^1"..GetCurrentResourceName().."^7] Player connecting without steamid, skipping identifier storage.")
		end
            else
                MySQL.Async.execute("INSERT INTO `fz_identifiers` (`steam`, `license`, `ip`, `name`, `xbl`, `live`, `discord`, `fivem`) VALUES (@steam, @license, @ip, @name, @xbl, @live, @discord, @fivem) ON DUPLICATE KEY UPDATE `license`=@license, `ip`=@ip, `name`=@name, `xbl`=@xbl, `live`=@live, `discord`=@discord, `fivem`=@fivem",data)
            end
        end
    else
        if Config.backup_kick_method then DropPlayer(source,"[ZedLife RP] No identifiers were found when connecting, please reconnect") else def.done("[ZedLife RP] No identifiers were found when connecting, please reconnect") end
    end
end)

AddEventHandler("playerDropped",function(reason)
    if open_assists[source] then open_assists[source]=nil end
    for k,v in ipairs(active_assists) do
        if v==source then
            active_assists[k]=nil
            TriggerClientEvent("chat:addMessage",k,{color={255,0,0},multiline=false,args={"ZedLife RP","Admini Ke Be Shoma Report Shoma Residegi Mikard Az Server Disconnect Shod"}})
            return
        elseif k==source then
            TriggerClientEvent("fzadmin:assistDone",v)
            TriggerClientEvent("chat:addMessage",v,{color={255,0,0},multiline=false,args={"ZedLife RP","Playeri Ke Reportesh Residegi Mikardid Az Server Disconnect Shod, Dar Hale Teleport Shodan Be Makane Ghabli..."}})
            active_assists[k]=nil
            return
        end
    end
end)

function refreshNameCache()
    namecache={}
    for k,v in ipairs(MySQL.Sync.fetchAll("SELECT steam,name FROM fz_identifiers")) do
        namecache[v.steam]=v.name
    end
end

function refreshBanCache()
    bancache={}
    for k,v in ipairs(MySQL.Sync.fetchAll("SELECT id,receiver,sender,reason,UNIX_TIMESTAMP(length) AS length,unbanned FROM fz_bans")) do
        table.insert(bancache,{id=v.id,sender=v.sender,sender_name=namecache[v.sender]~=nil and namecache[v.sender] or "N/A",receiver=json.decode(v.receiver),reason=v.reason,length=v.length,unbanned=v.unbanned==1})
    end
end

function sendToDiscord(msg)
    if discord_webhook ~= "" then
        PerformHttpRequest(discord_webhook, function(a,b,c)end, "POST", json.encode({embeds={{title="ZedLife RP Admin Activity",description=msg:gsub("%^%d",""),color=65280,}}}), {["Content-Type"]="application/json"})
    end
end

function logAdmin(msg)
    for k,v in ipairs(ESX.GetPlayers()) do
        if isAdmin(ESX.GetPlayerFromId(v)) then
		    
            TriggerClientEvent("chat:addMessage",v,{
			template = '<div class="chat-message"> {0}</div>',
      args = { msg}})
            sendToDiscord(msg)
        end
    end
end

function isBanned(identifiers)
    for _,ban in ipairs(bancache) do
        if not ban.unbanned and (ban.length==nil or ban.length>os.time()) then
            for _,bid in ipairs(ban.receiver) do
                for _,pid in ipairs(identifiers) do
                    if bid==pid then return true, ban end
                end
            end
        end
    end
    return false, nil
end

function isAdmin(xPlayer)
        if xPlayer.permission_level>0 then return true end
    return false
end

function execOnAdmins(func)
    local ac = 0
    for k,v in ipairs(ESX.GetPlayers()) do
        if isAdmin(ESX.GetPlayerFromId(v)) then
            ac = ac + 1
            func(v)
        end
    end
    return ac
end

function logUnfairUse(xPlayer)
    if not xPlayer then return end
    print(("[^1"..GetCurrentResourceName().."^7] Player %s (%s) tried to use an admin feature"):format(xPlayer.getName(),xPlayer.identifier))
    logAdmin(("Player %s (%s) tried to use an admin feature"):format(xPlayer.getName(),xPlayer.identifier))
end

function banPlayer(xPlayer,xTarget,reason,length,offline)
    local targetidentifiers,offlinename,timestring,data = {},nil,nil,nil
    if offline then
        data = MySQL.Sync.fetchAll("SELECT * FROM fz_identifiers WHERE steam=@identifier",{["@identifier"]=xTarget})
        if #data<1 then
            return false, "~r~Identifier is not in identifiers database!"
        end
        offlinename = data[1].name
        for k,v in pairs(data[1]) do
            if k~="name" then table.insert(targetidentifiers,v) end
        end
    else
        targetidentifiers = GetPlayerIdentifiers(xTarget.source)
    end
    if length=="" then length = nil end
    MySQL.Async.execute("INSERT INTO fz_bans(id,receiver,sender,length,reason) VALUES(NULL,@receiver,@sender,@length,@reason)",{["@receiver"]=json.encode(targetidentifiers),["@sender"]=xPlayer.identifier,["@length"]=length,["@reason"]=reason},function(_)
        local banid = MySQL.Sync.fetchScalar("SELECT MAX(id) FROM fz_bans")
        logAdmin(("Player ^1%s^7 (%s) got banned by ^1%s^7, expiration: %s, reason: '%s'"..(offline and " (OFFLINE BAN)" or "")):format(offline and offlinename or xTarget.getName(),offline and data[1].steam or xTarget.identifier,xPlayer.getName(),length~=nil and length or "PERMANENT",reason))
        if length~=nil then
            timestring=length
            local year,month,day,hour,minute = string.match(length,"(%d+)/(%d+)/(%d+) (%d+):(%d+)")
            length = os.time({year=year,month=month,day=day,hour=hour,min=minute})
        end
        table.insert(bancache,{id=banid==nil and "1" or banid,sender=xPlayer.identifier,reason=reason,sender_name=xPlayer.getName(),receiver=targetidentifiers,length=length})
        if offline then xTarget = ESX.GetPlayerFromIdentifier(xTarget) end -- just in case the player is on the server, you never know
        if xTarget then
            TriggerClientEvent("fzadmin:gotBanned",xTarget.source, reason)
            Citizen.SetTimeout(5000, function()
                DropPlayer(xTarget.source,Config.banformat:format(reason,length~=nil and timestring or "PERMANENT",xPlayer.getName(),banid==nil and "1" or banid))
            end)
        else return false, "~r~Unknown error (MySQL?)" end
        return true, ""
    end)
end

function warnPlayer(xPlayer,xTarget,message,anon)
    MySQL.Async.execute("INSERT INTO fz_warnings(id,receiver,sender,message) VALUES(NULL,@receiver,@sender,@message)",{["@receiver"]=xTarget.identifier,["@sender"]=xPlayer.identifier,["@message"]=message})
    TriggerClientEvent("fzadmin:receiveWarn",xTarget.source,anon and "" or GetPlayerName(xPlayer.source),message)
    logAdmin(("Admin ^1%s^7 Be ^1%s^7 (%s) Warn Dad Be Dalile: '%s'"):format(GetPlayerName(xPlayer.source),GetPlayerName(xTarget.source),xTarget.identifier,message))
end

AddEventHandler("fzadmin:ban",function(sender,target,reason,length,offline)
    if source=="" then -- if it's from server only
        banPlayer(sender,target,reason,length,offline)
    end
end)

AddEventHandler("fzadmin:warn",function(sender,target,message,anon)
    if source=="" then -- if it's from server only
        warnPlayer(sender,target,message,anon)
    end
end)

RegisterCommand("report", function(source, args, rawCommand)
    local reason = table.concat(args," ")
    if reason=="" or not reason then TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Lotfan Dalil Khod Ra Benevisid"}}); return end
    if not open_assists[source] and not active_assists[source] then
        local ac = execOnAdmins(function(admin) 
		TriggerClientEvent("fzadmin:requestedAssist",admin,source); 
					 TriggerClientEvent('chat:addMessage', admin, {
      template = '<div class="chat-message report">^1Report: ^2{0} ({1}) \n^4Dalil^7: {2} ^2/ar {1}^7 Baraye Accept</div>',
      args = { GetPlayerName(source), source,reason}
    }) end)
        if ac>0 then
            open_assists[source]=reason
            Citizen.SetTimeout(120000,function()
                if open_assists[source] then 
				open_assists[source]=nil 
                if GetPlayerName(source)~=nil then
                    TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Reporte Shoma Monghazi Shod"}})
                end
				end
            end)

            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"ZedLife RP","Report Shoma Ersal Shod Va (120 Saniye) Digar Monghazi Mishavad, Baraye Cancel Kardan Report ^1/creport^7 Benevisid"}})
        else
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Admini Toye Server Online Nist"}})
        end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Kasi Dar Hale Baresi Report Shoma Hast Ya Shoma Report Dar Hale Anjam Darid"}})
    end
end)

RegisterCommand("creport", function(source, args, rawCommand)
    if open_assists[source] then
        open_assists[source]=nil
        TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"ZedLife RP","Darkhaste Shoma Cancel Shod"}})
        execOnAdmins(function(admin) TriggerClientEvent("fzadmin:hideAssistPopup",admin) end)
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Dar Hale Hazer Shoma Darkhasti Nadarid"}})
    end
end)

RegisterCommand("rd", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
        local found = false
		local message = table.concat(args, " ",1)
        for k,v in pairs(active_assists) do

		--v admin k player
            if v==source then
			found = true
                TriggerClientEvent('chat:addMessage', k, {
						template = '<div class="chat-message police">^1Admin {0}: {1}</div>',
						args = {GetPlayerName(source),message}
					})
					TriggerClientEvent('chat:addMessage', v, {
						template = '<div class="chat-message police">^1Admin {0}: {1}</div>',
						args = {GetPlayerName(source),message}
					})
				
            
			elseif k==source then
			found = true
			TriggerClientEvent('chat:addMessage', v, {
						template = '<div class="chat-message police"> {0}: {1}</div>',
						args = {GetPlayerName(source),message}
					})
					TriggerClientEvent('chat:addMessage', k, {
						template = '<div class="chat-message police"> {0}: {1}</div>',
						args = {GetPlayerName(source),message}
					})
			end
		end
        if not found then TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Shoma Be Darhale Residegi Be Report Nistid"}}) end
end)


RegisterCommand("fr", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
        local found = false
        for k,v in pairs(active_assists) do
            if v==source then
                found = true
                active_assists[k]=nil
                TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=false,args={"ZedLife RP","Reporti Ke Dar Hale Residegi Bodid Baste Shod"}})
                TriggerClientEvent("fzadmin:assistDone",source)
            end
        end
        if not found then TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Shoma Be Darhale Residegi Be Report Nistid"}}) end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Shoma Dastresi Be In Command Ra Nadarid!"}})
    end
end)

RegisterCommand("reports", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
	        local openassistsmsg,activeassistsmsg = "",""
            for k,v in pairs(open_assists) do
                openassistsmsg=openassistsmsg.."^5ID "..k.." ("..GetPlayerName(k)..")^7 - "..v.."\n"
            end
            for k,v in pairs(active_assists) do
                activeassistsmsg=activeassistsmsg.."^5ID "..k.." ("..GetPlayerName(k)..")^7 - "..v.." ("..GetPlayerName(v)..")\n"
            end
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=true,args={"ZedLife RP","Report Haye Anjam Nashode:\n"..(openassistsmsg~="" and openassistsmsg or "^1Reporti Vojod Nadarad")}})
            TriggerClientEvent("chat:addMessage",source,{color={0,255,0},multiline=true,args={"ZedLife RP","Report Haye Dar Hale Anjam:\n"..(activeassistsmsg~="" and activeassistsmsg or "^1Reporti Dar Hale Anjam Nist")}})
	end
end)

RegisterCommand("warn", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
	  TriggerClientEvent("fzadmin:showWindow",source,"warn")
	end
end)

RegisterCommand("warnlist", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if isAdmin(xPlayer) then
	  TriggerClientEvent("fzadmin:showWindow",source,"warnlist")
	end
end)


function acceptAssist(xPlayer,target)
    if isAdmin(xPlayer) then
        local source = xPlayer.source
        for k,v in pairs(active_assists) do
            if v==source then
                TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Shoma Dar Hale Anjame Report Hastid"}})
                return
            end
        end
        if open_assists[target] and not active_assists[target] then
            open_assists[target]=nil
            active_assists[target]=source
            TriggerClientEvent("fzadmin:acceptedAssist",source,target)
            TriggerClientEvent("fzadmin:hideAssistPopup",source)
            TriggerClientEvent("chat:addMessage",target,{color={0,255,0},multiline=false,args={"ZedLife RP",GetPlayerName(xPlayer.source).." Darkhaste Report Shomara Ghabol Kard ^1Baraye Sohbat Kardan Az /rd Estefade Konid"}})
			sendToDiscord(GetPlayerName(xPlayer.source).." Darkhaste Reporte ("..target..") Ra Ghabol Kard")
			logAdmin('^1'..GetPlayerName(xPlayer.source).." ^7Darkhaste Reporte ("..target..") Ra Ghabol Kard")
        elseif not open_assists[target] and active_assists[target] and active_assists[target]~=source then
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Kasi Darhale Residegi Be Reporte In Player Hast"}})
        else
            TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Player Ba In Id Darkhast Nadade Ast"}})
        end
    else
        TriggerClientEvent("chat:addMessage",source,{color={255,0,0},multiline=false,args={"ZedLife RP","Shoma Dastresi Be In Command Ra Nadarid!"}})
    end
end

RegisterCommand("ar", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    local target = tonumber(args[1])
    acceptAssist(xPlayer,target)
end)
RegisterServerEvent("fzadmin:acceptAssistKey")
AddEventHandler("fzadmin:acceptAssistKey",function(target)
    if not target then return end
    local _source = source
    acceptAssist(ESX.GetPlayerFromId(_source),target)
end)

RegisterServerEvent("AdminArea:setCoords")
AddEventHandler("AdminArea:setCoords", function(id, coords)

    if not coords then return end
    
    if blips[id] then
        blips[id].coords = coords
    else
        print("Exception happened blip id: " .. tostring(id) .. " does not exist")
    end

end)

RegisterCommand('setada', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.permission_level > 1 then

        if xPlayer.permission_level > 1 then
            local radius = tonumber(args[1])
            if radius then radius = radius / 1.0 else radius = 80.0 end
            local index = math.floor(TableLength() + 1)
            local blip = {id = 269, name = "Admin Area(" .. index .. ")", radius = radius, color = 3, index = tostring(index), coords = 0}
            table.insert(blips, blip)
            TriggerClientEvent("fzadmin:AdminAreaSet", -1, blip, source)
        else
            TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma nemitavanid dar halat ^1OffDuty ^0az command haye admini estefade konid!")
        end

    else
        TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma admin nistid!")
    end
end)

RegisterCommand('clearada', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer.permission_level > 1 then

        if xPlayer.permission_level > 1 then

            if args[1] then
                if tonumber(args[1]) then
                    local blipID = tonumber(args[1])

                    if findArea(blipID) then
                        TriggerClientEvent("fzadmin:AdminAreaClear", -1, tostring(blipID))
                        SRemoveBlip(blipID)
                    else
                        TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Blip ID vared shode eshtebah ast!")
                    end

                else
                    TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma dar ghesmat ID blip faghat mitavanid adad vared konid!")
                end
            else
                TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma dar ghesmat ID blip chizi vared nakardid!")
            end
              
        else
              TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma nemitavanid dar halat ^1OffDuty ^0az command haye admini estefade konid!")
        end

    else
        TriggerClientEvent('chatMessage', source, "[SYSTEM]", {255, 0, 0}, " ^0Shoma admin nistid!")
    end
end)

AddEventHandler('esx:playerLoaded', function(source)
    
    if #blips ~= 0 then
        for k,v in pairs(blips) do
            if v.coords ~= 0 then
                TriggerClientEvent("fzadmin:AdminAreaSet", source, v)
            end
        end
    end

end)

function findArea(areaID)
    for k,v in pairs(blips) do
        if k == areaID then
            return true
        end
    end

    return false
end

function SRemoveBlip(areaID)
    blips[areaID] = nil
end

function TableLength()

    if #blips == 0 then
        return 0
    else
        return blips[#blips].index
    end

end