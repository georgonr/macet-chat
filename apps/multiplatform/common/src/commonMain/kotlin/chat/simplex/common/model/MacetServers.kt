package chat.simplex.common.model

import chat.simplex.common.platform.Log
import chat.simplex.common.platform.TAG

/**
 * Macet network configuration.
 *
 * Macet is the only operator of this build. The upstream preset operators (SimpleX Chat, Flux)
 * and their preset SMP/XFTP servers are compiled into the Haskell core
 * (`src/Simplex/Chat/Operators/Presets.hs`) and are seeded into the chat database when it is
 * created. This fork uses the core as a prebuilt binary, and the core refuses to delete preset
 * server rows - `setUserServers'` in `src/Simplex/Chat/Store/Profiles.hs` only deletes rows with
 * `preset = 0`, and `updateServerOperator` only writes `enabled` and the operator roles.
 *
 * So the preset rows cannot be removed from the database, and the configuration is instead
 * enforced over the API every time the chat starts and whenever a profile is created:
 *
 *  - every preset operator is disabled, which excludes all of its servers from the configuration
 *    that is handed to the agent (`useServers` only collects servers of enabled operators);
 *  - every preset server is disabled as well, so nothing is left enabled behind a disabled operator;
 *  - the Macet servers are installed in the operator-less group and enabled, which is the group
 *    the app uses for new connections.
 *
 * The UI hides the disabled preset operators, so Macet is the only operator the user ever sees.
 */
object MacetServers {
  const val operatorName = "Macet"
  const val serverDomain = "cht.macet.eu"

  const val smp = "smp://gEnQK3KVoYlhg8OO71p8SWUSHfmSGpOn2Fd4Vwkdj3M=:VeMInRcv8gAc5z4RmibE7z9NYrV9ndbXyuNtStpI@cht.macet.eu:5223"
  const val xftp = "xftp://8fATYZeSTIyuYz9DCmXgGXooU3u31X0usA8KMPru4RI=@cht.macet.eu:5443"

  /** Default WebRTC ICE server, used whenever the user has not configured their own. */
  const val iceServer = "turn:macet:FCSJMOxqOZt4W4cdXcnYNUansG1pHGT4@cht.macet.eu:3478"
}

/** Two server addresses point at the same server when the part after the key is the same. */
private fun sameServer(a: String, b: String): Boolean =
  a.substringAfter('@').trimEnd('/') == b.substringAfter('@').trimEnd('/')

private fun macetOnly(servers: List<UserServer>, macet: String): List<UserServer> {
  val existing = servers.firstOrNull { sameServer(it.server, macet) }
  // preset servers are ignored here - this is the operator-less group, which has none
  val others = servers.filter { !sameServer(it.server, macet) }.map { it.copy(deleted = true) }
  val macetServer = existing?.copy(server = macet, enabled = true, deleted = false)
    ?: UserServer(
      remoteHostId = null,
      serverId = null,
      server = macet,
      preset = false,
      tested = null,
      enabled = true,
      deleted = false
    )
  return listOf(macetServer) + others
}

private fun isMacetOnly(servers: List<UserOperatorServers>): Boolean {
  val presetOperatorsDisabled = servers.all { it.operator == null || !it.operator.enabled }
  val ours = servers.firstOrNull { it.operator == null } ?: return false
  fun onlyOurs(list: List<UserServer>, macet: String) =
    list.size == 1 && list[0].enabled && !list[0].deleted && sameServer(list[0].server, macet)
  return presetOperatorsDisabled &&
      onlyOurs(ours.smpServers, MacetServers.smp) &&
      onlyOurs(ours.xftpServers, MacetServers.xftp)
}

private fun macetServers(servers: List<UserOperatorServers>): List<UserOperatorServers> =
  servers.map { group ->
    val operator = group.operator
    if (operator == null) {
      group.copy(
        smpServers = macetOnly(group.smpServers, MacetServers.smp),
        xftpServers = macetOnly(group.xftpServers, MacetServers.xftp)
      )
    } else {
      group.copy(
        operator = operator.copy(enabled = false),
        smpServers = group.smpServers.map { it.copy(enabled = false) },
        xftpServers = group.xftpServers.map { it.copy(enabled = false) }
      )
    }
  }

/**
 * Makes the Macet servers the only servers of [userId], and disables every preset operator.
 * Does nothing when the configuration already matches, so it is cheap to call on every start.
 */
suspend fun ChatController.applyMacetServers(rh: Long?, userId: Long): Boolean {
  val r = sendCmd(rh, CC.ApiGetUserServers(userId))
  val current = if (r is API.Result && r.res is CR.UserServers) r.res.userServers else {
    Log.e(TAG, "applyMacetServers: cannot read servers of user $userId: ${r.responseType} ${r.details}")
    return false
  }
  if (isMacetOnly(current)) return true
  val updated = sendCmd(rh, CC.ApiSetUserServers(userId, macetServers(current)))
  if (updated.result is CR.CmdOk) {
    Log.i(TAG, "applyMacetServers: Macet servers configured for user $userId")
    return true
  }
  Log.e(TAG, "applyMacetServers: cannot set servers of user $userId: ${updated.responseType} ${updated.details}")
  return false
}

/** Applies [applyMacetServers] to every profile, and disables the preset operators globally. */
suspend fun ChatController.applyMacetServersToAllUsers(rh: Long?) {
  try {
    val conditions = getServerOperators(rh)
    if (conditions != null && conditions.serverOperators.any { it.enabled }) {
      val updated = setServerOperators(rh, conditions.serverOperators.map { it.copy(enabled = false) })
      // Keep the model in step, otherwise views that read it keep showing the operators as enabled
      if (updated != null) chatModel.conditions.value = updated
    }
    listUsers(rh).forEach { applyMacetServers(rh, it.user.userId) }
  } catch (e: Exception) {
    Log.e(TAG, "applyMacetServersToAllUsers failed: ${e.stackTraceToString()}")
  }
}
