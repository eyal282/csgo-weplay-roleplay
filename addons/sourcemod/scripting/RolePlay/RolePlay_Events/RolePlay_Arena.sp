#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>

enum struct enDaysArray
{
	char EventName[32];
	char EventWeapon[64];
	int EventHealth;
	int EventArmor;
	bool bEventHelmet;
	int HSOnly;
	int NoScope;
}


enDaysArray daysArray[] =
{
    { "AK-47 Event", "weapon_ak47", 250, 0, false, 2, 0 },
    { "Scout Event", "weapon_ssg08", 100, 0, false, 0, 2 },
    { "Awp Event", "weapon_awp", 400, 100, true, 2, 0 },
    { "Deagle Event", "weapon_deagle", 250, 0, false, 2, 0 },
	{ "Knife 1HP Event", "weapon_knife", 1, 100, true, 0, 0 },
	{ "Knife Backstabs Event", "weapon_knife", 100, 100, true, 1, 0 },
	{ "Ump-45 Event", "weapon_ump45", 100, 100, false, 1, 0 }
}

new MIN_ARENA_REWARD = 0;
new MAX_ARENA_REWARD = 1;

new MIN_JOTD_EXP = 0;
new MAX_JOTD_EXP = 1;

new EngineVersion:g_Game;
new bool:joinedArena[MAXPLAYERS+1];

new bool:g_bBlockArena = false;

new Float:arenaSpawnPoints[64][3], arenaSpawnPointsSize;

new g_GlowColors[64][3];

new String:g_GlowNames[64][16];

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new String:dayNameRN[64];
new bool:g_OnlyHS;
new bool:g_NoScope;
new bool:g_Backstabs;
new selectedDay;
new bool:dayStarted;
new bool:g_InArena[MAXPLAYERS+1];
new g_ArenaKills[MAXPLAYERS+1];
new g_ArenaDamage[MAXPLAYERS+1];
new g_WeaponRef[MAXPLAYERS+1];
new bool:joinArenaStarted;
new g_iTimeLeft;

new ARENA_DELAY_WEEKDAY = MAX_INTEGER;
new ARENA_DELAY_WEEKEND = MAX_INTEGER;

new SpyKarma = false;

new Handle:hTimer_BlockAttacks = INVALID_HANDLE;

new Handle:Trie_ArenaEco;

public RP_OnEcoLoaded()
{
	arenaSpawnPointsSize = 0;
	
	Trie_ArenaEco = RP_GetEcoTrie("Arena");
	
	if(Trie_ArenaEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Arena");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "ARENA_SPAWN_XYZ_#%i", i);
		
		if(!GetTrieString(Trie_ArenaEco, Key, TempFormat, sizeof(TempFormat)))
			break;
		
		StringToVector(TempFormat, arenaSpawnPoints[arenaSpawnPointsSize]);
		
		FormatEx(Key, sizeof(Key), "ARENA_SPAWN_GLOW_#%i", i);
		GetTrieString(Trie_ArenaEco, Key, TempFormat, sizeof(TempFormat));
		
		StringToRGB(TempFormat, g_GlowColors[arenaSpawnPointsSize]);
		
		FormatEx(Key, sizeof(Key), "ARENA_SPAWN_GLOW_NAME_#%i", i);
		GetTrieString(Trie_ArenaEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_GlowNames[arenaSpawnPointsSize], sizeof(g_GlowNames[]), TempFormat);
		
		arenaSpawnPointsSize++;
		
		i++;
	}
	
	GetTrieString(Trie_ArenaEco, "ARENA_DELAY_WEEKDAY", TempFormat, sizeof(TempFormat));
	
	ARENA_DELAY_WEEKDAY = StringToInt(TempFormat);	
	
	GetTrieString(Trie_ArenaEco, "ARENA_DELAY_WEEKEND", TempFormat, sizeof(TempFormat));
	
	ARENA_DELAY_WEEKEND = StringToInt(TempFormat);	
	
	GetTrieString(Trie_ArenaEco, "MIN_ARENA_REWARD", TempFormat, sizeof(TempFormat));
	
	MIN_ARENA_REWARD = StringToInt(TempFormat);	
	
	GetTrieString(Trie_ArenaEco, "MAX_ARENA_REWARD", TempFormat, sizeof(TempFormat));
	
	MAX_ARENA_REWARD = StringToInt(TempFormat);
	
	GetTrieString(Trie_ArenaEco, "MIN_JOTD_EXP", TempFormat, sizeof(TempFormat));
	
	MIN_JOTD_EXP = StringToInt(TempFormat);	
	
	GetTrieString(Trie_ArenaEco, "MAX_JOTD_EXP", TempFormat, sizeof(TempFormat));
	
	MAX_JOTD_EXP = StringToInt(TempFormat);
	
	if(g_iTimeLeft > MAX_INTEGER / 2)
	{
		g_iTimeLeft = ARENA_DELAY_WEEKDAY;
	
		if(IsWeekend())
			g_iTimeLeft = ARENA_DELAY_WEEKEND;
	}
}

