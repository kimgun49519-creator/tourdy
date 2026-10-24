import XCTest
@testable import Tourdy

@MainActor
final class TourdyNativeTests: XCTestCase {
    private func directory() -> URL {FileManager.default.temporaryDirectory.appendingPathComponent("TourdyTests-"+UUID().uuidString,isDirectory:true)}
    func testRewardWaitsForStudyEndAndIsRedeemedOnce() throws {
        let store=NativeStore(directory:directory())
        let subject=Subject(name:"수학")
        XCTAssertTrue(store.commit {$0.subjects=[subject];$0.running=RunningStudy(subject:subject.id,start:Date().addingTimeInterval(-1801))})
        XCTAssertEqual(store.state.firstReward,"pending")
        store.finishAll()
        XCTAssertEqual(store.state.firstReward,"ready")
        let busan=try XCTUnwrap(store.place("busan")),balance=store.balance
        store.gift(busan,origin:"seoul")
        XCTAssertEqual(store.state.firstReward,"used")
        XCTAssertEqual(store.state.stamps.count,1)
        XCTAssertEqual(store.balance,balance,accuracy:0.01)
        store.gift(busan,origin:"seoul")
        XCTAssertEqual(store.state.stamps.count,1)
    }
    func testRestAndManualRecordsCannotEarnFirstReward() {
        let store=NativeStore(directory:directory()),subject=Subject(name:"영어"),now=Date()
        XCTAssertTrue(store.commit {$0.subjects=[subject];$0.sessions=[StudySession(subject:subject.id,start:now.addingTimeInterval(-3600),end:now,manual:true)];$0.running=RunningStudy(subject:subject.id,start:now.addingTimeInterval(-3600),kind:"rest")})
        store.finishAll()
        XCTAssertEqual(store.state.firstReward,"pending")
        XCTAssertEqual(store.balance,0)
    }
    func testFailedGiftSaveRetainsTicketLocationAndBalance() throws {
        var failed=false
        let store=NativeStore(directory:directory(),write:{data,url in if failed {throw CocoaError(.fileWriteOutOfSpace)};try data.write(to:url,options:.atomic)})
        XCTAssertTrue(store.commit {$0.firstReward="ready"})
        failed=true
        store.gift(try XCTUnwrap(store.place("busan")),origin:"seoul")
        XCTAssertEqual(store.state.firstReward,"ready")
        XCTAssertEqual(store.state.positions["kr"],"seoul")
        XCTAssertTrue(store.state.stamps.isEmpty)
        XCTAssertNil(store.arrival)
    }
    func testPaidArrivalAndStampSurviveReopenWithoutDoubleCharge() throws {
        let folder=directory(),store=NativeStore(directory:folder),subject=Subject(name:"전공"),now=Date()
        // Ten completed eight-hour days provide enough miles for Seoul → Busan.
        XCTAssertTrue(store.commit {s in
            s.subjects=[subject]
            for day in 1...10 {let start=now.addingTimeInterval(-Double(day)*86400);s.sessions.append(StudySession(subject:subject.id,start:start,end:start.addingTimeInterval(28800)))}
        })
        store.checkIn(try XCTUnwrap(store.place("busan")),cabin:1,goal:nil)
        let used=store.state.used
        XCTAssertGreaterThan(used,0)
        let reopened=NativeStore(directory:folder)
        reopened.settleJourney()
        XCTAssertEqual(reopened.state.positions["kr"],"busan")
        XCTAssertEqual(reopened.state.stamps.count,1)
        XCTAssertEqual(reopened.state.used,used)
        XCTAssertFalse(reopened.unlocked("world"))
    }
    func testScheduledPomodoroReconcilesAfterSuspension() {
        let store=NativeStore(directory:directory()),subject=Subject(name:"과학"),start=Date().addingTimeInterval(-300)
        XCTAssertTrue(store.commit {$0.subjects=[subject]})
        store.schedule(subject:subject.id,start:start,minutes:1,sets:2,rest:1)
        XCTAssertNil(store.state.running)
        XCTAssertNil(store.prefs.plan)
        XCTAssertEqual(store.state.sessions.filter {($0.kind ?? "study")=="study"}.count,2)
        XCTAssertEqual(store.state.sessions.filter {$0.kind=="rest"}.count,1)
        XCTAssertEqual(store.completedSeconds,120,accuracy:1)
    }
}
