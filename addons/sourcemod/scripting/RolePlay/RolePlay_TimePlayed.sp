#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "WePlay - Play Time",
	author = "Author was lost, heavy edit by Eyal282",
	description = "xoxoxoxoxoxoxooxoxoxoxooxoxoxo",
	version = PLUGIN_VERSION,
	url = ""
}

// This means that if someone is connected for 4 seconds and disconnects, it's like he never connected. This cannot be a float.
#define TIME_REGISTER_DELAY 15

new Handle:dbTime, Handle:dbClientPrefs;

new bool:PostAdminCheck[MAXPLAYERS+1];

new ClientMinutes[MAXPLAYERS+1];

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:sError[], err_max)
{
	CreateNative("GetTimePlayed", Native_GetTimePlayed);
}

public int Native_GetTimePlayed(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	return ClientMinutes[client];
}

public OnPluginStart()
{	
	ConnectToDatabase();
	
	//RegAdminCmd("sm_settime", Command_SetTime, ADMFLAG_ROOT);
}

public ConnectToDatabase()
{		
	new String:Error[256];
	if((dbTime = SQL_Connect("eyal_rp", true, Error, sizeof(Error))) == INVALID_HANDLE)
		LogError(Error);
	
	else
	{ 
		SQL_TQuery(dbTime, SQLCB_Error, "CREATE TABLE IF NOT EXISTS PlayTime_players (AuthId VARCHAR(64) NOT NULL UNIQUE, Name VARCHAR(64) NOT NULL, SecondsInGame INT(15) NOT NULL)", _, DBPrio_High);		

		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			else if(!IsClientAuthorized(i))
				continue;
				
			OnAuthorized(i);
			
			OnPostAdminCheck(i);
		}
	}
	
	if((dbClientPrefs = SQLite_UseDatabase("clientprefs-sqlite", Error, sizeof(Error))) == INVALID_HANDLE)
	{
		LogError(Error);
	}
}

public SQLCB_Error(Handle:db, Handle:hndl, const String:sError[], data)
{
	if(hndl == null)
	{
		if(data == 0)
			ThrowError(sError);
		
		else
			ThrowError("Error No. %i - [%s]", data, sError);
	}
}

public SQLCB_ErrorIgnore(Handle:db, Handle:hndl, const String:sError[], data)
{

}

public OnClientConnected(client)
{
	PostAdminCheck[client] = false;
}
public OnClientAuthorized(client)
{
	OnAuthorized(client);
}

OnAuthorized(client)
{
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:sQuery[256];
	SQL_FormatQuery(dbTime, sQuery, sizeof(sQuery), "INSERT IGNORE INTO PlayTime_players (AuthId, Name, SecondsInGame) VALUES ('%s', '%N', 0)", AuthId, client);	

	SQL_TQuery(dbTime, SQLCB_ErrorIgnore, sQuery);
	
	CreateTimer(float(TIME_REGISTER_DELAY), Timer_RegisterTime, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	
	SQL_FormatQuery(dbTime, sQuery, sizeof(sQuery), "SELECT * FROM PlayTime_players WHERE AuthId = '%s'", AuthId);
	
	SQL_TQuery(dbTime, SQLCB_SQLTimeToSourcemodVariable, sQuery, GetClientUserId(client), DBPrio_Normal);
}

public OnClientPostAdminCheck(client)
{
	OnPostAdminCheck(client);
}

public OnPostAdminCheck(client)
{
	PostAdminCheck[client] = true;
}

public Action:Timer_RegisterTime(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return Plugin_Stop;
		
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:sQuery[256];

	SQL_FormatQuery(dbTime, sQuery, sizeof(sQuery), "UPDATE PlayTime_players SET SecondsInGame = SecondsInGame + %i, Name = '%N' WHERE AuthId = '%s'", TIME_REGISTER_DELAY, client, AuthId);
	
	SQL_TQuery(dbTime, SQLCB_Error, sQuery, _, DBPrio_Normal);
	
	return Plugin_Continue;
}

public SQLCB_SQLTimeToSourcemodVariable(Handle:db, Handle:hndl, const String:sError[], UserId)
{
	if(hndl == null)
		ThrowError(sError);
	
	else if(SQL_GetRowCount(hndl) == 0)
		return;

	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
		
	else if(!SQL_FetchRow(hndl))
		return;

	new SecondsInGame = SQL_FetchInt(hndl, 2);
	
	ClientMinutes[client] = RoundToFloor(float(SecondsInGame) / 60.0);
}


stock FormatTimeHMS(char[] Time, length, timestamp, bool:LimitTo24H = false)
{
	if(LimitTo24H)
	{
		if(timestamp >= 86400)
			timestamp %= 86400;
	}
	new HH, MM, SS;
	
	HH = timestamp / 3600
	MM = timestamp % 3600 / 60
	SS = timestamp % 3600 % 60 
	
	Format(Time, length, "%02d:%02d:%02d", HH, MM, SS);
}