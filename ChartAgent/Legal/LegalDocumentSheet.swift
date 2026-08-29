import SwiftUI

enum LegalDocumentKind: String, Identifiable {
    case termsOfUse
    case privacyPolicy

    var id: Self { self }

    var title: String {
        switch self {
        case .termsOfUse: AppLanguage.localized("이용약관")
        case .privacyPolicy: AppLanguage.localized("개인정보 처리 안내")
        }
    }

    fileprivate var resourceName: String {
        switch self {
        case .termsOfUse: "TermsOfUse"
        case .privacyPolicy: "PrivacyPolicy"
        }
    }
}

struct LegalDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: LegalDocumentKind

    private var blocks: [LegalDocumentBlock] {
        LegalDocumentStore.blocks(for: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { block in
                        LegalDocumentBlockView(block: block)
                    }
                }
                .padding(.horizontal, ChartTheme.screenPadding)
                .padding(.vertical, 22)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text(verbatim: kind.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct LegalDocumentBlockView: View {
    let block: LegalDocumentBlock

    var body: some View {
        switch block.style {
        case .title:
            Text(verbatim: block.text)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .padding(.bottom, 2)
        case .heading:
            Text(verbatim: block.text)
                .font(.title3.bold())
                .foregroundStyle(ChartTheme.mint)
                .padding(.top, 12)
        case .subheading:
            Text(verbatim: block.text)
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 6)
        case .paragraph:
            inlineMarkdownText
                .font(.body)
                .foregroundStyle(.white.opacity(0.80))
                .lineSpacing(4)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•")
                    .foregroundStyle(ChartTheme.mint)
                inlineMarkdownText
                    .foregroundStyle(.white.opacity(0.80))
            }
            .font(.body)
        }
    }

    private var inlineMarkdownText: Text {
        if let attributed = try? AttributedString(markdown: block.text) {
            Text(attributed)
        } else {
            Text(verbatim: block.text)
        }
    }
}

private struct LegalDocumentBlock: Identifiable {
    enum Style {
        case title
        case heading
        case subheading
        case paragraph
        case bullet
    }

    let id: Int
    let style: Style
    let text: String
}

private enum LegalDocumentStore {
    static let termsOfUse = load(.termsOfUse)
    static let privacyPolicy = load(.privacyPolicy)

    static func blocks(for kind: LegalDocumentKind) -> [LegalDocumentBlock] {
        switch kind {
        case .termsOfUse: termsOfUse
        case .privacyPolicy: privacyPolicy
        }
    }

    private static func load(_ kind: LegalDocumentKind) -> [LegalDocumentBlock] {
        let url = Bundle.main.url(forResource: kind.resourceName, withExtension: "md", subdirectory: "Legal")
            ?? Bundle.main.url(forResource: kind.resourceName, withExtension: "md")
        guard let url, let source = try? String(contentsOf: url, encoding: .utf8) else {
            return [.init(id: 0, style: .paragraph, text: "This document is temporarily unavailable.")]
        }
        return parse(source)
    }

    private static func parse(_ source: String) -> [LegalDocumentBlock] {
        var blocks: [LegalDocumentBlock] = []
        var paragraphLines: [String] = []

        func appendParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(
                .init(
                    id: blocks.count,
                    style: .paragraph,
                    text: paragraphLines.joined(separator: " ")
                )
            )
            paragraphLines.removeAll(keepingCapacity: true)
        }

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                appendParagraph()
            } else if line.hasPrefix("### ") {
                appendParagraph()
                blocks.append(.init(id: blocks.count, style: .subheading, text: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                appendParagraph()
                blocks.append(.init(id: blocks.count, style: .heading, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                appendParagraph()
                blocks.append(.init(id: blocks.count, style: .title, text: String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") {
                appendParagraph()
                blocks.append(.init(id: blocks.count, style: .bullet, text: String(line.dropFirst(2))))
            } else {
                paragraphLines.append(line)
            }
        }

        appendParagraph()
        return blocks
    }
}
