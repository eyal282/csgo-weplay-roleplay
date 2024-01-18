#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
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

#define SEND_TAX 0.1

new g_iOldButtons[MAXPLAYERS+1];
new g_iSendingCash[MAXPLAYERS+1];

new Handle:g_hOpenMenu;
new Handle:g_hMenuPress;

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	g_hOpenMenu = CreateGlobalForward("RP_OnPlayerMenu", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_Cell);
	g_hMenuPress = CreateGlobalForward("RP_OnMenuPressed", ET_Ignore, Param_Cell, Param_Cell, Param_String);
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	new target = GetClientOfUserId(g_iSendingCash[client])
	
	if(target == 0)
	{
		return Plugin_Continue;
	}
	else if (StrEqual(sArgs, "-1", true))
	{
		RP_PrintToChat(client, "Operation cancelled!");
		
		g_iSendingCash[client] = 0;
		
		return Plugin_Stop;
	}
	
	new cash = StringToInt(sArgs);
	
	if (cash < 1)
	{
		RP_PrintToChat(client, "This cash amount is not valid, try again.");
		ShowCommunicateMenu(client, target);
		
		g_iSendingCash[client] = 0;
		
		return Plugin_Stop;
	}
	
	else if (GetClientCash(client, POCKET_CASH) < cash)
	{
		RP_PrintToChat(client, "You dont have enough cash on your pocket!");
		ShowCommunicateMenu(client, target);
		
		g_iSendingCash[client] = 0;
		
		return Plugin_Stop;
	}
	
	new bool:TaxesDisabled = RP_IsClientTaxesDisabled(client) || RP_IsClientTaxesDisabled(target);
	
	GiveClientCashNoGangTax(client, POCKET_CASH, -1 * cash);
	
	if(!TaxesDisabled)
	{
		cash -= RoundToNearest(float(cash) * SEND_TAX);
		
		GiveClientCashNoGangTax(target, POCKET_CASH, cash);
	}
	else
		GiveClientCashNoGangTax(target, BANK_CASH, cash);
		
	RP_PrintToChat(client, "You have sent \x02%i\x01 cash to \x04%N!\x01 \x02(%.1f%% tax.)\x01", cash, target, TaxesDisabled ? 0.0 : SEND_TAX * 100.0);
	
	RP_PrintToChat(target, "\x02%N\x01 has sent you \x04%i\x01 cash. \x02(%.1f%% tax.)", client, cash, TaxesDisabled ? 0.0 : SEND_TAX * 100.0);
	RolePlayLog("%N has sent %N %i (%s)cash!", client, target, cash, sArgs);
	
	g_iSendingCash[client] = 0;
	
	return Plugin_Stop;
}

public OnClientPostAdminCheck(client)
{
	g_iSendingCash[client] = 0;
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Menu");
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3])
{
	if (buttons & IN_RELOAD && !(g_iOldButtons[client] & IN_RELOAD))
	{
		static String:WeaponName[32];
		GetClientWeapon(client, WeaponName, 32);

		if (StrContains(WeaponName, "weapon_knife", false) != -1 || StrContains(WeaponName, "bayonet", false) != -1)
		{
			FakeClientCommand(client, "sm_inv");
		}
	}
	else
	{
		if (buttons & IN_USE && !(g_iOldButtons[client] & IN_USE))
		{
			new player = GetClientAimTarget(client, true);

			if (player != -1 && CheckDistance(client, player) < 150.0)
			{
				ShowCommunicateMenu(client, player);
			}
		}
	}
	g_iOldButtons[client] = buttons;
	return Plugin_Continue;
}

ShowCommunicateMenu(client, player)
{
	if (player < 1 || player > MaxClients)
		return;
		
	else if(!IsPlayerAlive(client) || !IsPlayerAlive(player))
		return;
		
	else if(!RP_IsClientInRP(client) || !RP_IsClientInRP(player))
		return;
		
	new String:szIndex[16];
	FormatEx(szIndex, 16, "%i", GetClientUserId(player));
	new Menu:menu = CreateMenu(CommunicateMenu_Handler);
	RP_SetMenuTitle(menu, "Player Menu - Talking with %N\nPocket Cash: $%i\nBank Cash: $%i", player, GetClientCash(client, POCKET_CASH), GetClientCash(client, BANK_CASH));
	AddMenuItem(menu, szIndex, "Send item.", 0);
	AddMenuItem(menu, szIndex, "Send cash.", 0);
	
	for (new i = 1; i <= 20;i++)
	{
		Call_StartForward(g_hOpenMenu);
		
		Call_PushCell(client);
		Call_PushCell(player);
		Call_PushCellRef(menu);
		Call_PushCell(i);
		
		Call_Finish();
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public CommunicateMenu_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
		CloseHandle(menu);

	else if (action == MenuAction_Select)
	{
		new String:szIndex[8];
		GetMenuItem(menu, 0, szIndex, 6);
		new player = GetClientOfUserId(StringToInt(szIndex));
		
		if(player == 0)
		{
			RP_PrintToChat(client, "The target player has disconnected from the server!");
			return;
		}
		switch (key)
		{
			case 0:
			{
				RP_SendItem(client, player);
			}
			case 1:
			{
				g_iSendingCash[client] = GetClientUserId(player);
				RP_PrintToChat(client, "Type cash amount to send or \x02-1\x01 to cancel!");
			}
			default:
			{
				new String:szSpecialInfo[32];
				GetMenuItem(menu, key, szSpecialInfo, 32);
				
				Call_StartForward(g_hMenuPress);
				Call_PushCell(client);
				Call_PushCell(player);
				Call_PushString(szSpecialInfo);

				Call_Finish();
			}
		}
	}
}

 