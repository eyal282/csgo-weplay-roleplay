#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new g_iJobNPC;
new g_iTotalJobs;
new ArrayList:g_aJobName;
new ArrayList:g_aJobShortName;
new ArrayList:g_aJobModel;
new ArrayList:g_aJobMaxLevel;

new g_iPlayerLevel[MAXPLAYERS+1][32];
new g_iPlayerEXP[MAXPLAYERS+1][32];
new g_iPlayerBank[MAXPLAYERS+1][32];

new g_iPlayerJob[MAXPLAYERS+1];
new Float:g_fJobDelay[MAXPLAYERS+1];
new Handle:g_hJobStats;
new Handle:g_hChangeJob;
new Handle:g_hChangeJobPost;
new Handle:g_hEXPGained;
new bool:g_bLoadedData[MAXPLAYERS+1];
new Database:g_hDatabase;

new String:g_szClientJobName[MAXPLAYERS+1][32];
new Handle:hcv_JobChangeDelay = INVALID_HANDLE;

public OnPluginStart()
{
	g_Game = GetEngineVersion();
	
	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	LoadTranslations("common.phrases");
	if (!g_hDatabase)
	{
		new String:error[256];
		g_hDatabase = SQL_Connect("eyal_rp", true, error, 255);
		if (!g_hDatabase)
		{
			PrintToServer("Could not connect [SQL]: %s", error);
		}
	}
	
	if(g_hDatabase)
		SQL_TQuery(g_hDatabase, SQL_NoAction, "CREATE TABLE IF NOT EXISTS `rp_jobs` ( `AuthId` varchar(32) NOT NULL, `nickname` varchar(64), `job_short_name` varchar(32) NOT NULL, `exp` int(11) NOT NULL, `bank` int(11) NOT NULL, UNIQUE KEY `AuthId` (`AuthId`,`job_short_name`) )", any:0, DBPriority:1);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			Func_OnClientPostAdminCheck(i);
		}
	}
	g_aJobName = CreateArray(32, 0);
	g_aJobShortName = CreateArray(32, 0);
	g_aJobModel = CreateArray(PLATFORM_MAX_PATH, 0);
	g_aJobMaxLevel = CreateArray(1, 0);
	g_hJobStats = CreateGlobalForward("UpdateJobStats", ET_Event, Param_Cell, Param_Cell);
	g_hChangeJob = CreateGlobalForward("OnClientChangeJob", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	g_hChangeJobPost = CreateGlobalForward("OnClientChangeJobPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hEXPGained = CreateGlobalForward("OnClientEarnJobEXP", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	
	RegAdminCmd("sm_givejobexp", Command_GiveJobExp, ADMFLAG_ROOT, "Gives client job exp", "", 0);
	RegAdminCmd("sm_givejobbalance", Command_GiveJobBalance, ADMFLAG_ROOT, "Gives client job balance", "", 0);
	RegConsoleCmd("sm_depositjob", Command_DepositJob);
	
	HookEvent("player_spawn", EventOnPlayerRespawn, EventHookMode_Post);
	
	hcv_JobChangeDelay = CreateConVar("rp_change_job_delay", "180.0");
	return;
}

public Action:EventOnPlayerRespawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	
	//ResetKnife(client);
	if (g_iPlayerJob[client] != -1)
	{
		SetClientJobStats(client);
		
		Call_StartForward(g_hChangeJobPost);
		Call_PushCell(client);
		Call_PushCell(g_iPlayerJob[client]);
		Call_PushCell(g_iPlayerJob[client]);
		Call_PushCell(true);

		Call_Finish();
	}
	else
		CS_SetClientClanTag(client, "Jobless");
		
	return Plugin_Continue;
}

