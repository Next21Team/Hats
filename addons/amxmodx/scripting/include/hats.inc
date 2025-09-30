#if defined _hats_included
    #endinput
#endif
#define _hats_included

/**
 * Called after changing the player's hat entity
 *
 * @param iPlayer           - Client index
 * @param iHatEnt           - Hat entity index
 * @noreturn
 */
forward n21_on_hat_changed(iPlayer, iHatEnt);

/**
 * Check access to the hat
 *
 * @param iPlayer           - Client index
 * @param iHatId            - Hat index
 * @return                  - true if access granted
 */
native bool:n21_check_hat_access(iPlayer, iHatId);

/**
 * Get the number of hats
 *
 * @return                  - Hats number
 */
native n21_get_hats_num();

/**
 * Get the number of hat's parts
 *
 * @param iHatId            - Hat index
 * @return                  - Hat's parts number
 */
native n21_get_hat_parts_num(iHatId);

/**
 * Get the name of the hat
 *
 * @param iHatId            - Hat index
 * @param szName            - Buffer to copy string to
 * @param iMaxLen           - Maximum size of buffer
 * @noreturn
 */
native n21_get_hat_name(iHatId, szName[], iMaxLen);

/**
 * Get the name of the hat's part
 *
 * @param iHatId            - Hat index
 * @param iPartId           - Hat part index
 * @param szName            - Buffer to copy string to
 * @param iMaxLen           - Maximum size of buffer
 * @noreturn
 */
native n21_get_hat_part_name(iHatId, iPartId, szName[], iCharsNum);

/**
 * Get the player's hat index
 *
 * @param iPlayer           - Client index
 * @return                  - Hat index
 */
native n21_get_player_hat_id(iPlayer);

/**
 * Get the player's hat part index
 *
 * @param iPlayer           - Client index
 * @return                  - Hat part index
 */
native n21_get_player_hat_part_id(iPlayer);

/**
 * Get the player's hat entity index
 *
 * @param iPlayer           - Client index
 * @return                  - Hat entity index
 */
native n21_get_player_hat_entity(iPlayer);

/**
 * Give the hat to the player
 *
 * @param iPlayer           - Client index
 * @param iHatId            - Hat index (-1 to remove)
 * @param iPartId           - Hat part index
 * @return                  - Hat entity index
 */
native n21_set_hat(iPlayer, iHatId, iPartId=0);