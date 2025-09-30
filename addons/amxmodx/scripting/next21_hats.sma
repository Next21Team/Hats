#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>
#include <time>
#include <nvault>

#define USE_JSON

#if defined USE_JSON
#include <json>
#endif

new const PLUGIN[] = 	"Hats"
new const AUTHOR[] = 	"Psycrow"
new const VERSION[] = 	"1.8"

new const HATS_PATH[] =	"models/next21_hats"
#define MAX_HATS 		64
#define VIP_FLAG 		ADMIN_LEVEL_H
#define VAULT_DAYS 		30

new const ITEM_POSTFIX_FORMAT[] = " \y[\r%L\y]"
new const CHAT_SET_HAT_FORMAT[] = "^4[%s] ^3%L ^4%s"
#define NAME_LEN 		64

#define MAXSTUDIOBODYPARTS	32

enum _:PLAYER_DATA
{
    PLR_HAT_ENT,
    PLR_HAT_ID,
    PLR_HAT_PART_ID,
    PLR_MENU_HATID
}

enum _:HAT_DATA
{
    HAT_MODEL[NAME_LEN],
    HAT_NAME[NAME_LEN],
    HAT_SKINS_NUM,
    HAT_BODIES_NUM,
    HAT_PARTS_NAMES[MAXSTUDIOBODYPARTS * NAME_LEN],
    HAT_TAG,
    bool:HAT_VIP_FLAG
}

new g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA], g_eHatData[MAX_HATS][HAT_DATA],
    Array:g_aInitialHats,
    g_iTotalHats, g_fwChangeHat, g_iVaultHats

new bool:g_pCvarMenuEnabled


public plugin_natives()
{
    register_native("n21_check_hat_access", "_check_hat_access")
    register_native("n21_get_hats_num", "_get_hats_num")
    register_native("n21_get_hat_parts_num", "_get_hat_parts_num")
    register_native("n21_get_hat_name", "_get_hat_name")
    register_native("n21_get_hat_part_name", "_get_hat_part_name")
    register_native("n21_get_player_hat_id", "_get_player_hat_id")
    register_native("n21_get_player_hat_part_id", "_get_player_hat_part_id")
    register_native("n21_get_player_hat_entity", "_get_player_hat_entity")
    register_native("n21_set_hat", "_set_hat")
}

public plugin_precache()
{
    new szCfgDir[32], szHatFile[64]
    get_configsdir(szCfgDir, charsmax(szCfgDir))

    #if defined USE_JSON
    formatex(szHatFile, charsmax(szHatFile), "%s/hats.json", szCfgDir)
    #else
    formatex(szHatFile, charsmax(szHatFile), "%s/hats.ini", szCfgDir)
    #endif

    g_aInitialHats = ArrayCreate()
    load_hats(szHatFile)

    for (new i, szCurrentFile[256]; i < g_iTotalHats; i++)
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

    bind_pcvar_num(register_cvar("hat_menu_enabled", "1"), g_pCvarMenuEnabled)

    g_fwChangeHat = CreateMultiForward("n21_on_hat_changed", ET_STOP, FP_CELL, FP_CELL)
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

    new iHatId = -1, iPartId
    if (!szValue[0])
    {
        new iInitialHatsNum = ArraySize(g_aInitialHats)
        if (iInitialHatsNum > 0)
        {
            iHatId = ArrayGetCell(g_aInitialHats, random(iInitialHatsNum))
            iPartId = random(get_hat_parts_num(iHatId))
        }

        goto set_hat_and_return
    }

    static szHatModel[120], szHatPart[5]
    split(szValue, szHatModel, charsmax(szHatModel), szHatPart, charsmax(szHatPart), "|")

    if (equal(szHatModel, "{NULL}"))
        goto set_hat_and_return

    for (new i; i < g_iTotalHats; i++)
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
    if (!is_user_alive(iPlayer))
        return HC_CONTINUE

    new iHatId = g_ePlayerData[iPlayer][PLR_HAT_ID]
    if (iHatId < 0)
        return HC_CONTINUE

    new iHatEnt = g_ePlayerData[iPlayer][PLR_HAT_ENT]
    if (is_nullent(iHatEnt))
        return HC_CONTINUE

    if (g_eHatData[iHatId][HAT_TAG] == 't')
    {
        new iPartId = TeamName:get_member(iPlayer, m_iTeam) == TEAM_CT

        if (g_eHatData[iHatId][HAT_BODIES_NUM] > 1)
            set_entvar(iHatEnt, var_body, iPartId)

        if (g_eHatData[iHatId][HAT_SKINS_NUM] > 1)
            set_entvar(iHatEnt, var_skin, iPartId)
    }

    return HC_CONTINUE
}