public Action:Command_GiveJobExp(client, args)
{
	if (!IsHighManagement(client))
	{
		RP_PrintToChat(client, "Sorry! but you cant use this command.");
	}
	else
	{
		if (args < 2)
		{
			RP_PrintToChat(client, "Missing arguments!, sm_givejobexp <client> <exp>");
			
			return Plugin_Handled;
		}
		new String:szArg1[32];
		new String:szArg2[16];
		GetCmdArg(1, szArg1, 32);
		new target = FindTarget(client, szArg1, true, false);
		
		if (target == -1)
		{
			return Plugin_Handled;
		}
		else if(!g_bLoadedData[target])
		{
			return Plugin_Handled;
		}
		else if(g_iPlayerJob[target] == -1)
		{
			RP_PrintToChat(client, "Target doesn't have a job!");
			return Plugin_Handled;
		}
		GetCmdArg(2, szArg2, 16);
		new exp = StringToInt(szArg2, 10);
		AddUserExp(target, g_iPlayerJob[target], exp, false);
		RP_PrintToChat(client, "You have given \x02%N\x01 \x04%i\x01 exp to his \x02current job!", target, exp);
		RP_PrintToChat(target, "\x02%N\x01 has gave you \x04%i\x01 exp to your current job!", client, exp);
		RolePlayAdminLog("%N has gave %N %i (%i)job exp! [ADMIN]", client, target, exp, g_iPlayerJob[target]);
	}
	return Plugin_Handled;
}


public Action:Command_GiveJobBalance(client, args)
{
	if (!IsHighManagement(client))
	{
		RP_PrintToChat(client, "Sorry! but you cant use this command.");
	}
	else
	{
		if (args < 2)
		{
			RP_PrintToChat(client, "Missing arguments!, sm_givejobbalance <client> <amount>");
			
			return Plugin_Handled;
		}
		new String:szArg1[32];
		new String:szArg2[16];
		GetCmdArg(1, szArg1, 32);
		new target = FindTarget(client, szArg1, true, false);
		
		if (target == -1)
		{
			return Plugin_Handled;
		}
		else if(!g_bLoadedData[target])
		{
			return Plugin_Handled;
		}
		else if(g_iPlayerJob[target] == -1)
		{
			RP_PrintToChat(client, "Target doesn't have a job!");
			return Plugin_Handled;
		}
		GetCmdArg(2, szArg2, 16);
		new amount = StringToInt(szArg2, 10);
		AddUserBank(target, g_iPlayerJob[target], amount);
		RP_PrintToChat(client, "You have given \x02%N\x01 \x04%i\x01 balance to his \x02current job!", target, amount);
		RP_PrintToChat(target, "\x02%N\x01 has gave you \x04%i\x01 balance to your current job!", client, amount);
		RolePlayAdminLog("%N has gave %N %i (%i)job balance! [ADMIN]", client, target, amount, g_iPlayerJob[target]);
	}
	return Plugin_Handled;
}

