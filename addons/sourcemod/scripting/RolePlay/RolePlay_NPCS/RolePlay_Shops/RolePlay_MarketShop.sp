#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

#define ROB_COOLDOWN 1500.0

enum struct enItemInfo
{
    char ItemName[32];
    char ItemShortName[16];
    int ItemHP;
    int ItemPrice;
}

enItemInfo g_ShopItems[128];

new MAX_FOOD = 250;

new Float:FOOD_SELL_MULTIPLIER = 0.6

new FOOD_STORE_ROB_TIME = 60;
new FOOD_STORE_ROB_KARMA = 1290;
new FOOD_STORE_MAX_KARMA = 1399;

// Amount of items robbed from the weapon store.
new g_iThief_RobItems[11];

new g_iThief_MinRobReward[11];

new g_iThief_MaxRobReward[11];

new Float:NextFood[MAXPLAYERS+1];

new g_iLastNPC[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "RolePlay - Market Shop",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};
new ArrayList:Array_ItemIds;
new g_iShopNPC;
new g_iFillHP[66];

new g_iThiefJob = -1;
new Float:g_fNPCNextRob[4096];
new Float:g_fNextBountyMessage[MAXPLAYERS+1]
new bool:g_bNPCBeingRobbed[4096];

new Handle:hTimer_RobShop[MAXPLAYERS+1];

new Handle:Trie_MarketShopEco;

public RP_OnEcoLoaded()
{
	
	Trie_MarketShopEco = RP_GetEcoTrie("Market Shop");
	
	if(Trie_MarketShopEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Market Shop");
		
	new String:TempFormat[64];

	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "ITEM_NAME_#%i", i);
		
		new String:ItemName[32], String:ItemShortName[8], ItemPrice, ItemHP
		
		if(!GetTrieString(Trie_MarketShopEco, Key, ItemName, sizeof(ItemName)))
			break;
		
		FormatEx(Key, sizeof(Key), "ITEM_SHORTNAME_#%i", i);
		GetTrieString(Trie_MarketShopEco, Key, ItemShortName, sizeof(ItemShortName));
		
		FormatEx(Key, sizeof(Key), "ITEM_PRICE_#%i", i);
		GetTrieString(Trie_MarketShopEco, Key, TempFormat, sizeof(TempFormat));
		
		ItemPrice = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "ITEM_HP_#%i", i);
		GetTrieString(Trie_MarketShopEco, Key, TempFormat, sizeof(TempFormat));
		
		ItemHP = StringToInt(TempFormat);		
		
		g_ShopItems[i].ItemName = ItemName;
		g_ShopItems[i].ItemShortName = ItemShortName;
		g_ShopItems[i].ItemPrice = ItemPrice;
		g_ShopItems[i].ItemHP = ItemHP;
		
		i++;
	}
	
	i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_ITEMS_LVL_#%i", i);
		
		if(!GetTrieString(Trie_MarketShopEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iThief_RobItems[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_MIN_ROB_REWARD_LVL_#%i", i);
		
		GetTrieString(Trie_MarketShopEco, Key, TempFormat, sizeof(TempFormat));
			
		g_iThief_MinRobReward[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_MAX_ROB_REWARD_LVL_#%i", i);
		
		GetTrieString(Trie_MarketShopEco, Key, TempFormat, sizeof(TempFormat));
			
		g_iThief_MaxRobReward[i] = StringToInt(TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_MarketShopEco, "MAX_FOOD", TempFormat, sizeof(TempFormat));
	
	MAX_FOOD = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MarketShopEco, "FOOD_SELL_MULTIPLIER", TempFormat, sizeof(TempFormat));
	
	FOOD_SELL_MULTIPLIER = StringToFloat(TempFormat);

	GetTrieString(Trie_MarketShopEco, "MAX_FOOD", TempFormat, sizeof(TempFormat));
	
	MAX_FOOD = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MarketShopEco, "FOOD_STORE_ROB_TIME", TempFormat, sizeof(TempFormat));
	
	FOOD_STORE_ROB_TIME = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MarketShopEco, "FOOD_STORE_ROB_KARMA", TempFormat, sizeof(TempFormat));
	
	FOOD_STORE_ROB_KARMA = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MarketShopEco, "FOOD_STORE_MAX_KARMA", TempFormat, sizeof(TempFormat));
	
	FOOD_STORE_MAX_KARMA = StringToInt(TempFormat);	

	new cat = RP_AddCategory("Food");
		
	for(i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].ItemName[0] == EOS)
			break;
			
		new item = RP_CreateItem(g_ShopItems[i].ItemName, g_ShopItems[i].ItemShortName);
		RP_SetItemCategory(item, cat);
		PushArrayCell(Array_ItemIds, item);
	}
}