public Action:Command_SpyKarma(client, args)
{
	SpyKarma = !SpyKarma;
	
	return Plugin_Handled;
}

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	RegAdminCmd("sm_spykarma", Command_SpyKarma, ADMFLAG_ROOT);
	
	RegAdminCmd("sm_blockarena", cmd_blockArena, ADMFLAG_CHEATS, "[RolePlay] Blocks JA from happening")
	RegAdminCmd("sm_startarena", cmd_arena, ADMFLAG_ROOT, "[ROLEPLAY] Starts the arena event.");
	RegConsoleCmd("sm_ja", cmd_joinarena, "[ROLEPLAY] Join the arena event.", 0);
	RegConsoleCmd("sm_unja", cmd_unjoinarena, "[ROLEPLAY] Unjoin the arena event.", 0);
	RegConsoleCmd("sm_jant", cmd_unjoinarena, "[ROLEPLAY] Join the arena event.", 0);
	
	HookEvent("player_death", eventDeath, EventHookMode_Post);
	HookEvent("player_hurt", eventHurt, EventHookMode_Post);
	HookEvent("weapon_reload", Event_WeaponFireOnEmpty, EventHookMode_Post);
	HookEvent("weapon_fire_on_empty", Event_WeaponFireOnEmpty, EventHookMode_Post);
	
	g_iTimeLeft = MAX_INTEGER;
		
	CreateTimer(1.0, timer_StartArenaTask, _, TIMER_REPEAT);
	
	new i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
		i++;
	}
	
	if(RP_GetEcoTrie("Arena") != INVALID_HANDLE)
		RP_OnEcoLoaded();
	
}

