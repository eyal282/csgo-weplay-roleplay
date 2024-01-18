#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <basecomm>
#include <Eyal-RP>

#define PLUGIN_VERSION "1.0"

enum struct enWeapons
{
	char WeaponName[32];
	char WeaponClassname[32];
}

enWeapons Weapons[] =
{
	{ "No Weapons", "weapon_null" },
	{ "Anything", "weapon_custom" },
	{ "Knife", "weapon_knife" },
	{ "M4A4", "weapon_m4a1" },
	{ "AK47", "weapon_ak47" },
	{ "AWP", "weapon_awp" },
	{ "Scout", "weapon_ssg08" },
	{ "Auto Noob", "weapon_scar20" }
	
}

int HealthValues[] =
{
	1,
	25,
	50,
	55,
	65,
	100,
	105,
	110,
	115,
	120,
	130,
	140,
	150,
	175,
	200,
	250,
	300,
	350,
	400,
	450,
	500,
	750,
	1000
}

new bool:g_bParticipant[MAXPLAYERS + 1];
new bool:g_bHost[MAXPLAYERS + 1];
new bool:g_bBlind[MAXPLAYERS + 1];

enum struct enEvent
{
	float Origin[3]; 			// Location of the event ( teleport all players here )
	bool bFreeze; 				// Freeze players upon joining?
	char WeaponName[32]; 	// Weapon Name.
	char WeaponClassname[32]; 	// Weapon classname or weapon_null for disarmed.
	int Health;					// Player health after the event starts
	bool bHeadshots;			// Headshot only enabled or disabled? ( For knife it means backstabs )
	bool bOnlySeeHost;			// If true, players will not see eachother*
	bool bInvitesRolled;		// Have we sent invites to all players?
	bool bStarted;				// Has the event started yet?
}
// * Useful for blind cow, where you want high FPS and no visual blocks.

enEvent eEvent;

public Plugin:myinfo = 
{
	name = "[CS:GO] RolePlay Event Manager",
	author = "Author was lost, heavy edit by Eyal282",
	description = "",
	version = PLUGIN_VERSION,
	url = "N/A"
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_EventManager");
	
	CreateNative("RP_IsUserInEvent", Native_Event);
}

public Native_Event(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(23, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(23, "Client %d is not connected", client);
	}
	return g_bParticipant[client] || g_bHost[client];
}
public OnPluginStart()
{	
	RegAdminCmd("sm_addpart", Command_AddPart, ADMFLAG_CHEATS, "[RolePlay] Adds a participant to the event");
	RegAdminCmd("sm_addhost", Command_AddHost, ADMFLAG_CHEATS, "[RolePlay] Adds a host to the event");
	
	RegAdminCmd("sm_event", Command_Event, ADMFLAG_CHEATS);
	RegAdminCmd("sm_eventblind", Command_EventBlind, ADMFLAG_CHEATS);
	RegAdminCmd("sm_muteevent", Command_MuteEvent, ADMFLAG_CHEATS);
	RegAdminCmd("sm_unmuteevent", Command_UnmuteEvent, ADMFLAG_CHEATS);
	
	RegConsoleCmd("sm_je", Command_JoinEvent);
	RegConsoleCmd("sm_joinevent", Command_JoinEvent);
	RegConsoleCmd("sm_unje", Command_UnjoinEvent);
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	HookEvent("weapon_reload", Event_WeaponFireOnEmpty, EventHookMode_Post);
	HookEvent("weapon_fire_on_empty", Event_WeaponFireOnEmpty, EventHookMode_Post);
	
	AddMultiTargetFilter("@event", TargetFilter_Event, "all players in the event", false);
	AddMultiTargetFilter("@host", TargetFilter_Host, "all hosts in the event", false);
	AddMultiTargetFilter("@hosts", TargetFilter_Host, "all hosts in the event", false);
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		Func_OnClientPutInServer(i);
	}
}


