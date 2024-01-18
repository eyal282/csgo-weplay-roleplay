#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <Eyal-RP>

#define MAX_POSSIBLE_MONEY 65535

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new EngineVersion:g_Game;
new ArrayList:g_aItemsShortName;
new ArrayList:g_aItemsName;
new ArrayList:g_aClientItems[MAXPLAYERS+1][10];
new ArrayList:g_aCategoryNames;
new g_iClientCash[MAXPLAYERS+1][2];
new bool:g_bLoadedCash[MAXPLAYERS+1];
new bool:g_bLoadedItems[MAXPLAYERS+1];
new g_iItemCategory[2048];
new Handle:g_hItemUse;
new Handle:g_hItemUsePost;
new Handle:g_hItemSent;
new Database:g_hDatabase;

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
	{
		SQL_TQuery(g_hDatabase, SQL_NoAction, "CREATE TABLE IF NOT EXISTS `rp_cash` ( `AuthId` varchar(32) NOT NULL UNIQUE, `nickname` varchar(32) NOT NULL, `cash` int(11) NOT NULL,`bank` int(11) NOT NULL)");
		SQL_TQuery(g_hDatabase, SQL_NoAction, "CREATE TABLE IF NOT EXISTS `rp_items` ( `AuthId` varchar(32) NOT NULL, `item_short_name` varchar(32) NOT NULL, `item_count` INT(11) NOT NULL, UNIQUE KEY `AuthId` (`AuthId`,`item_short_name`) )");
	}
	
	g_aItemsShortName = CreateArray(5);
	g_aItemsName = CreateArray(64);
	g_aCategoryNames = CreateArray(64);
	
	for(new i=1;i <= MaxClients;i++)
	{
		for(new j=0;j < sizeof(g_aClientItems[]);j++)
		{
			g_aClientItems[i][j] = CreateArray(1);
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPostAdminCheck(i);
	}
	g_hItemUse = CreateGlobalForward("OnItemUsed", ET_Event, Param_Cell, Param_Cell);
	g_hItemUsePost = CreateGlobalForward("OnItemUsedPost", ET_Ignore, Param_Cell, Param_Cell);
	g_hItemSent = CreateGlobalForward("OnItemSent", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	RegConsoleCmd("sm_inv", Command_Inventory, "Opens up inventory.");

	RegAdminCmd("sm_givecash", Command_GiveCash, ADMFLAG_ROOT, "Gives client cash.");
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
}

/*
public CheckLicense(String:webUrl[], String:containedKey[], String:failError[])
{
	new Handle:pack = CreateDataPack();
	
	WritePackString(pack, containedKey);
	WritePackString(pack, failError);
	
	new Handle:socket = SocketCreate(SocketType:1, OnSocketError);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, "www.pastebin.com", 80);
	SocketSetArg(socket, pack);
}

public OnSocketConnected(Handle:socket, any:data)
{
	new String:requestStr[256];
	new String:containedKey[256];
	new String:failError[256];
	new String:FinalURL[256];

	
	PrintToChatEyalDelay("alpha");
	ResetPack(data);
	ReadPackString(data, containedKey, 256);
	ReadPackString(data, failError, 256);

	Format(requestStr, 256, "GET /raw/vsx30e1t HTTP/1.1\r\nHost: pastebin.com\r\nConnection: close\r\n\r\n");
	SocketSend(socket, requestStr, -1);
	return 0;
}

public OnSocketReceive(Handle:socket, String:receiveData[], dataSize, DataPack:data)
{

	if (!data || data)
	{
		return 0;
	}
	ResetPack(data, false);
//	ReadPackString(data, args[0][args], 256);

	PrintToChatEyalDelay("a");
	SocketDisconnect(socket);
	CloseHandle(socket);
	socket = INVALID_HANDLE;
	return 0;
}

public OnSocketDisconnected(Handle:socket, DataPack:data)
{
	CloseHandle(data);
	data = null;
	CloseHandle(socket);
	PrintToChatEyalDelay("b");
	return 0;
}

public OnSocketError(Handle:socket, errorType, errorNum, DataPack:data)
{
	//SetFailState(args[3]);
	PrintToChatEyalDelay("c");
	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(data);
	data = null;
	CloseHandle(socket);
	return 0;
}

public void:xfEncrypt(String:original[], String:dest[])
{
	new destNum;
	new i;
	while (strlen(original) > i)
	{
		destNum++;
		dest[destNum] = original[i] % 7 + original[i];
		destNum++;
		dest[destNum] = original[i] % 8 + original[i];
		destNum++;
		dest[destNum] = original[i] % 9 + original[i];
		i++;
	}
	return void:0;
}
*/

public Action:Command_GiveCash(client, args)
{
	if (!IsHighManagement(client))
	{
		RP_PrintToChat(client, "Sorry! but you cant use this command.");
		return Plugin_Handled;
	}
	else
	{
		if (args < 3)
		{
			RP_PrintToChat(client, "Missing arguments!, sm_givecash <client> <cash> <type 0-pocket, 1-cash>");
			
			return Plugin_Handled;
		}
		new String:szArg1[32];
		new String:szArg2[16];
		new String:szArg3[16];
		GetCmdArg(1, szArg1, 32);
		new target = FindTarget(client, szArg1, false, false);
		if (target == -1)
		{
			return Plugin_Handled;
		}
		GetCmdArg(2, szArg2, sizeof(szArg2));
		new iAmount = StringToInt(szArg2);
		GetCmdArg(3, szArg3, sizeof(szArg3));
		new cashType:type = view_as<cashType>(StringToInt(szArg3));
		
		if(type != POCKET_CASH && type != BANK_CASH)
		{
			RP_PrintToChat(client, "Invalid arguments!, sm_givecash <client> <cash> <type 0-pocket, 1-cash>");
			return Plugin_Handled;
		}
		RP_PrintToChat(client, "You have given \x02%N\x01 \x04$%i\x01 cash to his \x02%s", target, iAmount, type ? "bank" : "cash");

		RP_PrintToChat(client, "\x02%N\x01 has gave you \x04$%i\x01 cash to your \x02%s!", target, iAmount, type ? "bank" : "cash");

		RolePlayAdminLog("%L has gave %L %i (%s)cash! [ADMIN]", client, target, iAmount, type ? "bank" : "cash");
		
		GiveCash(target, type, iAmount);
	}
	return Plugin_Handled;
}
public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
		
	UpdateCashInScoreBoard(client);
}
public Action:Command_Inventory(client, args)
{
	ShowInventoryMenu(client);
	
	return Plugin_Handled;
}

