#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <emitsoundany>
#include <Eyal-RP>

float DEPOSIT_TAX = 0.1;
float WITHDRAW_TAX = 0.1;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "0.00",
	url = ""
};

int g_iDepositOptions[64];
int g_iWithdrawOptions[64]

new bool:TaxesDisabled;

new g_iBankNPC;

new g_iCustomWithdraw[MAXPLAYERS+1];

public OnClientDisconnect(client)
{
	g_iCustomWithdraw[client] = -1;
}

public OnClientConnected(client)
{
	g_iCustomWithdraw[client] = -1;
}


public APLRes:AskPluginLoad2()
{
	CreateNative("RP_IsClientTaxesDisabled", Native_AreTaxesDisabled);
}

public any:Native_AreTaxesDisabled(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	
	return IsClientExempt(client);
}

public OnMapStart()
{
	LoadDirOfModels("materials/models/player/kuristaja/trump");
	LoadDirOfModels("models/player/custom_player/kuristaja/trump");
	PrecacheModel("models/player/custom_player/kuristaja/trump/trump.mdl", false);
	
	for(new i=0;i < sizeof(g_iCustomWithdraw);i++)
		g_iCustomWithdraw[i] = -1;
}

public OnPluginStart()
{
	if(RP_GetEcoTrie("Bank") != INVALID_HANDLE)
		RP_OnEcoLoaded();

	//RegAdminCmd("sm_notaxes", Command_NoTaxes, ADMFLAG_ROOT, "Disables all admin-to-player taxes");
}



Handle Trie_BankEco;

public void RP_OnEcoLoaded()
{
	
	Trie_BankEco = RP_GetEcoTrie("Bank");
	
	if(Trie_BankEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Bank");
		
	new String:TempFormat[64];

	new i=0;
	while(i > -1)
	{
		char Key[64];
		
		FormatEx(Key, sizeof(Key), "DEPOSIT_BANK_AMOUNT_#%i", i);
		
		if(!GetTrieString(Trie_BankEco, Key, TempFormat, sizeof(TempFormat)))
			break;

		g_iDepositOptions[i] = StringToInt(TempFormat);
		
		i++;
	}
	
	i=0;

	while(i > -1)
	{
		char Key[64];
		
		FormatEx(Key, sizeof(Key), "WITHDRAW_BANK_AMOUNT_#%i", i);
		
		if(!GetTrieString(Trie_BankEco, Key, TempFormat, sizeof(TempFormat)))
			break;

		g_iWithdrawOptions[i] = StringToInt(TempFormat);
		
		i++;
	}
		
	char Key[64];
	
	FormatEx(Key, sizeof(Key), "DEPOSIT_BANK_TAX");

	if(GetTrieString(Trie_BankEco, Key, TempFormat, sizeof(TempFormat)))
	{
		DEPOSIT_TAX = StringToFloat(TempFormat) / 100.0;
	}

	FormatEx(Key, sizeof(Key), "WITHDRAW_BANK_TAX");

	if(GetTrieString(Trie_BankEco, Key, TempFormat, sizeof(TempFormat)))
	{
		WITHDRAW_TAX = StringToFloat(TempFormat) / 100.0;
	}

}



public Action:Command_NoTaxes(client, args)
{
	TaxesDisabled = !TaxesDisabled;
	
	if(TaxesDisabled)
	{
	//	DEPOSIT_TAX = 0.0;
		//WITHDRAW_TAX = 0.0;
		
		PrintToChatAll("Admin %N disabled all admin-to-player taxes!", client);
	}
	else
	{
		//DEPOSIT_TAX = DEFAULT_DEPOSIT_TAX;
		//WITHDRAW_TAX = DEFAULT_WITHDRAW_TAX;
		PrintToChatAll("Admin %N enabled all admin-to-player taxes!", client);
	}
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (g_iCustomWithdraw[client] == -1)
	{
		return Plugin_Continue;
	}
	new entity = g_iCustomWithdraw[client];
	
	if (CheckDistance(client, entity) > 150.0)
	{
		RP_PrintToChat(client, "You are too far away from this NPC! Operation canelled!");
	}
	else if (StrEqual(sArgs, "-1", true))
	{
		RP_PrintToChat(client, "Operation cancelled!");
	}
	else
	{
	
		new iWithdrawAmount = StringToInt(sArgs);
		
		if(iWithdrawAmount <= 0)
		{
			RP_PrintToChat(client, "Invalid Amount!")
			
			g_iCustomWithdraw[client] = -1;
			
			return Plugin_Continue;
		}
		else if(GetClientCash(client, BANK_CASH) < iWithdrawAmount)
		{
			RP_PrintToChat(client, "You don't have enough money in your bank. Operation cancelled!");
			
			g_iCustomWithdraw[client] = -1;
			
			return Plugin_Stop;
		}
		if(IsClientExempt(client) || GetClientCash(client, BANK_CASH) >= iWithdrawAmount + RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX))
		{	
			new iWithdrawAmountPostTax;
			
			GiveClientCashNoGangTax(client, POCKET_CASH, iWithdrawAmount);
			
			iWithdrawAmountPostTax = iWithdrawAmount + RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX);
			
			if(IsClientExempt(client))
				iWithdrawAmountPostTax = iWithdrawAmount;
			
			GiveClientCashNoGangTax(client, BANK_CASH, -1 * iWithdrawAmountPostTax);
			
			RP_PrintToChat(client, "You have withdrawed \x04$%i\x01 from your bank! (Tax: $%i)", iWithdrawAmount, iWithdrawAmountPostTax - iWithdrawAmount);
		}
		else
		{
			new iWithdrawAmountPostTax;
			
			iWithdrawAmount = GetClientCash(client, BANK_CASH);
			
			GiveClientCashNoGangTax(client, BANK_CASH, -1 * iWithdrawAmount);
			
			iWithdrawAmountPostTax = iWithdrawAmount - RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX);
			
			GiveClientCashNoGangTax(client, POCKET_CASH, iWithdrawAmountPostTax);
			
			RP_PrintToChat(client, "You have withdrawed \x04$%i\x01 from your bank! (Tax: $%i)", iWithdrawAmountPostTax, iWithdrawAmount - iWithdrawAmountPostTax);

		}
	}
	
	g_iCustomWithdraw[client] = -1;
	return Plugin_Stop;
}
	

