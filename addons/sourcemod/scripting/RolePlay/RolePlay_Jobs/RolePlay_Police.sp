#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>
#include <basecomm>

new g_iViewModel;
new g_iWorldModel;

new Handle:Array_LegalWeapons = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "RolePlay Police Job", 
	description = "", 
	author = "Author was lost, heavy edit by Eyal282", 
	version = "1.00", 
	url = "https://steamcommunity.com/id/xflane/"
};

new g_iPoliceJob = -1;
new g_iThiefJob = -1;
new g_iCoronaJob = -1;

new MINUTES_TO_BECOME_POLICE = 10800;

new String:g_szLevels[11][32];
new Float:FreezeTimers[11];

new CASH_BONUS_TAKE_PRIMARY = 0;
new CASH_BONUS_TAKE_SECONDARY = 0;
new CASH_BONUS_ARREST = 0;

new bool:g_bFreezeMode[MAXPLAYERS + 1]
new bool:g_bCuffed[MAXPLAYERS + 1];
new Handle:g_hFreezeTimer[MAXPLAYERS + 1];
new bool:g_bBanCTLoaded;
new Float:NextAllowMovement[MAXPLAYERS + 1];

new Float:NextWeaponPickup[4096];

new Handle:fwOnClientArrestedPost = INVALID_HANDLE;


new Handle:Trie_PoliceEco;

#define TYPE_MUTE           1   /**< Voice Mute */
#define TYPE_SILENCE        3   /**< Silence (mute + gag) */

public SourceComms_OnBlockAdded(client, target, time, type, String:reason[])
{
	if(type != TYPE_MUTE && type != TYPE_SILENCE)
		return;
		
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		RP_PrintToChat(target, "You cannot play as\x02 The Police\x01 while you are muted.");
		
		ForcePlayerSuicide(target);
		RP_SetClientJob(target, -1);
		
		
	}
}
public RP_OnEcoLoaded()
{
	
	Trie_PoliceEco = RP_GetEcoTrie("Police");
	
	if (Trie_PoliceEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Police");
	
	new String:TempFormat[64];
	
	new i = 0;
	while (i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "FREEZE_TIMER_LVL_#%i", i);
		
		if (!GetTrieString(Trie_PoliceEco, Key, TempFormat, sizeof(TempFormat)))
			break;
		
		FreezeTimers[i] = StringToFloat(TempFormat);
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_PoliceEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_PoliceEco, "MINUTES_TO_BECOME_POLICE", TempFormat, sizeof(TempFormat));
	
	MINUTES_TO_BECOME_POLICE = StringToInt(TempFormat);
	
	GetTrieString(Trie_PoliceEco, "CASH_BONUS_TAKE_PRIMARY", TempFormat, sizeof(TempFormat));
	
	CASH_BONUS_TAKE_PRIMARY = StringToInt(TempFormat);
	
	GetTrieString(Trie_PoliceEco, "CASH_BONUS_TAKE_SECONDARY", TempFormat, sizeof(TempFormat));
	
	CASH_BONUS_TAKE_SECONDARY = StringToInt(TempFormat);
	
	GetTrieString(Trie_PoliceEco, "CASH_BONUS_ARREST", TempFormat, sizeof(TempFormat));
	
	CASH_BONUS_ARREST = StringToInt(TempFormat);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:sError[], err_max)
{
	MarkNativeAsOptional("IsPlayerBannedFromCT");
	MarkNativeAsOptional("GetPlayerBanCTUnix");
	
	CreateNative("RP_IsClientCuffed", Native_IsClientCuffed);
	CreateNative("RP_TryUncuffClient", Native_TryUncuffClient);
	
	CreateNative("RP_GetMinutesToBecomePolice", Native_GetMinutesToBecomePolice);
	
	
	return APLRes:0;
}

public int Native_IsClientCuffed(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	return g_bCuffed[client];
}

public int Native_TryUncuffClient(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	ClearFreezeTimer(client);
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
}

public int Native_GetMinutesToBecomePolice(Handle:plugin, numParams)
{
	return MINUTES_TO_BECOME_POLICE;
}

public OnEntityCreated(entity)
{
	if (!IsValidEdict(entity))
		return;
	
	NextWeaponPickup[entity] = 0.0;
}