public OnMapStart()
{
	dayStarted = false;
	joinArenaStarted = false;
	
	hTimer_BlockAttacks = CreateTimer(1.0, Timer_BlockAttacks, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:Timer_BlockAttacks(Handle:hTimer)
{
	for(new i=1;i <= MaxClients;i++)
	{
		if(!dayStarted)
			continue;
		
		else if(!g_InArena[i])
			continue;
			
		else if(!IsClientInGame(i))
			continue;
			
		else if(!IsPlayerAlive(i))
			continue;
			
		if(GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue") <= 0.0)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			
			if(activeWeapon == -1)
				continue;
				
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.5);
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.5);
			
			continue;
		}
		
		else if(g_NoScope)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
		
			if(activeWeapon == -1)
				continue;
				
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.5);
		}
		
		else if(g_Backstabs)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.5);
		}
	}
}
/*
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if(!dayStarted)
		return Plugin_Continue;
	
	else if(!g_InArena[client])
		return Plugin_Continue;
		
	if(g_NoScope)
		buttons &= ~IN_ATTACK2;
		
	return Plugin_Continue;
}
*/
public Action:timer_StartArenaTask(Handle:timer, any:data)
{
	if (dayStarted)
	{
		return Plugin_Continue;
	}
	
	g_iTimeLeft--;
	
	if(g_iTimeLeft > 0)
		return Plugin_Continue;
	
	else if(g_bBlockArena)
		return Plugin_Continue;
		
	g_iTimeLeft = ARENA_DELAY_WEEKDAY;
	
	if(IsWeekend())
		g_iTimeLeft = ARENA_DELAY_WEEKEND;
		
	selectedDay = GetRandomInt(0, sizeof(daysArray)-1);
	FormatEx(dayNameRN, 64, "%s (%i hp)", daysArray[selectedDay].EventName, daysArray[selectedDay].EventHealth);
	
	if(daysArray[selectedDay].HSOnly == 1)
	{
		g_OnlyHS = true;
	}
	else
	{
		if (daysArray[selectedDay].HSOnly == 2)
		{
			g_OnlyHS = view_as<bool>(GetRandomInt(0, 1));
			
		}
		else
		{
			g_OnlyHS = false;
		}
	}
	
	g_Backstabs = false;
	
	if(g_OnlyHS && StrEqual(daysArray[selectedDay].EventWeapon, "weapon_knife"))
	{
		g_OnlyHS = false;
		g_Backstabs = true;
	}
	if(daysArray[selectedDay].NoScope == 1)
	{
		g_NoScope = true;
	}
	else
	{
		if (daysArray[selectedDay].NoScope == 2)
		{
			g_NoScope = view_as<bool>(GetRandomInt(0, 1));
		}
		else
		{
			g_NoScope = false;
		}
	}
	if (g_OnlyHS)
	{
		Format(dayNameRN, sizeof(dayNameRN), "%s [Headshot Only]", dayNameRN);
	}
	if (g_NoScope)
	{
		Format(dayNameRN, sizeof(dayNameRN), "%s [No Scope]", dayNameRN);
	}
	
	RP_PrintToChatAll("Arena event started, You have 60 seconds to join!");
	RP_PrintToChatAll("Type \x02!ja\x01 to join the arena event! \x06(gang members only)\x01.");
	RP_PrintToChatAll("Event Type: \x06%s", dayNameRN);
	
	Event newevent_message = CreateEvent("cs_win_panel_round");
	newevent_message.SetString("funfact_token", "Arena event started, You have 60 seconds to join!\nType !ja to join the arena event! (gang members only)");

	for(int z = 1; z <= MaxClients; z++)
	if(IsClientInGame(z) && !IsFakeClient(z))
		newevent_message.FireToClient(z);
                                
	newevent_message.Cancel(); 
	
	dayStarted = true;
	joinArenaStarted = true;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			joinedArena[i] = false;
			g_InArena[i] = false;
			g_ArenaKills[i] = 0;
			g_ArenaDamage[i] = 0;
		}
	}
	
	CreateTimer(15.0, timer_HideFunFact);
	CreateTimer(60.0, timer_StartArena, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action:timer_HideFunFact(Handle:hTimer)
{
	Event newevent_round = CreateEvent("round_start");

	for(int z = 1; z <= MaxClients; z++)
	{
		if(IsClientInGame(z) && !IsFakeClient(z))
			newevent_round.FireToClient(z);
	}
}


/*
public Action:eventWeaponShoot(Handle:hEvent, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (!g_InArena[client])
	{
		return Plugin_Continue;
	}
	new weaponEntity = GetPlayerWeaponSlot(client, 0);
	if (weaponEntity != -1)
	{
		if (GetEntProp(weaponEntity, Prop_Send, "m_iClip1", 4, 0) == 1)
		{
			DoClipRefillAmmo(EntIndexToEntRef(weaponEntity));
		}
	}
	weaponEntity = GetPlayerWeaponSlot(client, 1);
	if (weaponEntity != -1)
	{
		if (GetEntProp(weaponEntity, Prop_Send, "m_iClip1", 4, 0) == 1)
		{
			DoClipRefillAmmo(EntIndexToEntRef(weaponEntity));
		}
	}
	return Plugin_Continue;
}

DoClipRefillAmmo(weaponRef)
{
	new weaponEntity = EntRefToEntIndex(weaponRef);
	if (IsValidEdict(weaponEntity))
	{
		new String:weaponNamev[64];
		new String:clipSize;
		new String:maxAmmoCount;
		if (GetEntityClassname(weaponEntity, weaponNamev, 64))
		{
			clipSize = GetWeaponAmmoCount(weaponNamev, true);
			maxAmmoCount = GetWeaponAmmoCount(weaponNamev, false);
			switch (GetEntProp(weaponRef, Prop_Send, "m_iItemDefinitionIndex", 4, 0))
			{
				case 60:
				{
					clipSize = MissingTAG:20;
				}
				case 61:
				{
					clipSize = MissingTAG:12;
				}
				case 63:
				{
					clipSize = MissingTAG:12;
				}
				case 64:
				{
					clipSize = MissingTAG:8;
				}
				default:
				{
				}
			}
		}
		SetEntProp(weaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", maxAmmoCount, 4, 0);
	}
	
}
*/

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Arena");
	
	CreateNative("RP_IsUserInArena", Native_Arena);
}