ShowSendItemMenu(client, player)
{
	if (!IsClientInGame(player))
	{
		RP_PrintToChat(client, "This player is offline.");
	}
	else
	{
		if (IsClientInGame(player))
		{
			new items;
			new String:szMenuItem[32];
			new String:szItemIndex[128];
			new Handle:menu = CreateMenu(MenuHandler_SendItem);
			RP_SetMenuTitle(menu, "Inventory Menu - Send Menu\n Sending item to %N\n ", player);

			new Handle:NoDuplicatesArray = CreateArray(1);
			
			new Handle:SortArray = CreateArray(128);
			
			for(new i=0;i < GetArraySize(g_aCategoryNames);i++)
			{
				for(new j=0;j < GetArraySize(g_aClientItems[client][i]);j++)
				{
					GetArrayString(g_aItemsName, GetArrayCell(g_aClientItems[client][i], j), szMenuItem, sizeof(szMenuItem));
					
					if(FindValueInArray(NoDuplicatesArray, GetArrayCell(g_aClientItems[client][i], j)) != -1)
						continue;
					
					Format(szMenuItem, sizeof(szMenuItem), "%s [Σ%i]", szMenuItem, CountPlayerItems(client, GetArrayCell(g_aClientItems[client][i], j)));
					
					FormatEx(szItemIndex, 128, "%s,%i,%i", szMenuItem, player, GetArrayCell(g_aClientItems[client][i], j));
					
					PushArrayString(SortArray, szItemIndex);
					
					PushArrayCell(NoDuplicatesArray, GetArrayCell(g_aClientItems[client][i], j));
					
					items++;
				}
			}
			
			CloseHandle(NoDuplicatesArray);
			
			if (!items)
			{
				AddMenuItem(menu, "", "You don't have any items.", 1);
			}
			else
			{
				SortADTArray(SortArray, Sort_Ascending, Sort_String);
				
				for(new i=0;i < GetArraySize(SortArray);i++)
				{
					GetArrayString(SortArray, i, szItemIndex, sizeof(szItemIndex));
				
					new String:params[3][32];
					ExplodeString(szItemIndex, ",", params, 3, 32, false);
					
					FormatEx(szItemIndex, sizeof(szItemIndex), "%s,%s", params[1], params[2]);
					
					FormatEx(szMenuItem, sizeof(szMenuItem), params[0]);
					
					AddMenuItem(menu, szItemIndex, szMenuItem);
				}
			}
			
			CloseHandle(SortArray);
			
			DisplayMenu(menu, client, 0);
		}
	}
	
}

