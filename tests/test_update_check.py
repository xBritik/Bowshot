import shutil, subprocess, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'dm/mac/UpdateCheck.swift'

# The update check's decisions (which version is newer, which answer of GitHub counts), compiled with the real source and run: they must not depend on the network
HARNESS = r'''
import Foundation
func cmp(_ a: String, _ b: String) -> String { UpdateCheck.compare(a, b).map(String.init) ?? "nil" }
func json(_ tag: String, draft: Bool = false, pre: Bool = false, url: String = "https://github.com/xBritik/Bowshot/releases/tag/v0.1.4") -> Data {
    try! JSONSerialization.data(withJSONObject: ["tag_name": tag, "html_url": url, "draft": draft, "prerelease": pre])
}
func out(_ o: UpdateCheck.Outcome) -> String {
    switch o { case .newer(let r): return "newer \(r.version)"; case .current: return "current"; case .ahead(let r): return "ahead \(r.version)"; case .failed: return "failed" }
}
print(cmp("0.1.3", "0.1.2"), cmp("0.1.3", "0.1.3-beta-6"), cmp("0.1.3-beta-6", "0.1.3"), cmp("0.1.3-beta-10", "0.1.3-beta-9"), cmp("0.1", "0.1.0"), cmp("v0.2.0", "0.1.9"), cmp("0.1.10", "0.1.9"), cmp("x", "0.1"), cmp("0.1.3", ""))
print(out(UpdateCheck.outcome(current: "0.1.3", data: json("v0.1.4"))), out(UpdateCheck.outcome(current: "0.1.4", data: json("v0.1.4"))), out(UpdateCheck.outcome(current: "0.2.0", data: json("v0.1.4"))), out(UpdateCheck.outcome(current: "0.1.4-beta-2", data: json("v0.1.4"))))
print(out(UpdateCheck.outcome(current: "0.1.3", data: json("v0.1.4", pre: true))), out(UpdateCheck.outcome(current: "0.1.3", data: json("v0.1.4", draft: true))), out(UpdateCheck.outcome(current: "0.1.3", data: json("latest"))))
print(out(UpdateCheck.outcome(current: "0.1.3", data: json("v0.1.4", url: "https://example.com/Bowshot"))), out(UpdateCheck.outcome(current: "0.1.3", data: json("v0.1.4", url: "http://github.com/xBritik/Bowshot"))), out(UpdateCheck.outcome(current: "0.1.3", data: Data("not json".utf8))))
'''


@unittest.skipUnless(shutil.which('swiftc') and sys.platform == 'darwin', 'needs swiftc on a Mac')
class UpdateCheck(unittest.TestCase):
    def test_versions_and_answers(self):
        d = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        (d / 'main.swift').write_text(HARNESS)
        subprocess.run(['xcrun', 'swiftc', '-O', str(d / 'main.swift'), str(SOURCE), '-o', str(d / 'check')], check=True, capture_output=True)
        lines = subprocess.run([str(d / 'check')], check=True, capture_output=True, text=True).stdout.strip().split('\n')
        self.assertEqual(lines, [
            '1 1 -1 1 0 1 1 nil nil',                                  # numbers by value (0.1.10 over 0.1.9), a release over its pre-releases, beta-10 over beta-9, not a version: nil
            'newer 0.1.4 current ahead 0.1.4 newer 0.1.4',             # a beta of 0.1.4 is older than the release 0.1.4
            'failed failed failed',                                    # a pre-release, a draft, a tag that is not a version
            'failed failed failed',                                    # a page outside github.com, not https, not JSON
        ])

    def test_the_request_carries_nothing_about_the_user(self):   # one GET, a fixed User-Agent, no version, no identifiers
        text = SOURCE.read_text()
        self.assertEqual(text.count('setValue('), 2); self.assertIn('setValue("Bowshot", forHTTPHeaderField: "User-Agent")', text)
        self.assertNotIn('httpBody', text); self.assertNotIn('URLQueryItem', text); self.assertNotIn('NSUserName', text); self.assertNotIn('hostName', text)


if __name__ == '__main__':
    unittest.main()