public Action:Command_DepositJob(client, args)
{
	if(args < 2)
	{
		PrintToChat(client, "[SM] Usage: sm_depositjob <\"job name\"> <amount>");
		
		return Plugin_Handled;
	}
	
	new String:Arg[32];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new job = FindJobByContainedName(Arg);
	
	if(job == -1)
	{
		PrintToChat(client, "[SM] Error: Job \"%s\" was not found.", Arg);
		
		return Plugin_Handled;
	}
	else if(job == -2)
	{
		PrintToChat(client, "[SM] Error: Name \"%s\" was found in more than one job.", Arg);
		
		return Plugin_Handled;		
	}
	
	new maxLevel = GetArrayCell(g_aJobMaxLevel, job);
	
	if(g_iPlayerLevel[client][job] == maxLevel)
	{
		RP_PrintToChat(client, "You are already max level in this job.");
		
		return Plugin_Handled;
	}
	
	new String:Arg2[11];
	GetCmdArg(2, Arg2, sizeof(Arg2));
	
	new amount = StringToInt(Arg2);
	
	if(g_iPlayerBank[client][job] + amount > CalculateBankForNextLevel(g_iPlayerLevel[client][job]))
		amount = CalculateBankForNextLevel(g_iPlayerLevel[client][job]) - g_iPlayerBank[client][job];
		
	if(amount <= 0)
	{
		if(CalculateBankForNextLevel(g_iPlayerLevel[client][job]) - g_iPlayerBank[client][job] <= 0)
			RP_PrintToChat(client, "Your job balance is maxed for this job!");
			
		else
			RP_PrintToChat(client, "Invalid amount!");
		
		return Plugin_Handled;
	}
	else if(GetClientCash(client, BANK_CASH) < amount)
	{
		RP_PrintToChat(client, "You dont have enough cash in your bank!");
		
		return Plugin_Handled;
	}
	
	new Handle:hMenu = CreateMenu(DepositJob_MenuHandler);
	
	new String:sAmount[11], String:sJob[11];
	
	IntToString(amount, sAmount, sizeof(sAmount));
	IntToString(job, sJob, sizeof(sJob));
	
	AddMenuItem(hMenu, sAmount, "Yes");
	AddMenuItem(hMenu, sJob, "No");
	new String:JobName[32];
	
	GetArrayString(g_aJobName, job, JobName, sizeof(JobName));
	
	SetMenuTitle(hMenu, "Deposit %s job cash\nCash for level up: $%i / $%i\nAre you sure you want to deposit $%i? You cannot withdraw it", JobName, g_iPlayerBank[client][job], CalculateBankForNextLevel(g_iPlayerLevel[client][job]), amount);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public DepositJob_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
	if (action == MenuAction_Select)
	{
		if(item == 0)
		{
			new String:sAmount[11], String:sJob[11];

			GetMenuItem(hMenu, 0, sAmount, sizeof(sAmount));
			GetMenuItem(hMenu, 1, sJob, sizeof(sJob));
			
			new amount = StringToInt(sAmount);
			new job = StringToInt(sJob);
			
			if(GetClientCash(client, BANK_CASH) < amount)
			{
				RP_PrintToChat(client, "You dont have enough cash in your bank!");
				
				return;
			}
			
			GiveClientCashNoGangTax(client, BANK_CASH, -1 * amount);
			RP_PrintToChat(client, "You have deposited $%i to your job's bank", amount);
			
			
			AddUserBank(client, job, amount);
		}
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(hMenu);
			hMenu = INVALID_HANDLE;
		}
	}
	return;
}
public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Jobs");
	CreateNative("RP_CreateJob", _RP_CreateJob);
	CreateNative("RP_SetClientJob", _RP_SetClientJob);
	CreateNative("RP_AddClientEXP", _RP_AddClientEXP);
	CreateNative("RP_GetClientJob", _RP_GetClientJob);
	CreateNative("RP_GetClientJobBank", _RP_GetClientJobBank);
	CreateNative("RP_GetJobName", _RP_GetJobName);
	CreateNative("RP_GetJobShortName", _RP_GetJobShortName);
	CreateNative("RP_GetJobModel", _RP_GetJobModel);
	CreateNative("RP_SetJobModel", _RP_SetJobModel);
	CreateNative("RP_FindJobByName", _RP_FindJobByName);
	CreateNative("RP_FindJobByShortName", _RP_FindJobByShortName);
	CreateNative("RP_GetClientJobName", _RP_GetClientJobName);
	CreateNative("RP_GetClientJobShortName", _RP_GetClientJobShortName);
	CreateNative("RP_SetClientJobName", _RP_SetClientJobName);
	CreateNative("RP_GetClientLevel", _RP_GetClientLevel);
	CreateNative("RP_GetClientTrueLevel", _RP_GetClientTrueLevel);
	CreateNative("RP_GetClientEXP", _RP_GetClientEXP);
	return APLRes:0;
}

public _RP_GetClientEXP(Handle:plugin, numParams)
{
	return g_iPlayerEXP[GetNativeCell(1)][GetNativeCell(2)];
}

public _RP_SetClientJob(Handle:plugin, numParams)
{
	new job = GetNativeCell(2);
	new client = GetNativeCell(1);
	if (job == -1)
		g_fJobDelay[client] = 0.0;
		
	ChangeClientJob(client, job, job != -1 ? true : false);

	return 1;
}