public bool:TargetFilter_Event(const char[] pattern, Handle clients)
{	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(g_bParticipant[i])
			PushArrayCell(clients, i);
	}
	
	return true;
}


public bool:TargetFilter_Host(const char[] pattern, Handle clients)
{	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(g_bHost[i])
			PushArrayCell(clients, i);
	}
	
	return true;
}



public OnPluginEnd()
{
	RemoveMultiTargetFilter("@event", TargetFilter_Event);
	RemoveMultiTargetFilter("@host", TargetFilter_Host);
	RemoveMultiTargetFilter("@hosts", TargetFilter_Host);
}

public OnMapStart()
{
	eEvent.Health = 100;
	eEvent.WeaponName = Weapons[0].WeaponName
	eEvent.WeaponClassname = Weapons[0].WeaponClassname
	
	eEvent.Origin = NULL_VECTOR;
}


public Action:RolePlay_OnKarmaChanged(client, &karma, String:Reason[])
{
	if(g_bParticipant[client] || g_bHost[client])
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	Func_OnClientPutInServer(client);
}

Func_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, SDK_TraceAttack);
	SDKHook(client, SDKHook_WeaponCanUse, SDK_WeaponCanUse);
	SDKHook(client, SDKHook_SetTransmit, SDK_SetTransmit);
	
	g_bParticipant[client] = false;
	g_bHost[client] = false;
}

public Action:SDK_SetTransmit(client, viewer)
{
	if(!eEvent.bStarted)
		return Plugin_Continue;
	
	else if(client == viewer)
		return Plugin_Continue;
		
	else if(!IsPlayer(viewer))
		return Plugin_Continue; 
	
	else if(g_bBlind[viewer] && g_bParticipant[client])
		return Plugin_Handled;
		
	else if(g_bHost[client] && !g_bHost[viewer] && !g_bParticipant[viewer])
		return Plugin_Handled;
		
	// If one is participant and other is not
	else if((g_bParticipant[client] && !g_bParticipant[viewer]) || !g_bParticipant[client] && g_bParticipant[viewer])
	{
		if(!g_bHost[client] && !g_bHost[viewer])
			return Plugin_Handled;
			
		else
			return Plugin_Continue;
	}
		
	else if(g_bParticipant[client] && g_bParticipant[viewer] && eEvent.bOnlySeeHost)
		return Plugin_Handled;
	
	return Plugin_Continue;
		
}

