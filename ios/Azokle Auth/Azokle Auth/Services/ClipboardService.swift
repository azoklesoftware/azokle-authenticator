//
//  ClipboardService.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import UIKit

public final class ClipboardService {
    public static let shared = ClipboardService()

    private var clearTimer: Timer?
    private var lastCopiedCode: String?

    private init() {}

    public func copy(code: String, clearAfter seconds: TimeInterval = 30) {
        lastCopiedCode = code
        let expirationDate = Date().addingTimeInterval(seconds)

        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": code]],
            options: [
                .localOnly: true,
                .expirationDate: expirationDate
            ]
        )

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Local timer backup
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if UIPasteboard.general.string == self.lastCopiedCode {
                UIPasteboard.general.string = ""
            }
            self.lastCopiedCode = nil
        }
    }
}
