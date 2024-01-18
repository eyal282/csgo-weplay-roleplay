#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>
#include <fuckzones>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <autoexecconfig>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

new const String:JACKPOT_NAME[] = "NPCModule_Jackpot";
new const String:GAMBLE_NAME[] = "NPCModule_Gamble";

new ClientBetAmount[MAXPLAYERS+1];
new String:ClientLastNPCName[MAXPLAYERS+1][50];

#define PLUGIN_VERSION "1.0"

new bool:JackpotStarted = false;

new Handle:Trie_Jackpot = INVALID_HANDLE;

new Handle:hTimer_EndJackpot = INVALID_HANDLE;

new bool:FullyAuthorized[MAXPLAYERS+1];
new JackpotCredits;

new Handle:dbJackpot = INVALID_HANDLE;

new Handle:hcv_JackpotMinCash = INVALID_HANDLE;
new Handle:hcv_JackpotMaxCash = INVALID_HANDLE;

new Handle:hcv_GambleMinCash = INVALID_HANDLE;
new Handle:hcv_GambleMaxCash = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "Store Module - RolePlay Jackpot",
	author = "Author was lost, heavy edit by Eyal282",
	description = "A jackpot system for store in RolePlay servers",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("RolePlay_Jackpot");
	
	#endif
	
	hcv_JackpotMinCash = UC_CreateConVar("roleplay_jackpot_min_cash", "25", "Jackpot Minimum");
	hcv_JackpotMaxCash = UC_CreateConVar("roleplay_jackpot_max_cash", "10000", "Jackpot Maximum");
	
	hcv_GambleMinCash = UC_CreateConVar("roleplay_gamble_min_cash", "25", "Jackpot Minimum");
	hcv_GambleMaxCash = UC_CreateConVar("roleplay_gamble_max_cash", "10000", "Jackpot Maximum");
	
	Trie_Jackpot = CreateTrie();
	
	RegConsoleCmd("sm_jackpot", Command_Jackpot, "Places a bet on the jackpot");
	RegConsoleCmd("sm_j", Command_Jackpot, "Places a bet on the jackpot");
	
	//RegConsoleCmd("sm_gamble", Command_Gamble);
	//RegConsoleCmd("sm_g", Command_Gamble);
	
	ConnectToDatabase();
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsClientAuthorized(i))
			continue;
			
		OnClientPostAdminCheck(i);
	}
	
	#if defined _autoexecconfig_included
	
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
	
	#endif
}

