#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <time>
#include <nvault>

new const PLUGIN[] = 	"Hats"
new const AUTHOR[] = 	"Psycrow"
new const VERSION[] = 	"1.6"

new const HATS_PATH[] =	"models/next21_hats"
#define MAX_HATS 		64
#define VIP_FLAG 		ADMIN_LEVEL_H
#define VAULT_DAYS 		30

new const ITEM_POSTFIX_FORMAT[] = " \y[\r%L\y]"
#define NAME_LEN 		64

#define MAXSTUDIOBODYPARTS	32

enum _:PLAYER_DATA
{
    PLR_HAT_ENT,
    PLR_HAT_ID,
    PLR_MENU_HATID
}

enum _:HAT_DATA
{
    HAT_MODEL[NAME_LEN],
    HAT_NAME[NAME_LEN],
    HAT_SKINS_NUM,
    HAT_BODIES_NUM,
    HAT_BODIES_NAMES[MAXSTUDIOBODYPARTS * NAME_LEN],
    HAT_TAG,
    HAT_VIP_FLAG
}

new g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA], g_eHatData[MAX_HATS][HAT_DATA],
    g_iTotalHats, g_fwChangeHat, g_iVaultHats


public plugin_precache()
{
    new szCfgDir[32], szHatFile[64]
    get_configsdir(szCfgDir, charsmax(szCfgDir))
    formatex(szHatFile, charsmax(szHatFile), "%s/hats.ini", szCfgDir)
    load_hats(szHatFile)
    
    for (new i = 1, szCurrentFile[256]; i < g_iTotalHats; i++)
    {
        formatex(szCurrentFile, charsmax(szCurrentFile), "%s/%s", HATS_PATH, g_eHatData[i][HAT_MODEL])
        precache_model(szCurrentFile)
        server_print("[%s] Precached %s", PLUGIN, szCurrentFile)
    }
}

public plugin_cfg()
{
    g_iVaultHats = nvault_open("next21_hat")
            
    if (g_iVaultHats == INVALID_HANDLE)
        set_fail_state("Error opening nVault!")
        
    nvault_prune(g_iVaultHats, 0, get_systime() - (SECONDS_IN_DAY * VAULT_DAYS))
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
        
    register_concmd("amx_givehat", "concmd_give_hat", ADMIN_RCON, "<nick> <hat #> <part #>")
    register_concmd("amx_removehats", "concmd_remove_all_hats", ADMIN_RCON, " - Removes hats from everyone")
        
    register_clcmd("say /hats", "clcmd_show_menu", .info="Shows hats menu")
    register_clcmd("say_team /hats", "clcmd_show_menu", .info="Shows hats menu")
    register_clcmd("hats", "clcmd_show_menu", .info="Shows hats menu")

    register_dictionary("next21_hats.txt")
    
    g_fwChangeHat = CreateMultiForward("n21_change_hat", ET_STOP, FP_CELL, FP_CELL)
}

public plugin_end()
{
    nvault_close(g_iVaultHats)
    DestroyForward(g_fwChangeHat)
}

public client_putinserver(iPlayer)
{
    remove_hat(iPlayer)

    static szKey[24], szValue[128]
    get_user_authid(iPlayer, szKey, charsmax(szKey))
    nvault_get(g_iVaultHats, szKey, szValue, charsmax(szValue))

    new iHatId, iPartId
    if (!szValue[0])
        goto set_hat_and_return

    static szHatModel[120], szHatPart[5]
    split(szValue, szHatModel, charsmax(szHatModel), szHatPart, charsmax(szHatPart), "|")

    if (equal(szHatModel, "!NULL"))
        goto set_hat_and_return
    
    for (new i = 1; i < g_iTotalHats; i++)
    {
        if (!equal(szHatModel, g_eHatData[i][HAT_MODEL]))
            continue

        if (check_hat_access(iPlayer, i))
        {
            iHatId = i
            iPartId = str_to_num(szHatPart)
        }
        goto set_hat_and_return
    }

    set_hat_and_return:
    set_hat(iPlayer, iHatId, iPlayer, iPartId)
}