public Action:SDK_TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if(!eEvent.bStarted)
		return Plugin_Continue;

	else if(g_bHost[victim])
	{
		damage = 0.0;
		return Plugin_Stop;
	}
	
	else if(g_bHost[attacker] && !g_bParticipant[victim])
		return Plugin_Stop;
		
	else if(!g_bHost[attacker] && ((g_bParticipant[attacker] && !g_bParticipant[victim]) || !g_bParticipant[attacker] && g_bParticipant[victim]))
	{
		damage = 0.0;
		return Plugin_Stop;
	}
	
	else if(!g_bParticipant[victim])
		return Plugin_Continue;
	
	
	new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return Plugin_Continue;
		
	new String:Classname[32];
	
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if (eEvent.bHeadshots && hitgroup != 1 && !StrEqual(Classname, "weapon_knife"))
	{
		damage = 0.0;
		return Plugin_Stop;
	}
	else if(eEvent.bHeadshots && StrEqual(Classname, "weapon_knife"))
	{	
		if(damage < 69) // Knife should deal 76 max.
		{
			damage = 0.0;
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action:SDK_WeaponCanUse(client, weapon)
{
	if(!eEvent.bStarted)
		return Plugin_Continue;
	
	else if(!g_bParticipant[client])
		return Plugin_Continue;
	
	else if(StrEqual(eEvent.WeaponClassname, "weapon_custom"))
		return Plugin_Continue;
		
	new String:Classname[64];
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!StrEqual(Classname, eEvent.WeaponClassname))
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action:CS_OnCSWeaponDrop(client, weapon)
{
	if(g_bParticipant[client])
		return Plugin_Stop;
		
	return Plugin_Continue;

}

public Action:Command_JoinEvent(client, args)
{
	if(!RP_IsClientInRP(client))
	{
		RP_PrintToChat(client, "Cannot join an event from Admin Room, Duels or Arena");
		return Plugin_Handled;
	}
	else if (!eEvent.bInvitesRolled)
	{
		RP_PrintToChat(client, "Event registration has not started.");
		return Plugin_Handled;
	}
	else if (g_bParticipant[client])
	{
		RP_PrintToChat(client, "You are already registered to the event.");
		return Plugin_Handled;
	}

	RP_PrintToChat(client, "You are now registered to the event.");
	
	AddClientAsParticipant(client);
	
	return Plugin_Handled;
}

public Action:Command_UnjoinEvent(client, args)
{
	if (!eEvent.bInvitesRolled)
	{
		RP_PrintToChat(client, "Event registration has not started.");
		return Plugin_Handled;
	}
	else if (!g_bParticipant[client])
	{
		RP_PrintToChat(client, "You are already not registered to the event.");
		return Plugin_Handled;
	}

	RP_PrintToChat(client, "You are no longer registered to the event.");

	ForcePlayerSuicide(client);
	
	return Plugin_Handled;
}

public Action:Command_AddPart(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addpart <#userid|name>");
		return Plugin_Handled;
	}

	char ArgString[64];
	GetCmdArgString(ArgString, sizeof(ArgString));
	char target_name[MAX_TARGET_LENGTH];
	int [] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;
	
	
	target_count = ProcessTargetString(
					ArgString,
					client,
					target_list,
					MaxClients+1,
					COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
					target_name,
					sizeof(target_name),
					tn_is_ml);

	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		
		AddClientAsParticipant(target);
	}
	
	RP_PrintToChat(client, "\x04You \x01just added \x05%s \x01to the event!", target_name);

	return Plugin_Handled;
}

public Action:Command_AddHost(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addhost <#userid|name>");
		return Plugin_Handled;
	}

	char ArgString[64];
	GetCmdArgString(ArgString, sizeof(ArgString));
	char target_name[MAX_TARGET_LENGTH];
	int [] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;
	
	
	target_count = ProcessTargetString(
					ArgString,
					client,
					target_list,
					MaxClients+1,
					COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
					target_name,
					sizeof(target_name),
					tn_is_ml);

	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		
		AddClientAsHost(target);
	}
	
	RP_PrintToChat(client, "\x04You \x01just added \x05%s \x01as an event host!", target_name);

	return Plugin_Handled;
}


public Action:Command_EventBlind(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_eventblind <#userid|name>");
		return Plugin_Handled;
	}

	char ArgString[64];
	GetCmdArgString(ArgString, sizeof(ArgString));
	char target_name[MAX_TARGET_LENGTH];
	int [] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;
	
	
	target_count = ProcessTargetString(
					ArgString,
					client,
					target_list,
					MaxClients+1,
					COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_IMMUNITY,
					target_name,
					sizeof(target_name),
					tn_is_ml);

	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(int i = 0; i < target_count; i++)
	{
		int target = target_list[i];
		
		if(!g_bHost[target])
		{
			RP_PrintToChat(client, "This command can only be used on event hosts!");
			
			return Plugin_Handled;
		}
		g_bBlind[target] = !g_bBlind[target];
		
		if(g_bBlind[target])
			PrintToChatEvent("%s %N is now blind for other players!", target);
			
		else	
			PrintToChatEvent("%s %N is now able to see other players!", target);
	}

	return Plugin_Handled;
}

