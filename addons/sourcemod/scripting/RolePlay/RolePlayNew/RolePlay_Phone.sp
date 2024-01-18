#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>

new EngineVersion:g_Game;

#define SEND_TAX 0.1

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new Handle:g_hOpenMenu;
new Handle:g_hMenuPress;

Handle CallList[MAXPLAYERS + 1]; // This array is capped at MAXPLAYERS + 1, it doesn't assign each cell to a player!

float g_fAcceptCall[MAXPLAYERS + 1][MAXPLAYERS + 1]; // First is the calling, second is the called. 

int g_iSendingCash[MAXPLAYERS + 1];


public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Phone");
	
	CreateNative("RP_GetClientCallSlot", _RP_GetClientCallSlot);
}

public _RP_GetClientCallSlot(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(!RP_IsClientInRP(client))
		return -1;
		
	return GetClientCallSlot(client);
}

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	g_hOpenMenu = CreateGlobalForward("RP_OnPhoneMenu", ET_Ignore, Param_Cell, Param_CellByRef, Param_Cell);
	g_hMenuPress = CreateGlobalForward("RP_OnPhoneMenuPressed", ET_Ignore, Param_Cell, Param_String);
	
	for (new i = 0; i < sizeof(CallList);i++)
		CallList[i] = CreateArray(1);
		
	AddCommandListener(Listener_Drop, "drop");
}

public OnMapStart()
{
	for (new i = 1; i <= MaxClients;i++)
	{
		Func_OnClientConnected(i);
	}
}

public OnClientConnected(client)
{
	Func_OnClientConnected(client);
}

Func_OnClientConnected(client)
{
	for (new i = 0; i < sizeof(g_fAcceptCall);i++)
	{
		g_fAcceptCall[client][i] = 0.0;
		g_fAcceptCall[i][client] = 0.0;
	}
	
	TryHangUpCall(client);
}

public OnClientDisconnect(client)
{
	TryHangUpCall(client);
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	new target = GetClientOfUserId(g_iSendingCash[client]);
	
	if (target == 0)
		return Plugin_Continue;
		
	else if(StrEqual(sArgs, "-1", true))
	{
		RP_PrintToChat(client, "Operation cancelled!");
		
		g_iSendingCash[client] = 0;
		return Plugin_Handled;
	}
	
	new cash = StringToInt(sArgs);
	
	if (cash < 1)
	{
		RP_PrintToChat(client, "This cash amount is not valid, try again.");
		
		g_iSendingCash[client] = 0;
		
		ShowPhoneMenu(client);
		
		return Plugin_Handled;
	}

	else if (GetClientCash(client, BANK_CASH) < cash)
	{
		RP_PrintToChat(client, "You dont have enough cash on your bank!");
		ShowPhoneMenu(client);
		
		return Plugin_Stop;
	}
		
	new bool:TaxesDisabled = RP_IsClientTaxesDisabled(client) || RP_IsClientTaxesDisabled(target);
	
	GiveClientCashNoGangTax(client, BANK_CASH, -1 * cash);
	
	if(!TaxesDisabled)
	{
		cash -= RoundToNearest(float(cash) * SEND_TAX);
		
		GiveClientCashNoGangTax(target, BANK_CASH, cash);
	}
	else
		GiveClientCashNoGangTax(target, BANK_CASH, cash);
		
	RP_PrintToChat(client, "You have wire transferred \x02%i\x01 cash to \x04%N!\x01 \x02(%.1f%% tax.)\x01", cash, target, TaxesDisabled ? 0.0 : SEND_TAX * 100.0);
	
	RP_PrintToChat(target, "\x02%N\x01 has wire transferred you \x04%i\x01 cash. \x02(%.1f%% tax.)", client, cash, TaxesDisabled ? 0.0 : SEND_TAX * 100.0);
	RolePlayLog("%N has wire transfered %N %i (%s)cash!", client, target, cash, sArgs);
	
	g_iSendingCash[client] = 0;
	
	return Plugin_Stop;
}

public OnClientPostAdminCheck(client)
{
	g_iSendingCash[client] = 0;
}

public Action:Listener_Drop(client, const String:command[], args)
{

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	else if(!RP_IsClientInRP(client))
		return Plugin_Continue;

	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return Plugin_Continue;
		
	new String:Classname[64];
	
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!StrEqual(Classname, "weapon_knife"))
		return Plugin_Continue;
		
	ShowPhoneMenu(client)
	
	return Plugin_Continue;
}