public OnClientPostAdminCheck(client)
{
	FullyAuthorized[client] = true;
	CreateTimer(10.0, Timer_LoadJackpotDebt, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientDisconnect(client)
{
	FullyAuthorized[client] = false;
}
ConnectToDatabase()
{
	new String:Error[256];
	if((dbJackpot = SQLite_UseDatabase("jackpot-debts", Error, sizeof(Error))) == INVALID_HANDLE)
		SetFailState(Error);

	else
		SQL_TQuery(dbJackpot, SQLCB_Error, "CREATE TABLE IF NOT EXISTS Jackpot_Debt (AuthId VARCHAR(35) NOT NULL UNIQUE, credits INT(11) NOT NULL)"); 
}

public SQLCB_Error(Handle:db, Handle:hResults, const String:Error[], data) 
{ 
	/* If something fucked up. */ 
	if (hResults == null) 
		ThrowError(Error); 
} 

public OnMapStart()
{
	hTimer_EndJackpot = INVALID_HANDLE;
}
public OnMapEnd()
{
	CheckJackpotEnd();
}

public OnPluginEnd()
{
	CheckJackpotEnd();
}

public CheckJackpotEnd()
{
	if(!JackpotStarted)
		return;
		
	new Handle:Trie_Snapshot = CreateTrieSnapshot(Trie_Jackpot);
	
	new RNG = GetRandomInt(1, JackpotCredits);
	
	new initValue;
	
	new String:WinnerAuthId[35];
	
	new size = TrieSnapshotLength(Trie_Snapshot);
	for(new i=0;i < size;i++)
	{
		new String:AuthId[35];
		GetTrieSnapshotKey(Trie_Snapshot, i, AuthId, sizeof(AuthId));
		
		new credits;
		GetTrieValue(Trie_Jackpot, AuthId, credits);
		
		if(RNG > initValue && RNG <= (initValue + credits))
		{
			WinnerAuthId = AuthId;
			break;
		}
		initValue += credits;
	}
	
	CloseHandle(Trie_Snapshot);
	
	new Winner = FindClientByAuthId(WinnerAuthId);
	
	if(Winner == 0)
	{
		SaveJackpotDebt(WinnerAuthId, JackpotCredits);
		RP_PrintToChatAll("\x01The winner \x07disconnected, \x01saving his \x07%i \x01redits for next time he joins. Winner's \x01Steam ID: \x07%s", JackpotCredits, WinnerAuthId);
	}	
	else
	{
		GiveClientCashNoGangTax(Winner, POCKET_CASH, JackpotCredits);
		
		RP_PrintToChatAll("The winner is \x04%N\x01, he won \x07%i cash", Winner, JackpotCredits);
	}
	
	JackpotStarted = false;
	JackpotCredits = 0;
	ClearTrie(Trie_Jackpot);
}

public Action:Command_Jackpot(client, args)
{
	if(!Zone_IsClientInZone(client, "Casino", false))
	{
		ReplyToCommand(client, "You must be inside the casino to start a jackpot");
		return Plugin_Handled;
	}
	
	else if(args != 1)
	{
		ReplyToCommand(client, "Usage: sm_jackpot <amount>");
		return Plugin_Handled;
	}
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	if(GetTrieValue(Trie_Jackpot, AuthId, args))
	{
		ReplyToCommand(client, "You \x05already \x01joined the \x07jackpot.");
		return Plugin_Handled;
	}
	new String:Arg[35];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new joinCredits = StringToInt(Arg);
	
	new credits = GetClientCash(client, POCKET_CASH);
	
	if(StrEqual(Arg, "all", false))
	{
		joinCredits = credits;
		
		if(joinCredits > GetConVarInt(hcv_JackpotMaxCash))
			joinCredits = GetConVarInt(hcv_JackpotMaxCash);
	}
	
	if(credits < joinCredits)
	{
		ReplyToCommand(client, "You \x07don't \x01have enough \x07pocket cash.");
		return Plugin_Handled;
	}
	
	else if (GetConVarInt(hcv_JackpotMinCash) > joinCredits)
	{
		ReplyToCommand(client, " \x01The \x07Minimum \x01amount of \x07cash \x01to join the jackpot is \x05%i", GetConVarInt(hcv_JackpotMinCash))
		return Plugin_Handled;
	}
	
	else if (GetConVarInt(hcv_JackpotMaxCash) < joinCredits)
	{
		ReplyToCommand(client, " \x01The \x07Maximum \x01amount of \x07cash \x01to join the jackpot is \x05%i", GetConVarInt(hcv_JackpotMaxCash))
		return Plugin_Handled;
	}
	
	if(!JackpotStarted)
	{
		if(hTimer_EndJackpot != INVALID_HANDLE)
		{
			CloseHandle(hTimer_EndJackpot);
			hTimer_EndJackpot = INVALID_HANDLE;
		}
		hTimer_EndJackpot = CreateTimer(60.0, Timer_EndJackpot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	GiveClientCashNoGangTax(client, POCKET_CASH, -1 * joinCredits);

	SetTrieValue(Trie_Jackpot, AuthId, joinCredits);

	JackpotStarted = true;
	
	JackpotCredits += joinCredits;
	
	RP_PrintToChatAll("\x04%N \x01joined the \x07jackpot \x01with \x07%i \x01cash! \x07Total: \x05%i \x07( %.2f%% )", client, joinCredits, JackpotCredits, GetJackpotChance(AuthId));
	
	new karma = RoundFloat(float(joinCredits) * 0.05);
	
	if(GetClientTeam(client) == CS_TEAM_CT)
		karma = RoundFloat(float(karma) * 1.5);
	
	RP_UpdateScoreBoard_Karma(client);
	return Plugin_Handled;
}

public Action:Timer_EndJackpot(Handle:hTimer)
{
	CheckJackpotEnd();
	
	hTimer_EndJackpot = INVALID_HANDLE;
}

public SaveJackpotDebt(const String:AuthId[], amount)
{
	new String:sQuery[256];
	
	Format(sQuery, sizeof(sQuery), "UPDATE OR IGNORE Jackpot_Debt SET credits = credits + %i WHERE AuthId = '%s'", amount, AuthId);
	SQL_TQuery(dbJackpot, SQLCB_Error, sQuery);
	
	Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO Jackpot_Debt (AuthId, credits) VALUES ('%s', %d)", AuthId, amount);
	SQL_TQuery(dbJackpot, SQLCB_Error, sQuery);
}

public Action:Timer_LoadJackpotDebt(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
		
	new String:sQuery[256];
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	Format(sQuery, sizeof(sQuery), "SELECT * FROM Jackpot_Debt WHERE AuthId = '%s'", AuthId); 
	SQL_TQuery(dbJackpot, SQLCB_LoadDebt, sQuery, GetClientUserId(client));
}


public SQLCB_LoadDebt(Handle:db, Handle:hResults, const String:Error[], UserId)
{
	if(hResults == null)
		ThrowError(Error);
	
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
	
	else if(!FullyAuthorized[client])
		return;
		
	else if(SQL_GetRowCount(hResults) > 0)
	{
		SQL_FetchRow(hResults);
		
		new debt = SQL_FetchInt(hResults, 1);
		
		new String:AuthId[35];
		GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId))
		
		new String:sQuery[256];
		Format(sQuery, sizeof(sQuery), "DELETE FROM Jackpot_Debt WHERE AuthId = '%s'", AuthId);

		SQL_TQuery(dbJackpot, SQLCB_Error, sQuery, _, DBPrio_High);
		
		RP_PrintToChat(client, "Jackpot system owed you \x07%i \x01credits because you left before you \x04WON", debt);
		
		GiveClientCashNoGangTax(client, POCKET_CASH, debt);
	}
}

stock Float:GetJackpotChance(const String:AuthId[])
{
	new clientCredits;
	GetTrieValue(Trie_Jackpot, AuthId, clientCredits);
	
	if(JackpotCredits == 0.0)
		return 0.0;
		
	return 100.0 * (float(clientCredits) / float(JackpotCredits));
}

stock FindClientByAuthId(const String:AuthId[])
{
	new String:iAuthId[35];
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!FullyAuthorized[i]) // Only due to Store's absolutely trash methods of setting a player's credits
			continue;
			
		GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));
		
		if(StrEqual(AuthId, iAuthId, true))
			return i;
	}
	
	return 0;
}

