#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

#define MAX_CASH_LOST 500000

new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};


new g_iCoinsAppearFromValue[] =
{
	50, 250, 500, 1500, 3000, 5000, 50000
};

new g_iCoinsValue[] =
{
	50, 250, 500, 1500, 3000, 5000, 25000
};

new String:g_szCoins[][] =
{
	"models/money/broncoin.mdl",
	"models/money/silvcoin.mdl",
	"models/money/goldcoin.mdl",
	"models/money/note.mdl",
	"models/money/note2.mdl",
	"models/money/note3.mdl",
	"models/props_survival/cash/prop_cash_stack_block.mdl"
};

new g_iCoinValue[2048];
new g_iOldButtons[MAXPLAYERS+1];

new Handle:fw_ShouldDropCoins = INVALID_HANDLE;

public OnPluginStart()
{
	g_Game = GetEngineVersion();
	
	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	fw_ShouldDropCoins = CreateGlobalForward("RP_ShouldClientDropCoins", ET_Event, Param_Cell);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
}

public OnMapStart()
{
	DownloadDir("materials/money/");
	DownloadDir("models/money/");
	PrecacheModel("models/money/broncoin.mdl", true);
	PrecacheModel("models/money/silvcoin.mdl", true);
	PrecacheModel("models/money/goldcoin.mdl", true);
	PrecacheModel("models/money/note.mdl", true);
	PrecacheModel("models/money/note2.mdl", true);
	PrecacheModel("models/money/note3.mdl", true);
	PrecacheModel("models/props/cs_assault/money.mdl", true)
}

public Action:Event_OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid", 0));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));

	
	if (RP_IsUserInArena(victim) || RP_IsUserInDuel(victim))
	{
		return;
	}
	
	else if(attacker != 0 && (RP_IsUserInArena(attacker) || RP_IsUserInDuel(attacker)))
	{
		return;
	}
	
	if(GetClientCash(victim, POCKET_CASH) > 0)
	{
		new Action:result;
		
		Call_StartForward(fw_ShouldDropCoins);
		
		Call_PushCell(victim);
		
		Call_Finish(result);
		
		if(result != Plugin_Continue && result != Plugin_Changed)
			return;
			
		new cashLost = GetClientCash(victim, POCKET_CASH);
		
		if(cashLost > MAX_CASH_LOST)
			cashLost = MAX_CASH_LOST;
			
		CreateMoneyCoins(victim, cashLost);
		
		GiveClientCash(victim, POCKET_CASH, -1 * cashLost);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3])
{
	if (!IsPlayerAlive(client))
	{
		return;
	}

	if(buttons & IN_USE && !(g_iOldButtons[client] & IN_USE))
	{
		new ent = GetClientAimTarget(client, false);

		if (IsValidEntity(ent) && g_iCoinValue[ent])
		{

			new String:szCoinName[8];
			GetEdictClassname(ent, szCoinName, 5);
			if (StrEqual(szCoinName, "coin", true))
			{
				new Float:Origin[3], Float:CoinOrigin[3];
				
				GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
				GetEntPropVector(ent, Prop_Data, "m_vecOrigin", CoinOrigin);
				
				if(GetVectorDistance(Origin, CoinOrigin, false) <= 128.0)
				{
					new cash = GiveClientCash(client, POCKET_CASH, g_iCoinValue[ent]);
					AcceptEntityInput(ent, "Kill", -1, -1, 0);
					RP_PrintToChat(client, "You have picked \x02%i\x01 cash!", cash);
				
					g_iCoinValue[ent] = 0;
				}
			}
			else
			{
				g_iCoinValue[ent] = 0;
			}
		}
	}
	g_iOldButtons[client] = buttons;
}

CreateMoneyCoins(client, amount)
{
	new coin;
	while (0 < amount)
	{
		coin = GetCoinForMoney(amount);
		if (coin != -1)
		{
			new Float:fOrigin[3] = 0.0;
			GetClientAbsOrigin(client, fOrigin);
			new ent = CreateEntityByName("prop_physics_override", -1);
			DispatchKeyValue(ent, "model", g_szCoins[coin]);
			DispatchKeyValue(ent, "classname", "coin");
			DispatchSpawn(ent);
			SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1)
			fOrigin[2] += 32.0;
			fOrigin[0] = fOrigin[0] + GetRandomFloat(-70.0, 70.0);
			fOrigin[1] += GetRandomFloat(-70.0, 70.0);
			TeleportEntity(ent, fOrigin, NULL_VECTOR, NULL_VECTOR);
			DispatchKeyValue(ent, "OnUser1", "!self,Kill,,60.0,-1");
			AcceptEntityInput(ent, "FireUser1", -1, -1, 0);
			amount -= g_iCoinsValue[coin];
			g_iCoinValue[ent] = g_iCoinsValue[coin];
					
			SDKHook(ent, SDKHook_OnTakeDamage, SDKEvent_NeverTakeDamage);
		}
		else
		{
			amount = 0;
		}
	}
}

public Action:SDKEvent_NeverTakeDamage(victimEntity)
{
	return Plugin_Handled;
}	

public GetCoinForMoney(money)
{
	for(new i=sizeof(g_iCoinsValue)-1;i > 0;i--)
	{
		if (g_iCoinsValue[i] <= money && g_iCoinsAppearFromValue[i] <= money)
		{
			return i;
		}
	}
	return -1;
}

public DownloadDir(String:dirofmodels[])
{
	new String:path[256];
	new FileType:type;
	new String:FileAfter[256];
	new Handle:dir = OpenDirectory(dirofmodels, false, "GAME");
	if (!dir)
	{
		return;
	}
	while (ReadDirEntry(dir, path, 256, type))
	{
		if (type == FileType:2)
		{
			FormatEx(FileAfter, 256, "%s/%s", dirofmodels, path);
			AddFileToDownloadsTable(FileAfter);
		}
	}
	CloseHandle(dir);
	dir = null;
}