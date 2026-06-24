import Foundation
import CryptoKit
import Security

enum SecurityPinningMode {
    case backend
    case none
}

enum NetworkSecurityError: Error {
    case insecureURL
}

final class SecureNetworkTransport: NSObject {
    static let shared = SecureNetworkTransport()

    private lazy var backendSession: URLSession = {
        URLSession(
            configuration: Self.makeConfiguration(),
            delegate: self,
            delegateQueue: nil
        )
    }()

    private lazy var standardSession: URLSession = {
        URLSession(configuration: Self.makeConfiguration())
    }()

    func data(for request: URLRequest, pinning: SecurityPinningMode) async throws -> (Data, URLResponse) {
        guard request.url?.scheme?.lowercased() == "https" else {
            throw NetworkSecurityError.insecureURL
        }

        switch pinning {
        case .backend:
            return try await backendSession.data(for: request)
        case .none:
            return try await standardSession.data(for: request)
        }
    }

    private static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }
}

extension SecureNetworkTransport: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard host == Config.backendBaseURL.host else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(trust, policy)

        guard SecTrustEvaluateWithError(trust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let pinnedHashes = Set(Config.backendPinnedCertificateSHA256)
        guard !pinnedHashes.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let certificateCount = SecTrustGetCertificateCount(trust)
        for index in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(trust, index) else { continue }
            let certificateData = SecCertificateCopyData(certificate) as Data
            let digest = SHA256.hash(data: certificateData)
            let hash = Data(digest).base64EncodedString()

            if pinnedHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