public _RP_GetClientLevel(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new job = GetNativeCell(2);
	
	new level = g_iPlayerLevel[client][job];
	
	if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
		level++;
		
	if(level >= GetArrayCell(g_aJobMaxLevel, job) - 1)
		level = GetArrayCell(g_aJobMaxLevel, job) - 1;
	
		
	return level;
}

public _RP_GetClientTrueLevel(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new job = GetNativeCell(2);
	
	new level = g_iPlayerLevel[client][job];
		
	return level;
}

public _RP_GetClientJob(Handle:plugin, numParams)
{
	return g_iPlayerJob[GetNativeCell(1)];
}

public _RP_GetClientJobBank(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	return g_iPlayerBank[client][g_iPlayerJob[client]];
}

public _RP_SetClientJobName(Handle:plugin, numParams)
{
	new String:szJobName[32];
	GetNativeString(2, szJobName, 32);
	strcopy(g_szClientJobName[GetNativeCell(1)], 32, szJobName);
	return 0;
}

public _RP_GetJobName(Handle:plugin, numParams)
{
	new job = GetNativeCell(1);
	
	if(job >= GetArraySize(g_aJobShortName) || job < 0)
		return 0;
		
	new String:szBuffer[32];
	GetArrayString(g_aJobName, job, szBuffer, 32);
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}

public _RP_GetJobShortName(Handle:plugin, numParams)
{
	new job = GetNativeCell(1);
	
	if(job >= GetArraySize(g_aJobShortName))
		return 0;
		
	new String:szBuffer[32];
	GetArrayString(g_aJobShortName, job, szBuffer, 32);
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}


public _RP_GetJobModel(Handle:plugin, numParams)
{
	new job = GetNativeCell(1);
	
	if(job >= GetArraySize(g_aJobModel))
		return 0;
		
	new String:szBuffer[PLATFORM_MAX_PATH];
	GetArrayString(g_aJobModel, job, szBuffer, sizeof(szBuffer));
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}

public _RP_SetJobModel(Handle:plugin, numParams)
{
	new job = GetNativeCell(1);
	
	if(job >= GetArraySize(g_aJobModel))
		return 0;
		
	new String:szBuffer[PLATFORM_MAX_PATH];
	GetNativeString(2, szBuffer, sizeof(szBuffer));
	
	SetArrayString(g_aJobModel, job, szBuffer);
	return 1;
}

public _RP_FindJobByName(Handle:plugin, numParams)
{
	new String:szJobName[32];
	GetNativeString(1, szJobName, 32);
	
	return FindStringInArray(g_aJobName, szJobName);
}

public _RP_FindJobByShortName(Handle:plugin, numParams)
{
	new String:szJobShortName[32];
	
	GetNativeString(1, szJobShortName, 32);
	
	return FindStringInArray(g_aJobShortName, szJobShortName);
}
public _RP_GetClientJobName(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	/*
	new String:szBuffer[32];
	if (g_iPlayerJob[client] == -1)
	{
		strcopy(szBuffer, 32, "None");
	}
	else
	{
		strcopy(szBuffer, 32, g_szClientJobName[client]);
	}
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	*/
	
	new job = g_iPlayerJob[client];
	
	if(job >= GetArraySize(g_aJobShortName) || job < 0)
		return 0;
		
	new String:szBuffer[32];
	GetArrayString(g_aJobName, job, szBuffer, 32);
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}

public _RP_GetClientJobShortName(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new String:szBuffer[32];
	if (g_iPlayerJob[client] == -1)
	{
		strcopy(szBuffer, 32, "None");
	}
	else
	{
		GetArrayString(g_aJobShortName, g_iPlayerJob[client], szBuffer, 32);
	}
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}

