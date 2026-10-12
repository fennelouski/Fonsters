import Foundation
// Only compile-time fixture for unrelated biography parsing used by the real
// editorial catalogue. No records, accounts, network or real user data.
nonisolated enum FonsterBiography {
    static func list(from text: String) -> [String] { text.split(separator: ",").map(String.init) }
}
actor Calls { var count=0; func hit() {count += 1} }
@main struct Verify {
    static func main() async throws {
        let calls=Calls()
        let resolver=try FonsterPrivateInterestResolver(endpoint: URL(string:"https://synthetic.invalid/api/private-interests/search")!,
            session:{await calls.hit(); return "synthetic"},transport:{_ in await calls.hit(); throw URLError(.unsupportedURL)})
        do {_ = try await resolver.resolve("Synthetic film",category:.movies);fatalError("protected gate bypassed")}
        catch FonsterPrivateInterestResolver.Failure.protectedExperience {}
        let count=await calls.count
        precondition(count==0,"Protected users touched session or network")
        do {_ = try FonsterPrivateInterestResolver(endpoint:URL(string:"http://synthetic.invalid/api/private-interests/search")!,session:{nil});fatalError("HTTP allowed")}
        catch FonsterPrivateInterestResolver.Failure.invalidConfiguration {}
        precondition(!ProtectedPlayPolicy.allowsAccounts && !ProtectedPlayPolicy.allowsThirdPartyRequests && !ProtectedPlayPolicy.allowsPublicSocialProfiles)
        let now=Date(timeIntervalSince1970: 1_700_000_000)
        let record: [String: Any] = ["id":"00000000-0000-4000-8000-000000000000", "source":"wikipedia", "sourceID":"en:1", "title":"Synthetic film", "url":"https://en.wikipedia.org/?curid=1", "detail":"Synthetic", "approval":"unreviewed", "verification":["method":"provider-api","checkedAt":"2023-11-14T22:13:20.000Z"]]
        func data(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject:["version":1,"records":[value]]) }
        let duplicate = try JSONSerialization.data(withJSONObject:["version":1,"records":[record,record]])
        do { _ = try FonsterPrivateInterestResolver.entities(duplicate,category:.movies,now:now); fatalError("duplicate canonical IDs accepted") }
        catch FonsterPrivateInterestResolver.Failure.invalidResponse {}
        let found=try FonsterPrivateInterestResolver.entities(data(record),category:.movies,now:now)
        precondition(found.count==1 && found[0].title=="Synthetic film")
        for (key,value) in [("source","youtube"),("approval","approved"),("url","http://en.wikipedia.org"),("url","https://evil.invalid"),("title","bad\u{0000}title")] {
            var forged=record;forged[key]=value
            do {_ = try FonsterPrivateInterestResolver.entities(data(forged),category:.movies,now:now);fatalError("unsafe canonical record accepted")}
            catch FonsterPrivateInterestResolver.Failure.invalidResponse {}
        }
        do {_ = try FonsterPrivateInterestResolver.entities(data(record),category:.movies,now:now.addingTimeInterval(3600));fatalError("expired record accepted")}
        catch FonsterPrivateInterestResolver.Failure.invalidResponse {}
        let endpoint=URL(string:"https://synthetic.invalid/api/private-interests/search")!
        let redirected=HTTPURLResponse(url:URL(string:"https://evil.invalid/api/private-interests/search")!,statusCode:200,httpVersion:nil,headerFields:nil)!
        precondition(!FonsterPrivateInterestResolver.responseMatches(redirected,endpoint:endpoint))
        let http=HTTPURLResponse(url:endpoint,statusCode:302,httpVersion:nil,headerFields:nil)!
        let session=URLSession(configuration:.ephemeral)
        let task=session.dataTask(with:endpoint)
        let deniedRedirect=await withCheckedContinuation { continuation in
            FonsterAccountRedirectGuard().urlSession(session,task:task,willPerformHTTPRedirection:http,newRequest:URLRequest(url:redirected.url!)) { next in continuation.resume(returning:next == nil) }
        }
        precondition(deniedRedirect)
        session.invalidateAndCancel()
        print("PASS: fractional JavaScript timestamps; redirected endpoint rejected; redirect delegate forwards no request")
        print("PASS: canonical source/host/expiry/schema rejection; protected default transport calls=0")
        print("PASS: native account/provider policy blocks session and transport; invalid HTTP endpoint rejected; public social disabled")
    }
}
