import Foundation
import NIO
import NIOEmbedded
@preconcurrency import NIOIMAP
import Testing
@testable import SwiftMail

@Suite(.serialized, .timeLimit(.minutes(1)))
struct SubscribeMailboxCommandTests {
    @Test
    func rejectsEmptyName() {
        #expect(throws: IMAPError.self) { try SubscribeMailboxCommand(mailboxName: "").validate() }
    }

    @Test
    func serializesSubscribe() async throws {
        let channel = try await NIOAsyncTestingChannel.withIMAPClientHandler()
        let tagged = SubscribeMailboxCommand(mailboxName: "Folders/Work").toTaggedCommand(tag: "S001")
        try await channel.writeAndFlush(IMAPClientHandler.OutboundIn.part(CommandStreamPart.tagged(tagged)))
        var buffer = try #require(try await channel.readOutbound(as: ByteBuffer.self))
        #expect(buffer.readString(length: buffer.readableBytes) == "S001 SUBSCRIBE \"Folders/Work\"\r\n")
    }
}

#if os(macOS)
    @Suite(.serialized, .timeLimit(.minutes(1)))
    struct SubscribeMailboxTests {
        @Test
        func subscribesTheMailboxInsideThePersonalNamespace() async throws {
            try await withServer { server, testServer in
                try await server.subscribeMailbox("Work")
                #expect(testServer.commandLog.contains { $0.hasSuffix(" SUBSCRIBE \"INBOX.Work\"") })
            }
        }

        @Test
        func throwsWhenTheServerRefuses() async throws {
            try await withServer { server, _ in
                let error = await #expect(throws: IMAPError.self) { try await server.subscribeMailbox("Refused") }
                guard case .commandFailed(let reason) = error else {
                    Issue.record("Expected commandFailed, got \(String(describing: error))")
                    return
                }
                #expect(reason.contains("No such mailbox"))
            }
        }

        private func withServer(_ body: (SwiftMail.IMAPServer, IMAPTestServer) async throws -> Void) async throws {
            let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let maildir = tempRoot.appendingPathComponent("Maildir")
            try FileManager.default.createDirectory(at: maildir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempRoot) }

            let testServer = try IMAPTestServer(
                personalNamespacePrefix: "INBOX.",
                namespaceDelimiter: ".",
                maildirURL: maildir
            )
            try testServer.start()
            try await testServer.run {
                let server = SwiftMail.IMAPServer(host: "127.0.0.1", port: testServer.port, useTLS: false)
                try await server.connect()
                try await server.login(username: "testuser", password: "testpass")
                try await body(server, testServer)
                try await server.disconnect()
            }
        }
    }
#endif