public MenuHandler_SendItem(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szKey[24];
		new String:params[2][32];
		new String:szMenuItem[32];
		GetMenuItem(menu, key, szKey, sizeof(szKey));
		ExplodeString(szKey, ",", params, 2, 16, false);
		
		new player = StringToInt(params[0]);
		new item = StringToInt(params[1]);
		
		GetArrayString(g_aItemsName, item, szMenuItem, sizeof(szMenuItem));
		
		new Action:result;
		
		Call_StartForward(g_hItemSent);
		
		Call_PushCell(client);
		Call_PushCell(player);
		Call_PushCell(item);
		
		Call_Finish(result);
		
		if(result >= Plugin_Handled)
			return;
			
		DeleteClientItem(client, item);
		GiveClientItem(player, item);
		RP_PrintToChat(client, "You have sent \x04%s\x01 to \x02%N.", szMenuItem, player);
		RP_PrintToChat(player, "\x02%N\x01 has sent you \x04%s.", client, szMenuItem);
		RolePlayLog("%L has sent %L %s!", client, player, szMenuItem);
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

ShowInventoryMenu(client)
{
	new job = RP_GetClientJob(client);
	new String:szCategoryName[96];
	new Menu:menu = CreateMenu(MenuHandler_Inventory);
	
	if (job == -1)
	{
		RP_SetMenuTitle(menu, "Inventory Menu - Main Menu\n● Pocket cash: %i\n● Bank cash: %i\n● Job: None\n ", g_iClientCash[client][POCKET_CASH], g_iClientCash[client][BANK_CASH]);
	}
	else
	{
		new String:szClientJob[32];
		RP_GetClientJobName(client, szClientJob, 32);
		new String:szJobMainName[32];
		RP_GetJobName(job, szJobMainName, 32);

		new level = RP_GetClientTrueLevel(client, job);
		
		// Before Jobs had nicknames
		//RP_SetMenuTitle(menu, "Inventory Menu - Main Menu\n● Pocket cash: $%i\n● Bank cash: $%i\n● Job: %s (%s)\n● Job Level: %i (%i/%i)\n● Job balance: ($%i/$%i)\n ", g_iClientCash[client][POCKET_CASH], g_iClientCash[client][BANK_CASH], szJobMainName, szClientJob, level, RP_GetClientEXP(client, job), CalculateEXPForNextLevel(level), RP_GetClientJobBank(client), CalculateBankForNextLevel(level));
		
		RP_SetMenuTitle(menu, "Inventory Menu - Main Menu\n● Pocket cash: $%i\n● Bank cash: $%i\n● Job: %s\n● Job Level: %i (%i/%i)\n● Job balance: ($%i/$%i)\n ", g_iClientCash[client][POCKET_CASH], g_iClientCash[client][BANK_CASH], szJobMainName, level, RP_GetClientEXP(client, job), CalculateEXPForNextLevel(level), RP_GetClientJobBank(client), CalculateBankForNextLevel(level));
		
	}
	new size = GetArraySize(g_aCategoryNames);

	new Handle:SortArray = CreateArray(96);
	
	for(new i=0;i < size;i++)
	{
		GetArrayString(g_aCategoryNames, i, szCategoryName, sizeof(szCategoryName));
		
		new clientSize = GetArraySize(g_aClientItems[client][i]);

		Format(szCategoryName, 96, "%s - [%i Item%s]", szCategoryName, clientSize, clientSize == 1 ? "" : "s");

		PushArrayString(SortArray, szCategoryName);
		
	}
	
	SortADTArray(SortArray, Sort_Ascending, Sort_String);
	
	for(new i=0;i < GetArraySize(SortArray);i++)
	{
		GetArrayString(SortArray, i, szCategoryName, sizeof(szCategoryName));
		
		AddMenuItem(menu, "", szCategoryName, StrContains(szCategoryName, "[0 item", false) == -1 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	CloseHandle(SortArray);
	
	DisplayMenu(menu, client, 0);
	
}

public MenuHandler_Inventory(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szCategoryName[64], String:dummy_value[1];
		GetMenuItem(menu, key, dummy_value, 0, _, szCategoryName, sizeof(szCategoryName));
	
		if(RP_IsClientInJail(client))
			return 0;
			
		new len = StrContains(szCategoryName, " - ");
		
		szCategoryName[len] = EOS;
		
		new cat = FindStringInArray(g_aCategoryNames, szCategoryName);
		
		ShowCategoryItems(client, cat, 0);
	}
	else
	{
		if (action == MenuAction:16)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
	return 0;
}

ShowCategoryItems(client, category, item)
{
	new String:szCategoryId[8];
	IntToString(category, szCategoryId, 6);
	new String:Info[128];
	new String:szFormat[64];
	GetArrayString(g_aCategoryNames, category, szFormat, 64);
	new Menu:menu = CreateMenu(MenuHandler_ViewingCategory); // , MenuAction:28
	RP_SetMenuTitle(menu, "Inventory Menu - Viewing Items \n● Category: %s\n● Pocket cash: %i\n● Bank cash: %i\n ", szFormat, g_iClientCash[client][POCKET_CASH], g_iClientCash[client][BANK_CASH]);

	new Handle:NoDuplicatesArray = CreateArray(1);
	new Handle:SortArray = CreateArray(128);
	
	for(new i=0;i < GetArraySize(g_aClientItems[client][category]);i++)
	{
	
		GetArrayString(g_aItemsName, GetArrayCell(g_aClientItems[client][category], i, 0, false), szFormat, sizeof(szFormat));		
		
		if(FindValueInArray(NoDuplicatesArray, GetArrayCell(g_aClientItems[client][category], i)) != -1)
			continue;
		
		IntToString(GetArrayCell(g_aClientItems[client][category], i), szCategoryId, sizeof(szCategoryId));
		
		FormatEx(Info, sizeof(Info), "%s|||%i|||%i", szFormat, GetArrayCell(g_aClientItems[client][category], i), category);
		
		PushArrayString(SortArray, Info);
		
		PushArrayCell(NoDuplicatesArray, GetArrayCell(g_aClientItems[client][category], i));
	}
	
	CloseHandle(NoDuplicatesArray);
	
	SortADTArray(SortArray, Sort_Ascending, Sort_String);
	
	for(new i=0;i < GetArraySize(SortArray);i++)
	{
		GetArrayString(SortArray, i, Info, sizeof(Info));
		
		new String:params[3][32];
		ExplodeString(Info, "|||", params, 3, 32, false);
		
		FormatEx(Info, sizeof(Info), "%s|||%s", params[1], params[2]);
		
		Format(szFormat, sizeof(szFormat), "%s [Σ%i]", params[0], CountPlayerItems(client, StringToInt(params[1])));
		
		AddMenuItem(menu, Info, szFormat, 0);
	}
	
	CloseHandle(SortArray);
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenuAtItem(menu, client, item, 0);
	
}

public MenuHandler_ViewingCategory(Menu:menu, MenuAction:action, client, key)
{
	if(action == MenuAction_Cancel && key == MenuCancel_ExitBack)
	{
		ShowInventoryMenu(client);
	}
	if (action == MenuAction_Select)
	{	
		new String:szKey[32];
		new String:params[2][32];

		GetMenuItem(menu, key, szKey, sizeof(szKey));
		ExplodeString(szKey, "|||", params, 2, 16, false);
		
		new iItem = StringToInt(params[0]);
		new iCategory = StringToInt(params[1]);
		new String:szFormat[64];
		GetArrayString(g_aItemsName, iItem, szFormat, 64);
		
		
		// Bar color
		if(RP_IsClientInJail(client))
		{
			RP_PrintToChat(client, "You cannot use items from your inventory while in jail");
			return;
		}
		else if(RP_IsUserInArena(client))
		{
			RP_PrintToChat(client, "You cannot use items from your inventory while in arena");
			return;
		}
		else if(RP_IsUserInDuel(client))
		{
			RP_PrintToChat(client, "You cannot use items from your inventory while in a duel");
			return;
		}
		else if(RP_IsUserInEvent(client))
		{
			RP_PrintToChat(client, "You cannot use items from your inventory while in an event");
			return;
		}
		else if(CountPlayerItems(client, iItem) == 0)
		{
			RP_PrintToChat(client, "This item does not exist!");
			return;
		}
		
		new Action:result;
		
		Call_StartForward(g_hItemUse);
		
		Call_PushCell(client);
		Call_PushCell(iItem);
		Call_Finish(result);
		
		if(result != Plugin_Handled && result != Plugin_Stop)
			DeleteClientItem(client, iItem);
		
		Call_StartForward(g_hItemUsePost);
		
		Call_PushCell(client);
		Call_PushCell(iItem);
		Call_Finish(result);
		
		ShowCategoryItems(client, iCategory, GetMenuSelectionPosition());
	}
	else
	{
		if (action == MenuAction:8)
		{
			if (key == -3)
			{
				ShowInventoryMenu(client);
			}
		}
		if (action == MenuAction:16)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
}

public OnClientDisconnect(client)
{
	g_bLoadedCash[client] = false;
	g_bLoadedItems[client] = false;
	g_iClientCash[client][POCKET_CASH] = 0;
	g_iClientCash[client][BANK_CASH] = 0;
	
}

public OnClientPostAdminCheck(client)
{
	for(new i=0;i < sizeof(g_aClientItems[]);i++)
	{
		ClearArray(g_aClientItems[client][i]);
	}
	g_iClientCash[client][POCKET_CASH] = 0;
	g_iClientCash[client][BANK_CASH] = 0;
	UpdateCashInScoreBoard(client);
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT cash, bank from rp_cash where AuthId='%s'", szAuth);
	SQL_TQuery(g_hDatabase, SQL_LoadCash, szQuery, GetClientSerial(client), DBPrio_Normal);
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT item_short_name, item_count from rp_items where AuthId='%s'", szAuth);
	SQL_TQuery(g_hDatabase, SQL_LoadItems, szQuery, GetClientSerial(client), DBPrio_Normal);
	
}

public SQL_LoadCash(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	if (!client)
	{
		return;
	}
	if (handle)
	{
		if (!SQL_FetchRow(handle))
		{
			new String:szAuth[32];
			GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
			new String:szName[32];
			GetClientName(client, szName, 32);
			new String:szQuery[256];
			
			new String:szNameSecure[32];
			
			SQLSecure(szName, szNameSecure, sizeof(szNameSecure));
			
			SQL_FormatQuery(g_hDatabase, szQuery, sizeof(szQuery), "INSERT INTO rp_cash (AuthId, nickname, cash, bank) VALUES ('%s', '%s', '0', '%i')", szAuth, szNameSecure, START_CASH);
			
			SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, any:0, DBPrio_Normal);
			g_iClientCash[client][POCKET_CASH] = 0;
			g_iClientCash[client][BANK_CASH] = START_CASH;
		}
		else
		{
			g_iClientCash[client][POCKET_CASH] = SQL_FetchInt(handle, 0);
			g_iClientCash[client][BANK_CASH] = SQL_FetchInt(handle, 1);
		}
		
		UpdateCashInScoreBoard(client);
		g_bLoadedCash[client] = true;
		
		return;
	}
	LogError("[1] SQL query failed: %s", error);
	
}

public SQL_LoadItems(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	if (!client)
	{
		return;
	}
	if (handle)
	{
		if (SQL_GetRowCount(handle))
		{
			new String:szShortName[16];
			new item = -1;
			while (SQL_FetchRow(handle))
			{
				SQL_FetchString(handle, 0, szShortName, sizeof(szShortName));
				
				new item_count = SQL_FetchInt(handle, 1);
				item = FindStringInArray(g_aItemsShortName, szShortName);
				
				if (item != -1)
				{
					for(new i=0;i < item_count;i++)
					{
						PushArrayCell(g_aClientItems[client][g_iItemCategory[item]], item);
					}
				}
			}
		}
		
		for(new i=0;i < GetArraySize(g_aItemsShortName);i++)
		{
			new String:szAuth[32];
			GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
			new String:szItemShortName[16];
			GetArrayString(g_aItemsShortName, i, szItemShortName, sizeof(szItemShortName));
			new String:szQuery[256];
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "INSERT IGNORE INTO rp_items (AuthId, item_short_name, item_count) VALUES ('%s', '%s', 0)", szAuth, szItemShortName);
			SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, _, DBPrio_Normal);
		}
			
		g_bLoadedItems[client] = true;
		
		return;
	}
	LogError("[2] SQL query failed: %s", error);
	
}

public SQL_NoAction(Handle:owner, Handle:handle, String:szError[], any:data)
{
	if (!handle)
	{
		LogError("[Error %i] SQL query failed: %s", data, szError);
	}
	
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Cash");
	CreateNative("GetClientCash", _GetClientCash);
	CreateNative("GiveClientCash", _GiveClientCash);
	CreateNative("GiveAuthIdCash", _GiveAuthIdCash);
	CreateNative("GiveClientCashNoGangTax", _GiveClientCashNoGangTax);
	CreateNative("RP_AddCategory", _RP_AddCategory);
	CreateNative("RP_GetItemCategory", _RP_GetItemCategory);
	CreateNative("RP_SetItemCategory", _RP_SetItemCategory);
	CreateNative("RP_CreateItem", _RP_CreateItem);
	CreateNative("RP_GetItemId", _RP_GetItemId);
	CreateNative("RP_GiveItem", _RP_GiveItem);
	CreateNative("RP_GiveSeveralItems", _RP_GiveSeveralItems);
	CreateNative("RP_DeleteItem", _RP_DeleteItem);
	CreateNative("RP_CountPlayerItems", _RP_CountPlayerItems);
	CreateNative("RP_SendItem", _RP_SendItem);
	CreateNative("RP_GetCategoryByName", _RP_GetCategoryByName);
	CreateNative("RP_GetRandomItem", _RP_GetRandomItem);
	CreateNative("RP_GetRandomItemByCategory", _RP_GetRandomItemByCategory);
	CreateNative("RP_GetClientItems", _RP_GetClientItems);
	CreateNative("RP_GetClientItemsByCategory", _RP_GetClientItemsByCategory);
	CreateNative("RP_GetItemName", _RP_GetItemName);
}

public _RP_GetItemName(Handle:plugin, numParams)
{
	
	new item = GetNativeCell(1);
	new String:szBuffer[32];
	GetArrayString(g_aItemsName, item, szBuffer, 32);
	new len = GetNativeCell(3);
	SetNativeString(2, szBuffer, len, false);
	return 1;
}

public _RP_SendItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new player = GetNativeCell(2);
	ShowSendItemMenu(client, player);
	return 0;
}

