//
//  OnboardingStepsView.swift
//  SimpleX (iOS)
//
//  Created by Evgeny on 07/05/2022.
//  Copyright © 2022 SimpleX Chat. All rights reserved.
//
// Spec: spec/client/navigation.md

import SwiftUI

// Spec: spec/client/navigation.md#OnboardingView
struct OnboardingView: View {
    var onboarding: OnboardingStage

    var body: some View {
        NavigationView {
            switch onboarding {
            case .step1_SimpleXInfo:
                SimpleXInfo(onboarding: true)
                    .modifier(ThemedBackground())
            case .step2_CreateProfile:
                CreateFirstProfile()
                    .modifier(ThemedBackground())
            case .step3_CreateSimpleXAddress: // deprecated
                CreateSimpleXAddress()
            case .step3_ChooseServerOperators,
                .step4_SetNotificationsMode: // deprecated
                YourNetworkView()
                    .navigationBarBackButtonHidden(true)
                    .modifier(ThemedBackground())
            // The operator conditions step is skipped in this build - see MacetServers.swift.
            // The case is kept because the stage is persisted in UserDefaults; installs standing
            // on it are mapped to onboardingComplete on read, see OnboardingStageDefault.
            case .step4_NetworkCommitments, .onboardingComplete: EmptyView()
            }
        }
    }
}

func onboardingButtonPlaceholder() -> some View {
    Spacer().frame(height: 40)
}

// Spec: spec/client/navigation.md#onboardingStage
enum OnboardingStage: String, Identifiable {
    case step1_SimpleXInfo
    case step2_CreateProfile
    case step3_CreateSimpleXAddress // deprecated
    case step3_ChooseServerOperators
    case step4_SetNotificationsMode // deprecated
    case step4_NetworkCommitments
    case onboardingComplete

    public var id: Self { self }
}

struct OnboardingStepsView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onboarding: .step1_SimpleXInfo)
    }
}