public clcmd_show_menu(iPlayer)
{
    if (!g_pCvarMenuEnabled)
        return PLUGIN_CONTINUE

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
    for (new iHatId; iHatId < g_iTotalHats; iHatId++)
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

    for (new i; i < iSkinsNum; i++)
        menu_additem(iMenu, g_eHatData[iHatId][HAT_PARTS_NAMES][i * NAME_LEN])
    set_menu_common_prop(iMenu, iPlayer)

    menu_display(iPlayer, iMenu)
}

display_bodies_menu(iPlayer)
{
    new iHatId = g_ePlayerData[iPlayer][PLR_MENU_HATID]
    new iMenu = menu_create(fmt("Hat Model (\r%s\y)", g_eHatData[iHatId][HAT_NAME]), "handler_hatparts_menu")
    new iBodiesNum = g_eHatData[iHatId][HAT_BODIES_NUM]

    for (new i; i < iBodiesNum; i++)
        menu_additem(iMenu, g_eHatData[iHatId][HAT_PARTS_NAMES][i * NAME_LEN])
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

    new iHatId = iItem - 1

    // Remove hat
    if (iHatId < 0)
    {
        set_hat(iPlayer, -1, iPlayer, 0, true)
        menu_display(iPlayer, iMenu)
        return PLUGIN_HANDLED
    }

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
                iPartId = TeamName:get_member(iPlayer, m_iTeam) == TEAM_CT
            set_hat(iPlayer, iHatId, iPlayer, iPartId, true)
            menu_display(iPlayer, iMenu, iItem / 7)
        }
    }

    return PLUGIN_HANDLED
}

public handler_hatparts_menu(iPlayer, iMenu, iItem)
{
    new iHatId = g_ePlayerData[iPlayer][PLR_MENU_HATID]

    if (iItem == MENU_EXIT)
    {
        menu_destroy(iMenu)
        display_hats_menu(iPlayer, (iHatId + 1) / 7)
        return PLUGIN_HANDLED
    }

    set_hat(iPlayer, iHatId, iPlayer, iItem, true)
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
    if (!is_nullent(iHatEnt))
        set_entvar(iHatEnt, var_flags, FL_KILLME)
    g_ePlayerData[iPlayer][PLR_HAT_ENT] = NULLENT
    g_ePlayerData[iPlayer][PLR_HAT_ID] = -1
    g_ePlayerData[iPlayer][PLR_HAT_PART_ID] = 0
}

