import Foundation
import NIO
import NIOIMAPCore

/** Handler for the SUBSCRIBE command */
final class SubscribeMailboxHandler: BaseIMAPCommandHandler<Void>, IMAPCommandHandler, @unchecked Sendable {
    typealias ResultType = Void
    typealias InboundIn = Response
    typealias InboundOut = Never
}