public client_disconnected(iPlayer)
{
    remove_hat(iPlayer)
}

public CBasePlayer_Spawn_Post(const iPlayer)
{
    if (!g_ePlayerData[iPlayer][PLR_HAT_ID] || !is_user_alive(iPlayer))
        return HC_CONTINUE

    new iHatId = g_ePlayerData[iPlayer][PLR_HAT_ID]
    if (g_eHatData[iHatId][HAT_TAG] != 't')
        return HC_CONTINUE

    new iHatEnt = g_ePlayerData[iPlayer][PLR_HAT_ENT],
        iPartId = get_member(iPlayer, m_iTeam) == 2

    if (g_eHatData[iHatId][HAT_BODIES_NUM] > 1)
        set_entvar(iHatEnt, var_body, iPartId)
    
    if (g_eHatData[iHatId][HAT_SKINS_NUM] > 1)
        set_entvar(iHatEnt, var_skin, iPartId)
        
    return HC_CONTINUE
}

public clcmd_show_menu(iPlayer)
{
    display_hats_menu(iPlayer)
    return PLUGIN_HANDLED
}

public concmd_give_hat(iPlayer, iLevel, cid)
{
    if (!cmd_access(iPlayer, iLevel, cid, 1))
        return PLUGIN_CONTINUE

    new szPlayerName[32], szHatId[4], szPartId[5]
    read_argv(1, szPlayerName, charsmax(szPlayerName))
    read_argv(2, szHatId, charsmax(szHatId))
    read_argv(3, szPartId, charsmax(szPartId))
    
    new iTarget = find_player_ex(FindPlayer_MatchName, szPlayerName)
    if (!iTarget)
    {
        client_print(iPlayer, print_console, "[%s] %L", PLUGIN, iPlayer, "HAT_NICK_NOT_FOUND")
        return PLUGIN_HANDLED
    }
    
    new iHatId = str_to_num(szHatId)
    if (iHatId >= g_iTotalHats)
        return PLUGIN_HANDLED
            
    set_hat(iTarget, iHatId, iPlayer, str_to_num(szPartId))
    return PLUGIN_HANDLED
}

public concmd_remove_all_hats(iPlayer, iLevel, cid)
{
    if (!cmd_access(iPlayer, iLevel, cid, 1))
        return PLUGIN_CONTINUE

    new iMaxPlayers = get_maxplayers()
    for (new i = 1; i <= iMaxPlayers; i++)
        if (is_user_connected(i))
            remove_hat(i)
    
    client_print(iPlayer, print_console, "[%s] %L", PLUGIN, iPlayer, "HAT_ALL_REMOVED")
    return PLUGIN_HANDLED
}

display_hats_menu(iPlayer, iPage=0)
{
    static szItemName[128]
    new iMenu = menu_create("Hat Menu", "handler_hats_menu")

    menu_additem(iMenu, fmt("\r%L", iPlayer, "HAT_ITEM_REMOVE"))
    for (new iHatId = 1; iHatId < g_iTotalHats; iHatId++)
    {
        szItemName[0] = 0
        if (g_eHatData[iHatId][HAT_VIP_FLAG])
            add(szItemName, charsmax(szItemName), "\r[VIP] \w")
        add(szItemName, charsmax(szItemName), g_eHatData[iHatId][HAT_NAME])

        switch (g_eHatData[iHatId][HAT_TAG])
        {
            case 's': add(szItemName, charsmax(szItemName),
                fmt(ITEM_POSTFIX_FORMAT, iPlayer, "HAT_POSTFIX_SKIN"))
            case 'b', 'c': add(szItemName, charsmax(szItemName),
                fmt(ITEM_POSTFIX_FORMAT, iPlayer, "HAT_POSTFIX_MODEL"))
            case 't': add(szItemName, charsmax(szItemName),
                fmt(ITEM_POSTFIX_FORMAT, iPlayer,
                g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? "HAT_POSTFIX_TEAM_MODEL" : "HAT_POSTFIX_TEAM_COLOR"))
        }

        menu_additem(iMenu, szItemName)
    }
    set_menu_common_prop(iMenu, iPlayer)
    
    menu_display(iPlayer, iMenu, iPage)
}