public OnPluginStart()
{
	fwOnClientArrestedPost = CreateGlobalForward("RP_OnClientArrestedPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		OnClientPutInServer(i);
	}
	
	Array_LegalWeapons = CreateArray(64);
	
	PushArrayString(Array_LegalWeapons, "weapon_taser");
	PushArrayString(Array_LegalWeapons, "weapon_healthshot");
	
	RegConsoleCmd("sm_push", Command_Push, "[Police] Pushes a player you're aiming at if he's close to you");
	
	AddCommandListener(Listener_Ping, "player_ping");
	AddCommandListener(Listener_Drop, "drop");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	if (RP_GetEcoTrie("Police") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public OnMapStart()
{
	LoadDirOfModels("models/weapons/eminem/police_baton/");
	LoadDirOfModels("materials/models/weapons/eminem/police_baton/");
	g_iWorldModel = PrecacheModel("models/weapons/eminem/police_baton/w_police_baton.mdl", true);
	g_iViewModel = PrecacheModel("models/weapons/eminem/police_baton/v_police_baton.mdl", true);
	
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (client == 0)
		return;
	
	g_bCuffed[client] = false;
	
	if (g_hFreezeTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hFreezeTimer[client]);
		
		g_hFreezeTimer[client] = INVALID_HANDLE;
	}
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (client == 0)
		return;
	
	g_bCuffed[client] = false;
	
	if (g_hFreezeTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hFreezeTimer[client]);
		
		g_hFreezeTimer[client] = INVALID_HANDLE;
	}
	
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

public Action:Event_PlayerHurt(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == victim || attacker == 0)
		return;
		
	if (GetClientTeam(victim) == CS_TEAM_CT && !g_bFreezeMode[victim])
	{
		RP_PrintToChat(victim, "Freeze mode force enabled for being hit.");
		
		g_bFreezeMode[victim] = true;
	}
}

public OnClientChangeJob(client, job, oldjob, &bool:ok)
{
	if (g_iPoliceJob == job)
	{		
		if (GetTimePlayed(client) < MINUTES_TO_BECOME_POLICE)
		{
			ok = false;
			new MissingTime = MINUTES_TO_BECOME_POLICE - GetTimePlayed(client);
			
			new String:TimeFormat[32];
			FormatTimeHM(TimeFormat, sizeof(TimeFormat), MissingTime * 60);
			
			RP_PrintToChat(client, "Playtime left to play as police: [\x02%s\x01]", TimeFormat);
		}
		
		else if (g_bBanCTLoaded && IsPlayerBannedFromCT(client))
		{
			ok = false;
			new String:TimeFormat[64];
			FormatTime(TimeFormat, 64, "%m/%d/%y %H:%M:%S", GetPlayerBanCTUnix(client));
			RP_PrintToChat(client, "You are banned from playing as \x02The Police\x01 until \x04%s.", TimeFormat);
		}
		
		else if(BaseComm_IsClientMuted(client))
		{
			ok = false;
			
			RP_PrintToChat(client, "You need a microphone to play as\x02 The Police.\x01 You are muted.");
			
			FakeClientCommand(client, "sm_comms");
		}
		else if (RP_GetKarma(client) >= ARREST_KARMA)
		{
			ok = false;
			RP_PrintToChat(client, "\x01This job is not for \x07criminals!!");
		}
		
		else if (RoundToFloor(((float(GetPlayerCount(CS_TEAM_T)) - 1.0) / 4.0) + 1.0) < GetPlayerCount(CS_TEAM_CT) + 1 && GetPlayerCount(CS_TEAM_CT) > 0)
		{
			ok = false;
			RP_PrintToChat(client, "\x01There are too many CT, must be 1 CT per 5 players.");
		}
	}
	if (g_iPoliceJob == oldjob)
	{
		RemoveAllWeapons(client);
		RP_GivePlayerItem(client, "weapon_knife");
	}
}