public _RP_AddClientEXP(Handle:plugin, numParams)
{
	AddUserExp(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
	return 0;
}

public _RP_CreateJob(Handle:plugin, numParams)
{
	new String:szJobName[32];
	GetNativeString(1, szJobName, 32);
	new String:szJobShortName[32];
	GetNativeString(2, szJobShortName, 32);
	if (FindStringInArray(g_aJobName, szJobName) != -1)
	{
		new index = FindStringInArray(g_aJobName, szJobName);
		return index;
	}
	PushArrayString(g_aJobName, szJobName);
	PushArrayString(g_aJobShortName, szJobShortName);
	PushArrayString(g_aJobModel, "");
	PushArrayCell(g_aJobMaxLevel, GetNativeCell(3));
	g_iTotalJobs += 1;
	return g_iTotalJobs - 1;
}

public OnClientPostAdminCheck(client)
{
	Func_OnClientPostAdminCheck(client);
}

public Func_OnClientPostAdminCheck(client)
{
	for(new i=0;i < g_iTotalJobs;i++)
	{
		g_iPlayerLevel[client][i] = 0;
		g_iPlayerEXP[client][i] = 0;
	}
	
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT job_short_name, exp, bank from rp_jobs where AuthId='%s'", szAuth);

	SQL_TQuery(g_hDatabase, SQL_LoadData, szQuery, GetClientSerial(client));
	return;
}

public OnClientConnected(client)
{
	g_iPlayerJob[client] = -1;
	
	g_fJobDelay[client] = 0.0;
	return;
}

public OnClientDisconnect(client)
{
	ChangeClientJob(client, -1, false);
	
	g_bLoadedData[client] = false;

	return;
}

public OnMapStart()
{
	LoadDirOfModels("models/player/custom_player/kuristaja/l4d2/nick");
	LoadDirOfModels("materials/models/player/kuristaja/l4d2/nick");
	PrecacheModel("models/player/custom_player/kuristaja/l4d2/nick/nickv2.mdl", true);
	
	for (new i = 0; i <= 10;i++)
	{
		new String:TempFormat[256];
		
		FormatEx(TempFormat, sizeof(TempFormat), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", 11169420 + i);
		AddFileToDownloadsTable(TempFormat);
	}
	SDKHook(FindEntityByClassname(MaxClients+1, "cs_player_manager"), SDKHook_ThinkPost, Hook_OnThinkPost);
	
	return;
}


public void Hook_OnThinkPost(int ent)
{
	new g_iRankPlayers[MAXPLAYERS + 1], g_iRankPlayersType[MAXPLAYERS + 1];
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(g_iPlayerJob[i] == -1)
			g_iRankPlayers[i] = 11169420;
			
		else
			g_iRankPlayers[i] = 11169420 + g_iPlayerLevel[i][g_iPlayerJob[i]];
	}
		
	new g_iRankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
	new g_iRankOffsetType = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRankType");
	
	SetEntDataArray(ent, g_iRankOffset, g_iRankPlayers, MAXPLAYERS+1);
	SetEntDataArray(ent, g_iRankOffsetType, g_iRankPlayersType, MAXPLAYERS+1, 1);
}

public Action OnPlayerRunCmd(int iClient, int& buttons, int& impulse, float fVel[3], float fAngles[3], int& iWeapon)
{
	if(StartMessageOne("ServerRankRevealAll", iClient) != INVALID_HANDLE)
	{
		EndMessage();
	}
}


public OnUseNPC(client, id, entity)
{
	if (g_iJobNPC == id)
	{
		ShowJobMenu(client, entity);
	}
	return;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_NPC", true))
	{
		g_iJobNPC = RP_CreateNPC("models/player/custom_player/kuristaja/l4d2/nick/nickv2.mdl", "JOB_NPC");
	}
	return;
}

ShowJobMenu(client, entity)
{
	new String:szFormat[64], String:szJobName[32];
	new String:szEntityId[8];
	
	IntToString(entity, szEntityId, 5);
	
	new Menu:menu = CreateMenu(JobMenu_Handler);
	
	new jotd, expLeft;
	
	RP_GetClientJOTD(client, jotd, expLeft);
	
	new String:JobName[32];
	
	if(jotd != -1 && expLeft > 0)	
	{
		RP_GetJobName(jotd, JobName, sizeof(JobName));
		
		RP_SetMenuTitle(menu, "Job Menu - Select Job\n \n● Job of the Day: %s\n● Type !jotd for more information\n \n", JobName);
	}
	else
		RP_SetMenuTitle(menu, "Job Menu - Select Job\n ");
	
	new Handle:SortArray = CreateArray(64);
	
	for(new i=0;i < GetArraySize(g_aJobName);i++)
	{
		GetArrayString(g_aJobName, i, szFormat, 32);
		
		FormatEx(szFormat, 128, "%s,%i,%i", szFormat, i, entity);
					
		PushArrayString(SortArray, szFormat);
	}
	
	SortADTArray(SortArray, Sort_Ascending, Sort_String);

	for(new i=0;i < GetArraySize(SortArray);i++)
	{
		GetArrayString(SortArray, i, szFormat, sizeof(szFormat));
		
	
		new String:params[3][32];
		ExplodeString(szFormat, ",", params, 3, 32, false);
		
		new pos = StringToInt(params[1]);
		
		FormatEx(szFormat, sizeof(szFormat), "%i,%i", pos, entity);
		
		GetArrayString(g_aJobName, pos, szJobName, 32);
		AddMenuItem(menu, szFormat, szJobName, 0);
	}
	
	CloseHandle(SortArray);
	DisplayMenu(menu, client, 0);
	return;
}

public JobMenu_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szFormat[32];
		GetMenuItem(menu, key, szFormat, sizeof(szFormat));
		new String:params[2][11];
		ExplodeString(szFormat, ",", params, 2, 11, false);
		
		new pos = StringToInt(params[0]);
		
		new entity = StringToInt(params[1]);
	
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			if (g_fJobDelay[client] > GetGameTime())
			{
				RP_PrintToChat(client, "Please wait \x02%1.f\x01 seconds before trying to change job.", g_fJobDelay[client] - GetGameTime());
				return;
			}
			new String:szJobName[32];
			GetArrayString(g_aJobName, pos, szJobName, 32);
			
			if (pos == g_iPlayerJob[client])
			{
				RP_PrintToChat(client, "You are already working as \x02%s!", szJobName);
			}
			else
			{
				ChangeClientJob(client, pos);
			}
		}
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
	return;
}