display_skins_menu(iPlayer)
{
    new iHatId = g_ePlayerData[iPlayer][PLR_MENU_HATID]
    new iMenu = menu_create(fmt("Hat Skin (\r%s\y)", g_eHatData[iHatId][HAT_NAME]), "handler_hatparts_menu")
    new iSkinsNum = g_eHatData[iHatId][HAT_SKINS_NUM]

    for (new i = 1; i <= iSkinsNum; i++)
        menu_additem(iMenu, fmt("Skin %i", i))
    set_menu_common_prop(iMenu, iPlayer)
    
    menu_display(iPlayer, iMenu)
}

display_bodies_menu(iPlayer)
{
    new iHatId = g_ePlayerData[iPlayer][PLR_MENU_HATID]
    new iMenu = menu_create(fmt("Hat Model (\r%s\y)", g_eHatData[iHatId][HAT_NAME]), "handler_hatparts_menu")
    new iBodiesNum = g_eHatData[iHatId][HAT_BODIES_NUM]

    for (new i; i < iBodiesNum; i++)
        menu_additem(iMenu, g_eHatData[iHatId][HAT_BODIES_NAMES][i * NAME_LEN])
    set_menu_common_prop(iMenu, iPlayer)
    
    menu_display(iPlayer, iMenu)
}

public handler_hats_menu(iPlayer, iMenu, iItem)
{
    if (iItem == MENU_EXIT)
    {
        menu_destroy(iMenu)
        return PLUGIN_HANDLED
    }

    new iHatId = iItem

    if (!check_hat_access(iPlayer, iHatId))
    {
        client_print_color(iPlayer, print_team_red, "^4[%s] ^3%L", PLUGIN, iPlayer, "HAT_ONLY_VIP")
        menu_display(iPlayer, iMenu, iItem / 7)
        return PLUGIN_HANDLED
    }

    new cTag = g_eHatData[iHatId][HAT_TAG]
    switch (cTag)
    {
        case 's':
        {
            g_ePlayerData[iPlayer][PLR_MENU_HATID] = iHatId
            menu_destroy(iMenu)
            display_skins_menu(iPlayer)
        }
        case 'b', 'c':
        {
            g_ePlayerData[iPlayer][PLR_MENU_HATID] = iHatId
            menu_destroy(iMenu)
            display_bodies_menu(iPlayer)
        }
        default:
        {
            new iPartId
            if (cTag == 't')
                iPartId = get_member(iPlayer, m_iTeam) == 2
            set_hat(iPlayer, iHatId, iPlayer, iPartId)
            menu_display(iPlayer, iMenu, iItem / 7)
        }
    }

    return PLUGIN_HANDLED
}

public handler_hatparts_menu(iPlayer, iMenu, iItem)
{
    if (iItem == MENU_EXIT)
    {
        menu_destroy(iMenu)
        // display_hats_menu(iPlayer, iItem / 7)
        return PLUGIN_HANDLED
    }

    new iHatId = g_ePlayerData[iPlayer][PLR_MENU_HATID]
    set_hat(iPlayer, iHatId, iPlayer, iItem)
    menu_display(iPlayer, iMenu, iItem / 7)
    return PLUGIN_HANDLED
}

set_menu_common_prop(iMenu, iLangId)
{
    menu_setprop(iMenu, MPROP_BACKNAME, fmt("%L", iLangId, "HAT_ITEM_PREV"))
    menu_setprop(iMenu, MPROP_NEXTNAME, fmt("%L", iLangId, "HAT_ITEM_NEXT"))
    menu_setprop(iMenu, MPROP_EXITNAME, fmt("%L", iLangId, "HAT_ITEM_EXIT"))
}

