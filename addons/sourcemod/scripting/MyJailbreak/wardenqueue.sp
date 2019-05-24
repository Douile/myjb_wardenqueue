/*
 * MyJailbreak - Warden Queue Plugin.
 * by: Douile
 * https://github.com/douile/
 *
 * https://github.com/shanapu/MyJailbreak/
 *
 * This file is part of the MyJailbreak SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* TODO
[x] Add commands
[x] Add convars
[ ] --> Add text (localisation)
[x] Add enable/disable
[ ] List/Admin control
[~] Override sm_warden, sm_unwarden, (?sm_vetowarden)
[ ] Add VIP queue skip
[ ] Chat commands
*/

/* Includes */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>
#include <warden>
#include <mystocks>
#include <myjailbreak>

/* Compiler options */
#pragma semicolon 1
#pragma newdecls required


/* ConVars */
ConVar gc_bPlugin;
ConVar gc_bRemoveTemp;
ConVar gc_bEmptyRandomWarden;

/* Handles */
Handle g_aWardenQueue;

/* Integers */
int g_iNextWarden;

/* Plugin info */
#define PLUGIN_VERSION "0.2"

public Plugin myinfo = {
  name = "MyJailbreak - Warden Queue",
  author = "Douile",
  version = PLUGIN_VERSION
};

/* Start */
public void OnPluginStart() {

  LoadTranslations("MyJailbreak.WardenQueue.phrases");

  /* Client Commands */
  RegConsoleCmd("sm_warden", Command_JoinWardenQueue, "Join the warden queue");
  RegConsoleCmd("sm_unwarden", Command_LeaveWardenQueue, "Step down as warden and leave the warden queue");
  AddCommandListener(CommandListener_JoinWardenQueue,"sm_warden");
  AddCommandListener(CommandListener_LeaveWardenQueue,"sm_unwarden");

  /* AutoExecConfig */
  AutoExecConfig_SetFile("Warden_Queue", "MyJailbreak");
  AutoExecConfig_SetCreateFile(true);

  /* ConVars */
  AutoExecConfig_CreateConVar("sm_wardenqueue_version", PLUGIN_VERSION, "The version of this plugin", FCVAR_SPONLY|FCVAR_REPLICATED,FCVAR_NOTIFY|FCVAR_DONTRECORD);
  gc_bPlugin = AutoExecConfig_CreateConVar("sm_wardenqueue_enable","1","0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
  gc_bRemoveTemp = AutoExecConfig_CreateConVar("sm_wardenqueue_removetemporary","1","0/1 - remove wardens set after a warden death from the queue", _, true, 0.0, true, 1.0);
  gc_bEmptyRandomWarden = AutoExecConfig_CreateConVar("sm_wardenqueue_emptyrandom","0","0/1 - choose a random warden if the queue is empty at the start of the round", _, true, 0.0, true, 1.0);

  /* AutoExecConfig finalize */
  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();

  /* Hooks */
  HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_Post);
  HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);

  /* Arrays */
  g_aWardenQueue = CreateArray();
}


/* Commands */

public Action Command_LeaveWardenQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  warden_remove(client); /* This checks whether client is warden and removes if he is */

  RemovePlayerFromWardenQueue(client);

  return Plugin_Handled;
}

public Action Command_JoinWardenQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  if (GetClientTeam(client) != CS_TEAM_CT) {
    /* Must be CT to join warden queue */
    if (!warden_exist()) {
      /* No current warden so skip queue */
      warden_set(client, client);
    } else {
      /* Check VIP */
      AddPlayerToWardenQueue(client);
    }
  }

  return Plugin_Handled;
}

/* Events */

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool bDontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  /* Check CT */
  if (GetClientTeam(client) != 3) return Plugin_Continue;

  /* Check valid client */
  if (!IsValidClient(client, true, false)) return Plugin_Continue;

  /*
  Check if client is next in queue / set as warden...
  */
  if (client == g_iNextWarden || ShouldChooseRandomWarden()) {
    /* This client should be the warden */

    if (!warden_exist()) warden_set(client, client);
    g_iNextWarden = -1;
  }

  return Plugin_Continue;
}

public Action Event_PlayerTeam_Post(Event event, const char[] szName, bool bDontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  /* If player switches from CT remove them from warden queue */
  if (event.GetInt("team") != CS_TEAM_CT) {
    RemovePlayerFromWardenQueue(client);
  }
}

public Action Event_RoundEnd_Post(Event event, const char[] szName, bool bDontBroadcast) {
  g_iNextWarden = -1;
  if (GetArraySize(g_aWardenQueue)) {
    g_iNextWarden = GetArrayCell(g_aWardenQueue, 0);
    RemovePlayerFromWardenQueue(g_iNextWarden);

    /* Print to chat (warden plugin already does) */
  } else {
    /* No wardens in queue, random ct will be chosen */
    g_iNextWarden = -2;
  }
}

/* Functions */

public void AddPlayerToWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);

  if (iIndex == -1) {
    iIndex = PushArrayCell(g_aWardenQueue, client);
  }
}

public bool IsPlayerInWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);

  return iIndex != -1;
}

bool ShouldChooseRandomWarden() {
  return gc_bEmptyRandomWarden && g_iNextWarden == -2;
}

/* Forwards */

public void OnClientDisconnect_Post(int client) {
  RemovePlayerFromWardenQueue(client);
}

public void warden_OnWardenRemoved(int client) {
  /* Set new warden for the round */
}

}

/* Stocks */

stock bool RemovePlayerFromWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);
  if (iIndex == -1) return;
  RemoveFromArray(g_aWardenQueue, iIndex);
}
