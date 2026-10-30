import Foundation
import NIO
import NIOEmbedded
@preconcurrency import NIOIMAP
@preconcurrency import NIOIMAPCore
import Testing
@testable import SwiftMail

/// `MessageInfo.rawEnvelope` keeps the ENVELOPE strings as the server sent them,
/// before SwiftMail decodes or rebuilds anything, for callers with their own
/// RFC 2047 decoder.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct RawEnvelopeTests {
    @Test
    func keepsTheEncodedSubjectNextToTheDecodedOne() async throws {
        let envelope = "(NIL \"=?UTF-8?B?WmHFvMOzxYLEhw==?= gęślą\" NIL NIL NIL NIL NIL NIL NIL NIL)"
        let infos = try await fetch(envelope: envelope)

        #expect(infos[0].subject == "Zażółć gęślą")
        #expect(infos[0].rawEnvelope?.subject == "=?UTF-8?B?WmHFvMOzxYLEhw==?= gęślą")
    }

    @Test
    func keepsTheEncodedFromNameAndTheAddressParts() async throws {
        let from = "((\"=?ISO-8859-2?Q?Pawe=B3?= Kowalski\" NIL \"pawel\" \"example.pl\")"
            + "(NIL NIL \"bot\" \"example.com\"))"
        let infos = try await fetch(envelope: "(NIL NIL \(from) NIL NIL NIL NIL NIL NIL NIL)")

        #expect(infos[0].fromAddresses.first?.mailboxes.first?.name == "Paweł Kowalski")
        #expect(infos[0].rawEnvelope?.from == [
            .init(name: "=?ISO-8859-2?Q?Pawe=B3?= Kowalski", mailbox: "pawel", host: "example.pl"),
            .init(name: nil, mailbox: "bot", host: "example.com")
        ])
    }

    @Test
    func givesTheMembersOfAFromGroupInOrder() async throws {
        let from = "((NIL NIL \"=?UTF-8?Q?Zesp=C3=B3=C5=82?=\" NIL)(\"Ann\" NIL \"ann\" \"example.com\")"
            + "(NIL NIL \"bob\" \"example.com\")(NIL NIL NIL NIL))"
        let infos = try await fetch(envelope: "(NIL NIL \(from) NIL NIL NIL NIL NIL NIL NIL)")

        #expect(infos[0].rawEnvelope?.from == [
            .init(name: "Ann", mailbox: "ann", host: "example.com"),
            .init(name: nil, mailbox: "bob", host: "example.com")
        ])
    }

    @Test
    func keepsTheMessageIDAsSentEvenWhenSwiftMailCannotReadIt() async throws {
        let unbracketed = try await fetch(envelope: "(NIL NIL NIL NIL NIL NIL NIL NIL NIL \"abc@example.com\")")
        #expect(unbracketed[0].rawEnvelope?.messageID == "abc@example.com")

        let unreadable = try await fetch(envelope: "(NIL NIL NIL NIL NIL NIL NIL NIL NIL \"not an id\")")
        #expect(unreadable[0].messageId == nil)
        #expect(unreadable[0].rawEnvelope?.messageID == "not an id")
    }

    @Test
    func survivesCodableAndIsAbsentFromOlderData() throws {
        var info = MessageInfo(sequenceNumber: SequenceNumber(1))
        let from: [MessageInfo.RawEnvelope.Address] = [.init(name: "n", mailbox: "m", host: "h")]
        info.rawEnvelope = .init(subject: "=?UTF-8?Q?a?=", from: from, messageID: "<i>")
        let decoded = try JSONDecoder().decode(MessageInfo.self, from: JSONEncoder().encode(info))
        #expect(decoded.rawEnvelope == info.rawEnvelope)

        let older = try JSONDecoder().decode(MessageInfo.self, from: Data(#"{"sequenceNumber":1}"#.utf8))
        #expect(older.rawEnvelope == nil)
    }

    private func fetch(envelope: String) async throws -> [MessageInfo] {
        let channel = try await NIOAsyncTestingChannel.withIMAPClientHandler()
        let promise = channel.eventLoop.makePromise(of: [MessageInfo].self)
        try await channel.pipeline.addHandler(FetchMessageInfoHandler(commandTag: "A001", promise: promise))

        let command = TaggedCommand(tag: "A001", command: .noop)
        try await channel.writeAndFlush(IMAPClientHandler.OutboundIn.part(.tagged(command)))
        _ = try await channel.readOutbound(as: ByteBuffer.self)

        for line in ["* 1 FETCH (UID 7 ENVELOPE \(envelope))\r\n", "A001 OK FETCH completed\r\n"] {
            try await channel.writeInbound(ByteBuffer(string: line))
        }
        return try await promise.futureResult.get()
    }
}