public Native_Arena(Handle:plugin, numParams)
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
	return g_InArena[client];
}

public OnClientConnected(client)
{
	joinedArena[client] = false;
	g_InArena[client] = false;
	g_ArenaKills[client] = 0;
	g_ArenaDamage[client] = 0;
}
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, SDK_TraceAttack);
	SDKHook(client, SDKHook_WeaponCanUse, SDK_WeaponCanUse);
	
}


public Action:SDK_TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if(!g_InArena[victim])
		return Plugin_Continue;
	
	else if(Are_Users_Same_Gang(victim, attacker))
	{
		PrintCenterText(attacker, "DON'T KILL YOUR OWN GANG!!!")
		damage = 0.0;
		return Plugin_Stop;
	}
	else if (g_OnlyHS && hitgroup != 1)
	{
		damage = 0.0;
		return Plugin_Stop;
	}
	else if(g_Backstabs)
	{
		
		new weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
			
		new String:Classname[50];
		GetEdictClassname(weapon, Classname, sizeof(Classname));
		if(strncmp(Classname, "weapon_knife", 12) == 0)
		{
			if(damage < 69) // Knife should deal 76 max.
			{
				damage = 0.0;
				return Plugin_Stop;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:SDK_WeaponCanUse(client, weapon)
{
	if(!g_InArena[client])
		return Plugin_Continue;
		
	new String:Classname[64];
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!StrEqual(Classname, daysArray[selectedDay].EventWeapon))
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action:OnItemUsed(int client, int item)
{
	if(g_InArena[client])
	{
		RP_PrintToChat(client, "You cannot use items while in the arena.");
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
public Action:RolePlay_OnKarmaChanged(client, &karma, String:Reason[])
{
	if(g_InArena[client])
	{
		if(SpyKarma)
			PrintToChatEyal("Karma Failed %N JA", client);
			
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:RolePlay_OnBountySet(client)
{
	if(g_InArena[client])
		return Plugin_Handled;

	return Plugin_Continue;
}


public Action:eventHurt(Handle:event, String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));
	
	if(attacker == 0)
		return;
		
	else if(g_InArena[attacker])
		return;
	
	g_ArenaDamage[attacker] += GetEventInt(event, "dmg_health");
}

public Action:eventDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));
	
	if (g_InArena[client])
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
		g_InArena[client] = false;
		
		if(attacker != 0 && attacker != client)
		{
			if(Are_Users_Same_Gang(client, attacker))
				g_ArenaKills[attacker]--;
			
			else
				g_ArenaKills[attacker]++;
		}
		new bool:gangsBool[MAXPLAYERS+1];
		new alivePlayers[MAXPLAYERS+1];
		new gangsJoined;
		new g_Id;

		for(new i=1;i <= MaxClients;i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || !g_InArena[i])
			{
			}
			else
			{
				g_Id = Get_User_Gang(i);
				if (!(g_Id == -1))
				{
					if (!gangsBool[g_Id])
					{
						gangsBool[g_Id] = true;
						gangsJoined++;
					}
					alivePlayers[g_Id]++;
				}
			}
		}
		if (gangsJoined == 1)
		{
			new gangId;
			
			for(new i=1;i <= MaxClients;i++)
			{
				if (!IsClientInGame(i) || !IsPlayerAlive(i) || !g_InArena[i])
				{
				}
				else
				{
					gangId = Get_User_Gang(i);
					g_InArena[i] = false;
					SetEntityRenderColor(i, 255, 255, 255, 255);
					
					RemoveAllWeapons(i);
					SetEntityHealth(i, 100);
					SetClientArmor(i, 0);
					SetClientHelmet(i, false);
				
					CS_RespawnPlayer(i);
					attacker = i;
				}
			}
			
			new prize = 0;
			new expPrize = 0;

			new count = 0
			
			for(new i=1;i <= MaxClients;i++)
			{
				if (IsClientInGame(i))
				{
					if (gangId == Get_User_Gang(i))
					{
						count++;
						
						if(prize == 0)
						{
							new minPrize = MIN_ARENA_REWARD;
							new maxPrize = MAX_ARENA_REWARD;
							
							minPrize += RoundToCeil(float(minPrize) * ((float(Get_User_Luck_Bonus(client)) / 100.0) * 2.0)); // * 2.0 to make critical luck ( $12,500 ) also more likely without allowing to pass $12,500
							
							prize = GetRandomInt(minPrize, maxPrize);
						}
						if(expPrize == 0)
						{
							new minExpPrize = MIN_JOTD_EXP;
							new maxExpPrize = MAX_JOTD_EXP;
							
							minExpPrize += RoundToCeil(float(minExpPrize) * ((float(Get_User_Luck_Bonus(client)) / 100.0) * 2.0)); // * 2.0 to make critical luck ( 30 exp ) also more likely without allowing to pass 30 exp
							
							expPrize = GetRandomInt(minExpPrize, maxExpPrize);
						}
					}
				}
			}
			
			if(count == 0)
				count = 1;
				
			prize /= count;
			
			new initClient = 0;
			for(new i=1;i <= MaxClients;i++)
			{
				if (IsClientInGame(i))
				{
					if (gangId == Get_User_Gang(i))
					{
						if(initClient == 0)
						{
							initClient = i;
							
							continue; // Reward him in the end for proper calculations.
						}
						
						GiveClientCash(i, BANK_CASH, prize);
						
						RP_AddJOTDExp(i, expPrize);
						
						RolePlayLog("%N has won arena event (%i cash.)", i, prize);
					}
				}
			}
			
			if(initClient != 0)
			{
				RolePlayLog("%N has won arena event (%i cash.)", initClient, prize); // Not to edit prize yet.
				
				RP_AddJOTDExp(initClient, expPrize);
				
				prize = GiveClientCash(initClient, BANK_CASH, prize);
			}
			
			new String:g_Name[32];
			Get_User_Gang_Name(attacker, g_Name, sizeof(g_Name));
			RP_PrintToChatAll("\x06%s\x01 gang has won the event! well played!", g_Name);
			RP_PrintToChatAll("Each member of the gang received \x06%i\x01 cash and \x06%i\x01 JOTD exp!", prize, expPrize);
			
			new MVP = 0, MVPKills = 0;
			
			for(new i=1;i <= MaxClients;i++)
			{
				if(!IsClientInGame(i))
					continue;
					
				if(MVP == 0 || g_ArenaKills[i] > g_ArenaKills[MVP])
				{
					MVP = i;
					MVPKills = g_ArenaKills[MVP];
				}	
				else if(g_ArenaKills[i] == g_ArenaKills[MVP])
				{
					if(g_ArenaDamage[i] > g_ArenaDamage[MVP] || g_ArenaDamage[i] == g_ArenaDamage[MVP] && GetRandomInt(0, 1) == 1)
					{
						MVP = i;
						MVPKills = g_ArenaKills[MVP];
					}
						
				}
			}
			
			if(MVP != 0)
			{
				new awpItemId = RP_GetItemId("AWP");
				
				if(awpItemId == -1)
				{
					prize = GetRandomInt(1000, 3000);
					GiveClientCash(MVP, BANK_CASH, prize);
					
					RolePlayLog("%N has achieved MVP arena event (%i cash.)", MVP, prize);
				
					PrintToChatAll("%N got $%i for having most kills (%i) in the event", MVP, prize, MVPKills);
				}
				else
				{
					RP_GiveItem(MVP, awpItemId);

					RP_PrintToChatAll("\x07%N \x01got an AWP for having most kills \x10(%i) \x01in the event", MVP, MVPKills);
				}
			}
			
			dayStarted = false;
			
			joinArenaStarted = false;
			
			return Plugin_Continue;
		}
		
		BroadcastEventStatus();
	}
	return Plugin_Continue;
}