ChangeClientJob(client, job, bool:message=true)
{
	new bool:ok = true;
	
	Call_StartForward(g_hChangeJob);
	Call_PushCell(client);
	Call_PushCell(job);
	Call_PushCell(g_iPlayerJob[client]);
	Call_PushCellRef(ok);

	Call_Finish();
	
	if (ok)
	{
		new oldjob = g_iPlayerJob[client];
		
		g_iPlayerJob[client] = job;
		SetClientJobStats(client);
		
		if(message && job != -1) // job delay here as well because message is false on no job.
		{
			new String:szJobName[32];
			GetArrayString(g_aJobName, job, szJobName, 32);
			
			RP_PrintToChat(client, "You are now working as \x02%s!", szJobName);
		
			if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
				g_fJobDelay[client] = GetGameTime() + (GetConVarFloat(hcv_JobChangeDelay) / 8.0);
				
			else
				g_fJobDelay[client] = GetGameTime() + GetConVarFloat(hcv_JobChangeDelay);
		}
		
		if(job != oldjob)
		{
			Call_StartForward(g_hChangeJobPost);
			Call_PushCell(client);
			Call_PushCell(job);
			Call_PushCell(oldjob);
			Call_PushCell(false);
	
			Call_Finish();
		}
	}
	return;
}

