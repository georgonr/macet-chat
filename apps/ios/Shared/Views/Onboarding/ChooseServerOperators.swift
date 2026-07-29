//
//  ChooseServerOperators.swift
//  SimpleX (iOS)
//
//  Created by spaced4ndy on 31.10.2024.
//  Copyright © 2024 SimpleX Chat. All rights reserved.
//
// Spec: spec/client/navigation.md

import SwiftUI
import SimpleXChat

// The operator picker and the onboarding conditions screen that used to live here are gone -
// Macet is the only operator of this build, see MacetServers.swift. What remains are the links
// to the conditions, which the rest of the app still uses.

// Macet runs the only servers of this build, so the conditions and the privacy policy are this
// fork's own document, not the upstream operators' one - see PRIVACY.md in the repository root.
let conditionsURL = URL(string: "https://github.com/georgonr/macet-chat/blob/macet-brand/PRIVACY.md")!
// Upstream linked the commit that last changed the conditions; ours are tracked in the file history.
let conditionsHistoryURL = URL(string: "https://github.com/georgonr/macet-chat/commits/macet-brand/PRIVACY.md")!
