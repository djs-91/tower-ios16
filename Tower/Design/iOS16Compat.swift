import SwiftUI

// MARK: - iOS 16 stand-ins for iOS-17-only SwiftUI
//
// Nothing in here changes what the app does beyond dropping the effect the
// platform could not yet provide.

// MARK: - PhaseAnimator (iOS 17)
//
// The onboarding scenes walk a short list of decorative phases. `PhaseDriver`
// steps the same list on a fixed cadence; the original derived the dwell time
// from each phase's `Animation`, which is not worth reproducing.
struct PhaseDriver<Phase: Equatable, Content: View>: View {
    let phases: [Phase]
    let interval: Duration
    @ViewBuilder let content: (Phase) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int = 0

    var body: some View {
        Group {
            if reduceMotion {
                content(phases[0])
            } else {
                content(phases[index % phases.count])
                    .id(index % phases.count)
                    .transition(.opacity)
            }
        }
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            index = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                index = (index + 1) % phases.count
            }
        }
    }
}

// MARK: - onGeometryChange(for:of:action:) (iOS 17)
//
// `GeometryReader` is the iOS 16 way to observe a geometry value: the transform
// runs on every layout pass and the action fires for each new value, including
// the first. `action` is a concrete `(Value) -> Void` rather than a generic
// parameter -- a bare generic constrained to a function type is not a function
// type as far as `@escaping` is concerned.
struct GeometryReporter<Value: Equatable>: View {
    let transform: (GeometryProxy) -> Value
    let action: (Value) -> Void

    init(_ transform: @escaping (GeometryProxy) -> Value, action: @escaping (Value) -> Void) {
        self.transform = transform
        self.action = action
    }

    var body: some View {
        GeometryReader { proxy in
            let value = transform(proxy)
            Color.clear
                .onAppear { action(value) }
                .onChange(of: value) { newValue in action(newValue) }
        }
    }
}

// MARK: - withAnimation(_:completionCriteria:_:completion:) (iOS 17)
//
// iOS 16 has no completion criterion, so the completion runs on the next
// main-queue turn after the animated update.
func withAnimation16<Value>(
    _ animation: Animation?,
    _ body: () -> Value,
    completion: @escaping () -> Void
) -> Value {
    let value = withAnimation(animation, body)
    DispatchQueue.main.async(execute: completion)
    return value
}

extension View {
    /// Call site form:
    /// `.onGeometryChange16(for: CGRect.self, transform: { $0.frame(in: .named(x)) },
    ///                     action: { store = $0 })`
    func onGeometryChange16<Value: Equatable>(
        for _: Value.Type,
        transform: @escaping (GeometryProxy) -> Value,
        action: @escaping (Value) -> Void
    ) -> some View {
        GeometryReporter(transform, action: action)
    }
}

// ------------------------------------------------------------------ (17) nav
// `navigationDestination(item:destination:)` is iOS 17. The iOS 16 pair is
// `navigationDestination(isPresented:)` + a presented-value box; this helper
// reproduces the iOS 17 call shape on top of it.
private struct RouteBox<Value> {
    var value: Binding<Value?>
}

extension RouteBox: View where Value: Hashable {
    var body: some View {
        EmptyView()
    }
}

extension View {
    @ViewBuilder
    func navigationDestination16<V: Hashable, D: View>(
        item: Binding<V?>,
        @ViewBuilder destination: @escaping (V) -> D
    ) -> some View {
        let isPresented = Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        navigationDestination(isPresented: isPresented) {
            if let value = item.wrappedValue {
                destination(value)
            }
        }
    }
}

// ------------------------------------------------------------------ (18) bar
// `{ item; item }` closure literals leave both toolbar(content:) overloads
// (@ViewBuilder and @ToolbarContentBuilder) alive and the iOS 16 checker
// reports the call as ambiguous. This passthrough pins the builder: the
// generic `Content: ToolbarContent` constraint makes the ViewBuilder
// overload unreachable, so the inner call resolves to exactly one candidate.
extension View {
    func toolbar16<Content: ToolbarContent>(
        @ToolbarContentBuilder content: () -> Content
    ) -> some View {
        self.toolbar(content: content)
    }
}
