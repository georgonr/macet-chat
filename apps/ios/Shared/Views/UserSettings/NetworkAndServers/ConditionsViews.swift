//
//  ConditionsViews.swift
//  SimpleX (iOS)
//
//  Created by spaced4ndy on 28.10.2024.
//  Copyright © 2024 SimpleX Chat. All rights reserved.
//
// Spec: spec/architecture.md
//
//  Was OperatorView.swift. Macet is the only operator of this build, so the operator screen and
//  its per-operator conditions view are gone - see MacetServers.swift. What remains are the
//  conditions components shared with UsageConditionsView, which WhatsNewView still opens.

import SwiftUI
import SimpleXChat
import Ink

func conditionsTimestamp(_ date: Date) -> String {
    let localDateFormatter = DateFormatter()
    localDateFormatter.dateStyle = .medium
    localDateFormatter.timeStyle = .none
    return localDateFormatter.string(from: date)
}

struct ConditionsTextView: View {
    @State private var conditionsData: (UsageConditions, String?, UsageConditions?)?
    @State private var failedToLoad: Bool = false
    @State private var conditionsHTML: String? = nil

    let defaultConditionsLink = conditionsURL.absoluteString

    var body: some View {
        viewBody()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                do {
                    let conditions = try await getUsageConditions()
                    let conditionsText = conditions.1
                    let parentLink =  "https://github.com/georgonr/macet-chat/blob/macet-brand"
                    let preparedText: String?
                    if let conditionsText {
                        let prepared = prepareMarkdown(conditionsText.trimmingCharacters(in: .whitespacesAndNewlines), parentLink)
                        conditionsHTML = MarkdownParser().html(from: prepared)
                        preparedText = prepared
                    } else {
                        preparedText = nil
                    }
                    conditionsData = (conditions.0, preparedText, conditions.2)
                } catch let error {
                    logger.error("ConditionsTextView getUsageConditions error: \(responseError(error))")
                    failedToLoad = true
                }
            }
    }

    // TODO Diff rendering
    @ViewBuilder private func viewBody() -> some View {
        if let (usageConditions, _, _) = conditionsData {
            if let conditionsHTML {
                ConditionsWebView(html: conditionsHTML)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
            } else {
                conditionsLinkView(defaultConditionsLink)
            }
        } else if failedToLoad {
            conditionsLinkView(defaultConditionsLink)
        } else {
            ProgressView()
                .scaleEffect(2)
        }
    }

    private func conditionsLinkView(_ conditionsLink: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Current conditions text couldn't be loaded, you can review conditions via this link:")
            ExternalLink(destination: URL(string: conditionsLink)!) {
                Text(conditionsLink)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func prepareMarkdown(_ text: String, _ parentLink: String) -> String {
        let localLinkRegex = try! NSRegularExpression(pattern: "\\[([^\\(]*)\\]\\(#.*\\)")
        let h1Regex = try! NSRegularExpression(pattern: "^# ")
        var text = localLinkRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "$1")
        text = h1Regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: "")
        return text
            .replacingOccurrences(of: "](/", with: "](\(parentLink)/")
            .replacingOccurrences(of: "](./", with: "](\(parentLink)/")
    }
}

func conditionsLinkButton() -> some View {
    return Menu {
        ExternalLink(destination: conditionsURL) {
            Label("Open conditions", systemImage: "doc")
        }
        ExternalLink(destination: conditionsHistoryURL) {
            Label("Open changes", systemImage: "ellipsis")
        }
    } label: {
        Image(systemName: "arrow.up.right.circle")
            .resizable()
            .scaledToFit()
            .frame(width: 20)
            .padding(2)
            .contentShape(Circle())
    }
}
