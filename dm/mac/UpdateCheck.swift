// SPDX-License-Identifier: MIT
import Foundation

// Bowshot's update check, shared by the builder (launcher/mac) and the game app's settings window (dm/mac).
// It asks GitHub for the latest release of xBritik/Bowshot and says whether it is newer than the version that is running. The request is a plain GET with a fixed User-Agent: it sends nothing
// about the Mac, the game, the player or the version in use. It never downloads or installs anything; the answer is a version number and the address of the release page.
enum UpdateCheck {
    struct Release: Equatable { let version: String; let url: URL }
    enum Outcome: Equatable {
        case newer(Release)    // a release newer than the running version
        case current           // the running version is the latest
        case ahead(Release)    // the running version is newer than the latest release (a version in preparation)
        case failed            // no answer, or one that is not a release
    }

    static let endpoint = URL(string: "https://api.github.com/repos/xBritik/Bowshot/releases/latest")!   // the latest published release: drafts and pre-releases are not in it
    static let automaticKey = "bowshot.updateCheck.automatic"
    static let lastCheckKey = "bowshot.updateCheck.last"
    static let interval: TimeInterval = 24 * 3600

    /// A version as numbers and a pre-release tail: "v0.1.3-beta-6" gives ([0, 1, 3], "beta-6"); nil when the head is not dotted numbers
    static func components(_ version: String) -> (core: [Int], pre: String)? {
        var text = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let head = parts.first, !head.isEmpty else { return nil }
        var numbers: [Int] = []
        for piece in head.split(separator: ".", omittingEmptySubsequences: false) {
            guard let n = Int(piece), n >= 0 else { return nil }
            numbers.append(n)
        }
        return (numbers, parts.count > 1 ? parts[1] : "")
    }

    /// 1 when a is newer than b, -1 when older, 0 when the same; nil when one of them is not a version. A release is newer than its own pre-releases (0.1.3 over 0.1.3-beta-6)
    static func compare(_ a: String, _ b: String) -> Int? {
        guard let x = components(a), let y = components(b) else { return nil }
        for i in 0..<max(x.core.count, y.core.count) {
            let p = i < x.core.count ? x.core[i] : 0, q = i < y.core.count ? y.core[i] : 0
            if p != q { return p > q ? 1 : -1 }
        }
        if x.pre == y.pre { return 0 }
        if x.pre.isEmpty { return 1 }
        if y.pre.isEmpty { return -1 }
        switch x.pre.compare(y.pre, options: .numeric) {
        case .orderedAscending: return -1
        case .orderedDescending: return 1
        case .orderedSame: return 0
        }
    }

    /// The latest release out of GitHub's answer: its tag as the version, and the page of the release (only an https address on github.com is taken)
    static func release(from data: Data) -> Release? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["draft"] as? Bool != true, object["prerelease"] as? Bool != true,
              let tag = object["tag_name"] as? String, components(tag) != nil,
              let page = object["html_url"] as? String, let url = URL(string: page), url.scheme == "https", url.host == "github.com" else { return nil }
        return Release(version: tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag, url: url)
    }

    static func outcome(current: String, data: Data) -> Outcome {
        guard let latest = release(from: data), let order = compare(latest.version, current) else { return .failed }
        return order > 0 ? .newer(latest) : order == 0 ? .current : .ahead(latest)
    }

    /// Asks GitHub now; completion runs on the main queue
    static func check(current: String, completion: @escaping (Outcome) -> Void) {
        let configuration = URLSessionConfiguration.ephemeral   // no cookies, no cache, nothing kept
        configuration.timeoutIntervalForRequest = 8
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil
        var request = URLRequest(url: endpoint)
        request.setValue("Bowshot", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession(configuration: configuration).dataTask(with: request) { data, response, _ in
            let answered = (response as? HTTPURLResponse)?.statusCode == 200
            let result: Outcome = answered ? (data.map { outcome(current: current, data: $0) } ?? .failed) : .failed
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// The automatic check is on unless the player turned it off (the builder's menu; DM_UPDATE_CHECK=0 in the game app's env.txt)
    static var automatic: Bool {
        get {
            if ProcessInfo.processInfo.environment["DM_UPDATE_CHECK"] == "0" { return false }
            return UserDefaults.standard.object(forKey: automaticKey) as? Bool ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: automaticKey) }
    }

    /// The automatic check: once a day at most, only while it is on and the running version is known. A failed check leaves the time alone, so the next start asks again
    static func automaticCheck(current: String?, now: Date = Date(), completion: @escaping (Outcome) -> Void) {
        guard automatic, let current, !current.isEmpty else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard now.timeIntervalSince1970 - last >= interval || ProcessInfo.processInfo.environment["BOWSHOT_TEST_VERSION"] != nil else { return }   // the test version asks every time
        check(current: current) { outcome in
            if outcome != .failed { UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastCheckKey) }
            completion(outcome)
        }
    }

    /// The version of the Bowshot that built or runs this app (its Info.plist), nil when it has none. BOWSHOT_TEST_VERSION names another one, to try the banner and the alerts (an interface test)
    static var runningVersion: String? {
        if let test = ProcessInfo.processInfo.environment["BOWSHOT_TEST_VERSION"], !test.isEmpty { return test }
        let v = Bundle.main.object(forInfoDictionaryKey: "BowshotVersion") as? String
        return v?.isEmpty == false ? v : nil
    }
}