public Action:Event_WeaponFireOnEmpty(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{	
	if(!dayStarted)
		return;
	
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!g_InArena[client])
		return;
	
	new weapon = EntRefToEntIndex(g_WeaponRef[client]);
	
	SetClientAmmo(client, weapon, 90);
}

public Action:cmd_joinarena(client, args)
{
	if (!joinArenaStarted)
	{
		if(g_bBlockArena)
		{
			RP_PrintToChat(client, "arena event registry is blocked by management!");
			return Plugin_Handled;			
		}
		else
		{
			RP_PrintToChat(client, "arena event registry opens in %.2f minutes.", float(g_iTimeLeft) / 60.0 );
			return Plugin_Handled;
		}
	}
	if(Get_User_Gang(client) == -1)
	{
		RP_PrintToChat(client, "You can't join without gang, this event is only for \x06gang members.\x01");
		return Plugin_Handled;
	}
	if (joinedArena[client])
	{
		RP_PrintToChat(client, "You are already registered to the arena event.");
		return Plugin_Handled;
	}

	RP_PrintToChat(client, "You are now registered to the arena event.");
	joinedArena[client] = true;
	new gang = Get_User_Gang(client);

	new totalCash = 0;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			if (gang == Get_User_Gang(i))
			{
				totalCash += GetClientCash(i, POCKET_CASH);
				
				if(client != i)
					RP_PrintToChat(i, "\x06%N\x01 from your gang joined the event, join by typing /ja!", client);
			}
		}
	}
	
	if (RP_IsUserInDuel(client))
		RP_PrintToChat(client, "Warning!!! If arena starts before your duel ends, you will not join the arena.");

	if(totalCash >= 75000)
	{
		for(new i=1;i <= MaxClients;i++)
		{
			if (IsClientInGame(i))
			{
				if (gang == Get_User_Gang(i))
					RP_PrintToChat(i, "Warning!!! JA Auto Deposit is disabled with $75000 total gang pocket cash!!!");
			}
		}
	}
	return Plugin_Handled;
}