set_hat(iPlayer, iHatId, iSender=0, iPartId=0, bool:bSaveData=false)
{
    static szKey[24]
    new iFwdReturn = PLUGIN_CONTINUE

    if (iSender > 0 && !check_hat_access(iPlayer, iHatId))
    {
        client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_ONLY_VIP")
        return NULLENT
    }

    if (iHatId < 0)
    {
        remove_hat(iPlayer)

        if (iSender > 0)
            client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_REMOVE")

        if (bSaveData)
        {
            get_user_authid(iPlayer, szKey, charsmax(szKey))
            nvault_set(g_iVaultHats, szKey, "{NULL}|0")
        }

        ExecuteForward(g_fwChangeHat, iFwdReturn, iPlayer, -1)

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

    g_ePlayerData[iPlayer][PLR_HAT_ID] = iHatId
    g_ePlayerData[iPlayer][PLR_HAT_ENT] = iHatEnt

    engfunc(EngFunc_SetModel, iHatEnt, fmt("%s/%s", HATS_PATH, g_eHatData[iHatId][HAT_MODEL]))

    new iSkin, iBody
    new cTag = g_eHatData[iHatId][HAT_TAG]

    switch (cTag)
    {
        case 's':
        {
            if (iPartId >= g_eHatData[iHatId][HAT_SKINS_NUM])
                iPartId = 0
            iSkin = iPartId
        }
        case 'b':
        {
            if (iPartId >= g_eHatData[iHatId][HAT_BODIES_NUM])
                iPartId = 0
            iBody = iPartId
        }
        case 'c', 't':
        {
            iSkin = iPartId < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPartId : 0
            iBody = iPartId < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPartId : 0
            iPartId = max(iSkin, iBody)
        }
    }

    g_ePlayerData[iPlayer][PLR_HAT_PART_ID] = iPartId

    if (iSender > 0)
    {
        switch (cTag)
        {
            case 's': client_print_color(iSender, print_team_red, CHAT_SET_HAT_FORMAT,
                PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_PARTS_NAMES][iSkin * NAME_LEN])

            case 'b', 'c': client_print_color(iSender, print_team_red, CHAT_SET_HAT_FORMAT,
                PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_PARTS_NAMES][iBody * NAME_LEN])

            default: client_print_color(iSender, print_team_red, CHAT_SET_HAT_FORMAT,
                PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME])
        }
    }

    set_entvar(iHatEnt, var_skin, iSkin)
    set_entvar(iHatEnt, var_body, iBody)

    set_entvar(iHatEnt, var_sequence, iBody)
    set_entvar(iHatEnt, var_framerate, 1.0)
    set_entvar(iHatEnt, var_animtime, get_gametime())

    if (bSaveData)
    {
        get_user_authid(iPlayer, szKey, charsmax(szKey))
        nvault_set(g_iVaultHats, szKey, fmt("%s|%i", g_eHatData[iHatId][HAT_MODEL], iPartId))
    }

    ExecuteForward(g_fwChangeHat, iFwdReturn, iPlayer, iHatEnt)

    return iHatEnt
}

load_hats(const szHatFile[])
{
    g_iTotalHats = 0
    ArrayClear(g_aInitialHats)

    #if defined USE_JSON
    new bool:bRes = load_hats_from_json(szHatFile)
    #else
    new bool:bRes = load_hats_from_ini(szHatFile)
    #endif

    if (bRes)
        server_print("[%s] Loaded %i hats from %s", PLUGIN, g_iTotalHats, szHatFile)
    else
        server_print("[%s] Failed load %s", PLUGIN, szHatFile)
}

