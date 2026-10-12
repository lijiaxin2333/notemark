/// State the conversion engine shares with its collaborators, passed at
/// initialization so the wiring is checked by the compiler.
@MainActor final class ConversionSession {
    /// The event tap is installed and conversion is enabled.
    var isRunning = false
    /// Input held while Notes acknowledges an edit.
    let heldInput = HeldInput()
    var onStatus: ((String) -> Void)?

    /// Notes can be read and edited: conversion is on and no edit is in progress.
    var canEdit: Bool { isRunning && !heldInput.isHolding }

    func report(_ status: String) { onStatus?(status) }
}