public _RP_GetRandomItem(Handle:plugin, numParams)
{	
	new client = GetNativeCell(1);
	new ArrayList:items = CreateArray(1);

	for(new i=0;i < GetArraySize(g_aCategoryNames);i++)
	{
		for(new j=0;j < GetArraySize(g_aClientItems[client][i]);j++)
		{
			PushArrayCell(items, GetArrayCell(g_aClientItems[client][i], j, 0, false));
		}
	}
	if (!GetArraySize(items))
	{
		CloseHandle(items);
		items = null;
		return -1;
	}
	new item = GetArrayCell(items, GetRandomInt(0, GetArraySize(items) - 1), 0, false);
	CloseHandle(items);
	items = null;
	return item;
}

public _RP_GetRandomItemByCategory(Handle:plugin, numParams)
{
		
	new client = GetNativeCell(1);
	
	new category = GetNativeCell(2);
	
	new ArrayList:items = CreateArray(1);

	for(new i=0;i < GetArraySize(g_aClientItems[client][category]);i++)
	{
		PushArrayCell(items, GetArrayCell(g_aClientItems[client][category], i, 0, false));
	}
	
	if (!GetArraySize(items))
	{
		CloseHandle(items);
		items = null;
		return -1;
	}
	new item = GetArrayCell(items, GetRandomInt(0, GetArraySize(items) - 1), 0, false);
	CloseHandle(items);
	items = null;
	return item;
}

