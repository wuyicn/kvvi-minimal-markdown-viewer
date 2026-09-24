import Foundation
import WebKit

enum ReaderNavigationDecision: Equatable {
    case allow
    case cancel
    case openExternally(URL)
}

enum NavigationPolicy {
    static func decision(
        for url: URL?,
        navigationType: WKNavigationType
    ) -> ReaderNavigationDecision {
        guard let url, let scheme = url.scheme?.lowercased() else {
            return .cancel
        }
        if scheme == "about" || scheme == "kewei-image" {
            return .allow
        }
        if ["http", "https"].contains(scheme), navigationType == .linkActivated {
            return .openExternally(url)
        }
        return .cancel
    }
}