remove_hat(iPlayer)
{
    new iHatEnt = g_ePlayerData[iPlayer][PLR_HAT_ENT]
    if (iHatEnt)
        set_entvar(iHatEnt, var_flags, FL_KILLME)
    g_ePlayerData[iPlayer][PLR_HAT_ENT] = 0
    g_ePlayerData[iPlayer][PLR_HAT_ID] = 0
}

set_hat(iPlayer, iHatId, iSender, iPartId=0)
{
    static szKey[24]
    new iFwdReturn = PLUGIN_CONTINUE
    
    if (!check_hat_access(iPlayer, iHatId))
    {
        client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_ONLY_VIP")
        return NULLENT
    }
    
    if (iHatId == 0)
    {
        remove_hat(iPlayer)
        client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_REMOVE")

        ExecuteForward(g_fwChangeHat, iFwdReturn, iPlayer, 0)

        get_user_authid(iPlayer, szKey, charsmax(szKey))
        nvault_set(g_iVaultHats, szKey, "!NULL|0")
        return NULLENT
    }

    new iHatEnt = g_ePlayerData[iPlayer][PLR_HAT_ENT]
    
    if (is_nullent(iHatEnt))
    {
        iHatEnt = rg_create_entity("info_target", true)
        if (is_nullent(iHatEnt))
            return NULLENT
                                            
        set_entvar(iHatEnt, var_movetype, MOVETYPE_FOLLOW)
        set_entvar(iHatEnt, var_aiment, iPlayer)
        set_entvar(iHatEnt, var_rendermode, kRenderNormal)
        set_entvar(iHatEnt, var_renderamt, 0.0)
    }

    ExecuteForward(g_fwChangeHat, iFwdReturn, iPlayer, iHatEnt)	
    g_ePlayerData[iPlayer][PLR_HAT_ID] = iHatId
        
    engfunc(EngFunc_SetModel, iHatEnt, fmt("%s/%s", HATS_PATH, g_eHatData[iHatId][HAT_MODEL]))
    
    new iSkin, iBody
    new cTag = g_eHatData[iHatId][HAT_TAG]

    switch (cTag)
    {
        case 's': iSkin = iPartId < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPartId : 0
        case 'b': iBody = iPartId < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPartId : 0
        case 'c', 't':
        {
            iSkin = iPartId < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPartId : 0
            iBody = iPartId < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPartId : 0
        }
    }
    
    switch (cTag)
    {
        case 's': client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s ^3(skin %i)", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME], iSkin)
        case 'b', 'c': client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_BODIES_NAMES][iBody * NAME_LEN])
        default: client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME])
    }

    set_entvar(iHatEnt, var_skin, iSkin)
    set_entvar(iHatEnt, var_body, iBody)
    
    set_entvar(iHatEnt, var_sequence, iBody)
    set_entvar(iHatEnt, var_framerate, 1.0)
    set_entvar(iHatEnt, var_animtime, get_gametime())
                                
    get_user_authid(iPlayer, szKey, charsmax(szKey))
    nvault_set(g_iVaultHats, szKey, fmt("%s|%i", g_eHatData[iHatId][HAT_MODEL], iPartId))

    g_ePlayerData[iPlayer][PLR_HAT_ENT] = iHatEnt

    return iHatEnt
}

