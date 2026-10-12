/// Asks whether an input method is composing at most once per input event;
/// each answer costs several Accessibility requests.
@MainActor final class ComposingProbe {
    private var answer: Bool?

    var isComposing: Bool {
        if let answer { return answer }
        let composing = InputMethodMonitor.isComposing()
        answer = composing
        return composing
    }
}
