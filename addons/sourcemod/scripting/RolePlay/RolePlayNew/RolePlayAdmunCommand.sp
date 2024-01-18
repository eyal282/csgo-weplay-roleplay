#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "WePlay - RolePlay Admin Commands",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Useful roleplay commands for admins",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_lockdoor", Command_LockDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_unlockdoor", Command_UnlockDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_resetjob", Command_ResetJob, ADMFLAG_ROOT);
	RegAdminCmd("sm_setkarma", Command_SetKarma, ADMFLAG_ROOT);
	RegAdminCmd("sm_jail", Command_Jail, ADMFLAG_ROOT);
	RegAdminCmd("sm_unjail", Command_Unjail, ADMFLAG_ROOT);
	RegAdminCmd("sm_ajail", Command_AdminJail, ADMFLAG_GENERIC);
	RegAdminCmd("sm_aunjail", Command_AdminUnjail, ADMFLAG_GENERIC);
	RegAdminCmd("sm_offlinejail", Command_OfflineAdminJail, ADMFLAG_GENERIC);
	RegAdminCmd("sm_offlineunjail", Command_OfflineAdminUnjail, ADMFLAG_GENERIC);
	RegAdminCmd("sm_deposit", Command_Deposit, ADMFLAG_ROOT);
	RegAdminCmd("sm_secret", Command_Secret, ADMFLAG_ROOT);
}

public Action:Command_LockDoor(client, args)
{
	new entity = GetClientAimTarget(client, false);
	if (IsValidEntity(entity))
	{
		new String:classname[128];
		GetEdictClassname(entity, classname, 128);
		if (StrContains(classname, "door", true) == -1)
		{
			RP_PrintToChat(client, "Im pretty sure that this isn't a door.");
			return Plugin_Handled;
		}
		RP_PrintToChat(client, "You have locked the door.");
		AcceptEntityInput(entity, "Lock", 0, -1, 0);
		return Plugin_Handled;
	}
	RP_PrintToChat(client, "You are not aiming at any entity.");
	return Action:3;
}

public Action:Command_UnlockDoor(client, args)
{
	new entity = GetClientAimTarget(client, false);
	
	if (IsValidEntity(entity))
	{
		new String:classname[128];
		GetEdictClassname(entity, classname, 128);
		if (StrContains(classname, "door", true) == -1)
		{
			RP_PrintToChat(client, "Im pretty sure that this isn't a door.");
			return Plugin_Handled;
		}
		RP_PrintToChat(client, "You have opened the door.");
		AcceptEntityInput(entity, "Unlock", 0, -1, 0);
		AcceptEntityInput(entity, "Open", 0, -1, 0);
		return Plugin_Handled;
	}
	RP_PrintToChat(client, "You are not aiming at any entity.");
	return Plugin_Handled;
}

public Action:Command_ResetJob(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_resetjob <#userid|name> [job]");
		
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	new job = -1;
	
	if(args >= 2)
	{
		char arg2[11];	
		GetCmdArg(2, arg2, sizeof(arg2));	
		
		job = StringToInt(arg2);
	}
		
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					0,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	new String:JobName[64];
	
	if(job != -1 && !RP_GetJobName(job, JobName, sizeof(JobName)))
	{
		ReplyToCommand(client, "Error: Job #%i does not exist.", job);
		
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		RP_SetClientJob(target, job);
	}

	if(job == -1)
		RP_PrintToChatAll("Admin \x02%N \x01reset \x07%s \x01job", client, target_name);
		
	else
		RP_PrintToChatAll("Admin \x02%N \x01set \x07%s \x01job to %s", client, target_name, JobName);
		
	
	return Plugin_Handled;
}
public Action:Command_SetKarma(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_setkarma <#userid|name> <karma>");
		
		return Plugin_Handled;
	}

	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));

	new karma = StringToInt(arg2); // My calculation
	
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_NO_MULTI,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		if(karma <= 0)
			RP_PrintToChat(client, "\x02%N \x01has \x07%i \x01karma", target, RP_GetKarma(target));
		
		else
		{
			RP_SetKarma(target, karma, true);
		}
		
	}
		
	if(karma > 0)
		RP_PrintToChatAll("Admin \x02%N \x01set karma of \x07%s \x01to \x04%i", client, target_name, karma);
	
	return Plugin_Handled;
}

public Action:Command_Jail(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_jail <#userid|name> [seconds]");
		
		return Plugin_Handled;
	}

	char arg[65], arg2[65];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new seconds = StringToInt(arg2);
	
	new karma = seconds * 5; // My calculation
	
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_NO_MULTI,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		if(RP_IsClientInJail(target))
			RP_UnJailClient(target);
		
		if(karma <= 0)
			karma = RP_GetKarma(target);
			
		RP_SetKarma(target, karma, true);
		
		RP_JailClient(target);
		
	}
		
	if(karma <= 0)
		RP_PrintToChatAll("Admin \x02%N \x01jailed \x07%s", client, target_name);
		
	else
		RP_PrintToChatAll("Admin \x02%N \x01jailed \x07%s \x01for \x04%i \x01seconds", client, target_name, seconds);
	
	return Plugin_Handled;
}

public Action:Command_Unjail(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_unjail <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
		
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_NO_MULTI,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		if(RP_IsClientInJail(target))
			RP_UnJailClient(target);
	}
		
	RP_PrintToChatAll("Admin \x02%N \x01unjailed \x07%s", client, target_name);
	
	return Plugin_Handled;
}