load_hats(const szHatFile[])
{
    if (file_exists(szHatFile))
    {
        g_iTotalHats = 1

        new szLineData[128], iFile = fopen(szHatFile, "rt"), cTag, iNamePos,
            iVipFlag, szHatModel[NAME_LEN], szHatName[NAME_LEN]

        while (iFile && !feof(iFile))
        {
            fgets(iFile, szLineData, charsmax(szLineData))
            
            if (szLineData[0] == ';' || strlen(szLineData) < 7)
                continue
            
            parse(szLineData, szHatModel, charsmax(szHatModel), szHatName, charsmax(szHatName))
            
            new szCurrentFile[256]
            formatex(szCurrentFile, charsmax(szCurrentFile), "%s/%s", HATS_PATH, szHatModel)
                
            if (!file_exists(szCurrentFile))
            {
                server_print("[%s] Failed to precache %s", PLUGIN, szCurrentFile)
                continue
            }
            
            if (szHatName[0] == 'v')
            {
                iVipFlag = 1
                cTag = szHatName[1]
                iNamePos = 1
            }
            else
            {
                iVipFlag = 0
                cTag = szHatName[0]
                iNamePos = 0
            }

            new iSkinsNum = 1, iBodiesNum = 1
                
            if (cTag == 's' || cTag == 'b' || cTag == 'c' || cTag == 't')
            {								
                new studiomodel = fopen(szCurrentFile, "rb"),			
                    bodypartindex, numbodyparts, nummodels
                                            
                fseek(studiomodel, 196, SEEK_SET)
                fread(studiomodel, iSkinsNum, BLOCK_INT)
                        
                fseek(studiomodel, 204, SEEK_SET)
                fread(studiomodel, numbodyparts, BLOCK_INT)
                fread(studiomodel, bodypartindex, BLOCK_INT)
                        
                fseek(studiomodel, bodypartindex, SEEK_SET)
                for (new i = 0, j; i < numbodyparts; i++)
                {
                    fseek(studiomodel, 64, SEEK_CUR)
                    fread(studiomodel, nummodels, BLOCK_INT)
                    fseek(studiomodel, 4, SEEK_CUR)
                    new modelindex; fread(studiomodel, modelindex, BLOCK_INT)
                                        
                    if (nummodels > iBodiesNum)
                    {
                        iBodiesNum = nummodels
                        
                        new nextpos = ftell(studiomodel)	
                        fseek(studiomodel, modelindex, SEEK_SET)
                        for (j = 0; j < nummodels; j++)
                        {
                            fread_blocks(studiomodel, g_eHatData[g_iTotalHats][HAT_BODIES_NAMES][j * NAME_LEN], NAME_LEN, BLOCK_CHAR)
                            fseek(studiomodel, 48, SEEK_CUR)
                        }
                        fseek(studiomodel, nextpos, SEEK_SET)
                    }
                }
        
                fclose(studiomodel)
            }

            switch (cTag)
            {
                case 's': if (iSkinsNum <= 1) cTag = 0
                case 'b': if (iBodiesNum <= 1) cTag = 0
                case 'c': if (iBodiesNum <= 1) cTag = iSkinsNum > 1 ? 's' : 0
                case 't': if (iSkinsNum <= 1 && iBodiesNum <= 1) cTag = 0
                default: cTag = 0
            }

            if (cTag) iNamePos++

            copy(g_eHatData[g_iTotalHats][HAT_MODEL], NAME_LEN - 1, szHatModel)
            copy(g_eHatData[g_iTotalHats][HAT_NAME], NAME_LEN - 1, szHatName[iNamePos])
            g_eHatData[g_iTotalHats][HAT_TAG] = cTag
            g_eHatData[g_iTotalHats][HAT_VIP_FLAG] = iVipFlag
            g_eHatData[g_iTotalHats][HAT_SKINS_NUM] = iSkinsNum
            g_eHatData[g_iTotalHats][HAT_BODIES_NUM] = iBodiesNum
            
            static bool: bWasSpawnReg
            if (!bWasSpawnReg && cTag == 't')
            {
                RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true)
                bWasSpawnReg = true
            }
                
            if (++g_iTotalHats == MAX_HATS)
            {
                server_print("[%s] Reached hat limit", PLUGIN)
                break
            }
        }

        if (iFile)
            fclose(iFile)
    }
    
    server_print("[%s] Loaded %i hats", PLUGIN, g_iTotalHats - 1)
}

bool: check_hat_access(iPlayer, iHatId)
{
    return !g_eHatData[iHatId][HAT_VIP_FLAG] || (get_user_flags(iPlayer) & VIP_FLAG)
}