stock void AddCommas(int value, const char[] seperator = ",", char[] buffer, len) // berni
{
	buffer[0] = '\0';
	int divisor = 1000;

	while (value >= 1000 || value <= -1000) {
		int offcut = value % divisor;
		value = RoundToFloor(float(value) / float(divisor));
		Format(buffer, len, "%c%03.d%s", seperator, offcut, buffer);
	}
	Format(buffer, len, "%d%s", value, buffer);
}

#if defined _autoexecconfig_included

stock ConVar:UC_CreateConVar(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0)
{
	return AutoExecConfig_CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}

#else

stock ConVar:UC_CreateConVar(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0)
{
	return CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
}
 
#endif

// NPC ID is invalid due to the nature of this module.
public NPC_OnClientStartTouch(client, const String:NPCName[], NPC)
{
	new String:TempFormat[256];

	FormatEx(ClientLastNPCName[client], sizeof(ClientLastNPCName[]), NPCName);
	
	if(StrEqual(NPCName, JACKPOT_NAME))
	{  
		new Handle:hMenu = CreateMenu(GeneralNPC_MenuHandler);
       
	   	Format(TempFormat, sizeof(TempFormat), "Place jackpot bet [%i]", ClientBetAmount[client]);
		
		AddMenuItem(hMenu, NPCName, TempFormat);
		
		RP_SetMenuTitle(hMenu, "Write in the chat how much to jackpot with, then press 1 to finish\nMax bet: %i", GetConVarInt(hcv_JackpotMaxCash));
		
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	else if(StrEqual(NPCName, GAMBLE_NAME))
	{
		new Handle:hMenu = CreateMenu(GeneralNPC_MenuHandler);
       
	   	Format(TempFormat, sizeof(TempFormat), "Place gamble bet [%i]", ClientBetAmount[client]);
		
		AddMenuItem(hMenu, NPCName, TempFormat);
		
		RP_SetMenuTitle(hMenu,  "Write in the chat how much to gamble with, then press 1 to finish\nMax bet: %i", GetConVarInt(hcv_GambleMaxCash));
		
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}
 
 
public GeneralNPC_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
    if(action == MenuAction_End)
        CloseHandle(hMenu);
		
	else if(action == MenuAction_Select)
	{
		new String:NPCName[50];
		GetMenuItem(hMenu, 0, NPCName, sizeof(NPCName));
		
		if(StrEqual(NPCName, GAMBLE_NAME, false))
			FakeClientCommand(client, "sm_gamble %i", ClientBetAmount[client])	
			
		else if(StrEqual(NPCName, JACKPOT_NAME, false))
			FakeClientCommand(client, "sm_jackpot %i", ClientBetAmount[client]);
	}
}