ShowBankMenu(client, entity)
{
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	new Handle:menu = CreateMenu(Bank_Handler, MenuAction:28);

	RP_SetMenuTitle(menu, "Bank Menu\n \n● Pocket cash: $%i\n● Bank money: $%i\n \n● Deposit tax: %.0f%%\n● Withdraw tax: %.0f%%\n\n ", GetClientCash(client, POCKET_CASH), GetClientCash(client, BANK_CASH), IsClientExempt(client) ? 0.0 : DEPOSIT_TAX * 100.0, IsClientExempt(client) ? 0.0 : WITHDRAW_TAX * 100.0);


	AddMenuItem(menu, szEntityId, "Deposit Money", 0);
	AddMenuItem(menu, szEntityId, "Withdraw Money", 0);
	DisplayMenu(menu, client, 0);
}

public Bank_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
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
			switch(key)
			{
				case 0: ShowDepositMenu(client, entity);
				case 1: ShowWithdrawMenu(client, entity);
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
}

ShowWithdrawMenu(client, entity)
{
	new iBankCash = GetClientCash(client, BANK_CASH);
	new String:szFormat[64];
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	new Menu:menu = CreateMenu(WithdrawMenu_Handler, MenuAction:28);
	RP_SetMenuTitle(menu, "Bank Menu - Withdraw Menu\n● Pocket cash: %i\n● Bank money: %i\n ", GetClientCash(client, POCKET_CASH), iBankCash);
	FormatEx(szFormat, 64, "Custom Amount\n ");
	AddMenuItem(menu, szEntityId, szFormat, 0);

	for(new i=0;i < sizeof(g_iWithdrawOptions);i++)
	{
		if(g_iWithdrawOptions[i] == 0)
			break;

		FormatEx(szFormat, 64, "Withdraw %i cash.", g_iWithdrawOptions[i]);

		if(IsClientExempt(client))
			AddMenuItem(menu, szEntityId, szFormat, iBankCash >= g_iWithdrawOptions[i] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			
		else
			AddMenuItem(menu, szEntityId, szFormat, iBankCash >= g_iWithdrawOptions[i] + RoundToFloor(float(g_iWithdrawOptions[i]) * WITHDRAW_TAX) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	DisplayMenu(menu, client, 0);
}

public WithdrawMenu_Handler(Menu:menu, MenuAction:action, client, key)
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
			new iWithdrawAmount;
			
			if (!key)
			{
				g_iCustomWithdraw[client] = entity;
				
				RP_PrintToChat(client, "Write amount to withdraw, or -1 to cancel.");
				
				return;
			}
			else
			{
				iWithdrawAmount = g_iWithdrawOptions[key - 1];
			}
			
			if(GetClientCash(client, BANK_CASH) < iWithdrawAmount)
				return;

			if(IsClientExempt(client) || GetClientCash(client, BANK_CASH) >= iWithdrawAmount + RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX))
			{	
				new iWithdrawAmountPostTax;
				
				GiveClientCashNoGangTax(client, POCKET_CASH, iWithdrawAmount);
				
				if(iWithdrawAmount != GetClientCash(client, BANK_CASH))
					iWithdrawAmountPostTax = iWithdrawAmount + RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX);
				
				if(IsClientExempt(client))
					iWithdrawAmountPostTax = iWithdrawAmount;
					
				GiveClientCashNoGangTax(client, BANK_CASH, -1 * iWithdrawAmountPostTax);
				
				RP_PrintToChat(client, "You have withdrawed \x04$%i\x01 from your bank! (Tax: $%i)", iWithdrawAmount, iWithdrawAmountPostTax - iWithdrawAmount);
			}
			else
			{
				new iWithdrawAmountPostTax;
				
				iWithdrawAmount = GetClientCash(client, BANK_CASH);
				
				GiveClientCashNoGangTax(client, BANK_CASH, -1 * iWithdrawAmount);
				
				iWithdrawAmountPostTax = iWithdrawAmount - RoundToFloor(float(iWithdrawAmount) * WITHDRAW_TAX);
				
				GiveClientCashNoGangTax(client, POCKET_CASH, iWithdrawAmountPostTax);
				
				RP_PrintToChat(client, "You have withdrawed \x04$%i\x01 from your bank! (Tax: $%i)", iWithdrawAmountPostTax, iWithdrawAmount - iWithdrawAmountPostTax);
			}
		}
	}
}

