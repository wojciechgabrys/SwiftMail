import Foundation
import NIO
import NIOIMAPCore

/** Command to add a mailbox to the server's subscribed set (RFC 3501 §6.3.6). */
struct SubscribeMailboxCommand: IMAPTaggedCommand {
    typealias ResultType = Void
    typealias HandlerType = SubscribeMailboxHandler

    let mailboxName: String

    func validate() throws {
        guard !mailboxName.isEmpty else {
            throw IMAPError.invalidArgument("Mailbox name must not be empty")
        }
    }

    func toTaggedCommand(tag: String) -> TaggedCommand {
        let mailbox = MailboxName(ByteBuffer(string: mailboxName))
        return TaggedCommand(tag: tag, command: .subscribe(mailbox))
    }
}