public Action:cmd_unjoinarena(client, args)
{
	if (!joinArenaStarted)
	{
		RP_PrintToChat(client, "arena event registry opens in %.2f minutes.", float(g_iTimeLeft) / 60.0 );
		return Plugin_Handled;
	}
	else if (!joinedArena[client])
	{
		RP_PrintToChat(client, "You are already not registered to the arena event.");
		return Plugin_Handled;
	}

	RP_PrintToChat(client, "You are no longer registered to the arena event.");
	joinedArena[client] = false;
	
	new gang = Get_User_Gang(client);

	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			if (client != i && gang == Get_User_Gang(i))
			{
				RP_PrintToChat(i, "\x06%N\x01 from your gang ditched the event, you can leave with /unja!", client);
			}
		}
	}

	return Plugin_Handled;
}

public Action:cmd_arena(client, args)
{
	g_iTimeLeft = 0;
	
	return Plugin_Handled;
}

public Action:cmd_blockArena(client, args)
{
	g_bBlockArena = !g_bBlockArena;
	
	RP_PrintToChat(client, "Arena is now %s", g_bBlockArena ? "blocked" : "unblocked");
	
	return Plugin_Handled;
}

public Action:timer_StartArena(Handle:handle, any:data)
{	
	joinArenaStarted = false;
	
	Event newevent_round = CreateEvent("round_start");

	for(int z = 1; z <= MaxClients; z++)
	{
		if(IsClientInGame(z) && !IsFakeClient(z))
			newevent_round.FireToClient(z);
	}

	newevent_round.Cancel(); 
	
	new gangsJoined;
	new gangsSpawn[MAXPLAYERS+1];
	new bool:gangsBool[MAXPLAYERS+1];
	new gangColors[MAXPLAYERS+1];
	new g_Id;
	
	new alivePlayers[MAXPLAYERS+1];

	for(new i=1;i <= MaxClients;i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if(!joinedArena[i] || RP_IsClientInJail(i) || RP_IsUserInDuel(i) || IsPlayerInAdminRoom(i) || AFKM_IsClientAFK(i))
		{	
			continue;
		}
		else
		{
			g_Id = Get_User_Gang(i);
			if (!(g_Id == -1))
			{
				alivePlayers[g_Id]++;
				
				if (!(IsValidEntity(GetEntPropEnt(i, Prop_Send, "m_hVehicle", 0))))
				{
					if (!gangsBool[g_Id])
					{	
						if (gangsJoined > arenaSpawnPointsSize)
						{
							RP_PrintToChat(i, "No place for you gang.");
							continue;
							
						}
						gangsSpawn[g_Id] = gangsJoined;
						gangColors[g_Id] = gangsJoined;
						gangsBool[g_Id] = true;
						gangsJoined++;
					}
				}
			}
		}
	}
	if (gangsJoined < 2)
	{
		dayStarted = false;
		
		for(new i=1;i <= MaxClients;i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || !joinedArena[i])
			{
				continue;
			}
			else
			{
				g_InArena[i] = false;
				ShowHudText(i, 1, " ");
				ShowHudText(i, 2, " ");
				//CS_RespawnPlayer(i);
				SetEntityRenderColor(i, 255, 255, 255, 255);
			}
		}
		
		RP_PrintToChatAll("Not enough gangs registered to the arena event, canceling the event.");
		
		return Plugin_Handled;
	}
	
	else
	{
		new totalCash[MAXPLAYERS + 1];
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			else if(Get_User_Gang(i) == -1)
				continue;
				
			totalCash[Get_User_Gang(i)] += GetClientCash(i, POCKET_CASH);
		}
		for(new i=1;i <= MaxClients;i++)
		{
			if (!IsClientInGame(i))
				continue;
			
			if(!joinedArena[i] || RP_IsUserInEvent(i) || Get_User_Gang(i) == -1 || RP_IsClientInJail(i) || RP_IsUserInDuel(i) || IsPlayerInAdminRoom(i))
				continue;

			else
			{
				new pocket = GetClientCash(i, POCKET_CASH);
				
				if(pocket > 0 && totalCash[Get_User_Gang(i)] <= 75000)
				{
					GiveClientCashNoGangTax(i, POCKET_CASH, -1 * GetClientCash(i, POCKET_CASH));

					GiveClientCashNoGangTax(i, BANK_CASH, pocket);
				}
				
				if(GetClientTeam(i) == CS_TEAM_CT)
				{
					CS_SwitchTeam(i, CS_TEAM_T);
					CS_UpdateClientModel(i);
					RP_SetClientJob(i, -1);
				}
				
				g_Id = Get_User_Gang(i);
				
				if(!IsPlayerAlive(i))
				{
					CS_RespawnPlayer(i);
				}	
				if(IsPlayerAlive(i))
				{
					RP_TryUncuffClient(i);
					g_InArena[i] = true;
					g_ArenaKills[i] = 0;
					g_ArenaDamage[i] = 0;
					SetHudTextParams(-1.0, 0.1, 120.0, g_GlowColors[gangColors[g_Id]][0], g_GlowColors[gangColors[g_Id]][1], g_GlowColors[gangColors[g_Id]][2], 255, 1, 0.1, 0.1, 0.1);
					ShowHudText(i, -1, "Your gang color is: %s\nEvent Type: %s", g_GlowNames[gangColors[g_Id]], dayNameRN);
					SetHudTextParams(-1.0, 0.18, 3.0, g_GlowColors[gangColors[g_Id]][0], g_GlowColors[gangColors[g_Id]][1], g_GlowColors[gangColors[g_Id]][2], 255, 2, 0.2, 0.1, 0.1);
					ShowHudText(i, -1, "Starting in 5 seconds.");
					SetEntityRenderColor(i, g_GlowColors[gangColors[g_Id]][0], g_GlowColors[gangColors[g_Id]][1], g_GlowColors[gangColors[g_Id]][2], 255);
					TeleportEntity(i, arenaSpawnPoints[gangsSpawn[g_Id]], NULL_VECTOR, NULL_VECTOR);
					SetEntityHealth(i, 100);
					SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.0, 0);
					RemoveAllWeapons(i);
				}
			}
		}
	}

	CreateTimer(5.0, startTheDay);
		
	BroadcastEventStatus();
	return Plugin_Handled;
}

