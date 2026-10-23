import SwiftUI
import AVFoundation
import AudioToolbox
import UserNotifications

struct TimerPlan: Codable {
    var subject: UUID
    var start: Date
    var study: Double
    var rest: Double
    var sets: Int
    var set = 1
    var phase = "waiting"
    var remaining: Double?
    var pausedKind: String?
}
struct RepeatTask: Codable, Identifiable {var id = UUID(); var title: String; var weekdays: [Int]; var subject: UUID?}
struct StudyBook: Codable, Identifiable {var id = UUID(); var title: String; var subject: UUID?; var units: Int; var target: Int; var completed: [Int] = []}
struct ActiveRoute: Codable {var id: String; var leg: Int}
struct SpecialRoute: Codable, Identifiable {
    var id: String; var w: String; var name: String; var desc: String; var stops: [String]; var season: [Int]?
    static let bundled: [SpecialRoute] = {
        guard let url=Bundle.main.url(forResource:"routes",withExtension:"json"),let data=try? Data(contentsOf:url) else {return []}
        return (try? JSONDecoder().decode([SpecialRoute].self,from:data)) ?? []
    }()
    var world: String { w == "w" ? "world" : "kr" }
    var icon: String {
        switch id {
        case "east","south","west","summersea","medi","pacific": return "water.waves"
        case "ancient","silk": return "building.columns"
        case "sakura","blossom": return "camera.macro"
        case "maple": return "leaf"
        case "snowfl","nordic": return "snowflake"
        case "xmasmkt": return "gift"
        default: return "point.topleft.down.to.point.bottomright.curvepath"
        }
    }
}
struct ExperienceState: Codable {
    var goalMinutes = 0
    var theme = "system"
    var accent = "#3182F6"
    var dayStart = 0
    var weekStart = 2
    var ddayName = ""
    var dday: Date?
    var travelEnabled = true
    var showBooks = false
    var showPVA = false
    var sound = true
    var notifications = false
    var warnFive = true
    var memo = false
    var vibration = true
    var arrivalSound = true
    var voice = false
    var window = true
    var stampStyle = "stamp"
    var plan: TimerPlan?
    var repeats: [RepeatTask] = []
    var books: [StudyBook] = []
    var route: ActiveRoute?
    var completedRoutes: [String: Date] = [:]
    var welcomeDone = false
    var passportName = "투어디 여권"
    var passportColor = "#173E79"
    var passportEmblem = "globe.asia.australia.fill"
    var postcards: [String:String] = [:]
    var badges: [String:Date] = [:]
}

@MainActor
enum NativeEffects {
    static let speech = AVSpeechSynthesizer()
    static func announce(_ text: String) {
        let utterance = AVSpeechUtterance(string:text)
        utterance.voice = AVSpeechSynthesisVoice(language:"ko-KR")
        speech.speak(utterance)
    }
}

