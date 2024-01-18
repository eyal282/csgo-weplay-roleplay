#include <sourcemod>
#include <sdkhooks>
#include <Eyal-RP>

int g_iNextCash[MAXPLAYERS + 1];

#define PLUGIN_VERSION "1.0"

enum struct enFlags
{
	char Name[64];
	int flag;
	int salary;
}

enFlags FlagsData[] =
{
	{ "an High Management", ADMFLAG_ROOT, 3000 },
	{ "a VIP", ADMFLAG_CUSTOM2, 3000 },
	{ "an Inspector", ADMFLAG_CUSTOM4, 2500 },
	{ "a Server Manager", ADMFLAG_CONVARS, 2000 },
	{ "a Sub Server Manager", ADMFLAG_GENERIC, 1500 },
	{ "an Admin", ADMFLAG_GENERIC, 1000 },
};
public Plugin:myinfo =
{
	name = "NPC RolePlay NextCash",
	author = "Author was lost, heavy edit by Eyal282",
	description = "RolePlay Next Cash for VIP",
	version = PLUGIN_VERSION,
	url = "None."
}

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			VIPAPI_OnClientAuthorizedPost(i, false);
	}
}
/* */

public void VIPAPI_OnClientAuthorizedPost(int client, bool VIP)
{
	g_iNextCash[client] = GetTime() + (60 * 15); // 15 minutes
	
	if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC) || CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
		CreateTimer(3600.0, Timer_AdminSalary, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:Timer_AdminSalary(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return Plugin_Stop;

	new iCash, FlagSlot = -1;
	new FlagBits = GetUserFlagBits(client);
	
	for(new i=0;i < sizeof(FlagsData);i++)
	{
		if(FlagBits & FlagsData[i].flag)
		{
			FlagSlot = i;
			break;
		}
	}
	
	if(FlagSlot == -1)
		return Plugin_Stop;
	
	iCash = FlagsData[FlagSlot].salary;
	
	GiveClientCashNoGangTax(client, BANK_CASH, iCash);

	new String:sCash[20];

	AddCommas(iCash, _, sCash, sizeof(sCash));
	
	RP_PrintToChat(client, "You have received %s cash for playing as %s for 60 minutes", sCash, FlagsData[FlagSlot].Name);
	
	return Plugin_Continue;
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