public Action RP_OnPlayerSuiciding(int client)
{
	if(RP_IsClientCuffed(client) && RP_GetKarma(client) >= ARREST_KARMA)
	{
		RP_PrintToChat(client, "You cannot commit suicide while frozen.");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public bool:UpdateJobStats(client, job)
{
	g_bFreezeMode[client] = true;
	if (job == -1)
		return false;
	
	new level = RP_GetClientLevel(client, g_iPoliceJob);
	
	if (job == g_iPoliceJob)
	{
		if (GetClientTeam(client) != CS_TEAM_CT)
		{
			CS_SwitchTeam(client, CS_TEAM_CT);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iPoliceJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);
		
		CS_SetClientClanTag(client, "Policeman");
		RP_SetClientJobName(client, g_szLevels[level]);
		
		//FPVMI_AddViewModelToClient(client, "weapon_knife", g_iViewModel);
		
		switch (level)
		{
			case 0, 1:
			{
				RP_GivePlayerItem(client, "weapon_usp_silencer");
			}
			case 2, 3:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 4, 5:
			{
				RP_GivePlayerItem(client, "weapon_mp9");
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 6:
			{
				RP_GivePlayerItem(client, "weapon_p90");
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 7, 8:
			{
				RP_GivePlayerItem(client, "weapon_galilar");
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 9, 10:
			{
				RP_GivePlayerItem(client, "weapon_m4a1_silencer");
				RP_GivePlayerItem(client, "weapon_deagle");
				RP_GivePlayerItem(client, "weapon_tagrenade");
			}
			default:
			{
			}
		}
		if (level >= 4)
		{
			SetClientArmor(client, 100);
		}
		if (level >= 6)
		{
			SetClientHelmet(client, true);
		}
	}
	
	if (level >= 8)
	{
		SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 7);
		SetEntityHealth(client, GetClientHealth(client) + 7);
		
	}
	else if (level >= 5)
	{
		SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 3);
		SetEntityHealth(client, GetClientHealth(client) + 3);
		
	}
	
	return false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iPoliceJob = RP_CreateJob("Policeman", "PM", 11);
	}
	else
	{
		if (StrEqual(name, "Ban_CT", true))
		{
			PrintToChatAll("BANCT LOADED");
			g_bBanCTLoaded = true;
		}
	}
	
}

public Action:Listener_Ping(client, const String:Name[], args)
{
	if (GetClientTeam(client) != CS_TEAM_CT)
		return Plugin_Continue;
	
	g_bFreezeMode[client] = !g_bFreezeMode[client];
	
	RP_PrintToChat(client, "You have toggled freeze mode as CT %s", g_bFreezeMode[client] ? "ON" : "OFF");
	
	return Plugin_Stop;
}

public Action:Listener_Drop(client, const String:Name[], args)
{
	if (GetClientTeam(client) != CS_TEAM_CT)
		return Plugin_Continue;
	
	else if(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(client, CS_SLOT_KNIFE))
		return Plugin_Continue;
		
	return Plugin_Stop;
}

public Action:Command_Push(client, args)
{
	new target = GetClientAimTarget(client, true);
	
	if (GetClientTeam(client) != CS_TEAM_CT || RP_GetClientJob(client) != g_iPoliceJob)
	{
		RP_PrintToChat(client, "Only the police can use this command.");
		return Plugin_Handled;
	}
	else if (RP_GetClientLevel(client, g_iPoliceJob) < 3)
	{
		RP_PrintToChat(client, "You must be level 3 to use this command.");
		return Plugin_Handled;
	}
	else if (target == -1)
	{
		RP_PrintToChat(client, "You are not aiming at anybody.");
		return Plugin_Handled;
	}
	else if (GetClientTeam(target) == CS_TEAM_CT || RP_GetClientJob(target) == g_iPoliceJob)
	{
		RP_PrintToChat(client, "This command can only be used against civilians.");
		return Plugin_Handled;
	}
	else if (g_bCuffed[target])
	{
		RP_PrintToChat(client, "Command cannot be used against frozen players.");
		return Plugin_Handled;
	}
	else if (IsPlayerInAdminRoom(client) || IsPlayerInAdminRoom(target))
	{
		RP_PrintToChat(client, "Command cannot be used inside admin room.");
		return Plugin_Handled;
	}
	
	new Float:Origin[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	
	new Float:targetOrigin[3];
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetOrigin);
	
	if (GetVectorDistance(Origin, targetOrigin, false) > 100.0)
	{
		RP_PrintToChat(client, "You are too far away!");
		
		return Plugin_Handled;
	}
	
	BitchSlapPlayer(target, client, 400.0);
	
	RP_PrintToChat(target, "%N pushed you backwards.", client);
	return Plugin_Handled;
}


public BitchSlapPlayer(victim, slapper, Float:strength) // Stole the dodgeball tactic from https://forums.alliedmods.net/showthread.php?t=17116
{
	NextAllowMovement[victim] = GetGameTime() + 0.5;
	
	new Float:origin[3], Float:velocity[3];
	GetEntPropVector(slapper, Prop_Data, "m_vecOrigin", origin);
	GetVelocityFromOrigin(victim, origin, strength, velocity);
	
	if (GetEntityFlags(victim) & FL_ONGROUND)
		velocity[2] = 256.0;
	
	else
		velocity[2] = 0.0;
	
	IncrementVelocity(victim, velocity);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3])
{
	if (NextAllowMovement[client] > GetGameTime())
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
	SDKHook(client, SDKHook_WeaponEquipPost, WeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDropPost, WeaponDropPost);
	
	NextAllowMovement[client] = 0.0;
}

public Action:WeaponCanUse(client, weapon)
{
	if (GetClientTeam(client) == CS_TEAM_CT)
		return Plugin_Continue;
	
	else if (NextWeaponPickup[weapon] <= GetGameTime() && !g_bCuffed[client])
		return Plugin_Continue;
	
	return Plugin_Handled;
}
public WeaponEquipPost(client, weapon)
{
	NextWeaponPickup[weapon] = 0.0;
}


/*public Action:CS_OnCSWeaponDrop(client, weapon)
{
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
		
	else if(GetClientTeam(client) != CS_TEAM_CT)
		return Plugin_Continue;
		
	return Plugin_Handled;
}
*/
public WeaponDropPost(client, weapon)
{
	new bool:bAlive = GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? true : false;
	
	if (GetClientTeam(client) != CS_TEAM_CT)
		return;
	
	else if (!bAlive)
		return;
	
	NextWeaponPickup[weapon] = GetGameTime() + 6.0;
}

public Action:TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!IsPlayer(attacker) || !IsPlayer(victim))
		return Plugin_Continue;
	
	else if (GetClientTeam(victim) == CS_TEAM_CT && GetClientTeam(attacker) == CS_TEAM_CT)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	new bool:rightStab = damage == 65.0 || damage == 180.0;
	
	if (IsPlayerInAdminRoom(attacker) || IsPlayerInAdminRoom(victim))
		return Plugin_Continue;

	else if (RP_GetClientJob(attacker) == g_iPoliceJob)
	{
		new String:szWeapon[32];
		GetClientWeapon(attacker, szWeapon, 32);
		
		if (StrContains(szWeapon, "weapon_knife", true) != -1 || StrContains(szWeapon, "bayonet", true) != -1)
		{
			if (g_bCuffed[victim])
			{
				if (rightStab)
				{
					if (RP_GetKarma(victim) > ARREST_KARMA)
					{
						PerformArrest(victim, attacker);
					}
					else
					{
						RP_PrintToChat(attacker, "You cant arrest players with less than \x04%i\x01 karma!", ARREST_KARMA);
					}
				}
				
				RP_GivePlayerItem(victim, "weapon_knife");
				
				ClearFreezeTimer(victim);
				
				SetEntityRenderColor(victim, 255, 255, 255, 255);
				
				SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", 1.0);
				
				
				RP_PrintToChat(victim, "\x04%N \x01unfreezed you.", attacker);
				
				damage = 0.0;
				return Plugin_Changed;
			}
			else
			{
				new exp = 0;
				
				if (RP_GetTotalGrams(victim) > 0)
				{
					new grams = RP_GetTotalGrams(victim);
					new worth = RP_ResetGrams(victim);
					
					GiveClientCash(attacker, BANK_CASH, worth);
					RP_PrintToChat(attacker, "You have found \x02%i\x01 grams on \x04%N\x01!", grams, victim);
					RP_PrintToChat(victim, "\x02%N\x01 has found \x04%i\x01 grams on you!", attacker, grams);
					
					exp += RoundToFloor(float(grams) / 45.0);
				}
				
				new weapon;
				
				new cash;
				if ((weapon = GetPlayerWeaponSlot(victim, CS_SLOT_PRIMARY)) != -1)
				{
					new String:Classname[32];
					
					GetEdictClassname(weapon, Classname, sizeof(Classname));
					
					if (StrEqual(Classname, "weapon_awp", false))
						exp += 8;
					
					else
						exp += 5;
					
					GiveClientCashNoGangTax(attacker, BANK_CASH, CASH_BONUS_TAKE_PRIMARY);
					
					cash += CASH_BONUS_TAKE_PRIMARY;
				}
				
				if (GetPlayerWeaponSlot(victim, CS_SLOT_SECONDARY) != -1)
				{
					exp += 5;
					
					GiveClientCashNoGangTax(attacker, BANK_CASH, CASH_BONUS_TAKE_SECONDARY);
					
					cash += CASH_BONUS_TAKE_SECONDARY;
				}
				
				RemoveAllWeapons(victim, Array_LegalWeapons);
				
				new level = RP_GetClientLevel(attacker, g_iPoliceJob);
				
				if (g_bFreezeMode[attacker] || RP_GetKarma(victim) >= ARREST_KARMA)
				{
					SetEntPropFloat(victim, Prop_Data, "m_flLaggedMovementValue", 0.0);
					
					SetEntityRenderColor(victim, 0, 128, 255, 192);
					
					if (g_iThiefJob == -1)
						g_iThiefJob = RP_FindJobByShortName("TH");
					
					new Float:time = FreezeTimers[level];
					
					if (RP_GetClientJob(victim) == g_iThiefJob || RP_GetClientJob(victim) == g_iCoronaJob || RP_GetKarma(victim) >= ARREST_KARMA)
						time = 30.0;
					
					g_hFreezeTimer[victim] = CreateTimer(time, UnfreezePlayer, victim);
					
					RP_PrintToChat(victim, "\x04%N \x01froze you for \x07%.0f \x01seconds.", attacker, time);
					
					g_bCuffed[victim] = true;
				}
				else
					RP_GivePlayerItem(victim, "weapon_knife");
				
				RP_AddClientEXP(attacker, g_iPoliceJob, exp);
				
				if (cash > 0)
					RP_PrintToChat(attacker, "You confiscated %N's weapons and gained $%i", victim, cash);
				
			}
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

PerformArrest(victim, attacker)
{
	RP_PrintToChat(victim, "\x02%N\x01 has thrown you to the jail!", attacker);
	RP_PrintToChat(attacker, "You have thrown \x02%N\x01 to the jail!", victim);
	
	RP_AddClientEXP(attacker, g_iPoliceJob, 10);
	
	new karma = RP_GetKarma(victim);
	
	RP_JailClient(victim);
	
	GiveClientCashNoGangTax(attacker, BANK_CASH, CASH_BONUS_ARREST);
	
	Call_StartForward(fwOnClientArrestedPost);
	
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(karma);
	
	Call_Finish();
}
public OnClientConnected(client)
{
	g_bCuffed[client] = false;
}

public OnClientDisconnect(client)
{
	ClearFreezeTimer(client);
	
}

ClearFreezeTimer(client)
{
	if (g_hFreezeTimer[client])
	{
		KillTimer(g_hFreezeTimer[client], false);
		g_hFreezeTimer[client] = INVALID_HANDLE;
	}
	
	g_bCuffed[client] = false;
}

public Action:UnfreezePlayer(Handle:timer, any:client)
{
	g_hFreezeTimer[client] = INVALID_HANDLE;
	g_bCuffed[client] = false;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0, 0);
	RP_GivePlayerItem(client, "weapon_knife");
	SetEntityRenderColor(client, 255, 255, 255, 255);
	return Plugin_Continue;
}

stock FormatTimeHM(char[] Time, length, timestamp, bool:LimitTo24H = false)
{
	if (LimitTo24H)
	{
		if (timestamp >= 86400)
			timestamp %= 86400;
	}
	new HH, MM;
	
	HH = timestamp / 3600
	MM = timestamp % 3600 / 60
	
	Format(Time, length, "%02d:%02d", HH, MM);
}


stock GetVelocityFromOrigin(ent, Float:fOrigin[3], Float:fSpeed, Float:fVelocity[3]) // Will crash server if fSpeed = -1.0
{
	new Float:fEntOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fEntOrigin);
	
	// Velocity = Distance / Time
	
	new Float:fDistance[3];
	fDistance[0] = fEntOrigin[0] - fOrigin[0];
	fDistance[1] = fEntOrigin[1] - fOrigin[1];
	fDistance[2] = fEntOrigin[2] - fOrigin[2];
	
	new Float:fTime = (GetVectorDistance(fEntOrigin, fOrigin) / fSpeed);
	
	if (fTime == 0.0)
		fTime = 1 / (fSpeed + 1.0);
	
	fVelocity[0] = fDistance[0] / fTime;
	fVelocity[1] = fDistance[1] / fTime;
	fVelocity[2] = fDistance[2] / fTime;
	
	return (fVelocity[0] && fVelocity[1] && fVelocity[2]);
}

stock void IncrementVelocity(int iEntity, float flInc[3])
{
	float flCurrentVec[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecVelocity", flCurrentVec);
	
	AddVectors(flCurrentVec, flInc, flCurrentVec);
	
	TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, flCurrentVec);
} 