extension NativeStore {
    var prefs: ExperienceState {state.experience ?? ExperienceState()}
    var accent: Color {Color(hex:prefs.accent)}
    var routes: [SpecialRoute] {
        SpecialRoute.bundled
    }
    func configure(_ update: (inout ExperienceState) -> Void) {
        commit { s in var p=s.experience ?? ExperienceState(); update(&p); s.experience=p }
    }
    func preference<Value>(_ path: WritableKeyPath<ExperienceState,Value>) -> Binding<Value> {
        Binding(get:{self.prefs[keyPath:path]},set:{value in self.configure {$0[keyPath:path]=value}})
    }
    func subjectColor(_ id: UUID) -> Color {Color(hex:state.subjects.first {$0.id==id}?.color ?? prefs.accent)}
    func studyDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for:date.addingTimeInterval(-Double(prefs.dayStart)*3600))
    }
    func sessions(on date: Date) -> [StudySession] {
        let start=Calendar.current.date(byAdding:.hour,value:prefs.dayStart,to:studyDay(date)) ?? date
        let end=Calendar.current.date(byAdding:.day,value:1,to:start) ?? start.addingTimeInterval(86400)
        var sessions=state.sessions
        if let run=state.running {sessions.append(StudySession(subject:run.subject,start:run.start,end:max(run.start,min(Date(),run.end ?? Date())),kind:run.kind))}
        return sessions.filter {$0.end>start && $0.start<end}.map {s in var s=s; s.start=max(start,s.start); s.end=min(end,s.end); return s}
    }
    func seconds(on date: Date, subject: UUID? = nil, kind: String = "study") -> Double {
        sessions(on:date).filter {($0.kind ?? "study")==kind && (subject==nil || $0.subject==subject)}.reduce(0){$0+$1.end.timeIntervalSince($1.start)}
    }
    private func close(_ s: inout NativeState, at date: Date) {
        guard let run=s.running else {return}
        let end=max(run.start,min(date,run.end ?? date))
        if end>run.start {s.sessions.append(StudySession(subject:run.subject,start:run.start,end:end,kind:run.kind))}
        s.running=nil
        let eligible=s.sessions.filter {($0.kind ?? "study")=="study" && $0.manual != true}.reduce(0){$0+$1.end.timeIntervalSince($1.start)}
        if s.firstReward=="pending" && eligible>=1800 {s.firstReward="ready"}
    }
    func toggleSubject(_ subject: Subject) {
        updateClock()
        let same=state.running?.subject==subject.id && (state.running?.kind ?? "study")=="study"
        if same, prefs.plan != nil {pausePlan();return}
        if prefs.plan?.phase=="paused", prefs.plan?.subject==subject.id {resumePlan();return}
        if commit({s in
            close(&s,at:Date())
            if !same {s.running=RunningStudy(subject:subject.id,start:Date(),kind:"study")}
            var p=s.experience ?? ExperienceState(); p.plan=nil; s.experience=p
        }) {refreshNotifications();settleJourney()}
    }
    func offTime(_ kind: String) {
        let same=state.running?.kind==kind
        if prefs.plan != nil && prefs.plan?.phase != "paused" {pausePlan()}
        commit {s in
            let subject=s.running?.subject ?? s.subjects.first?.id ?? UUID()
            close(&s,at:Date())
            if !same {s.running=RunningStudy(subject:subject,start:Date(),kind:kind)}
        }
        refreshNotifications()
    }
    func finishAll() {
        if commit({s in close(&s,at:Date());var p=s.experience ?? ExperienceState();p.plan=nil;s.experience=p}) {
            refreshNotifications();settleJourney()
            if prefs.memo,let last=state.sessions.last,(last.kind ?? "study")=="study",last.end.timeIntervalSince(last.start)>=60 {memoSession=last.id}
        }
    }
    func schedule(subject: UUID, start: Date, minutes: Int, sets: Int, rest: Int) {
        guard state.subjects.contains(where:{$0.id==subject}),minutes>0,sets>0,sets<=12 else {return}
        if commit({s in
            close(&s,at:Date())
            var p=s.experience ?? ExperienceState()
            p.plan=TimerPlan(subject:subject,start:start,study:Double(minutes*60),rest:Double(rest*60),sets:sets)
            s.experience=p
        }) {updateClock();refreshNotifications()}
    }
    func pausePlan() {
        guard var plan=prefs.plan,let run=state.running,let end=run.end else {return}
        plan.remaining=max(0,end.timeIntervalSinceNow);plan.pausedKind=run.kind ?? "study";plan.phase="paused"
        if commit({s in close(&s,at:Date());var p=s.experience ?? ExperienceState();p.plan=plan;s.experience=p}) {refreshNotifications();settleJourney()}
    }
    func resumePlan() {
        guard var plan=prefs.plan,let remaining=plan.remaining else {return}
        plan.phase=plan.pausedKind ?? "study";plan.remaining=nil
        if commit({s in close(&s,at:Date());s.running=RunningStudy(subject:plan.subject,start:Date(),kind:plan.phase,end:Date().addingTimeInterval(remaining));var p=s.experience ?? ExperienceState();p.plan=plan;s.experience=p}) {refreshNotifications()}
    }
    func extendPlan() {
        guard state.running?.end != nil else {return}
        commit {s in if var run=s.running,let end=run.end {run.end=end.addingTimeInterval(300);s.running=run}}
        refreshNotifications()
    }
    func updateClock() {
        clockDate=Date()
        guard var plan=prefs.plan else {settleJourney();return}
        let now=Date()
        guard plan.phase != "paused" else {settleJourney();return}
        let due=plan.phase=="waiting" ? plan.start<=now : (state.running?.end.map {$0<=now} ?? false)
        guard due else {settleJourney();return}
        if commit({s in
            if plan.phase=="waiting" {
                close(&s,at:plan.start);plan.phase="study"
                s.running=RunningStudy(subject:plan.subject,start:plan.start,kind:"study",end:plan.start.addingTimeInterval(plan.study))
            }
            var iterations=0
            while let run=s.running,let end=run.end,end<=now,iterations<32 {
                iterations+=1;close(&s,at:end)
                if plan.phase=="study" && plan.set>=plan.sets {break}
                if plan.phase=="study" && plan.rest>0 {
                    plan.phase="rest";s.running=RunningStudy(subject:plan.subject,start:end,kind:"rest",end:end.addingTimeInterval(plan.rest))
                } else {
                    plan.phase="study";plan.set+=1
                    s.running=RunningStudy(subject:plan.subject,start:end,kind:"study",end:end.addingTimeInterval(plan.study))
                }
            }
            var p=s.experience ?? ExperienceState();p.plan=s.running==nil ? nil : plan;s.experience=p
        }) {refreshNotifications();settleJourney()}
    }
    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]) { granted,_ in
            Task {@MainActor in self.configure {$0.notifications=granted};self.refreshNotifications()}
        }
    }
    func refreshNotifications() {
        let center=UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:["tourdy-start","tourdy-end","tourdy-warning"]+(0..<40).map {"tourdy-plan-\($0)"})
        guard prefs.notifications else {return}
        func add(_ id: String,_ title: String,_ date: Date) {
            guard date.timeIntervalSinceNow>1 else {return}
            let content=UNMutableNotificationContent();content.title=title;content.body="TOURDY에서 다음 공부를 이어가세요."
            if prefs.sound {content.sound = .default}
            let trigger=UNTimeIntervalNotificationTrigger(timeInterval:max(1,date.timeIntervalSinceNow),repeats:false)
            center.add(UNNotificationRequest(identifier:id,content:content,trigger:trigger))
        }
        if let end=state.running?.end {
            add("tourdy-end","세션을 마쳤어요",end)
            if prefs.warnFive {add("tourdy-warning","세션 종료까지 5분 남았어요",end.addingTimeInterval(-300))}
        }
        if let plan=prefs.plan,plan.phase != "paused" {
            var edge:Date
            var index=0
            if plan.phase=="waiting" {edge=plan.start}
            else if let end=state.running?.end {edge=end}
            else {return}
            if plan.phase=="study" {edge=edge.addingTimeInterval(plan.rest)}
            let firstSet=plan.phase=="waiting" ? plan.set : plan.set+1
            guard firstSet<=plan.sets else {return}
            for set in firstSet...plan.sets {
                add("tourdy-plan-\(index)","\(set)세트 공부 시작",edge);index+=1
                edge=edge.addingTimeInterval(plan.study)
                add("tourdy-plan-\(index)","\(set)세트 공부 완료",edge);index+=1
                edge=edge.addingTimeInterval(plan.rest)
            }
        }
    }
    func playArrival() {
        if prefs.vibration {UIImpactFeedbackGenerator(style:.light).impactOccurred()}
        if prefs.arrivalSound {AudioServicesPlaySystemSound(1025)}
        if prefs.voice,let arrival {NativeEffects.announce("이번 도착지는 \(place(arrival.place)?.name ?? "목적지")입니다.")}
    }
    func routeOpen(_ r: SpecialRoute) -> Bool {r.season?.contains(Calendar.current.component(.month,from:Date())) ?? true}
    func startRoute(_ route: SpecialRoute) {
        guard routeOpen(route),unlocked(route.world),state.positions[route.world]==route.stops.first,prefs.route==nil,state.journey==nil,route.stops.count>1,let to=place(route.stops[1]) else {return}
        let cabin=route.world=="kr" ? 1 : 2,price=fare(to,cabin:route.world=="kr" ? 1 : 2)
        if commit({s in var p=s.experience ?? ExperienceState();p.route=ActiveRoute(id:route.id,leg:0);s.experience=p;s.journey=Journey(from:route.stops[0],to:to.id,cost:price,premium:true,cabin:cabin)}) {settleJourney()}
    }
    func advanceRoute(_ s: inout NativeState,arrived: Place) {
        var p=s.experience ?? ExperienceState()
        guard var active=p.route,let route=routes.first(where:{$0.id==active.id}),active.leg+1<route.stops.count,route.stops[active.leg+1]==arrived.id else {return}
        active.leg+=1
        if active.leg==route.stops.count-1 {p.completedRoutes[route.id]=Date();p.route=nil}
        else if let next=place(route.stops[active.leg+1]) {
            let base=route.world=="kr" ? max(30,distance(arrived,next).rounded()) : max(30,(distance(arrived,next)/800*60).rounded())
            s.journey=Journey(from:arrived.id,to:next.id,cost:(base*(route.world=="kr" ? 1.3 : 1.6)).rounded(),premium:true,cabin:route.world=="kr" ? 1 : 2)
            p.route=active
        }
        s.experience=p
    }
    func materializeRepeats(on date: Date) {
        let day=studyDay(date),weekday=Calendar.current.component(.weekday,from:day)
        let missing=prefs.repeats.filter {r in r.weekdays.contains(weekday) && !state.tasks.contains(where:{$0.title==r.title && $0.day.map {Calendar.current.isDate($0,inSameDayAs:day)} == true})}
        guard !missing.isEmpty else {return}
        commit {s in for r in missing {s.tasks.append(Todo(title:r.title,day:day,subject:r.subject))}}
    }
    func fare(_ place: Place,cabin: Int) -> Double {
        guard place.world != "space" else {return place.cost}
        return (cost(place,premium:false) * ([1.0,1.3,1.6][min(2,max(0,cabin))])).rounded()
    }
    func checkIn(_ place: Place,cabin: Int,goal: Date?) {
        guard unlocked(place.world),zoneOpen(place),state.journey==nil,
              let from=state.positions[place.world],from != place.id else {return}
        if commit({$0.journey=Journey(from:from,to:place.id,cost:fare(place,cabin:cabin),premium:cabin>0,cabin:cabin,goal:goal)}) {settleJourney()}
    }
    func decodeLegacy(_ data: Data) throws -> NativeState {
        guard let raw=try JSONSerialization.jsonObject(with:data) as? [String:Any],let subjects=raw["subjects"] as? [[String:Any]],raw["sessions"] is [[String:Any]] else {throw CocoaError(.fileReadCorruptFile)}
        var next=NativeState(),ids:[String:UUID]=[:]
        let symbols=["book":"book.fill","fx":"function","globe":"globe","atom":"atom","pen":"pencil","grad":"graduationcap.fill"]
        for subject in subjects {
            guard let oldID=subject["id"] as? String,let name=subject["name"] as? String else {throw CocoaError(.fileReadCorruptFile)}
            let id=UUID(uuidString:oldID) ?? UUID();ids[oldID]=id
            next.subjects.append(Subject(id:id,name:name,color:subject["color"] as? String,icon:symbols[subject["icon"] as? String ?? "book"] ?? "book.fill",goal:subject["goal"] as? Double))
        }
        func subjectID(_ value: Any?) -> UUID {
            let key=value as? String ?? "unassigned"
            if let id=ids[key] {return id}
            let id=UUID();ids[key]=id
            next.subjects.append(Subject(id:id,name:"이전 과목",icon:"book.fill"))
            return id
        }
        for s in raw["sessions"] as? [[String:Any]] ?? [] {
            guard let start=s["start"] as? Double,let end=s["end"] as? Double,start.isFinite,end.isFinite,end>=start else {throw CocoaError(.fileReadCorruptFile)}
            let id=subjectID(s["sid"])
            next.sessions.append(StudySession(subject:id,start:Date(timeIntervalSince1970:start/1000),end:Date(timeIntervalSince1970:end/1000),kind:s["kind"] as? String,manual:(s["manual"] as? Bool == true || s["noMile"] as? Bool == true || s["ex"] as? Bool == true),memo:s["memo"] as? String))
        }
        if let run=raw["running"] as? [String:Any],let start=run["start"] as? Double {
            next.running=RunningStudy(subject:subjectID(run["sid"]),start:Date(timeIntervalSince1970:start/1000),kind:run["kind"] as? String,end:(run["end"] as? Double).map {Date(timeIntervalSince1970:$0/1000)})
        }
        let dateFormat=DateFormatter();dateFormat.locale=Locale(identifier:"en_US_POSIX");dateFormat.dateFormat="yyyy-MM-dd"
        for (day,tasks) in raw["tasks"] as? [String:[[String:Any]]] ?? [:] {
            for task in tasks {
                guard let title=task["text"] as? String ?? task["title"] as? String else {continue}
                next.tasks.append(Todo(title:title,done:task["done"] as? Bool ?? false,day:dateFormat.date(from:day),subject:(task["sid"] as? String).flatMap {ids[$0]},estimate:task["est"] as? Double))
            }
        }
        if let t=raw["travel"] as? [String:Any] {
            let kr=t["kr"] as? [String:Any] ?? [:],space=t["sp2"] as? [String:Any] ?? [:]
            next.used=t["used"] as? Double ?? 0
            next.home=kr["home"] as? String ?? "seoul"
            next.positions=["kr":kr["at"] as? String ?? "seoul","world":t["at"] as? String ?? "KR","space":space["at"] as? String ?? "earth"]
            for (world,list,home) in [("kr",kr["done"],next.home),("world",t["stamps"],"KR"),("space",space["done"],"earth")] {
                var from=home
                for stamp in list as? [[String:Any]] ?? [] {
                    guard let id=stamp["c"] as? String,place(id)?.world==world else {throw CocoaError(.fileReadCorruptFile)}
                    let date=(stamp["d"] as? String).flatMap {dateFormat.date(from:$0)} ?? Date()
                    next.stamps.append(Stamp(place:id,from:from,date:date,premium:(stamp["tier"] as? Int ?? 0)>0,free:stamp["free"] as? Bool ?? false));from=id
                }
            }
            for (world,obj) in [("kr",kr),("world",t),("space",space)] {
                if let to=obj["to"] as? String,let p=place(to),let from=next.positions[world] {
                    let cls=obj["cls"] as? Int ?? 0
                    let base:Double
                    if world=="space" {base=p.cost}
                    else if let a=place(from) {let km=distance(a,p);base=world=="kr" ? max(30,km.rounded()) : max(30,(km/800*60).rounded())}
                    else {throw CocoaError(.fileReadCorruptFile)}
                    next.journey=Journey(from:from,to:to,cost:(base*[1.0,1.3,1.6][min(2,max(0,cls))]).rounded(),premium:cls>0,cabin:cls)
                    break
                }
            }
        }
        let reward=raw["firstTrip"] as? [String:Any]
        let total=next.sessions.filter {($0.kind ?? "study")=="study" && $0.manual != true}.reduce(0){$0+$1.end.timeIntervalSince($1.start)}
        next.firstReward=reward?["status"] as? String ?? (total>=1800 ? "ready" : "pending")
        var preferences=ExperienceState()
        preferences.goalMinutes=raw["goal"] as? Int ?? 0;preferences.dayStart=raw["dayStart"] as? Int ?? 0
        let theme=raw["theme"] as? [String:Any] ?? [:]
        preferences.theme=theme["mode"] as? String ?? "system"
        preferences.welcomeDone = !next.subjects.isEmpty
        let extra=raw["extra"] as? [String:Any] ?? [:]
        preferences.showBooks=extra["books"] as? Bool ?? false;preferences.showPVA=extra["pva"] as? Bool ?? false
        next.experience=preferences
        return next
    }
    func transport(_ from: String,_ to: String) -> (String,String) {
        guard let a=place(from),let b=place(to) else {return ("airplane","항공편")}
        if b.world=="space" {return ("sparkles","우주선")}
        if b.world=="world" {
            let islands=Set("IS IE MT CY JP TW PH ID LK MV TL MG MU SC KM CV ST CU JM HT DO BS BB TT DM LC VC GD AG KN AU NZ FJ PG SB VU WS TO KI TV NR MH FM PW BH SG BN GB".split(separator:" ").map(String.init))
            let cruise=Set("IS IE MT CY JP TW PH ID LK MV TL MG MU SC KM CV ST CU JM HT DO BS BB TT DM LC VC GD AG KN NZ FJ PG SB VU WS TO KI TV NR MH FM PW AU AQ XG XE SJ XM XS".split(separator:" ").map(String.init))
            let km=distance(a,b)
            if (cruise.contains(from)||cruise.contains(to)) && km<=2500 {return ("ferry.fill","크루즈")}
            if a.zone==b.zone && [0,2].contains(a.zone) && km<=1300 && !islands.contains(from) && !islands.contains(to) && from != "KR" && to != "KR" {return ("bed.double.fill","야간열차")}
            return ("airplane","항공편")
        }
        if (a.region=="제주") != (b.region=="제주") || [from,to].contains("ulleung") {return ("ferry.fill","여객선")}
        let km=distance(a,b)
        if km<50 {return ("bus.fill",km<25 ? "시내버스" : "시외버스")}
        let hash=(from<to ? from+to : to+from).utf16.reduce(7) {($0*31+Int($1))%99991}
        return ("tram.fill",km>=180 ? (hash%2==1 ? "SRT" : "KTX") : km>=90 ? "ITX-새마을" : "무궁화호")
    }
    func seatNames(from: String,to: String) -> [String] {
        let mode=transport(from,to)
        if place(to)?.world=="world" {
            if mode.1=="크루즈" {return ["내측 객실","발코니 객실","스위트"]}
            if mode.1=="야간열차" {return ["2층 침대칸","1인 침대칸","스위트 침대칸"]}
            return ["이코노미","비즈니스","퍼스트"]
        }
        if mode.0=="ferry.fill" {return ["일반실","1등실"]}
        if mode.0=="bus.fill" {return ["일반","우등"]}
        return ["일반실","특실"]
    }
    func recordAchievements(_ s: inout NativeState,stamp: Stamp) {
        var p=s.experience ?? ExperienceState()
        let calendar=Calendar.current,hour=calendar.component(.hour,from:stamp.date),month=calendar.component(.month,from:stamp.date),day=calendar.component(.day,from:stamp.date)
        let today=s.stamps.filter {calendar.isDate($0.date,inSameDayAs:stamp.date)}
        let from=place(stamp.from),to=place(stamp.place),world=to?.world=="world"
        let continents=Set(today.compactMap {place($0.place)}.filter {$0.world=="world"}.map(\.zone))
        let checks:[String:Bool] = [
            "owl":hour<4,"dawn":hour>=5 && hour<7,"xmas":month==12 && [24,25].contains(day),"ny":month==1 && day==1,
            "triple":today.count>=3,"equator":world && (from?.latitude ?? 0)*(to?.latitude ?? 0)<0,
            "dateline":world && abs((from?.longitude ?? 0)-(to?.longitude ?? 0))>180,
            "home":to?.world=="kr" && stamp.place==s.home && s.stamps.count>1,"island":stamp.place=="ulleung",
            "far":world && from != nil && to != nil && distance(from!,to!)>=10000,
            "north":world && (to?.latitude ?? 0)>=59,"cont2":continents.count>=2,
            "sleeper":world && transport(stamp.from,stamp.place).1=="야간열차","captain":world && transport(stamp.from,stamp.place).1=="크루즈",
            "gold3":p.completedRoutes.count>=3
        ]
        for (key,done) in checks where done && p.badges[key]==nil {p.badges[key]=stamp.date}
        s.experience=p
    }
}

extension Color {
    init(hex: String) {
        let n=UInt64(hex.trimmingCharacters(in:CharacterSet(charactersIn:"#")),radix:16) ?? 0x3182F6
        self.init(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255)
    }
}