public Action:Command_AdminJail(int client, int args)
{
	if(args < 3)
	{
		ReplyToCommand(client, "Usage: sm_ajail <#userid|name> <seconds> <reason>");
		
		return Plugin_Handled;
	}

	new MAX_JAIL = 3600;
	
	if(CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS))
		MAX_JAIL = 18000;
	
	char arg[65], arg2[65], reason[256], buffer[256];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	GetCmdArg(3, reason, sizeof(reason));
		
	if(args >= 4)
	{
		for (int i = 4; i <= args; i++)
		{
			GetCmdArg(i, buffer, sizeof(buffer));
			Format(reason, sizeof(reason), "%s %s", reason, buffer);
		}
	}
	
	new seconds = StringToInt(arg2);
	
	if(seconds <= 0)
	{
		ReplyToCommand(client, "Usage: sm_ajail <#userid|name> <seconds> <reason>");
		
		return Plugin_Handled;
	}
	
	else if(seconds > MAX_JAIL)
	{
		ReplyToCommand(client, "Error: Cannot jail longer than 1 hour.");
		
		return Plugin_Handled;
	}
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_NO_MULTI,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	new String:AdminName[64];
	new String:AdminAuthId[32];
	
	GetClientName(client, AdminName, sizeof(AdminName));
	GetClientAuthId(client, AuthId_Engine, AdminAuthId, sizeof(AdminAuthId));
	
	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		if(RP_IsClientInAdminJail(target))
		{
			RP_PrintToChat(client, "\x02%N \x01is already in admin \x05jail!", target);
			return Plugin_Handled;
		}
		
		if(seconds == MAX_JAIL)
			RP_AdminJailClient(target, MAX_JAIL, reason, AdminName, AdminAuthId);
			
		else
			RP_AdminJailClient(target, seconds, reason, AdminName, AdminAuthId);
		
		
	}

	RP_PrintToChatAll("Admin \x02%N \x01sent \x07%s \x01to admin jail [%i seconds]. Reason: \x05%s", client, target_name, seconds, reason);
	
	return Plugin_Handled;
}

public Action:Command_AdminUnjail(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_aunjail <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
		
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					COMMAND_FILTER_NO_MULTI,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		if(RP_IsClientInAdminJail(target))
			RP_AdminUnJailClient(target)
	}
		
	RP_PrintToChatAll("Admin \x02%N \x01freed \x07%s \x01from admin jail.", client, target_name);
	
	return Plugin_Handled;
}


public Action:Command_OfflineAdminJail(int client, int args)
{
	if(args < 3)
	{
		ReplyToCommand(client, "Usage: sm_offlinejail <\"steamid\"> <seconds> <reason>");
		
		return Plugin_Handled;
	}

	new MAX_JAIL = 3600;
	
	if(CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS))
		MAX_JAIL = 18000;
		
	char arg[65], arg2[65], reason[256], buffer[256];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	GetCmdArg(3, reason, sizeof(reason));
		
	if(args >= 4)
	{
		for (int i = 4; i <= args; i++)
		{
			GetCmdArg(i, buffer, sizeof(buffer));
			Format(reason, sizeof(reason), "%s %s", reason, buffer);
		}
	}
	
	new seconds = StringToInt(arg2);
	
	if(seconds <= 0)
	{
		ReplyToCommand(client, "Usage: sm_offlinejail <\"steamid\"> <seconds> <reason>");
		
		return Plugin_Handled;
	}
	
	else if(seconds > MAX_JAIL)
	{
		ReplyToCommand(client, "Error: Cannot jail longer than 1 hour.");
		
		return Plugin_Handled;
	}

	new String:AdminName[64];
	new String:AdminAuthId[32];
	
	GetClientName(client, AdminName, sizeof(AdminName));
	GetClientAuthId(client, AuthId_Engine, AdminAuthId, sizeof(AdminAuthId));

	if(seconds == MAX_JAIL)
		RP_AdminJailSteamId(arg, MAX_JAIL - 1, reason, AdminName, AdminAuthId);
		
	else
		RP_AdminJailSteamId(arg, seconds, reason, AdminName, AdminAuthId);
			
	RP_PrintToChat(client, "Admin \x02%N \x01sent \x07%s \x01to admin jail [%i seconds]. Reason: \x05%s", client, arg, seconds, reason);
	
	return Plugin_Handled;
}

public Action:Command_OfflineAdminUnjail(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_offlineunjail <\"steamid\">");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
		
	RP_AdminUnJailSteamId(arg)
		
	RP_PrintToChat(client, "Admin \x02%N \x01freed \x07%s \x01from admin jail.", client, arg);
	
	return Plugin_Handled;
}


public Action:Command_Deposit(int client, int args)
{
	if(args != 1)
	{
		ReplyToCommand(client, "Usage: sm_deposit <#userid|name>");
		
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int[] target_list = new int[MaxClients+1];
	int target_count;
	bool tn_is_ml;

	target_count = ProcessTargetString(
					arg,
					client,
					target_list,
					MaxClients,
					0,
					target_name,
					sizeof(target_name),
					tn_is_ml);


	if(target_count <= COMMAND_TARGET_NONE)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i=0;i < target_count;i++)
	{
		int target = target_list[i];
		
		new pocket = GetClientCash(target, POCKET_CASH);
		
		if(pocket <= 0)
			continue;
			
		GiveClientCashNoGangTax(target, POCKET_CASH, -1 * GetClientCash(target, POCKET_CASH));
		
		GiveClientCashNoGangTax(target, BANK_CASH, pocket);
		
	}
		
	RP_PrintToChatAll("Admin \x02%N \x01deposited \x07%s \x01money to the bank.", client, target_name);
	
	return Plugin_Handled;
}

public Action:Command_Secret(int client, int args)
{
	new ent = FindEntityByTargetname(-1, "secretfunny", false, false);
	
	AcceptEntityInput(ent, "Volume 10");
	AcceptEntityInput(ent, "PlaySound");
	
	return Plugin_Handled;
}