public any:_RP_GetClientItems(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new ArrayList:items = CreateArray(1);

	for(new i=0;i < GetArraySize(g_aCategoryNames);i++)
	{
		for(new j=0;j < GetArraySize(g_aClientItems[client][i]);j++)
		{
			PushArrayCell(items, GetArrayCell(g_aClientItems[client][i], j, 0, false));
		}
	}

	return items;
}

public any:_RP_GetClientItemsByCategory(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new category = GetNativeCell(2);
	
	new ArrayList:items = CreateArray(1);

	for(new i=0;i < GetArraySize(g_aClientItems[client][category]);i++)
	{
		PushArrayCell(items, GetArrayCell(g_aClientItems[client][category], i, 0, false));
	}

	return items;
}


public _RP_GetCategoryByName(Handle:plugin, numParams)
{
	new String:szCategoryName[64];
	GetNativeString(1, szCategoryName, 64);
	return FindStringInArray(g_aCategoryNames, szCategoryName);
}

public _RP_CountPlayerItems(Handle:plugin, numParams)
{	
	return CountPlayerItems(GetNativeCell(1), GetNativeCell(2));
}

public _RP_AddCategory(Handle:plugin, numParams)
{
	new String:szCategoryName[64];
	new iCatNum = GetArraySize(g_aCategoryNames);
	GetNativeString(1, szCategoryName, 64);
	
	new pos = FindStringInArray(g_aCategoryNames, szCategoryName);
	
	if(pos != -1)
		return pos;
		
	PushArrayString(g_aCategoryNames, szCategoryName);
	
	if(iCatNum == 9)
		SetFailState("Max category count is 9");
	return iCatNum;
}