public Action:Command_MuteEvent(client, args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !BaseComm_IsClientMuted(i) && IsPlayerAlive(i) && g_bParticipant[client] && !g_bHost[client])
		{
			if (!CheckCommandAccess(i, "sm_cca_root", ADMFLAG_ROOT, true))
			{
				SetClientListeningFlags(i, VOICE_MUTED);
			}
		}
	}
		
	PrintToChatEvent("%s %N muted all players in the event!", client);
}

public Action:Command_UnmuteEvent(client, args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !BaseComm_IsClientMuted(i) && IsPlayerAlive(i) && g_bParticipant[client] && !g_bHost[client])
		{
			if (!CheckCommandAccess(i, "sm_cca_root", ADMFLAG_ROOT, true))
			{
				SetClientListeningFlags(i, VOICE_NORMAL);
			}
		}
	}
		
	PrintToChatEvent("%s %N unmuted all players in the event!", client);
}
public Action:Command_Event(client, args)
{
	new Menu:menu = CreateMenu(EventMenu_Handler);

	new String:TempFormat[64];
	
	FormatEx(TempFormat, sizeof(TempFormat), "Set Teleport Position");
	AddMenuItem(menu, "", TempFormat);

	FormatEx(TempFormat, sizeof(TempFormat), "Freeze players: %s", eEvent.bFreeze ? "ON" : "OFF");
	AddMenuItem(menu, "", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Event Weapon: %s", eEvent.WeaponName);
	AddMenuItem(menu, "new menu", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Health: %i", eEvent.Health);
	AddMenuItem(menu, "new menu", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Headshot Only: %s", eEvent.bHeadshots ? "ON" : "OFF");
	AddMenuItem(menu, "", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Players see: %s\n ", eEvent.bOnlySeeHost ? "Event Host" : "Everyone");
	AddMenuItem(menu, "", TempFormat);
	
	if(eEvent.bInvitesRolled)
		AddMenuItem(menu, "start", "START THE EVENT!!!");
		
	else if(eEvent.bStarted)
		AddMenuItem(menu, "end", "Terminate the Event.");
		
	else
		AddMenuItem(menu, "invite", "Invite Everybody!");
	
	RP_SetMenuTitle(menu, "Menu - Event Menu\n ");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public EventMenu_Handler(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
		
	else if (action == MenuAction_Select)
	{		
		new String:szInfo[32]
		GetMenuItem(menu, item, szInfo, sizeof(szInfo));
		
		switch(item)
		{
			case 0:
			{
				GetEntPropVector(client, Prop_Data, "m_vecOrigin", eEvent.Origin);
				
				RP_PrintToChat(client, "Successfully set teleport position to your position.")
			}
			
			case 1:
			{
				eEvent.bFreeze = !eEvent.bFreeze;
				
				RP_PrintToChat(client, "Sucessfully %s player freeze on event join!", eEvent.bFreeze ? "Enabled" : "Disabled");
			}
			
			case 2:
			{
				ShowWeaponsMenu(client);
			}
			
			case 3:
			{
				ShowHealthMenu(client);
			}
			
			case 4:
			{
				eEvent.bHeadshots = !eEvent.bHeadshots;
				
				RP_PrintToChat(client, "Sucessfully %s headshot only!", eEvent.bHeadshots ? "Enabled" : "Disabled");
			}
			
			case 5:
			{
				eEvent.bOnlySeeHost = !eEvent.bOnlySeeHost;
				
				RP_PrintToChat(client, "Players will now %s!", eEvent.bOnlySeeHost ? "only see the host" : "see everyone");
			}
			
			case 6:
			{
				if(StrEqual(szInfo, "start"))
				{
					if(eEvent.bInvitesRolled)
					{
						eEvent.bStarted = true;
						eEvent.bInvitesRolled = false;
						
						PrintToChatAll("THE EVENT HAS STARTED!");
						PrintToChatEvent("%s\x03 Headshot only\x01 mode is\x04 %s!", eEvent.bHeadshots ? "Enabled" : "Disabled");
						
						for (new i = 1; i <= MaxClients;i++)
						{
							if(!IsClientInGame(i))
								continue;
								
							else if(!g_bParticipant[i])
								continue;
								
							else if(!IsPlayerAlive(i))
							{
								g_bParticipant[i] = false;
								
								continue;
							}
							
							SetEntityHealth(i, eEvent.Health);
							SetEntityMaxHealth(i, 1); // Blocks all healings.
							
							SetEntityMoveType(i, MOVETYPE_WALK);
							RP_SetClientJob(i, -1);
							
							if(!StrEqual(eEvent.WeaponClassname, "weapon_null") && !StrEqual(eEvent.WeaponClassname, "weapon_custom"))
								GivePlayerItem(i, eEvent.WeaponClassname);
						}
					}
					else
					{
						RP_PrintToChat(client, "You cannot start the event unless invites were rolled!")
					}
				}
				else if(StrEqual(szInfo, "end"))
				{
					eEvent.bStarted = false;
					eEvent.bInvitesRolled = false;
					
					for (new i = 1; i <= MaxClients;i++)
					{
						if(!IsClientInGame(i))
							continue;
							
						g_bHost[i] = false;
						g_bBlind[i] = false;
						
						if(IsPlayerAlive(i))
							SetEntityRenderColor(client, 255, 255, 255, 255);
							
						if(!g_bParticipant[i])
							continue;
							
						g_bParticipant[i] = false;
						
						
						
						if(!IsPlayerAlive(i))	
							continue;
						
						SetEntityMaxHealth(i, 100); // Safety only.
						SetEntityHealth(i, 100);
						RemoveAllWeapons(i);
					
						CS_RespawnPlayer(i);
					}
					
					eEvent.Origin = NULL_VECTOR;
					
					PrintToChatAll("THE EVENT HAS ENDED!");
					
				}
				else
				{
					if(!IsEmptyVector(eEvent.Origin))
					{
						eEvent.bInvitesRolled = true;
					
						AddClientAsHost(client);
						
						PrintToChatAll("THE EVENT IS BEING PREPARED!");
						PrintToChatAll("Use !je to join the event!");
					}
					else
					{
						RP_PrintToChat(client, "You need to setup a teleport position for the event!");
					}
				}
			}
		}
		
		if(!StrEqual(szInfo, "new menu"))
			Command_Event(client, 0);
		
	}
}

ShowWeaponsMenu(client)
{
	new Menu:menu = CreateMenu(WeaponsMenu_Handler);
	
	for (new i = 0; i < sizeof(Weapons);i++)
		AddMenuItem(menu, "", Weapons[i].WeaponName);

	RP_SetMenuTitle(menu, "Menu - Event Menu\n Choose a weapon the players will get when the event starts!");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public WeaponsMenu_Handler(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
		
	else if (action == MenuAction_Select)
	{
		FormatEx(eEvent.WeaponClassname, sizeof(enEvent::WeaponClassname), Weapons[item].WeaponClassname);
		FormatEx(eEvent.WeaponName, sizeof(enEvent::WeaponName), Weapons[item].WeaponName);
		
		Command_Event(client, 0);
	}
}


ShowHealthMenu(client)
{
	new Menu:menu = CreateMenu(HealthMenu_Handler);
	
	for (new i = 0; i < sizeof(HealthValues);i++)
	{
		new String:szInfo[11];
		
		IntToString(HealthValues[i], szInfo, sizeof(szInfo));
		
		AddMenuItem(menu, szInfo, szInfo);
	}

	RP_SetMenuTitle(menu, "Menu - Event Menu\n Choose how much health participants will get!");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public HealthMenu_Handler(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
		
	else if (action == MenuAction_Select)
	{
		new String:szInfo[32]
		GetMenuItem(menu, item, szInfo, sizeof(szInfo));
		
		eEvent.Health = StringToInt(szInfo);
		
		Command_Event(client, 0);
	}
}


public Action:Event_WeaponFireOnEmpty(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{	
	if(!eEvent.bStarted)
		return;
	
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!g_bParticipant[client])
		return;
	
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return;
	
	SetClientAmmo(client, weapon, 90);
}

public Action:Event_PlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_bHost[client] = false;
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
	if(g_bParticipant[client])
	{	
		g_bParticipant[client] = false;
		
		RP_PrintToChat(client, "You have been killed! You are now disqualified from the event!");
		
		new count = 0;
		for (new i = 1; i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!g_bParticipant[i])
				continue;
				
			count++;
		}
		
		PrintHintTextHosts("%N Died.\n There are %i players left!", client, count);
	}
}


public Action:Event_PlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_bHost[client] = false;
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	if(g_bParticipant[client])
	{	
		g_bParticipant[client] = false;
		
		RP_PrintToChat(client, "You have been respawned! You are now disqualified from the event!");
		
		new count = 0;
		for (new i = 1; i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!g_bParticipant[i])
				continue;
				
			count++;
		}
		
		PrintHintTextHosts("%N Died.\n There are %i players left!", client, count);
	}
}

stock SetClientAmmo(client, weapon, ammo)
{
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo); //set reserve to 0
	
	new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if(ammotype == -1) return;
	
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
}


stock PrintToChatEvent(const String:format[], any:...)
{
	new String:buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;
			
		if(g_bParticipant[i] || g_bHost[i])
			RP_PrintToChat(i, buffer);
	}
}

stock PrintHintTextHosts(const String:format[], any:...)
{
	new String:buffer[291];
	VFormat(buffer, sizeof(buffer), format, 2);
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;
			
		if(g_bHost[i])
			PrintHintText(i, buffer);
	}
}