ShowPhoneMenu(client)
{
		
	new Menu:menu = CreateMenu(PhoneMenu_Handler);
	
	new String:TempFormat[256];
	
	if(IsClientInCall(client))
	{
		new count = 1;
		
		FormatEx(TempFormat, sizeof(TempFormat), "%N\n ", client);
		
		for (new i = 1; i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			else if(client == i)
				continue;
					
			else if(!RP_IsClientInRP(i))
				continue;
				
			else if(GetClientCallSlot(i) != GetClientCallSlot(client))
				continue;
				
			Format(TempFormat, sizeof(TempFormat), "%s%N%s", TempFormat, i, count % 2 == 0 ? "\n " : ", ");
			
			count++;
				
		}
		
		TempFormat[strlen(TempFormat) - 2] = EOS;
	}
	else
		FormatEx(TempFormat, sizeof(TempFormat), "None.")
		
	RP_SetMenuTitle(menu, "Phone Menu\n ◉ Bank cash: $%i\n Players in Call: %s", GetClientCash(client, BANK_CASH), TempFormat);
	
	AddMenuItem(menu, "", "Call to Player");
	AddMenuItem(menu, "", "Call to Gang", Get_User_Gang(client) != -1 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	//AddMenuItem(menu, szIndex, "Call to Gang", Get_User_Gang(client) != -1 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(menu, "", "Hang Up", IsClientInCall(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	AddMenuItem(menu, "", "Transfer Money")

	new String:szItemFormat[64];
	new String:szItemData[32];
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(i == client)
			continue;
		
		else if(g_fAcceptCall[i][client] < GetGameTime())
			continue;

		else if(!IsClientInCall(i))
			continue;
			
		else if (GetClientCallSlot(i) == GetClientCallSlot(client))
			continue;
			
		FormatEx(szItemData, sizeof(szItemData), "AcceptCall%i", GetClientUserId(i));

		FormatEx(szItemFormat, 64, "Call Accept: %N", i);
		AddMenuItem(menu, szItemData, szItemFormat, !IsClientInCall(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);	
	}
	for (new i = 1; i <= 20;i++)
	{
		Call_StartForward(g_hOpenMenu);
		
		Call_PushCell(client);
		Call_PushCellRef(menu);
		Call_PushCell(i);
		
		Call_Finish();
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public PhoneMenu_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
		CloseHandle(menu);

	else if (action == MenuAction_Select)
	{
		switch (key)
		{
			case 0:
			{
				ShowPlayersMenu(client);
			}
			case 1:
			{
				new bool:anyGang = false;
				
				TryCreateCall(client);
				
				for (new i = 1; i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;
					
					else if(i == client)
						continue;
					
					else if(!Are_Users_Same_Gang(client, i))
						continue;
						
					anyGang = true;
					
					RP_PrintToChat(i, "Gang mate %N is trying to call you.", client);
					
					g_fAcceptCall[client][i] = GetGameTime() + 20.0;
				}
				
				if(anyGang)
					RP_PrintToChat(client, "Call request sent!");
			}
			case 2:
			{
				new callSlot = TryHangUpCall(client);
				
				PrintToChatCall(callSlot, "%N hung up", client);
			}
			case 3:
			{
				ShowPlayersMenu_TransferMoney(client);
			}
			default:
			{
				new String:szSpecialInfo[32];
				GetMenuItem(menu, key, szSpecialInfo, 32);
				
				if(strncmp(szSpecialInfo, "AcceptCall", 10) == 0)
				{
					ReplaceStringEx(szSpecialInfo, sizeof(szSpecialInfo), "AcceptCall", "");
					
					int target = GetClientOfUserId(StringToInt(szSpecialInfo));
					
					if(target == 0)
						return;
						
					else if(IsClientInCall(client))
						return;
					
					new callSlot = AddClientToCall(target, client);
					
					PrintToChatCall(callSlot, "%N joined the call!", client);
				}
				else
				{
					Call_StartForward(g_hMenuPress);
					Call_PushCell(client);
					Call_PushString(szSpecialInfo);
		
					Call_Finish();
				}
			}
		}
	}
}

ShowPlayersMenu(client)
{
	new String:szItemFormat[64];
	new String:szItemData[11];

	new Menu:menu = CreateMenu(PlayersMenu_Handler);
	
	new count;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(i == client)
			continue;
			
		IntToString(GetClientUserId(i), szItemData, 11);
		
		if(!IsClientInCall(i))
			FormatEx(szItemFormat, 64, "%N", i);
		
		else
			FormatEx(szItemFormat, 64, "%N [In Call]", i)

		AddMenuItem(menu, szItemData, szItemFormat);
		
		count++;
	}
	
	if(count == 0)
	{
		AddMenuItem(menu, "0", "No players to add.");
	}
	
	RP_SetMenuTitle(menu, "Menu - Phone Menu\n ◉ Choose a player add to your call:\n ", count);
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenu(menu, client, 0);

}

public PlayersMenu_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Cancel && key == MenuCancel_ExitBack)
	{
		ShowPhoneMenu(client);
	}
	if (action == MenuAction_Select)
	{

		new String:szItemData[11];
		GetMenuItem(menu, key, szItemData, sizeof(szItemData));
		new target = GetClientOfUserId(StringToInt(szItemData));
		
		if(target != 0)
		{
			
			if(IsClientInCall(target))
			{
				RP_PrintToChat(client, "\x02%N\x01 is in call. Asking to call you back. ", target);
				
				RP_PrintToChat(target, "\x02%N\x01 is asking you to call him.", client);
			}
			else
			{
				TryCreateCall(client);
				
				g_fAcceptCall[client][target] = GetGameTime() + 10.0;
				
				RP_PrintToChat(client, "Call request sent!");
				
				RP_PrintToChat(target, "%N is trying to call you.", client);
			}
		}
		
		ShowPhoneMenu(client);
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
}