ShowDepositMenu(client, entity)
{
	new iPocketCash = GetClientCash(client, POCKET_CASH);
	new String:szFormat[64];
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	new Menu:menu = CreateMenu(DepositMenu_Handler, MenuAction:28);
	RP_SetMenuTitle(menu, "Bank Menu - Deposit Menu\n● Pocket cash: $%i\n● Bank money: $%i\n ", iPocketCash, GetClientCash(client, BANK_CASH));
	FormatEx(szFormat, 64, "Deposit %i cash.\n ", iPocketCash);
	AddMenuItem(menu, szEntityId, szFormat, 0);
	
	for(new i=0;i < sizeof(g_iDepositOptions);i++)
	{
		if(g_iDepositOptions[i] == 0)
			break;

		FormatEx(szFormat, 64, "Deposit %i cash.", g_iDepositOptions[i]);
	
		AddMenuItem(menu, szEntityId, szFormat, iPocketCash >= g_iDepositOptions[i] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	DisplayMenu(menu, client, 0);
}

public DepositMenu_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
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
			new iDepositAmount;
			if (!key)
			{
				iDepositAmount = GetClientCash(client, POCKET_CASH);
			}
			else
			{
				iDepositAmount = g_iDepositOptions[key - 1];
			}
			if (GetClientCash(client, POCKET_CASH) >= iDepositAmount)
			{
				RP_PrintToChat(client, "You have deposited \x04%i\x01 cash in your bank!", iDepositAmount);
				GiveClientCashNoGangTax(client, POCKET_CASH, -1 * iDepositAmount);
				
				if(!IsClientExempt(client))
					iDepositAmount -= RoundToFloor(float(iDepositAmount) * DEPOSIT_TAX);
				
				GiveClientCashNoGangTax(client, BANK_CASH, iDepositAmount);
			}
			else
			{
				RP_PrintToChat(client, "You dont have enough money to deposit!");
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
}

public OnUseNPC(client, id, entity)
{
	if (g_iBankNPC == id)
	{
		ShowBankMenu(client, entity);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_NPC", true))
	{
		g_iBankNPC = RP_CreateNPC("models/player/custom_player/kuristaja/trump/trump.mdl", "BANK");
	}
}

stock IsClientExempt(client)
{
	return TaxesDisabled && CheckCommandAccess(client, "sm_cma_root", ADMFLAG_ROOT, true);
}