public _RP_GetItemCategory(Handle:plugin, numParams)
{
	new item = GetNativeCell(1);
	
	return g_iItemCategory[item];
}
public _RP_SetItemCategory(Handle:plugin, numParams)
{
	new item = GetNativeCell(1);
	new category = GetNativeCell(2);
	g_iItemCategory[item] = category;
	return 0;
}

public _RP_CreateItem(Handle:plugin, numParams)
{
		
	new String:szItemName[64];
	new String:szItemShortName[16];
	GetNativeString(1, szItemName, 64);
	GetNativeString(2, szItemShortName, sizeof(szItemShortName));
	
	new pos = FindStringInArray(g_aItemsName, szItemName);
	
	if(pos != -1)
		return pos;
		
	PushArrayString(g_aItemsShortName, szItemShortName);
	PushArrayString(g_aItemsName, szItemName);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(!IsClientAuthorized(i))
			continue;
			
		new String:szAuth[32];
		GetClientAuthId(i, AuthId_Engine, szAuth, 32, true);
		new String:szQuery[256];
		SQL_FormatQuery(g_hDatabase, szQuery, 256, "INSERT IGNORE INTO rp_items (AuthId, item_short_name, item_count) VALUES ('%s', '%s', 0)", szAuth, szItemShortName);
		SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, _, DBPrio_Normal);
	}
	
	return GetArraySize(g_aItemsName) - 1;
}