SetClientJobStats(client)
{
	new job = g_iPlayerJob[client];
	
	if(job != -1)
	{	
		RP_GivePlayerItem(client, "weapon_knife");
		
		SetEntityMaxHealth(client, 100);
		
		if(GetClientHealth(client) > 100)
			SetEntityHealth(client, 100);
	}
		
	new bool:result;
	Call_StartForward(g_hJobStats);
	Call_PushCell(client);
	Call_PushCell(job);
	Call_Finish(result);
	
	new Handle:DP = CreateDataPack();
	
	WritePackCell(DP, GetClientUserId(client));
	WritePackCell(DP, result);
	
	RequestFrame(FrameOne_SwitchToKnife, DP);
	
	if(job == -1 && IsClientInGame(client))
	{
		if(GetClientTeam(client) == CS_TEAM_CT)
		{
			CS_SwitchTeam(client, CS_TEAM_T);
			CS_RespawnPlayer(client);
		}
		else
			CS_UpdateClientModel(client);
			
		CS_SetClientClanTag(client, "Jobless");
	}
		
	return;
}

public FrameOne_SwitchToKnife(Handle:DP)
{
	ResetPack(DP);
	
	new UserId = ReadPackCell(DP);
	
	new bool:result = ReadPackCell(DP);
	
	CloseHandle(DP);
	
	if(result)
		RequestFrame(FrameTwo_SwitchToKnife, UserId);
		
	else
		FrameTwo_SwitchToKnife(UserId);
}

public FrameTwo_SwitchToKnife(UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)	
		return;
		
	else if(!IsPlayerAlive(client))
		return;
		
	FakeClientCommand(client, "use weapon_knife");
}
AddUserExp(client, job, exp, bool:allowEXPEdit=true)
{
	new maxLevel = GetArrayCell(g_aJobMaxLevel, job);
	
	if (!g_bLoadedData[client])
	{
		return -1;
	}
	
	if(allowEXPEdit && CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
		exp = RoundToCeil(float(exp) * 2.0);
	
	new expToGive = exp;
	
	if(allowEXPEdit)
	{
		
		Call_StartForward(g_hEXPGained);
		
		Call_PushCell(client);
		Call_PushCell(job);
		Call_PushCell(exp);
		Call_PushCellRef(expToGive);
	
		Call_Finish();
	}
	
	new String:szJobName[32];
	GetArrayString(g_aJobName, job, szJobName, 32);
	
	RP_PrintToChat(client, "You have gained\x04 +%i \x01experience for your \x02%s\x01 job!", expToGive, szJobName);
	
	g_iPlayerEXP[client][job] += expToGive;
	
	while(CalculateEXPForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerEXP[client][job] && g_iPlayerLevel[client][job] < maxLevel - 1)
	{
		if(CalculateBankForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerBank[client][job])
		{
			g_iPlayerLevel[client][job]++;
			RP_PrintToChat(client, "You have leveled up in your \x02%s\x01 job!", szJobName);
			RP_PrintToChat(client, "Effects will take place the next time you will choose the job!");
		}
		else
		{
			new String:JobName[32];
			
			RP_GetJobName(job, JobName, sizeof(JobName));
			
			RP_PrintToChat(client, "Use\x03 !depositjob \"%s\" %i\x01 to level up your \x02%s\x01 job!", JobName, CalculateBankForNextLevel(g_iPlayerLevel[client][job]) - g_iPlayerBank[client][job], szJobName);
			
			break;
		}
	}
	
	// From here to there, this is to allow calculating level downs from !givejobexp
	g_iPlayerLevel[client][job] = 0;
	
	while(CalculateEXPForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerEXP[client][job] && g_iPlayerLevel[client][job] < maxLevel - 1)
	{
		if(CalculateBankForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerBank[client][job])
			g_iPlayerLevel[client][job]++;
			
		else
			break;
	}	
	// I am there
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szJobShortName[32];
	GetArrayString(g_aJobShortName, job, szJobShortName, 32);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_jobs set exp = exp + %i, nickname = '%N' where job_short_name='%s' and AuthId='%s'", expToGive, client, szJobShortName, szAuth);
	SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, any:0, DBPriority:1);
	return expToGive;
}


