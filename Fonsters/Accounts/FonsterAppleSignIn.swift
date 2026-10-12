#if os(macOS) || os(iOS)
import Foundation
import CryptoKit
@preconcurrency import AuthenticationServices

/// No email/name scopes. Created only by a future reviewed account composition;
/// the protected screen never instantiates or performs an authorization request.
@MainActor
final class FonsterAppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private var pending: CheckedContinuation<FonsterAccountClient.Credential, Error>?
    private var controller: ASAuthorizationController?
    private var requestID: UUID?
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func credential(nonce: String) async throws -> FonsterAccountClient.Credential {
        guard ProtectedPlayPolicy.allowsAccounts && ProtectedPlayPolicy.allowsThirdPartyRequests
            && FonsterAccountReleaseConfiguration.approvedEndpoint != nil else { throw FonsterAccountClient.Failure.protectedExperience }
        guard pending == nil else { throw FonsterAccountClient.Failure.superseded }
        try Task.checkCancellation()
        let id = UUID()
        requestID = id
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { requestID = nil; continuation.resume(throwing: CancellationError()); return }
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = []
                request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self; controller.presentationContextProvider = self
                self.pending = continuation; self.controller = controller
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor in if self.requestID == id { self.cancel() } }
        }
    }
    func cancel() {
        controller?.cancel()
        finish(.failure(CancellationError()))
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard self.controller === controller else { return }
        guard let value = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = value.identityToken, let code = value.authorizationCode,
              let identityToken = String(data: token, encoding: .utf8), let authorizationCode = String(data: code, encoding: .utf8) else {
            finish(.failure(FonsterAccountClient.Failure.invalidResponse)); return
        }
        finish(.success(.init(identityToken: identityToken, authorizationCode: authorizationCode)))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard self.controller === controller else { return }
        // Never expose provider errors or identity details in UI/logs.
        finish(.failure((error as? ASAuthorizationError)?.code == .canceled ? CancellationError() : FonsterAccountClient.Failure.unavailable))
    }
    private func finish(_ result: Result<FonsterAccountClient.Credential, Error>) {
        let continuation = pending; pending = nil; controller = nil; requestID = nil
        continuation?.resume(with: result)
    }
}
#endif
