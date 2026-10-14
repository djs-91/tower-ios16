
import SwiftUI

/// iOS 16 stand-in for SwiftUI's `ContentUnavailableView` (iOS 17).
/// All initializers build the concrete generic instantiation directly, so a
/// call site never has to infer `Actions` from a defaulted closure argument.
struct TowerContentUnavailableView<Label: View, Detail: View, Actions: View>: View {
    let label: Label
    let detail: Detail
    let actions: Actions

    init(@ViewBuilder label: () -> Label,
         @ViewBuilder detail: () -> Detail = { EmptyView() as! Detail },
         @ViewBuilder actions: () -> Actions = { EmptyView() as! Actions }) {
        self.label = label()
        self.detail = detail()
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 12) {
            label
            detail
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }
}

/// The label half of the built-in view, for the `(title, systemImage:)` shapes.
struct DefaultContentUnavailableLabel: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(titleKey)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
}

struct DefaultContentUnavailableSearchLabel: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(verbatim: "未找到结果")
                .font(.headline)
        }
    }
}

extension TowerContentUnavailableView where Label == DefaultContentUnavailableLabel,
                                             Detail == Text,
                                             Actions == EmptyView {
    init(_ titleKey: LocalizedStringKey, systemImage: String) {
        self.init(label: { DefaultContentUnavailableLabel(titleKey: titleKey, systemImage: systemImage) },
                  detail: { Text("") },
                  actions: { EmptyView() })
    }

    init(_ titleKey: LocalizedStringKey,
         systemImage: String,
         description: Text) {
        self.init(label: { DefaultContentUnavailableLabel(titleKey: titleKey, systemImage: systemImage) },
                  detail: { description },
                  actions: { EmptyView() })
    }
}

extension TowerContentUnavailableView where Label == DefaultContentUnavailableSearchLabel,
                                             Detail == Text,
                                             Actions == EmptyView {
    /// iOS 17 ships a dedicated `search` overload; Tower's empty result lists
    /// used it verbatim, so the shape is reproduced here.
    static func search(text: String) -> TowerContentUnavailableView<DefaultContentUnavailableSearchLabel, Text, EmptyView> {
        TowerContentUnavailableView<DefaultContentUnavailableSearchLabel, Text, EmptyView>(
            label: { DefaultContentUnavailableSearchLabel(text: text) },
            detail: { Text(verbatim: "没有与 “\(text)” 匹配的内容") },
            actions: { EmptyView() })
    }
}
