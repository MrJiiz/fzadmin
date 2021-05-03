# Fz Admin System
FiveM Ban/Warning/AdminArea/Help-Assist System for ESX
## Installation
1. Download the [resource](https://github.com/MrJiiz/fzadmin)
2. Rename it to `fzadmin` and put it in your resources folder
3. Import fz.sql into your database
4. Edit the config to your liking
5. Add `start fzadmin` to your server.cfg ***Make sure to add this after mysql-async and es_extended***
6. Start it and you're good to go

## Documentation
There's a few commands this adds:

- /setada `<raduis>`<- Set admin area
- /clearada `<blipid>`<- ClearAdminArea
- /warn <- opens the warn menu
- /warnlist    <- opens the warning list
- reports     <- shows pending/active assists in the chat
- /ar `<player id>` <- admin command, admins can accept help requests from players
- /fr       <- admin command, this closes the current help request and teleports you back to your original position
- /dreport       <- admin command, this just hides the current assist popup on the screen
- /report `<reason>` <- player command, players can request help with this
- /creport         <- player command, this cancels the players ongoing assist request  



To unban someone, go to the ban list and scroll far right to the "Actions" section, you'll find a green unban button there  

## Important notes
This bans **all** players identifiers, that means their ip,license,steam,discord,xbl ids will get banned  
Offline bans ban everything that's stored in the identifier db   
If you don't like the current design (i don't blame you, i'm really not a designer), you can edit the `html/index.html` and `html/style.css` files to change the design to your liking

If find any bugs, please join my [discord server](https://discord.gg/hUNCdNhtHD) and report it in the #bug-reports channel  
If you like my work, please check out [my page](https://overwolf.xyz), i'll probably release a few more things if i have the time and feel like it
