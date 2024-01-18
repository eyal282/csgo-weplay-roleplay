#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>
#include <fuckzones>

//models/props_survival/safe/safe.mdl

new const String:SAFE_MODEL[] = "models/props/de_nuke/hr_nuke/nuke_roof_ac/nuke_roof_ac_box.mdl";

new EngineVersion:g_Game;
public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new g_iVault = INVALID_ENT_REFERENCE;
new Float:g_fLastTouch[66];
new Float:g_fLastUsed[66];
new Float:g_fLastMessage;
new g_iLockPickProcess;
new g_iVaultPicker;
new Handle:g_hBankRobTimer;
new Handle:hcv_minDuo;
new Handle:hcv_freeLook;

new bool:ImmuneToPlayerLimit[MAXPLAYERS + 1];
new bool:BlockNextCoinDrop = false;

new Float:SAFE_SPAWN_XYZ[3];

new MIN_BANK_ROB_REWARD = 0;
new MAX_BANK_ROB_REWARD = 0;

new Float:BANK_ROB_DELAY = 5000.0;


new Handle:Trie_BankRobEco;

public RP_OnEcoLoaded()
{	
	Trie_BankRobEco = RP_GetEcoTrie("Bank Rob");
	
	if(Trie_BankRobEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Bank Rob");
		
	new String:TempFormat[64];
	
	GetTrieString(Trie_BankRobEco, "SAFE_SPAWN_XYZ", TempFormat, sizeof(TempFormat));
	
	StringToVector(TempFormat, SAFE_SPAWN_XYZ);
	
	GetTrieString(Trie_BankRobEco, "MIN_BANK_ROB_REWARD", TempFormat, sizeof(TempFormat));
	
	MIN_BANK_ROB_REWARD = StringToInt(TempFormat);	
	
	GetTrieString(Trie_BankRobEco, "MAX_BANK_ROB_REWARD", TempFormat, sizeof(TempFormat));
	
	MAX_BANK_ROB_REWARD = StringToInt(TempFormat);
	
	GetTrieString(Trie_BankRobEco, "BANK_ROB_DELAY", TempFormat, sizeof(TempFormat));
	
	BANK_ROB_DELAY = StringToFloat(TempFormat);
	
	if(g_hBankRobTimer != INVALID_HANDLE)
	{
		CloseHandle(g_hBankRobTimer);
		g_hBankRobTimer = INVALID_HANDLE;
	}
	
	g_hBankRobTimer = CreateTimer(BANK_ROB_DELAY, Timer_CreateVault, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	if(g_iVault != INVALID_ENT_REFERENCE)
	{
		int vault = EntRefToEntIndex(g_iVault);
		
		if(vault != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(g_iVault, "Kill", -1, -1, 0);
		}
	}
}
public OnPluginStart()
{		
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	BlockNextCoinDrop = false;
	g_iVault = INVALID_ENT_REFERENCE;
	
	hcv_minDuo = CreateConVar("roleplay_bank_rob_min_duo", "9", "The amount of players that force bank robs to be done in duos");
	hcv_freeLook = CreateConVar("roleplay_bank_rob_free_look", "0", "If set to 1, you can look anywhere and rob the bank.");
	RegAdminCmd("sm_spawnvault", Command_SpawnVault, ADMFLAG_ROOT, "", "", 0);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	if(RP_GetEcoTrie("Bank Rob") != INVALID_HANDLE)
		RP_OnEcoLoaded();
		
	return;
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
		
	ImmuneToPlayerLimit[client] = false;
}

public Action:Timer_CreateVault(Handle:timer, any:data)
{
	CreateVaultForRob();
	return Action:0;
}

public Action:Command_SpawnVault(client, args)
{
	CreateVaultForRob();
	
	return Plugin_Handled;
}

public void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zoneName, int type)
{
	if(StrContains(zoneName, "BankRob") != -1 && EntRefToEntIndex(g_iVault) != INVALID_ENT_REFERENCE)
	{
		CreateTimer(0.1, Timer_OnClientInsideBankRob, GetClientUserId(client));
	}
}

public Action:Timer_OnClientInsideBankRob(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
		
	OnClientInsideBankRob(client);
	
}

OnClientInsideBankRob(client)
{
	if(ImmuneToPlayerLimit[client])
		return;

	else if(GetClientTeam(client) == CS_TEAM_CT)
	{
		RP_PrintToChat(client, "You're not allowed to enter bank rob as CT.");
		
		ActionAgainstBadClient(client);
	}
	else if(GetClientTeam(client) == CS_TEAM_T)
	{
		if(Get_User_Gang(client) == -1)
		{
			RP_PrintToChat(client, "You're not allowed to enter bank rob without a gang.");
			
			ActionAgainstBadClient(client);
		}
		else
		{
			new count, bool:hasMate = false;
			
			for(new i=1;i <= MaxClients;i++)
			{
				if(client == i)
				{
					count++;
					continue;
				}	
				else if(!IsClientInGame(i))
					continue;
				
				else if(!IsValidTeam(i))
					continue;
				
				count++;
				
				if(!IsPlayerAlive(i))
					continue;
					
				else if(GetClientTeam(i) != CS_TEAM_T)
					continue;
				
				else if(!Are_Users_Same_Gang(client, i))
					continue;
					
				else if(!Zone_IsClientInZone(i, "SafeZone Bank", true) && !Zone_IsClientInZone(i, "BankRob", false))
					continue;
					
				hasMate = true;
			}
			
			if(count >= GetConVarInt(hcv_minDuo) && !hasMate)
			{
				RP_PrintToChat(client, "You're not allowed to enter bank rob without a friend at %i or more players.", GetConVarInt(hcv_minDuo));
				
				ActionAgainstBadClient(client);
			}
		}
	}
	
	ImmuneToPlayerLimit[client] = true; // This will be reset anyways if the client was killed.
}

ActionAgainstBadClient(client)
{
	BlockNextCoinDrop = true;
	ForcePlayerSuicide(client);

	BlockNextCoinDrop = false;
}

public Action:RP_ShouldClientDropCoins(client)
{
	if(BlockNextCoinDrop)
	{
		BlockNextCoinDrop = false;
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}

public CheckVaultInteraction(entity)
{
	if(!IsValidEntity(entity))
		return;
		
	RequestFrame(CheckVaultInteraction, entity);
	
	for(new client=1;client <= MaxClients;client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		else if(!IsPlayerAlive(client))
			continue;
		
		else if(GetClientTeam(client) == CS_TEAM_CT)
			continue;
			
		new Float:Origin[3], Float:boxOrigin[3];
		
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", boxOrigin);
		
		if(GetVectorDistance(Origin, boxOrigin, false) > 35.0)
			continue;
			
		else if(boxOrigin[2] - Origin[2] < 13.0 && !GetConVarBool(hcv_freeLook))
			continue;
			
		else if(!Zone_IsClientInZone(client, "BankRob CrackSpot", true, true))
			continue;
		
		static Float:time;
		time = GetEngineTime();
		if (time - g_fLastTouch[client] < 0.5)
		{
			return;
		}
		if (GetClientButtons(client) & IN_USE)
		{
			if (Get_User_Gang(client) == -1)
			{
				return;
			}
			if (time - g_fLastUsed[client] > 0.8)
			{
				g_iLockPickProcess = 0;
			}
			if (client != g_iVaultPicker)
			{
				g_iLockPickProcess = 0;
			}
			
			new Float:Position[3], Float:Angles[3];
			GetClientEyePosition(client, Position); 
			GetClientEyeAngles(client, Angles); 
			
			TR_TraceRayFilter(Position, Angles, MASK_SHOT, RayType_Infinite, Trace_HitSafeOnly, entity); //Start the trace 

			new entHit = TR_GetEntityIndex();
			if(entHit != entity && !GetConVarBool(hcv_freeLook))
				return; // Return will ensure he has 0.8 to look back at the vault
				
			g_iVaultPicker = client;
			g_iLockPickProcess += 1;
			
			new String:LoadingFormat[512];
			
			BuildLoadingFormat(g_iLockPickProcess, 40, LoadingFormat, sizeof(LoadingFormat))
			
			PrintCenterText(client, "<font color='#FF0000'>Cracking the vault!</font><br>[%s]", LoadingFormat);
			if (g_iLockPickProcess >= 40)
			{
				new String:szName[32];
				Get_User_Gang_Name(client, szName, 32);
				
				new minPrize = MIN_BANK_ROB_REWARD;
				new maxPrize = MAX_BANK_ROB_REWARD;
							
				minPrize += RoundToCeil(float(minPrize) * ((float(Get_User_Luck_Bonus(client)) / 100.0) * 2.0)); // * 2.0 to make critical luck ( $5,000 ) also more likely without allowing to pass $5,000
							
				new iCashToGive = GetRandomInt(minPrize, maxPrize); 
				
				new count=0;
				
				for(new i=1;i <= MaxClients;i++)
				{
					if (IsClientInGame(i))
					{
						if(client == i || Are_Users_Same_Gang(client, i))
						{
							if(Zone_IsClientInZone(i, "BankRob", false))
							{
								count++;
							}
						}
					}
				}
				
				if(count == 0)
					count = 1;
					
				iCashToGive = RoundToFloor(float(iCashToGive) / float(count));
			
				new initClient = 0;
				
				for(new i=1;i <= MaxClients;i++)
				{
					if (IsClientInGame(i))
					{
						if(client == i || Are_Users_Same_Gang(client, i))
						{
							if(Zone_IsClientInZone(i, "BankRob", false))
							{
								if(initClient == 0)
								{
									initClient = i; // Reward him in the end for proper calculations.
									
									continue;
								}
								
								GiveClientCash(i, BANK_CASH, iCashToGive);
							}
						}
					}
				}
				
				if(initClient != 0)
					iCashToGive = GiveClientCash(initClient, BANK_CASH, iCashToGive);

				RP_PrintToChatAll("\x02%s\x01 gang successfully breached the vault! Each one got $%i!", szName, iCashToGive);
				
				AcceptEntityInput(entity, "Kill", -1, -1, 0);
				
				g_iVault = INVALID_ENT_REFERENCE;
			}
			if (time - g_fLastMessage > 7.0)
			{
				new String:szName[32];
				Get_User_Gang_Name(client, szName, 32);
				RP_PrintToChatAll("\x02%s\x01 gang is now robbing the bank!! go and stop them", szName);
				g_fLastMessage = time;
			}
			g_fLastUsed[client] = time;
		}
		g_fLastTouch[client] = time;
		return;	
	}
}

public bool:Trace_HitSafeOnly(entity, contentsMask, safe) 
{ 
	return entity == safe; 
}  

public OnMapStart()
{
	PrecacheModel(SAFE_MODEL, true);
	BlockNextCoinDrop = false;
	
	g_iVault = INVALID_ENT_REFERENCE;
	return;
}

CreateVaultForRob()
{
	RP_PrintToChatAll("A vault has been spawned, go and rob it with your gang!");
	
	new vault = EntRefToEntIndex(g_iVault);
	
	if(vault != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(g_iVault, "Kill", -1, -1, 0);
	}
	new box = CreateEntityByName("prop_physics_override");
	
	if (IsValidEntity(box))
	{
		DispatchKeyValue(box, "model", SAFE_MODEL);
		DispatchKeyValue(box, "disableshadows", "1");
		DispatchKeyValue(box, "disablereceiveshadows", "1");
		DispatchKeyValue(box, "solid", "1");
		DispatchKeyValue(box, "spawnflags", "11");
		DispatchKeyValue(box, "PerformanceMode", "1");
		DispatchKeyValue(box, "classname", "vault");
		DispatchSpawn(box);

		TeleportEntity(box, SAFE_SPAWN_XYZ, Float:{0.0, -90.0, 0.0}, NULL_VECTOR);		

		AcceptEntityInput(box, "DisableMotion");
		RequestFrame(CheckVaultInteraction, box);
		
		//AcceptEntityInput(box, "DisableMotion");
	}
	
	g_iVault = EntIndexToEntRef(box);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsPlayerAlive(i))
			continue;
		
		ImmuneToPlayerLimit[i] = false;
		
		if(Zone_IsClientInZone(i, "BankRob", false))
			OnClientInsideBankRob(i);
	}
	return;
}

BuildLoadingFormat(current, total, String:buffer[], len)
{
	new i;
	
	Format(buffer, len, "<font color='#FF0000'>");
	while (i < current)
	{
		Format(buffer, len, "%s#", buffer);
		i++;
	}
	
	Format(buffer, len, "%s<font color='#FFFFFF'>", buffer);
	
	i = current;
	while (i < total)
	{
		Format(buffer, len, "%s_", buffer);
		i++;
	}
}

stock bool:IsValidTeam(client)
{
	return GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT
}	