#if defined USE_JSON
bool:load_hats_from_json(const szHatFile[])
{
    new JSON:jsonRoot = json_parse(szHatFile, true)
    if (jsonRoot == Invalid_JSON)
        return false

    new szCurrentFile[256], szHatModel[NAME_LEN], szTag[2], cTag
    new bool:bVipFlag, bool:bInitialFlag

    new iHatsNum = json_object_get_count(jsonRoot)
    for (new i, JSON:jsonHat, JSON:jsonHatItems; i < iHatsNum; i++)
    {
        jsonHat = json_object_get_value_at(jsonRoot, i)
        json_object_get_string(jsonHat, "model", szHatModel, charsmax(szHatModel))
        formatex(szCurrentFile, charsmax(szCurrentFile), "%s/%s", HATS_PATH, szHatModel)

        if (!file_exists(szCurrentFile))
        {
            json_free(jsonHat)
            server_print("[%s] Failed to precache %s", PLUGIN, szCurrentFile)
            continue
        }

        json_object_get_name(jsonRoot, i, g_eHatData[g_iTotalHats][HAT_NAME], NAME_LEN - 1)
        json_object_get_string(jsonHat, "tag", szTag, charsmax(szTag))
        bVipFlag = json_object_get_bool(jsonHat, "vip")
        bInitialFlag = json_object_get_bool(jsonHat, "initial")
        cTag = szTag[0]

        new iSkinsNum = 1, iBodiesNum = 1
        if (cTag == 's' || cTag == 'b' || cTag == 'c' || cTag == 't')
            parse_submodel_names(szCurrentFile, g_iTotalHats, iSkinsNum, iBodiesNum)

        validate_hat_tag(cTag, iSkinsNum, iBodiesNum)
        if (cTag == 's')
            set_hat_default_skin_names(g_iTotalHats, iSkinsNum)

        new iPartsNum = max(iSkinsNum, iBodiesNum)
        jsonHatItems = json_object_get_value(jsonHat, "items")
        if (jsonHatItems != Invalid_JSON)
        {
            iPartsNum = min(iPartsNum, json_object_get_count(jsonRoot))
            for (new j; j < iPartsNum; j++)
            {
                json_array_get_string(jsonHatItems, j,
                    g_eHatData[g_iTotalHats][HAT_PARTS_NAMES][j * NAME_LEN], NAME_LEN - 1)
            }
            json_free(jsonHatItems)
        }

        json_free(jsonHat)

        copy(g_eHatData[g_iTotalHats][HAT_MODEL], NAME_LEN - 1, szHatModel)
        g_eHatData[g_iTotalHats][HAT_TAG] = cTag
        g_eHatData[g_iTotalHats][HAT_VIP_FLAG] = bVipFlag
        g_eHatData[g_iTotalHats][HAT_SKINS_NUM] = iSkinsNum
        g_eHatData[g_iTotalHats][HAT_BODIES_NUM] = iBodiesNum

        if (bInitialFlag)
            ArrayPushCell(g_aInitialHats, g_iTotalHats)

        static bool:bWasSpawnReg
        if (!bWasSpawnReg && szTag[0] == 't')
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

    json_free(jsonRoot)
    return true
}
#else
bool:load_hats_from_ini(const szHatFile[])
{
    if (!file_exists(szHatFile))
        return false

    new szLineData[128], iFile = fopen(szHatFile, "rt"), cTag, iNamePos,
        szCurrentFile[256], szHatModel[NAME_LEN], szHatName[NAME_LEN],
        bool:bVipFlag

    while (iFile && !feof(iFile))
    {
        fgets(iFile, szLineData, charsmax(szLineData))
        if (szLineData[0] == ';' || strlen(szLineData) < 7)
            continue

        parse(szLineData, szHatModel, charsmax(szHatModel), szHatName, charsmax(szHatName))
        formatex(szCurrentFile, charsmax(szCurrentFile), "%s/%s", HATS_PATH, szHatModel)

        if (!file_exists(szCurrentFile))
        {
            server_print("[%s] Failed to precache %s", PLUGIN, szCurrentFile)
            continue
        }

        if (szHatName[0] == 'v')
        {
            bVipFlag = true
            cTag = szHatName[1]
            iNamePos = 1
        }
        else
        {
            bVipFlag = false
            cTag = szHatName[0]
            iNamePos = 0
        }

        new iSkinsNum = 1, iBodiesNum = 1
        if (cTag == 's' || cTag == 'b' || cTag == 'c' || cTag == 't')
            parse_submodel_names(szCurrentFile, g_iTotalHats, iSkinsNum, iBodiesNum)

        validate_hat_tag(cTag, iSkinsNum, iBodiesNum)
        if (cTag == 's')
            set_hat_default_skin_names(g_iTotalHats, iSkinsNum)

        if (cTag) iNamePos++

        copy(g_eHatData[g_iTotalHats][HAT_MODEL], NAME_LEN - 1, szHatModel)
        copy(g_eHatData[g_iTotalHats][HAT_NAME], NAME_LEN - 1, szHatName[iNamePos])
        g_eHatData[g_iTotalHats][HAT_TAG] = cTag
        g_eHatData[g_iTotalHats][HAT_VIP_FLAG] = bVipFlag
        g_eHatData[g_iTotalHats][HAT_SKINS_NUM] = iSkinsNum
        g_eHatData[g_iTotalHats][HAT_BODIES_NUM] = iBodiesNum

        static bool:bWasSpawnReg
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
    return true
}
#endif

parse_submodel_names(const szModelPath[], iHatId, &iSkinsNum, &iBodiesNum)
{
    new studiomodel = fopen(szModelPath, "rb"),
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
                fread_blocks(studiomodel, g_eHatData[iHatId][HAT_PARTS_NAMES][j * NAME_LEN], NAME_LEN, BLOCK_CHAR)
                fseek(studiomodel, 48, SEEK_CUR)
            }
            fseek(studiomodel, nextpos, SEEK_SET)
        }
    }
    fclose(studiomodel)

    // There may be more skins in the studiomodel, but they may not fit into the array
    iSkinsNum = min(iSkinsNum, MAXSTUDIOBODYPARTS)
}