public Action:startTheDay(Handle:timer, any:data)
{
	for(new i=1;i <= MaxClients;i++)
	{
		if (!IsClientInGame(i) || !g_InArena[i] || !IsPlayerAlive(i))
		{
			continue;
		}
		else
		{
			SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0, 0);
			
			RemoveAllWeapons(i);
			
			new weapon = GivePlayerItem(i, daysArray[selectedDay].EventWeapon);
			
			g_WeaponRef[i] = EntIndexToEntRef(weapon);
			
			SetEntityHealth(i, daysArray[selectedDay].EventHealth);
			SetClientArmor(i, daysArray[selectedDay].EventArmor);
			SetClientHelmet(i, daysArray[selectedDay].bEventHelmet);
		}
	}
	RP_PrintToChatAll("Arena event started, \x06good luck, have fun.\x01");
	RP_PrintToChatAll("Event Type: \x06%s", dayNameRN);
	
	CreateTimer(0.1, Timer_BlockAttacks, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}


stock SetClientAmmo(client, weapon, ammo)
{
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo); //set reserve to 0
	
	new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if(ammotype == -1) return;
	
	SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
}

BroadcastEventStatus()
{
	new bool:gangsBool[MAXPLAYERS+1];
	new alivePlayers[MAXPLAYERS+1];
	new gangsJoined;
	new g_Id;

	for(new i=1;i <= MaxClients;i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || !g_InArena[i])
		{
		}
		else
		{
			g_Id = Get_User_Gang(i);
			if (!(g_Id == -1))
			{
				if (!gangsBool[g_Id])
				{
					gangsBool[g_Id] = true;
					gangsJoined++;
				}
				alivePlayers[g_Id]++;
			}
		}
	}
		
	new String:chatMessage[128];
	new String:gangName[32];

	for(new i=0;i < sizeof(gangsBool);i++)
	{
		if (gangsBool[i])
		{
			for(new player=1;player <= MaxClients;player++)
			{
				if(!IsClientInGame(player))
					continue;
					
				else if(Get_User_Gang(player) == i)
					Get_User_Gang_Name(player, gangName, sizeof(gangName));
			}
			Format(chatMessage, 128, "%s\x06%s \x02(%i), ", chatMessage, gangName, alivePlayers[i]);
		}
	}
	chatMessage[strlen(chatMessage) - 2] = EOS;
	RP_PrintToChatAll("Event Status: %s\x01", chatMessage);
}