ShowPlayersMenu_TransferMoney(client)
{
	new String:szItemFormat[64];
	new String:szItemData[11];

	new Menu:menu = CreateMenu(PlayersMenuTransferMoney_Handler);
	
	new count;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(i == client)
			continue;
		
		IntToString(GetClientUserId(i), szItemData, sizeof(szItemData));
		
		FormatEx(szItemFormat, 64, "%N", i);

		AddMenuItem(menu, szItemData, szItemFormat);
		
		count++;
	}
	
	if(count == 0)
	{
		AddMenuItem(menu, "0", "No players online.");
	}
	
	RP_SetMenuTitle(menu, "Menu - Phone Menu\n ◉ Choose a player wire transfer money:\n ◉ Bank cash: %i", GetClientCash(client, BANK_CASH));
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenu(menu, client, 0);

}

public PlayersMenuTransferMoney_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Cancel && key == MenuCancel_ExitBack)
	{
		ShowPhoneMenu(client);
	}
	if (action == MenuAction_Select)
	{

		new String:szItemData[11];
		GetMenuItem(menu, key, szItemData, sizeof(szItemData));
		new target = GetClientOfUserId(StringToInt(szItemData));
		
		if(target != 0)
		{
			g_iSendingCash[client] = GetClientUserId(target);
			
			RP_PrintToChat(client, "Type cash amount to send or \x02-1\x01 to cancel!");
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
}

// Returns false if client is not in RP.
stock IsClientInCall(client)
{
	if(!RP_IsClientInRP(client))
		return false;
		
	return GetClientCallSlot(client) != -1;
}

stock GetClientCallSlot(client)
{		
	for (int i = 0; i < sizeof(CallList);i++)
	{
		Handle Array = CallList[i];
			
		if(FindValueInArray(Array, client) != -1)
			return i;
	}
	
	return -1;
}

// Returns slot in CallList
stock TryCreateCall(client)
{
	int emptyCallSlot = -1;
		
	for (int i = 0; i < sizeof(CallList);i++)
	{
		Handle Array = CallList[i];
		
		if(GetArraySize(Array) == 0 && emptyCallSlot == -1)
			emptyCallSlot = i;
			
		else if(FindValueInArray(Array, client) != -1)
			return i;
	}
	
	if(emptyCallSlot == -1)
		return emptyCallSlot;
		
	Handle Array = CallList[emptyCallSlot];
	
	PushArrayCell(Array, client);
	
	return emptyCallSlot;
}

// Returns slot in CallList, or -1 if base client is not in a call ( how... )

// base Client is the client already in a call.

// clientToAdd is the client to add to the call.

stock AddClientToCall(baseClient, clientToAdd)
{
	for (int i = 0; i < sizeof(CallList);i++)
	{
		Handle Array = CallList[i];
			
		if(FindValueInArray(Array, baseClient) != -1)
		{
			PushArrayCell(Array, clientToAdd);
			return i;
		}
	}
	
	return -1;
}

// Returns call slot BEFORE hanging up, or -1 if client was never in a call.
stock TryHangUpCall(client)
{
	for (int i = 0; i < sizeof(CallList);i++)
	{
		Handle Array = CallList[i];
			
		if(FindValueInArray(Array, client) != -1)
		{
			RemoveFromArray(Array, FindValueInArray(Array, client));
			return i;
		}
	}
	
	return -1;
}

stock PrintToChatCall(callSlot, const String:format[], any:...)
{
	new String:buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(IsFakeClient(i))
			continue;
		
		else if(GetClientCallSlot(i) != callSlot)
			continue;

		RP_PrintToChat(i, buffer);
	}
}
