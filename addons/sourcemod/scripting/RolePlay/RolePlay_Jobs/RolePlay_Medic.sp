#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <emitsoundany>
#include <Eyal-RP>

#define MENUINFO_HEAL "Medic - Heal Player"
#define MENUINFO_HEALTHSHOT "Medic - Sell Healthshot"

new EngineVersion:g_Game;

new sprLaserBeam;

new LastHealButtons[MAXPLAYERS+1];
new LastSellButtons[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "RolePlay Medic Job",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new Handle:fw_HealedPost = INVALID_HANDLE;

new Handle:hTimer_MedicStatus[MAXPLAYERS+1];
new Handle:hTimer_Regen[MAXPLAYERS+1];

new g_iMedicJob;

new Float:g_fMedicTime[MAXPLAYERS + 1];
new Float:g_fSellTime[MAXPLAYERS + 1];
new bool:UsedHealthshot[MAXPLAYERS + 1];

new g_iSpecialCategory;
new g_iHealthshotItem;

new MEDIC_PRICE = 1000;
new MEDIC_PROFIT_PER_HP = 1;

new HEALTHSHOT_PRICE = 10000;
new HEALTHSHOT_PROFIT = 50;

new String:g_szLevels[11][16];

new g_iHealAmount[11];

new Handle:Trie_MedicEco;

public RP_OnEcoLoaded()
{
	
	Trie_MedicEco = RP_GetEcoTrie("Medic");
	
	if(Trie_MedicEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Medic");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "HEAL_AMOUNT_LVL_#%i", i);
		
		if(!GetTrieString(Trie_MedicEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iHealAmount[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_MedicEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_MedicEco, "MEDIC_PRICE", TempFormat, sizeof(TempFormat));
	
	MEDIC_PRICE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MedicEco, "MEDIC_PROFIT_PER_HP", TempFormat, sizeof(TempFormat));
	
	MEDIC_PROFIT_PER_HP = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MedicEco, "HEALTHSHOT_PRICE", TempFormat, sizeof(TempFormat));
	
	HEALTHSHOT_PRICE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MedicEco, "HEALTHSHOT_PROFIT", TempFormat, sizeof(TempFormat));
	
	HEALTHSHOT_PROFIT = StringToInt(TempFormat);	
	
	
	
	g_iSpecialCategory = RP_AddCategory("Special (Once per Spawn)");

	g_iHealthshotItem = RP_CreateItem("Healthshot", "HPSHOT");
	
	RP_SetItemCategory(g_iHealthshotItem, g_iSpecialCategory);
}
public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		Func_OnClientPutInServer(i);
	}
	
	RegConsoleCmd("sm_medic", Command_Medic);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	fw_HealedPost = CreateGlobalForward("RP_OnMedicHealedPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	
	if(RP_GetEcoTrie("Medic") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
		
	UsedHealthshot[client] = false;
}

public Action:Command_Medic(client, args)
{
	if(hTimer_MedicStatus[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_MedicStatus[client]);
		hTimer_MedicStatus[client] = INVALID_HANDLE;
	}
	else
		hTimer_MedicStatus[client] = CreateTimer(1.0, Timer_ShowMedicStatus, client, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Timer_ShowMedicStatus(Handle:timer, any:client)
{	
	if(RP_GetClientJob(client) != g_iMedicJob)
	{
		hTimer_MedicStatus[client] = INVALID_HANDLE;
		return;
	}
	
	new closestTarget = 0, weakestTarget = 0;
	
	new Float:Origin[3], Float:targetDistance = 999999.0, targetHealth = 69420;
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(client == i)
			continue;
			
		else if(!IsClientInGame(i))
			continue;
		
		else if(!IsPlayerAlive(i))
			continue;
			
		else if(GetEntityHealth(i) >= GetEntityMaxHealth(i))
			continue;
			
		else if(RP_IsUserInArena(i) || RP_IsUserInDuel(i) || IsPlayerInAdminRoom(i))
			continue;
			
		new Float:iOrigin[3];
		
		GetEntPropVector(i, Prop_Data, "m_vecOrigin", iOrigin);
		
		if(GetVectorDistance(iOrigin, Origin, false) < targetDistance)
		{
			closestTarget = i;
			
			targetDistance = GetVectorDistance(iOrigin, Origin, false);
		}
		
		if(GetEntityHealth(i) < targetHealth)
		{	
			weakestTarget = i;
			
			targetHealth = GetEntityHealth(i);
		}
	}
	
	new String:ClosestName[64];
	GetClientName(closestTarget, ClosestName, sizeof(ClosestName));
	
	new String:WeakestName[64];
	GetClientName(weakestTarget, WeakestName, sizeof(WeakestName));
	
	new String:TempFormat[64];
	
	if(g_fMedicTime[client] > GetGameTime())
		FormatEx(TempFormat, sizeof(TempFormat), "[Cooldown %.0f seconds]", g_fMedicTime[client] - GetGameTime());
		
	else
		TempFormat = "ON";
		
	PrintHintText(client, "<font color='#f44336'><u>Medic Sense: %s</u></font><br><font color'#5D4037'>Closest | Weakest Target: </font><font color='#0000FF'>%s | %s</font><br><font color'#5D4037'></font>", TempFormat, closestTarget == 0 ? "None" : ClosestName, weakestTarget == 0 ? "None" : WeakestName);
	
	if(closestTarget != 0)
	{
		TE_SetupBeamLaser(closestTarget, client, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {0, 0, 255, 255}, 0);
		TE_SendToClient(client, 0.0);
	}
	
	if(weakestTarget != 0)
	{
		TE_SetupBeamLaser(weakestTarget, client, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {0, 255, 255, 255}, 0);
		TE_SendToClient(client, 0.0);
	}
	
	if(g_fMedicTime[client] > GetGameTime())
	{
		new Float:fraction = FloatFraction(g_fMedicTime[client] - GetGameTime())
		
		if(fraction == 0.0)
			fraction = 1.0;
			
		hTimer_MedicStatus[client] = CreateTimer(fraction, Timer_ShowMedicStatus, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
		hTimer_MedicStatus[client] = CreateTimer(1.0, Timer_ShowMedicStatus, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if(!(buttons == LastHealButtons[client]))
		LastHealButtons[client] = -1;
		
	if(!(buttons == LastSellButtons[client]))
		LastSellButtons[client] = -1;
}


public Action:OnItemUsed(client, item)
{
	new category = RP_GetItemCategory(item);
	
	if(category != g_iSpecialCategory)
		return Plugin_Continue;
	
	else if(g_iHealthshotItem != item)	
		return Plugin_Continue;
	
	else if(UsedHealthshot[client])
	{
		RP_PrintToChat(client, "You can only use the healthshot once per spawn.");
		return Plugin_Stop
	}
	
	new weapon = GivePlayerItem(client, "weapon_healthshot");
	
	if(weapon == -1)
	{
		weapon = CreateEntityByName("game_player_equip");
	
		DispatchKeyValue(weapon, "weapon_healthshot", "0");
		
		DispatchKeyValue(weapon, "spawnflags", "1");
		
		AcceptEntityInput(weapon, "use", client);
		
		//AcceptEntityInput(weapon, "Kill"); // Could throw errors for deleting -1.
	}
	
	RP_PrintToChat(client, "You have used your \x02%s!", "Healthshot");
	
	UsedHealthshot[client] = true;
	
	return Plugin_Continue;
}
public RP_OnPlayerMenu(client, target, &Menu:menu, priority)
{
	if(priority != PRIORITY_MEDIC)
		return;
		
	if (RP_GetClientJob(target) == g_iMedicJob)
	{		
	
		new bool:CanAfford = false;
		
		if(GetClientCash(client, POCKET_CASH) >= MEDIC_PRICE || GetClientCash(client, BANK_CASH) >= MEDIC_PRICE)
			CanAfford = true;

		new String:szFormatex[64];
		
		if(GetClientHealth(client) >= GetEntityMaxHealth(client))
		{
			FormatEx(szFormatex, 64, "Heal - $%i [Max HP]", MEDIC_PRICE);
			CanAfford = false;
		}
		else if(g_fMedicTime[target] > GetGameTime())
		{
			FormatEx(szFormatex, 64, "Heal - $%i [Cooldown %.1f seconds]", MEDIC_PRICE, g_fMedicTime[target] - GetGameTime());
			CanAfford = false;
		}
		else if(LastHealButtons[target] != -1)
		{
			FormatEx(szFormatex, 64, "Heal - $%i [AFK]", MEDIC_PRICE);
			CanAfford = false;
		}
		else
		{
			new hp;
			hp = g_iHealAmount[RP_GetClientLevel(target, g_iMedicJob)]
			
			if(GetClientHealth(client) + hp > GetEntityMaxHealth(client))
				hp = GetEntityMaxHealth(client) - GetClientHealth(client);
				
			FormatEx(szFormatex, 64, "Heal - $%i [+%i HP]", MEDIC_PRICE, hp);
		}
		
		AddMenuItem(menu, MENUINFO_HEAL, szFormatex, CanAfford ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		
		CanAfford = false;
		
		if(GetClientCash(client, POCKET_CASH) >= HEALTHSHOT_PRICE || GetClientCash(client, BANK_CASH) >= HEALTHSHOT_PRICE)
			CanAfford = true;

		szFormatex[0] = EOS;
		
		if(g_fSellTime[target] > GetGameTime())
		{
			FormatEx(szFormatex, 64, "Buy Healthshot - $%i [Cooldown %.1f seconds]", HEALTHSHOT_PRICE, g_fSellTime[target] - GetGameTime());
			CanAfford = false;
		}
		
		else if(LastSellButtons[target] != -1)
		{
			FormatEx(szFormatex, 64, "Buy Healthshot - $%i [AFK]", HEALTHSHOT_PRICE);
			CanAfford = false;
		}
		else
			FormatEx(szFormatex, 64, "Buy Healthshot - $%i", HEALTHSHOT_PRICE);
		
		AddMenuItem(menu, MENUINFO_HEALTHSHOT, szFormatex, CanAfford ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
}


public RP_OnMenuPressed(client, target, const String:info[])
{
	if (StrEqual(info, MENUINFO_HEAL))
	{
		
		new bool:CanAfford = false;
		
		if(GetClientCash(client, POCKET_CASH) >= MEDIC_PRICE || GetClientCash(client, BANK_CASH) >= MEDIC_PRICE)
			CanAfford = true;
		
		if(CheckDistance(client, target) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away!");
			
			return;
		}
		else if(!CanAfford)
		{
			RP_PrintToChat(client, "You dont have enough money");
			
			return;
		}
		
		else if (g_fMedicTime[target] > GetGameTime())
		{
			RP_PrintToChat(client, "Please wait more \x04%.1f\x01 seconds!", g_fMedicTime[target] - GetGameTime());
			
			return;
		}
		else if (GetClientHealth(client) >= GetEntityMaxHealth(client))
		{
			RP_PrintToChat(client, "Your health is already full!");
				
			return;
		}
		
		else if(!RP_IsClientInRP(client))
		{
			RP_PrintToChat(client, "You cannot heal when enemies are nearby.");
				
			return;
		}
		
		else if(LastHealButtons[target] != -1)
		{
			RP_PrintToChat(client, "You cannot heal from an AFK medic.");
				
			return;
		}
		
		else if(!IsPlayerAlive(client))
		{
			RP_PrintToChat(client, "%N is not a necromancer.", target);
				
			return;
		}
		
		new hp;
		hp = g_iHealAmount[RP_GetClientLevel(target, g_iMedicJob)]
		
		if(GetClientHealth(client) + hp > GetEntityMaxHealth(client))
			hp = GetEntityMaxHealth(client) - GetClientHealth(client);
			
		new money = hp * MEDIC_PROFIT_PER_HP;
		new exp = RoundToFloor((float(hp) / float(g_iHealAmount[RP_GetClientLevel(target, g_iMedicJob)])) * 15.0); // Assumes that no HP is lost in the heal, 10 exp is given.
		
		SetEntityHealth(client, GetClientHealth(client) + hp);
		
		RP_PrintToChat(client, "\x02%N\x01 has healed you for $%i\x04 (%i HP).", target, MEDIC_PRICE, hp);
		RP_PrintToChat(target, "You've healed \x02%N \x04(%i HP)\x01 for \x02$%i\x01!", client, hp, money);
		
		GiveClientCashNoGangTax(target, BANK_CASH, money);
		
		if(GetClientCash(client, POCKET_CASH) >= MEDIC_PRICE)
			GiveClientCash(client, POCKET_CASH, -1 * MEDIC_PRICE);
			
		else
			GiveClientCash(client, BANK_CASH, -1 * MEDIC_PRICE);
		
		g_fMedicTime[target] = GetGameTime() + 60.0;
		
		if(RP_GetClientLevel(target, g_iMedicJob) >= 7)
		{
	
			g_fMedicTime[target] -= 20.0;
		}
		else if(RP_GetClientLevel(target, g_iMedicJob) >= 2)
		{
	
			g_fMedicTime[target] -= 5.0;
		}
		
		RP_AddClientEXP(target, g_iMedicJob, exp);
		
		LastHealButtons[target] = GetClientButtons(target);
		
		new clients[MAXPLAYERS+1], count;
		
		new Float:Origin[3];
		
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!IsPlayerAlive(i))
				continue;
				
			new Float:iOrigin[3];
			
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", iOrigin);
			
			if(GetVectorDistance(iOrigin, Origin, false) < 512.0)
				clients[count++] = i;

		}
		
		EmitSoundAny(clients, count, "roleplay/medic_heal_.mp3", -2, SNDCHAN_AUTO, 75, 0, 1.0, 100, -1, Origin, NULL_VECTOR, true, 0.0);
		
		Call_StartForward(fw_HealedPost);
		
		Call_PushCell(client);
		Call_PushCell(target);
		Call_PushCell(g_iMedicJob);
		
		Call_Finish();
	}
	else if (StrEqual(info, MENUINFO_HEALTHSHOT))
	{
		
		new bool:CanAfford = false;
		
		if(GetClientCash(client, POCKET_CASH) >= HEALTHSHOT_PRICE || GetClientCash(client, BANK_CASH) >= HEALTHSHOT_PRICE)
			CanAfford = true;
		
		if(CheckDistance(client, target) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away!");
			
			return;
		}
		else if(!CanAfford)
		{
			RP_PrintToChat(client, "You dont have enough money");
			
			return;
		}
		
		else if (g_fSellTime[target] > GetGameTime())
		{
			RP_PrintToChat(client, "Please wait more \x04%.1f\x01 seconds!", g_fSellTime[target] - GetGameTime());
			
			return;
		}
		
		else if(!RP_IsClientInRP(client))
		{
			RP_PrintToChat(client, "You cannot heal when enemies are nearby.");
				
			return;
		}
		
		else if(LastSellButtons[target] != -1)
		{
			RP_PrintToChat(client, "You cannot buy from an AFK medic.");
				
			return;
		}
		
			
		new exp = 15;
		
		RP_PrintToChat(client, "\x02%N\x01 has sold you\x04 a healthshot\x01 for \x02$%i\x01!", target, HEALTHSHOT_PRICE);
		RP_PrintToChat(target, "You've sold \x02%N \x04a healthshot\x01 for \x02$%i\x01!", client, HEALTHSHOT_PROFIT);
		
		GiveClientCashNoGangTax(target, BANK_CASH, HEALTHSHOT_PROFIT);
		
		if(GetClientCash(client, POCKET_CASH) >= HEALTHSHOT_PRICE)
			GiveClientCash(client, POCKET_CASH, -1 * HEALTHSHOT_PRICE);
			
		else
			GiveClientCash(client, BANK_CASH, -1 * HEALTHSHOT_PRICE);
		
		RP_GiveItem(client, g_iHealthshotItem);
		
		g_fSellTime[target] = GetGameTime() + 70.0;
		
		if(RP_GetClientLevel(target, g_iMedicJob) >= 10)
		{
			g_fSellTime[target] = 0.0; // No cooldown, notice that you need to account for GetGameTime to edit the cooldown
		}
		else if(RP_GetClientLevel(target, g_iMedicJob) >= 7)
		{
	
			g_fSellTime[target] -= 20.0;
		}
		else if(RP_GetClientLevel(target, g_iMedicJob) >= 2)
		{
			g_fSellTime[target] -= 5.0;
		}
		
		RP_AddClientEXP(target, g_iMedicJob, exp);
		
		LastSellButtons[target] = GetClientButtons(target);
		
		new clients[MAXPLAYERS+1], count;
		
		new Float:Origin[3];
		
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!IsPlayerAlive(i))
				continue;
				
			new Float:iOrigin[3];
			
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", iOrigin);
			
			if(GetVectorDistance(iOrigin, Origin, false) < 512.0)
				clients[count++] = i;

		}
		
		EmitSoundAny(clients, count, "roleplay/medic_heal_.mp3", -2, SNDCHAN_AUTO, 75, 0, 1.0, 100, -1, Origin, NULL_VECTOR, true, 0.0);
	}
}

public OnClientDisconnect(client)
{
	if(hTimer_MedicStatus[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_MedicStatus[client]);
		hTimer_MedicStatus[client] = INVALID_HANDLE;
	}
	
	if(hTimer_Regen[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_Regen[client]);
		hTimer_Regen[client] = INVALID_HANDLE;
	}
}
public OnClientPutInServer(client)
{
	Func_OnClientPutInServer(client)
}
public Func_OnClientPutInServer(client)
{
	g_fMedicTime[client] = 0.0;
	g_fSellTime[client] = 0.0;
}

public OnMapStart()
{	
	for(new i=0;i < sizeof(hTimer_MedicStatus);i++)
		hTimer_MedicStatus[i] = INVALID_HANDLE;
		
	for(new i=0;i < sizeof(hTimer_Regen);i++)
		hTimer_Regen[i] = INVALID_HANDLE;
		

	AddFileToDownloadsTable("sound/roleplay/medic_heal_.mp3");
	PrecacheSoundAny("roleplay/medic_heal_.mp3", true);
	
	sprLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	
	CreateTimer(10.0, Timer_GangRegen, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
		
	new level = RP_GetClientLevel(client, g_iMedicJob);
	
	if(hTimer_Regen[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_Regen[client]);
		
		hTimer_Regen[client] = INVALID_HANDLE;
	}
	if (job == g_iMedicJob)
	{
		if (GetClientTeam(client) != 2)
		{
			CS_SwitchTeam(client, 2);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iMedicJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);

		GivePlayerItem(client, "weapon_healthshot", 0);
			
		CS_SetClientClanTag(client, "Medic");
		RP_SetClientJobName(client, g_szLevels[level]);
			
		switch (level)
		{
			case 1, 2:
			{
				RP_GivePlayerItem(client, "weapon_glock");
			}
			case 3, 4, 5, 6, 7, 8, 9:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 10:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
				RP_GivePlayerItem(client, "weapon_tagrenade");
			}
		}
		
		if(level >= 4)
			SetClientArmor(client, 100);
			
		if(level >= 6)
			SetClientHelmet(client, true);
		
		if(level >= 9)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 10);
			SetEntityHealth(client, GetClientHealth(client) + 10);
			
			for (new i = 0; i < 3;i++)
			{
				GivePlayerItem(client, "weapon_healthshot", 0);
			}
		}
		if(level >= 10)
			hTimer_Regen[client] = CreateTimer(1.0, Timer_Regen, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
			
		else if(level >= 5)
			hTimer_Regen[client] = CreateTimer(10.0, Timer_Regen, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
	}
	// If not medic.
	else if(level >= 5)
		hTimer_Regen[client] = CreateTimer(10.0, Timer_Regen, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
	
	return false;
}

public Action:Timer_GangRegen(Handle:timer)
{	
	for (new client = 1; client <= MaxClients;client++)
	{
		if(!IsClientInGame(client))
			continue; 
		
		if(!IsPlayerAlive(client))
			continue;
		
		if(!RP_IsClientInRP(client))
			continue;
			
		if(Get_User_Gang(client) == -1)
			continue;
			
		for (new i = 1; i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!IsPlayerAlive(i))
				continue;
			
			else if(GetEntityHealth(i) >= GetEntityMaxHealth(i))
				continue;
				
			else if(!RP_IsClientInRP(i))
				continue;
				
			else if(RP_GetClientJob(i) != g_iMedicJob)
				continue;
			
			else if(!Are_Users_Same_Gang(client, i))
				continue;
				
			else if(RP_GetClientLevel(i, g_iMedicJob) < 6)
				continue;
			
			else if(CheckDistance(client, i) > 512)
				continue;
				
			new maxHealth = GetEntityMaxHealth(client);
			
			new amountToHeal = 1;
			
			if(amountToHeal + GetClientHealth(client) > maxHealth)
			{
				amountToHeal = maxHealth - GetEntityHealth(client);
			}
			
			SetEntityHealth(client, GetClientHealth(client) + amountToHeal);
			
			i = MAX_INTEGER-10; // I don't like breaking in a double loop.
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_Regen(Handle:timer, any:client)
{	
	if(GetEntityHealth(client) >= GetEntityMaxHealth(client))
		return Plugin_Continue;
		
	else if(!RP_IsClientInRP(client))
		return Plugin_Continue;
		
	new maxHealth = GetEntityMaxHealth(client);
	
	new amountToHeal;
	
	new level = RP_GetClientLevel(client, g_iMedicJob);
	
	if(RP_GetClientJob(client) == g_iMedicJob && level >= 10)
		amountToHeal = 1;
		
	else
	{
		if(level >= 8)
			amountToHeal = 2;
			
		else if(level >= 5)
			amountToHeal = 1;
			
		if(RP_GetClientJob(client) == g_iMedicJob && level >= 6)
			amountToHeal += 1;
			
	}
	
	if(amountToHeal + GetClientHealth(client) > maxHealth)
	{
		amountToHeal = maxHealth - GetEntityHealth(client);
	}
	
	SetEntityHealth(client, GetClientHealth(client) + amountToHeal);
	
	return Plugin_Continue;
}


public OnClientChangeJobPost(int client, int job, int oldjob, bool:respawn)
{
	if(job == g_iMedicJob && !respawn)
		RP_PrintToChat(client, "Hint! You can use\x07 !medic\x01 to find injured players around the map!");

}
public Action:Thief_RequestIdentity(client, const String:JobShortName[], &FakeLevel, String:LevelName[32], String:Model[PLATFORM_MAX_PATH])
{
	if(StrEqual(JobShortName, "MED", false))
	{
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iMedicJob, model, sizeof(model));

		if(model[0] != EOS)
			FormatEx(Model, sizeof(Model), model);

		FormatEx(LevelName, sizeof(LevelName), g_szLevels[RP_GetClientLevel(client, g_iMedicJob)]);
		
		FakeLevel = RP_GetClientLevel(client, g_iMedicJob);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iMedicJob = RP_CreateJob("Medic", "MED", 11);
	}
}

stock GetEntityHealth(entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}