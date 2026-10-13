import Foundation

/// Where text a note gained since an earlier character count was inserted:
/// the growth, ending at the caret. Notes stores images and other
/// attachments as `MarkdownRule.attachmentCharacter`.
public enum AttachmentInsertion {
    /// The inserted range, or nil when the note did not grow. At most
    /// `limit` characters before the caret are included.
    public static func insertedRange(from previousCount: Int, to count: Int, caret: Int, limit: Int) -> NSRange? {
        guard count > previousCount, caret > 0, limit > 0 else { return nil }
        let length = min(count - previousCount, limit, caret)
        return NSRange(location: caret - length, length: length)
    }

    /// Whether `text`, the inserted range, holds an attachment.
    public static func containsAttachment(_ text: String) -> Bool {
        text.contains(MarkdownRule.attachmentCharacter)
    }
}