public _RP_GetItemId(Handle:plugin, numParams)
{
		
	new String:szItemShortName[16];
	GetNativeString(1, szItemShortName, sizeof(szItemShortName));
	
	new pos = FindStringInArray(g_aItemsShortName, szItemShortName);
	
	return pos;
}
public _GetClientCash(Handle:plugin, numParams)
{
	return g_iClientCash[GetNativeCell(1)][GetNativeCell(2)];
}

public _GiveClientCash(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new cashType:Type = GetNativeCell(2);
	new amount = GetNativeCell(3);
	new Float:TaxPercent = GetNativeCell(4);
	
	if(Get_User_Gang(client) == -1)
	{
		GiveCash(client, Type, amount);
	}
	else
	{	
		if(amount > 0)
		{
			new amountTaxed = RoundToFloor(float(amount) * (float(Get_User_Gang_Tax(client)) / 100.0) * (TaxPercent / 100.0));
			
			amount -= amountTaxed;
					
			Add_User_GangBank(client, amountTaxed);
			Add_User_Gang_Donations(client, amountTaxed);
		}
		
		GiveCash(client, Type, amount);
	}
	return amount;
}


public _GiveAuthIdCash(Handle:plugin, numParams)
{
	new String:AuthId[35];
	
	GetNativeString(1, AuthId, sizeof(AuthId));
	
	new amount = GetNativeCell(2);
	
	return GiveCashToAuthId(AuthId, amount);
}

public _GiveClientCashNoGangTax(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new cashType:Type = GetNativeCell(2);
	new amount = GetNativeCell(3);
	
	GiveCash(client, Type, amount);
}

