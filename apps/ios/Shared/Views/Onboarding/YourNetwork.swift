//
//  YourNetwork.swift
//  SimpleX (iOS)
//
//  Created by Evgeny on 22/04/2026.
//  Copyright © 2026 SimpleX Chat. All rights reserved.
//

import SwiftUI
import SimpleXChat

private enum YourNetworkSheet: Identifiable {
    case configureNotifications

    var id: String {
        switch self {
        case .configureNotifications: return "configureNotifications"
        }
    }
}

struct YourNetworkView: View {
    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var notificationMode: NotificationsMode = .instant
    @State private var sheetItem: YourNetworkSheet? = nil

    var body: some View {
        GeometryReader { g in
            VStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)

                #if SIMPLEX_ASSETS
                Image(colorScheme == .light ? "your-network" : "your-network-light")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                #else
                ZStack {
                    let gp = OnboardingCardView.gradientPoints(aspectRatio: 1.0, scale: colorScheme == .light ? 1.2 : 1.5)
                    LinearGradient(
                        stops: colorScheme == .light ? OnboardingCardView.lightStops : OnboardingCardView.darkStops,
                        startPoint: gp.start,
                        endPoint: gp.end
                    )
                    Image(systemName: "network")
                        .font(.system(size: 72))
                        .foregroundColor(theme.colors.primary)
                }
                .aspectRatio(1.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 25)
                .frame(maxWidth: .infinity)
                #endif

                Text("Your network")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 15)

                Text("Network routers cannot know\nwho talks to whom")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 20) {
                    configureNotificationsButton()
                }
                .padding(.top, 15)
                .padding(.bottom, 15)

                Spacer(minLength: 0)

                continueButton()
                    .padding(.bottom, g.safeAreaInsets.bottom == 0 ? 20 : 0)
            }
            .padding(.horizontal, 25)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(minHeight: g.size.height)
        }
        .sheet(item: $sheetItem) { item in
            switch item {
            case .configureNotifications:
                SetNotificationsMode(notificationMode: $notificationMode)
                    .modifier(ThemedBackground())
            }
        }
        .frame(maxHeight: .infinity)
        .navigationBarHidden(true)
    }

    private func configureNotificationsButton() -> some View {
        Button {
            sheetItem = .configureNotifications
        } label: {
            HStack(spacing: 4) {
                Text("Setup notifications")
                    .fontWeight(.medium)
                Image(systemName: notificationMode.icon)
            }
        }
    }

    private func continueButton() -> some View {
        Button {
            applyNotificationMode()
            // Macet is the only operator of this build, so the operator conditions step is
            // skipped - see MacetServers.swift.
            let m = ChatModel.shared
            onboardingStageDefault.set(.onboardingComplete)
            m.onboardingStage = .onboardingComplete
        } label: {
            Text("Continue")
        }
        .buttonStyle(OnboardingButtonStyle())
    }

    private func applyNotificationMode() {
        let m = ChatModel.shared
        if let token = m.deviceToken {
            switch notificationMode {
            case .off:
                m.tokenStatus = .new
                m.notificationMode = .off
            default:
                Task {
                    do {
                        let status = try await apiRegisterToken(token: token, notificationMode: notificationMode)
                        await MainActor.run {
                            m.tokenStatus = status
                            m.notificationMode = notificationMode
                        }
                    } catch let error {
                        let a = getErrorAlert(error, "Error enabling notifications")
                        AlertManager.shared.showAlertMsg(
                            title: a.title,
                            message: a.message
                        )
                    }
                }
            }
        }
    }
}
