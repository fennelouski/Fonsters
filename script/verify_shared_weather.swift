import Foundation
@main struct Verify {
 static func main() throws {
  let now=Date(timeIntervalSince1970:1_792_065_600),clock=now.timeIntervalSince1970*1000,hour=3_600_000.0
  let meta:[String:Any]=["observedAt":clock,"expiresAt":clock+hour,"providerExpiresAt":clock+hour]
  var current=meta; current["condition"]=["code":"Clear","temperatureC":21,"daylight":true]
  var hourly=meta;hourly["hours"]=(0..<24).map{["startAt":floor(clock/hour)*hour+Double($0)*hour,"code":"Clear","temperatureC":21,"daylight":true,"precipitationChance":0] as [String:Any]}
  let point=SharedWeatherSnapshot.Point(latitude:0,longitude:0)
  let attribution:[String:Any]=["serviceName":"Apple Weather","markURL":"https://weatherkit.apple.com/assets/light.png","darkMarkURL":"https://weatherkit.apple.com/assets/dark.png","legalPageURL":"https://weatherkit.apple.com/legal-attribution.html"]
  let value:[String:Any]=["version":2,"location":["latitude":0,"longitude":0],"datasets":["current":current,"hourly":hourly],"expiresAt":clock+hour,"source":"cache","stale":false,"attribution":attribution,"provenance":["provider":"apple-weather","transformed":false]]
  func data(_ v:[String:Any]) throws -> Data {try JSONSerialization.data(withJSONObject:v)}
  let decoded=try SharedWeatherSnapshot.decode(data(value),for:point,now:now)
  precondition(decoded.isValid(for:point,now:now))
  precondition(!decoded.isValid(for:point,now:now.addingTimeInterval(3600)))
  precondition(!decoded.isValid(for:.init(latitude:0,longitude:0.28),now:now))
  precondition(decoded.isValid(for:.init(latitude:0,longitude:0.26),now:now))
  precondition(!decoded.isValid(for:point,now:now.addingTimeInterval(-1)))
  func reject(_ changed:[String:Any]) throws {
   do {_ = try SharedWeatherSnapshot.decode(data(changed),for:point,now:now);fatalError("Invalid weather accepted")}
   catch SharedWeatherSnapshot.Failure.invalidSnapshot {} catch is DecodingError {}
  }
  for (key,v) in [("version",1 as Any),("stale",true),("source","fixture"),("expiresAt",clock+2*hour),("provenance",["provider":"apple-weather","transformed":true])] {var changed=value;changed[key]=v;try reject(changed)}
  for (key,v) in [("markURL","https://evil.invalid/logo"),("darkMarkURL","https://user:pass@weatherkit.apple.com/logo"),("legalPageURL","http://weatherkit.apple.com/legal"),("serviceName","Other")] {var a=attribution;a[key]=v;var changed=value;changed["attribution"]=a;try reject(changed)}
  var missing=value;var noMark=attribution;noMark.removeValue(forKey:"darkMarkURL");missing["attribution"]=noMark;try reject(missing)
  var gap=hourly;var hours=hourly["hours"] as! [[String:Any]];hours[1]["startAt"]=clock+2*hour;gap["hours"]=hours;var changed=value;changed["datasets"]=["current":current,"hourly":gap];try reject(changed)
  var stale=current;stale["observedAt"]=clock-2*hour;changed=value;changed["datasets"]=["current":stale,"hourly":hourly];try reject(changed)
  print("PASS shared weather: original expiry, 30km reuse, clock, branding hosts, both marks, provenance and 24-hour coverage")
 }
}
