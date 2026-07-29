//
//  MacetServers.swift
//  SimpleX (iOS)
//
//  Macet network configuration - the iOS counterpart of
//  apps/multiplatform/common/src/commonMain/kotlin/chat/simplex/common/model/MacetServers.kt
//

import Foundation
import SimpleXChat

/// Macet network configuration.
///
/// Macet is the only operator of this build. The upstream preset operators (SimpleX Chat, Flux)
/// and their preset SMP/XFTP servers are compiled into the Haskell core
/// (`src/Simplex/Chat/Operators/Presets.hs`) and are seeded into the chat database when it is
/// created. This fork uses the core as a prebuilt binary, and the core refuses to delete preset
/// server rows - `setUserServers'` in `src/Simplex/Chat/Store/Profiles.hs` only deletes rows with
/// `preset = 0`, and `updateServerOperator` only writes `enabled` and the operator roles.
///
/// So the preset rows cannot be removed from the database, and the configuration is instead
/// enforced over the API every time the chat starts and whenever a profile is created:
///
///  - every preset operator is disabled, which excludes all of its servers from the configuration
///    that is handed to the agent (`useServers` only collects servers of enabled operators);
///  - every preset server and chat relay is disabled as well, so nothing is left enabled behind a
///    disabled operator;
///  - the Macet servers are installed in the operator-less group and enabled, which is the group
///    the app uses for new connections.
///
/// The UI hides the disabled preset operators, so Macet is the only operator the user ever sees.
enum MacetServers {
    static let operatorName = "Macet"
    static let serverDomain = "cht.macet.eu"

    static let smp = "smp://gEnQK3KVoYlhg8OO71p8SWUSHfmSGpOn2Fd4Vwkdj3M=:VeMInRcv8gAc5z4RmibE7z9NYrV9ndbXyuNtStpI@cht.macet.eu:5223"
    static let xftp = "xftp://8fATYZeSTIyuYz9DCmXgGXooU3u31X0usA8KMPru4RI=@cht.macet.eu:5443"

    /// Default WebRTC ICE server, used whenever the user has not configured their own.
    static let iceServer = "turn:macet:FCSJMOxqOZt4W4cdXcnYNUansG1pHGT4@cht.macet.eu:3478"
}

/// Two server addresses point at the same server when the part after the key is the same.
private func sameServer(_ a: String, _ b: String) -> Bool {
    func hostPart(_ s: String) -> Substring {
        let afterKey = s.firstIndex(of: "@").map { s[s.index(after: $0)...] } ?? s[...]
        return afterKey.hasSuffix("/") ? afterKey.dropLast() : afterKey
    }
    return hostPart(a) == hostPart(b)
}

private func macetOnly(_ servers: [UserServer], _ macet: String) -> [UserServer] {
    let existing = servers.first { sameServer($0.server, macet) }
    // preset servers are ignored here - this is the operator-less group, which has none
    let others: [UserServer] = servers
        .filter { !sameServer($0.server, macet) }
        .map { s in var s = s; s.deleted = true; return s }
    let macetServer: UserServer
    if var e = existing {
        e.server = macet
        e.enabled = true
        e.deleted = false
        macetServer = e
    } else {
        macetServer = UserServer(
            serverId: nil,
            server: macet,
            preset: false,
            tested: nil,
            enabled: true,
            deleted: false
        )
    }
    return [macetServer] + others
}

private func isMacetOnly(_ servers: [UserOperatorServers]) -> Bool {
    let presetOperatorsDisabled = servers.allSatisfy { $0.operator == nil || !($0.operator?.enabled ?? false) }
    guard let ours = servers.first(where: { $0.operator == nil }) else { return false }
    func onlyOurs(_ list: [UserServer], _ macet: String) -> Bool {
        list.count == 1 && list[0].enabled && !list[0].deleted && sameServer(list[0].server, macet)
    }
    return presetOperatorsDisabled
        && onlyOurs(ours.smpServers, MacetServers.smp)
        && onlyOurs(ours.xftpServers, MacetServers.xftp)
}

private func macetServers(_ servers: [UserOperatorServers]) -> [UserOperatorServers] {
    servers.map { group in
        // mutate a copy - constructing a new value would drop the user's own chat relays
        var g = group
        if g.operator == nil {
            g.smpServers = macetOnly(g.smpServers, MacetServers.smp)
            g.xftpServers = macetOnly(g.xftpServers, MacetServers.xftp)
        } else {
            g.operator?.enabled = false
            g.smpServers = g.smpServers.map { s in var s = s; s.enabled = false; return s }
            g.xftpServers = g.xftpServers.map { s in var s = s; s.enabled = false; return s }
            g.chatRelays = g.chatRelays.map { r in var r = r; r.enabled = false; return r }
        }
        return g
    }
}

/// Makes the Macet servers the only servers of `userId`, and disables every preset operator.
/// Does nothing when the configuration already matches, so it is cheap to call on every start.
@discardableResult
func applyMacetServers(userId: Int64) -> Bool {
    do {
        let current = try getUserServersSync(userId: userId)
        if isMacetOnly(current) { return true }
        try setUserServersSync(userId: userId, userServers: macetServers(current))
        logger.debug("applyMacetServers: Macet servers configured for user \(userId)")
        return true
    } catch let error {
        logger.error("applyMacetServers: cannot configure servers of user \(userId): \(responseError(error))")
        return false
    }
}

/// Applies `applyMacetServers` to every profile, and disables the preset operators globally.
///
/// The core answers the server commands with `chatNotStarted` until `apiStartChat` has run, so
/// this must only be called once the chat is started.
func applyMacetServersToAllUsers() {
    do {
        let conditions = try getServerOperatorsSync()
        if conditions.serverOperators.contains(where: { $0.enabled }) {
            let disabled = conditions.serverOperators.map { op in var op = op; op.enabled = false; return op }
            let updated = try setServerOperatorsSync(operators: disabled)
            // Keep the model in step, otherwise views that read it keep showing the operators as enabled
            let m = ChatModel.shared
            if Thread.isMainThread {
                m.conditions = updated
            } else {
                DispatchQueue.main.async { m.conditions = updated }
            }
        }
        for u in try listUsers() {
            applyMacetServers(userId: u.user.userId)
        }
    } catch let error {
        logger.error("applyMacetServersToAllUsers failed: \(responseError(error))")
    }
}