public _RP_DeleteItem(Handle:plugin, numParams)
{
	return DeleteClientItem(GetNativeCell(1), GetNativeCell(2));
}

public _RP_GiveItem(Handle:plugin, numParams)
{
	return GiveClientItem(GetNativeCell(1), GetNativeCell(2));
}

public _RP_GiveSeveralItems(Handle:plugin, numParams)
{
	return GiveClientItem(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

SQLSecure(String:string[], String:buffer[], bufferLen)
{
	SQL_EscapeString(g_hDatabase, string, buffer, bufferLen);
}

GiveCash(client, cashType:Type, amount)
{
	if (!g_bLoadedCash[client])
	{
		return;
	}
	
	g_iClientCash[client][Type] += amount;
	
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szQuery[256];
	
	if(Type == POCKET_CASH)
		SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_cash SET cash = cash + %i WHERE AuthId = '%s'", amount, szAuth);
		
	else
		SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_cash SET bank = bank + %i WHERE AuthId = '%s'", amount, szAuth);
		
	SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
	UpdateCashInScoreBoard(client);
	
}

GiveCashToAuthId(String:AuthId[], amount)
{
	new client = FindClientByAuthId(AuthId);
	
	if(client == 0)
	{
		new String:szQuery[256];
		

		SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_cash SET bank = bank + %i WHERE AuthId = '%s'", amount, AuthId);
			
		SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
		
		return 0;
	}
	else if (!g_bLoadedCash[client])
	{
		new String:szQuery[256];

		SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_cash SET bank = bank + %i WHERE AuthId = '%s'", amount, AuthId);
			
		SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, DBPrio_High);
		
		return 0;
	}
	
	GiveCash(client, BANK_CASH, amount);
	
	return client;
	
}

UpdateCashInScoreBoard(client)
{
	new amount = g_iClientCash[client][POCKET_CASH];
	
	if(amount > MAX_POSSIBLE_MONEY)
		amount = MAX_POSSIBLE_MONEY;
		
	SetEntProp(client, Prop_Send, "m_iAccount", amount);
	
}

stock bool:GiveClientItem(client, item, count=1)
{
	if (!g_bLoadedItems[client])
	{
		return false;
	}
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szItemShortName[16];
	GetArrayString(g_aItemsShortName, item, szItemShortName, sizeof(szItemShortName));
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_items SET item_count = GREATEST(item_count + %i, 0) WHERE AuthId = '%s' AND item_short_name = '%s'", count, szAuth, szItemShortName);
	SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, _, DBPrio_Normal);
	
	if(count < 0)
	{
		count *= -1;
		
		for (new i = 0; i < count;i++)
		{
			RemoveFromArray(g_aClientItems[client][g_iItemCategory[item]], FindValueInArray(g_aClientItems[client][g_iItemCategory[item]], item));
		}
	}
	else
	{
		for (new i = 0; i < count;i++)
		{
			PushArrayCell(g_aClientItems[client][g_iItemCategory[item]], item);
		}
	}

	
	return true;
}

stock bool:DeleteClientItem(client, item)
{
	if (!g_bLoadedItems[client])
	{
		return false;
	}
	RemoveFromArray(g_aClientItems[client][g_iItemCategory[item]], FindValueInArray(g_aClientItems[client][g_iItemCategory[item]], item));
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szItemShortName[16];
	GetArrayString(g_aItemsShortName, item, szItemShortName, sizeof(szItemShortName));
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_items SET item_count = GREATEST(item_count - 1, 0) WHERE AuthId = '%s' AND item_short_name = '%s'", szAuth, szItemShortName);
	
	SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, _, DBPrio_Normal);
	
	return true;
	
}

CountPlayerItems(client, item)
{
	new count;

	for(new i=0;i < GetArraySize(g_aClientItems[client][g_iItemCategory[item]]);i++)
	{
		if (item == GetArrayCell(g_aClientItems[client][g_iItemCategory[item]], i))
		{
			count++;
		}
	}
	return count;
}


stock FindClientByAuthId(const String:AuthId[])
{
	new String:iAuthId[35];
	for(new i = 1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsClientAuthorized(i))
			continue;
			
		GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));
		
		if(StrEqual(AuthId, iAuthId, true))
			return i;
	}
	
	return 0;
}