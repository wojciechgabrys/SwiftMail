// MessageInfo+RawEnvelope.swift
// The ENVELOPE strings of a message as the server sent them.

import Foundation
import NIOIMAPCore

extension MessageInfo {
    /// The ENVELOPE strings of a message as the server sent them (RFC 3501 §7.4.2).
    ///
    /// ``MessageInfo/subject`` and the display names in ``MessageInfo/fromAddresses``
    /// are RFC 2047-decoded by SwiftMail. These are the same strings undecoded,
    /// for callers that decode header words their own way.
    public struct RawEnvelope: Codable, Sendable, Hashable {
        /// The `Subject`, undecoded. `nil` when the server sent NIL.
        public var subject: String?

        /// The `From` mailboxes, in order, with undecoded display names. A group
        /// gives its members in its place; its name is dropped.
        public var from: [Address]

        /// The `Message-ID`, exactly as sent, angle brackets included.
        /// ``MessageInfo/messageId`` is rebuilt from it, or `nil` when SwiftMail
        /// cannot read it. `nil` here when the server sent NIL.
        public var messageID: String?

        public init(subject: String? = nil, from: [Address] = [], messageID: String? = nil) {
            self.subject = subject
            self.from = from
            self.messageID = messageID
        }
    }
}

extension MessageInfo.RawEnvelope {
    /// One ENVELOPE address structure, its strings as the server sent them.
    public struct Address: Codable, Sendable, Hashable {
        /// The display name (`personal`), undecoded. `nil` when the server sent NIL.
        public var name: String?
        /// The local part (`mailbox`). `nil` when the server sent NIL.
        public var mailbox: String?
        /// The domain (`host`). `nil` when the server sent NIL.
        public var host: String?

        public init(name: String? = nil, mailbox: String? = nil, host: String? = nil) {
            self.name = name
            self.mailbox = mailbox
            self.host = host
        }
    }
}

extension MessageInfo.RawEnvelope {
    /// The raw strings of a parsed ENVELOPE.
    init(_ envelope: Envelope) {
        self.init(
            subject: envelope.subject?.stringValue,
            from: Address.mailboxes(in: envelope.from),
            messageID: envelope.messageID.map { String($0) }
        )
    }
}

extension MessageInfo.RawEnvelope.Address {
    /// The mailboxes of an address list in order, a group's members in its place.
    /// Nesting is walked with a stack rather than by recursion, so no depth a
    /// server sends can exhaust the call stack.
    static func mailboxes(in list: [EmailAddressListElement]) -> [Self] {
        var result: [Self] = []
        var pending = Array(list.reversed())
        while let element = pending.popLast() {
            switch element {
                case .singleAddress(let address):
                    result.append(Self(address))
                case .group(let group):
                    pending.append(contentsOf: group.children.reversed())
            }
        }
        return result
    }

    init(_ address: NIOIMAPCore.EmailAddress) {
        self.init(
            name: address.personName?.stringValue,
            mailbox: address.mailbox?.stringValue,
            host: address.host?.stringValue
        )
    }
}