public OnPluginStart()
{
	Array_ItemIds = CreateArray(1);
	
	if(RP_GetEcoTrie("Market Shop") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public OnClientConnected(client)
{
	g_iFillHP[client] = 0;
}

public OnClientDisconnect(client)
{
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		TriggerTimer(hTimer_RobShop[client], true);
		
		hTimer_RobShop[client] = INVALID_HANDLE;
	}
	
	g_fNextBountyMessage[client] = 0.0;
}
public OnClientPutInServer(client)
{
	g_fNextBountyMessage[client] = 0.0;
}
public OnMapStart()
{
	for(new i=0;i < sizeof(g_fNextBountyMessage);i++)
		g_fNextBountyMessage[i] = 0.0;
		
	for(new i=0;i < sizeof(g_fNPCNextRob);i++)
		g_fNPCNextRob[i] = 0.0;
		
	for(new i=0;i < sizeof(g_bNPCBeingRobbed);i++)
		g_bNPCBeingRobbed[i] = false;

	for(new i=0;i < sizeof(hTimer_RobShop);i++)
		hTimer_RobShop[i] = INVALID_HANDLE;
		
	LoadDirOfModels("materials/models/player/kuristaja/l4d2/rochelle");
	LoadDirOfModels("materials/models/player/kuristaja/l4d2/shared");
	LoadDirOfModels("models/player/custom_player/kuristaja/l4d2/rochelle");
	PrecacheModel("models/player/custom_player/kuristaja/l4d2/rochelle/rochellev2.mdl", false);
}

public OnUseNPC(client, id, entity)
{
	if(g_iThiefJob == -1)
		g_iThiefJob = RP_FindJobByShortName("TH");
		
	if (g_iShopNPC == id)
	{
		ShowShopMenu(client, entity);
	}
}

ShowShopMenu(client, entity)
{
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	
	new Handle:menu = CreateMenu(MenuHandler_ShopCategoriesMenu);
	RP_SetMenuTitle(menu, "Market Shop Menu\n● Bank cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	AddMenuItem(menu, szEntityId, "Buy Items");
	
	new level = RP_GetClientLevel(client, g_iThiefJob);
	
	if(GetPlayerCount() >= 5)
	{
		if(RP_GetClientJob(client) == g_iThiefJob)
		{
			new count = g_iThief_RobItems[level];
			new minLevel = MAX_INTEGER;
			
			if(count == 0)
			{
				for(new i=level+1;i < sizeof(g_iThief_RobItems);i++)
				{
					count = g_iThief_RobItems[i];
					
					if(count > 0)
					{
						minLevel = i;
						break;
					}
				}
				
				new String:TempFormat[64];
				FormatEx(TempFormat, sizeof(TempFormat), "ROB THE STORE [ Level %i ]", minLevel);
				
				AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
			}
			else
			{
				if(g_fNPCNextRob[entity] <= GetGameTime())
					AddMenuItem(menu, szEntityId, "ROB THE STORE");
					
				else
				{
					new String:TempFormat[64];
					FormatEx(TempFormat, sizeof(TempFormat), "ROB THE STORE [%.1fm]", (g_fNPCNextRob[entity] - GetGameTime()) / 60.0);
					
					AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
				}
			}
		}
		else
			AddMenuItem(menu, szEntityId, "ROB THE STORE [Thief]", ITEMDRAW_DISABLED);
	}
	else
		AddMenuItem(menu, szEntityId, "ROB THE STORE [Min. 5 Players]", ITEMDRAW_DISABLED);
		
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_ShopCategoriesMenu(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			if(key == 1)
			{
				if(RP_GetClientJob(client) == g_iThiefJob)
				{
					if(g_bNPCBeingRobbed[entity])
						RP_PrintToChat(client, "Someone else is robbing this shop. Shoot him to replace him");
						
					else
						RobFoodShop(client, entity);
				}
			}
			else
				ShowItemList(client, entity);
		}
	}
}


RobFoodShop(client, entity)
{
	new totalKarma = RP_GetKarma(client) + FOOD_STORE_ROB_KARMA;
	
	if(totalKarma > FOOD_STORE_MAX_KARMA)
		totalKarma = FOOD_STORE_MAX_KARMA;
	
	if(totalKarma > RP_GetKarma(client))
		RP_SetKarma(client, totalKarma, true);
		
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		RP_PrintToChat(client, "You are already robbing a store");
		return;
	}
	
	g_bNPCBeingRobbed[entity] = true;
	
	
	new Handle:DP;
	hTimer_RobShop[client] = CreateDataTimer(1.0, Timer_RobFoodStore, DP, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(DP, GetClientUserId(client));
	WritePackCell(DP, entity);
	WritePackCell(DP, FOOD_STORE_ROB_TIME);
}

public Action:Timer_RobFoodStore(Handle:hTimer, Handle:DP)
{
	ResetPack(DP);
	
	new client = GetClientOfUserId(ReadPackCell(DP));
	new entity = ReadPackCell(DP);
	new TimeLeft = ReadPackCell(DP);
	
	TimeLeft--;
	
	if(client == 0)
	{
		g_bNPCBeingRobbed[entity] = false;
		return;
	}
	hTimer_RobShop[client] = INVALID_HANDLE;
	
	if (CheckDistance(client, entity) > 512.0)
	{
		RP_PrintToChat(client, "You are too far away from this NPC!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(!IsPlayerAlive(client))
	{
		RP_PrintToChat(client, "Store robbery stopped because you died!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(g_fNPCNextRob[entity] > GetGameTime())
	{
		RP_PrintToChat(client, "Store robbery stopped someone else robbed it!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(TimeLeft > 0)
	{
		new Handle:MimicDP;
		hTimer_RobShop[client] = CreateDataTimer(1.0, Timer_RobFoodStore, MimicDP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(MimicDP, GetClientUserId(client));
		WritePackCell(MimicDP, entity);
		WritePackCell(MimicDP, TimeLeft);
		
		PrintHintText(client, "You are HPC!!!\nRobbing Food Store! Will complete in %i seconds.\nDo not go away from the NPC or it will fail!", TimeLeft);
		
		return;
	}
	
	new level = RP_GetClientLevel(client, g_iThiefJob);
	
	new award = GetRandomInt(g_iThief_MinRobReward[level], g_iThief_MaxRobReward[level]);
	
	award = GiveClientCash(client, POCKET_CASH, award);
	
	RP_PrintToChat(client, "You have successfully robbed the store! Robbed $%i!", award);
	
	Handle GoodList = CreateArray(1);
	
	new trueSize;
	
	for(new i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].ItemName[0] == EOS)
		{
			trueSize = i - 1;
			break;
		}
	}
	for(new i=0;i < g_iThief_RobItems[level];i++)
	{
		PushArrayCell(GoodList, GetRandomInt(0, trueSize-1));
	}
	
	new String:FormatGoods[512];
	
	FormatEx(FormatGoods, sizeof(FormatGoods), "Robbery successful! Looted items:\n");
	
	new Handle:GoodListCopy = CloneArray(GoodList);
	
	new bool:nLine = false;
	
	for(new i=0;i < GetArraySize(GoodListCopy);i++)
	{
		new key = GetArrayCell(GoodListCopy, i);
		
		new count = 0;
		
		for(new a=0;a < GetArraySize(GoodListCopy);a++)
		{
			if(GetArrayCell(GoodListCopy, a) == key)
			{
				RemoveFromArray(GoodListCopy, a);
				a--;
				count++;
			}
		}
		
		Format(FormatGoods, sizeof(FormatGoods), "%s%ix %s%s", FormatGoods, count, g_ShopItems[key].ItemName, nLine ? "\n" : ", ");
		
		nLine = !nLine;
		
		i--;
	}
	
	for(new i=0;i < GetArraySize(GoodList);i++)
	{
		RP_GiveItem(client, GetArrayCell(Array_ItemIds, GetArrayCell(GoodList, i)));
	}
	
	PrintHintText(client, FormatGoods);
	
	RP_AddClientEXP(client, g_iThiefJob, 10);

	g_fNPCNextRob[entity] = GetGameTime() + ROB_COOLDOWN;
	
	g_fNextBountyMessage[client] = GetGameTime() + 7.5;
	
	CloseHandle(GoodList);
	CloseHandle(GoodListCopy);
	
	g_bNPCBeingRobbed[entity] = false;
}

public Action:RolePlay_ShouldSeeBountyMessage(client)
{
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		//PrintToConsoleEyal("%N failed see bounty for robbing market", client);
		return Plugin_Handled;
	}	
	else if(g_fNextBountyMessage[client] > GetGameTime())
	{
		//PrintToConsoleEyal("%N failed see bounty for next bounty market", client);
		return Plugin_Handled;
	}
		
	return Plugin_Continue;
}


ShowItemList(client, entity)
{
	new String:szMenuItem[64];
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	new Menu:menu = CreateMenu(MenuHandler_ItemListMenu, MenuAction:28);
	
	RP_SetMenuTitle(menu, "Market Shop Menu\n● Bank cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	for(new i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].ItemName[0] == EOS)
			break;
			
		FormatEx(szMenuItem, 64, g_ShopItems[i].ItemName);
		
		AddMenuItem(menu, szEntityId, szMenuItem, 0);
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ItemListMenu(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			ShowFoodItemInfo(client, key, entity);
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

ShowFoodItemInfo(client, key, entity)
{
	g_iLastNPC[client] = entity;
	
	new String:szMenuItem[64];
	new String:Info[11];
	new String:szEntityId[8];
	
	IntToString(entity, szEntityId, 5);
	IntToString(key, Info, sizeof(Info));
	
	new Handle:menu = CreateMenu(MenuHandler_FoodInfoMenu);
	RP_SetMenuTitle(menu, "Market Shop Menu\n● Bank cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	new item = GetArrayCell(Array_ItemIds, key);
	
	FormatEx(szMenuItem, sizeof(szMenuItem), "Buy for $%i", g_ShopItems[key].ItemPrice);
	AddMenuItem(menu, szEntityId, szMenuItem, g_ShopItems[key].ItemPrice > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	FormatEx(szMenuItem, sizeof(szMenuItem), "Sell for $%i [Σ%i]", RoundToFloor(float(g_ShopItems[key].ItemPrice) * FOOD_SELL_MULTIPLIER), RP_CountPlayerItems(client, item));
	AddMenuItem(menu, Info, szMenuItem, RP_CountPlayerItems(client, item) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	FormatEx(szMenuItem, sizeof(szMenuItem), "Buy 10 for $%i", g_ShopItems[key].ItemPrice * 10);
	AddMenuItem(menu, szEntityId, szMenuItem, g_ShopItems[key].ItemPrice * 10 > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	FormatEx(szMenuItem, sizeof(szMenuItem), "Sell 10 for $%i [Σ%i]", RoundToFloor(float(g_ShopItems[key].ItemPrice) * 10.0 * FOOD_SELL_MULTIPLIER), RP_CountPlayerItems(client, item));
	AddMenuItem(menu, Info, szMenuItem, RP_CountPlayerItems(client, item) > 9 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_FoodInfoMenu(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}

	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowShopMenu(client, g_iLastNPC[client]);
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8], String:szKey[11];
		GetMenuItem(menu, 0, szEntityId, 5);
		GetMenuItem(menu, 1, szKey, sizeof(szKey));
		
		new entity = StringToInt(szEntityId);
		new key = StringToInt(szKey);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
			
			return;
		}
		
		switch(item)
		{
			case 0:
			{
				if (GetClientCash(client, BANK_CASH) < g_ShopItems[key].ItemPrice)
				{
					RP_PrintToChat(client, "You are missing \x02%i\x01 bank cash to buy the \x04%s!", g_ShopItems[key].ItemPrice - GetClientCash(client, BANK_CASH), g_ShopItems[key].ItemName);
					
					return;
				}
				
				else if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) >= MAX_FOOD)
				{
					RP_PrintToChat(client, "Maximum amount of a food you can hold is %i!", MAX_FOOD);
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully bought \x02%s\x01 for \x04$%i!", g_ShopItems[key].ItemName, g_ShopItems[key].ItemPrice);
				GiveClientCash(client, BANK_CASH, -1 * g_ShopItems[key].ItemPrice);
				
				RP_GiveItem(client, GetArrayCell(Array_ItemIds, key));
				
				ShowFoodItemInfo(client, key, entity);
			}
			
			case 1:
			{
				if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) <= 0)
				{
					RP_PrintToChat(client, "You don't have this food in your inventory!");
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully sold \x02%s\x01 for \x04$%i!", g_ShopItems[key].ItemName, RoundToFloor(float(g_ShopItems[key].ItemPrice) * FOOD_SELL_MULTIPLIER));
				GiveClientCashNoGangTax(client, BANK_CASH, RoundToFloor(float(g_ShopItems[key].ItemPrice) * FOOD_SELL_MULTIPLIER));
				
				RP_DeleteItem(client, GetArrayCell(Array_ItemIds, key));

				ShowFoodItemInfo(client, key, entity);
			}
			
			case 2:
			{
				if (GetClientCash(client, BANK_CASH) < g_ShopItems[key].ItemPrice * 10)
				{
					RP_PrintToChat(client, "You are missing \x02%i\x01 bank cash to buy the \x04%s!", g_ShopItems[key].ItemPrice - GetClientCash(client, BANK_CASH), g_ShopItems[key].ItemName);
					
					return;
				}
				
				else if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) + 9 >= MAX_FOOD)
				{
					RP_PrintToChat(client, "Maximum amount of a food you can hold is %i!", MAX_FOOD);
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully bought 10 \x02%s\x01 for \x04$%i!", g_ShopItems[key].ItemName, g_ShopItems[key].ItemPrice * 10);
				GiveClientCash(client, BANK_CASH, -1 * g_ShopItems[key].ItemPrice * 10);
				
				RP_GiveSeveralItems(client, GetArrayCell(Array_ItemIds, key), 10);
				
				ShowFoodItemInfo(client, key, entity);
			}
			case 3:
			{
				if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) <= 9)
				{
					RP_PrintToChat(client, "You don't have 10 of this food in your inventory!");
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully sold 10 \x02%s\x01 for \x04$%i!", g_ShopItems[key].ItemName, RoundToFloor(float(g_ShopItems[key].ItemPrice * 10) * FOOD_SELL_MULTIPLIER));
				GiveClientCashNoGangTax(client, BANK_CASH, RoundToFloor(float(g_ShopItems[key].ItemPrice) * 10.0 * FOOD_SELL_MULTIPLIER));
				
				RP_GiveSeveralItems(client, GetArrayCell(Array_ItemIds, key), -10);
				
				ShowFoodItemInfo(client, key, entity);
			}
		}
	}
}

public Action:OnItemUsed(client, item)
{
	new pos = FindValueInArray(Array_ItemIds, item, 0)
	if (pos != -1)
	{
		new TotalHP = GetClientHealth(client) + g_ShopItems[pos].ItemHP;
		
		if(TotalHP >= GetEntityMaxHealth(client))
		{
			RP_PrintToChat(client, "You are not hungry.");
			return Plugin_Handled;
		}
		if(NextFood[client] > GetGameTime())
		{
			RP_PrintToChat(client, "One food at a time! you will choke");
			return Plugin_Handled;
		}

		RP_PrintToChat(client, "Yum yum yum...");
		
		SetEntityHealth(client, TotalHP);
		NextFood[client] = GetGameTime() + 5.0;
	}
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_NPC", true))
	{
		g_iShopNPC = RP_CreateNPC("models/player/custom_player/kuristaja/l4d2/rochelle/rochellev2.mdl", "MARKET_SHOP");
	}
}

 