AddUserBank(client, job, amount)
{
	new maxLevel = GetArrayCell(g_aJobMaxLevel, job);
	
	if (!g_bLoadedData[client])
		return;
	
	else if(g_iPlayerLevel[client][job] == maxLevel)
		return;
		
	new String:szJobName[32];
	GetArrayString(g_aJobName, job, szJobName, 32);
	
	g_iPlayerBank[client][job] += amount;

	while(CalculateEXPForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerEXP[client][job] && g_iPlayerLevel[client][job] < maxLevel - 1)
	{
		if(CalculateBankForNextLevel(g_iPlayerLevel[client][job]) <= g_iPlayerBank[client][job])
		{
			g_iPlayerLevel[client][job]++;
			RP_PrintToChat(client, "You have leveled up in your \x02%s\x01 job!", szJobName);
			RP_PrintToChat(client, "Effects will take place the next time you will choose the job!");
		}
		else
			break;
	}
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szJobShortName[32];
	GetArrayString(g_aJobShortName, job, szJobShortName, 32);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_jobs set bank = bank + %i where job_short_name='%s' and AuthId='%s'", amount, szJobShortName, szAuth);
	SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, any:0, DBPriority:1);
	return;
}

public SQL_LoadData(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	
	if (!client)
		return;

	if(handle)
	{	
		new String:szJobShortName[32];

		new iJobIndex;
		while (SQL_FetchRow(handle))
		{
			SQL_FetchString(handle, 0, szJobShortName, 32);
			
			new exp = SQL_FetchInt(handle, 1);
			new bank = SQL_FetchInt(handle, 2);
			
			iJobIndex = FindStringInArray(g_aJobShortName, szJobShortName);

			if(iJobIndex != -1) // This is for when you delete a job and it obviously still exists in SQL.
			{
				g_iPlayerEXP[client][iJobIndex] = exp;
				g_iPlayerBank[client][iJobIndex] = bank;
				g_iPlayerLevel[client][iJobIndex] = 0;
				
				new maxLevel = GetArrayCell(g_aJobMaxLevel, iJobIndex);
				
				while(CalculateEXPForNextLevel(g_iPlayerLevel[client][iJobIndex]) <= g_iPlayerEXP[client][iJobIndex] && g_iPlayerLevel[client][iJobIndex] < maxLevel - 1)
				{
					if(CalculateBankForNextLevel(g_iPlayerLevel[client][iJobIndex]) <= g_iPlayerBank[client][iJobIndex])
						g_iPlayerLevel[client][iJobIndex]++

					else
						break;
				}
			}
		}
		
		for(new i=0;i < GetArraySize(g_aJobShortName);i++)
		{
			new String:szQuery[256];
	
			GetArrayString(g_aJobShortName, i, szJobShortName, 32);
			new String:szAuth[32];
			GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
			
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "INSERT IGNORE INTO rp_jobs (AuthId, nickname, job_short_name, exp, bank) VALUES ('%s','%N', '%s','0', '0')", szAuth, client, szJobShortName);
			SQL_TQuery(g_hDatabase, SQL_NoError, szQuery, any:0, DBPriority:1);
		}

		g_bLoadedData[client] = true;
		return;
	}
	
	LogError("[1] SQL query failed: %s", error);
	return;
}

public SQL_NoAction(Handle:owner, Handle:handle, String:szError[], any:data)
{
	if (!handle)
	{
		LogError("[Error %i] SQL query failed: %s", data, szError);
	}
	return;
}

public SQL_NoError(Handle:owner, Handle:handle, String:szError[], any:data)
{
	
}

// returns -1 if job name not found, -2 if more than one job found.
stock FindJobByContainedName(const String:JobName[])
{
	new AmountFound, LastJob;
	
	for(new i=0;i < GetArraySize(g_aJobName);i++)
	{
		new String:CompareName[32];
		GetArrayString(g_aJobName, i, CompareName, sizeof(CompareName));
			
		if(StrContains(CompareName, JobName, false) != -1)
		{
			AmountFound++;
			
			LastJob = i;
		}
	}
	
	switch(AmountFound)
	{
		case 0: return -1;
		case 1: return LastJob;
		
		default: return -2;
	}
}