set_hat_default_skin_names(iHatId, iSkinsNum)
{
    for (new i; i < iSkinsNum; i++)
        formatex(g_eHatData[iHatId][HAT_PARTS_NAMES][i * NAME_LEN],
            NAME_LEN - 1, "Skin %i", i + 1)
}

validate_hat_tag(&cTag, iSkinsNum, iBodiesNum)
{
    switch (cTag)
    {
        case 's': if (iSkinsNum <= 1) cTag = 0
        case 'b': if (iBodiesNum <= 1) cTag = 0
        case 'c': if (iBodiesNum <= 1) cTag = iSkinsNum > 1 ? 's' : 0
        case 't': if (iSkinsNum <= 1 && iBodiesNum <= 1) cTag = 0
        default: cTag = 0
    }
}

bool:check_hat_access(iPlayer, iHatId)
{
    if (iHatId < 0)
        return true

    return !g_eHatData[iHatId][HAT_VIP_FLAG] || (get_user_flags(iPlayer) & VIP_FLAG)
}

get_hat_parts_num(iHatId)
{
    new cTag = g_eHatData[iHatId][HAT_TAG]

    if (cTag == 's')
        return g_eHatData[iHatId][HAT_SKINS_NUM]

    if (cTag == 'b' || cTag ==  'c')
        return g_eHatData[iHatId][HAT_BODIES_NUM]

    return 1
}

public bool:_check_hat_access(plugin, num_params)
{
    enum
    {
        ARG_PLAYER_ID = 1,
        ARG_HAT_ID
    }

    new iPlayer = get_param(ARG_PLAYER_ID)
    new iHatId = get_param(ARG_HAT_ID)

    return check_hat_access(iPlayer, iHatId)
}

public _get_hats_num(plugin, num_params)
{
    return g_iTotalHats
}

public _get_hat_parts_num(plugin, num_params)
{
    new iHatId = get_param(1)
    return get_hat_parts_num(iHatId)
}

public _get_hat_name(plugin, num_params)
{
    enum
    {
        ARG_HAT_ID = 1,
        ARG_NAME,
        ARG_MAX_LEN
    }

    new iHatId = get_param(ARG_HAT_ID)
    new iMaxLen = get_param(ARG_MAX_LEN)

    set_string(ARG_NAME, g_eHatData[iHatId][HAT_NAME], iMaxLen)
}

public _get_hat_part_name(plugin, num_params)
{
    enum
    {
        ARG_HAT_ID = 1,
        ARG_PART_ID,
        ARG_NAME,
        ARG_MAX_LEN
    }

    new iHatId = get_param(ARG_HAT_ID)
    new iPartId = get_param(ARG_PART_ID)
    new iMaxLen = get_param(ARG_MAX_LEN)

    set_string(ARG_NAME, g_eHatData[iHatId][HAT_PARTS_NAMES][iPartId * NAME_LEN], iMaxLen)
}

public _get_player_hat_id(plugin, num_params)
{
    new iPlayer = get_param(1)
    return g_ePlayerData[iPlayer][PLR_HAT_ID]
}

public _get_player_hat_part_id(plugin, num_params)
{
    new iPlayer = get_param(1)
    return g_ePlayerData[iPlayer][PLR_HAT_PART_ID]
}

public _get_player_hat_entity(plugin, num_params)
{
    new iPlayer = get_param(1)
    return g_ePlayerData[iPlayer][PLR_HAT_ENT]
}

public _set_hat(plugin, num_params)
{
    enum
    {
        ARG_PLAYER_ID = 1,
        ARG_HAT_ID,
        ARG_PART_ID
    }

    new iPlayer = get_param(ARG_PLAYER_ID)
    new iHatId = get_param(ARG_HAT_ID)
    new iPartId = get_param(ARG_PART_ID)

    return set_hat(iPlayer, iHatId, -1, iPartId)
}