stock bool:AddClientAsParticipant(client)
{
	if(!RP_IsClientInRP(client))
		return false;
	
	else if(RP_IsClientInAdminJail(client))
		return false;
		
	g_bParticipant[client] = true;
	g_bHost[client] = false;
	
	SetEntityRenderColor(client, 0, 255, 0, 255);
	
	RP_SetKarma(client, 0, true);
	
	if(RP_IsClientInJail(client))
		RP_UnJailClient(client);
		
	RP_SetClientJob(client, -1);
	RemoveAllWeapons(client);
	
	if(eEvent.bFreeze)
		SetEntityMoveType(client, MOVETYPE_NONE);
		
	TeleportEntity(client, eEvent.Origin);
	
	if(eEvent.bStarted)
	{
		SetEntityHealth(client, eEvent.Health);
		SetEntityMaxHealth(client, 1); // Blocks all healings.
		
		SetEntityMoveType(client, MOVETYPE_WALK);
		RP_SetClientJob(client, -1);
		
		if(!StrEqual(eEvent.WeaponClassname, "weapon_null") && !StrEqual(eEvent.WeaponClassname, "weapon_custom"))
			GivePlayerItem(client, eEvent.WeaponClassname);
	}
	
	return true;
}

stock bool:AddClientAsHost(client)
{
	if(!eEvent.bInvitesRolled && !eEvent.bStarted)
		return false;
		
	else if(!RP_IsClientInRP(client))
		return false;
	
	else if(RP_IsClientInAdminJail(client))
		return false;
		
	g_bParticipant[client] = false;
	g_bHost[client] = true;
	
	RP_SetKarma(client, 0, true);
	
	if(RP_IsClientInJail(client))
		RP_UnJailClient(client);
		
	SetEntityRenderColor(client, 0, 255, 255, 255);
	
	ServerCommand("sm_silentcvar uc_glow_type 1");
	
	ServerCommand("sm_glow #%i red", GetClientUserId(client));
	
	TeleportEntity(client, eEvent.Origin);
	
	return true;
}