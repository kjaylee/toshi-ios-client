// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import XCTest
import UIKit
import Quick
import Nimble
import Teapot
@testable import Toshi

class IDAPIClientTests: QuickSpec {
    override func spec() {
        describe("the id API Client") {

            context("Ok status") {
                var subject: IDAPIClient!

                it("fetches the timestamp") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    waitUntil { done in
                        subject.fetchTimestamp { timestamp, error in
                            expect(timestamp).toNot(beNil())
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("registers user if needed") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user")
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    mockTeapot.overrideEndPoint(Cereal.shared.address, withFilename: "nonExistingUser")
                    subject = IDAPIClient(teapot: mockTeapot)

                    waitUntil { done in
                        subject.registerUserIfNeeded { status in
                            expect(status.rawValue).to(equal(UserRegisterStatus.registered.rawValue))
                            done()
                        }
                    }
                }

                it("updates Avatar") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user")
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let testImage = UIImage(named: "testImage.png", in: Bundle(for: IDAPIClientTests.self), compatibleWith: nil)
                    waitUntil { done in
                        subject.updateAvatar(testImage!) { success, error in
                            expect(success).to(beTruthy())
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("updates the user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user")
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let userDict: [String: Any] = [
                        "token_id": "van Diemenstraat 328",
                        "payment_address": "Longstreet 200",
                        "username": "marijn2000",
                        "about": "test user dict!",
                        "location": "Leiden",
                        "name": "Marijntje",
                        "avatar": "someURL",
                        "is_app": false,
                        "public": true,
                        "verified": false
                    ]

                    waitUntil { done in
                        subject.updateUser(userDict) { success, message in
                            expect(success).to(beTruthy())
                            expect(message).to(beNil())
                            done()
                        }
                    }
                }

                it("retrieve user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let username = "testUsername"

                    waitUntil { done in
                        subject.retrieveUser(username: username) { user in
                            expect(user).toNot(beNil())
                            done()
                        }
                    }
                }

                it("finds a contact") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user")
                    subject = IDAPIClient(teapot: mockTeapot)
                    
                    let username = "testUsername"

                    waitUntil { done in
                        subject.findContact(name: username) { user in
                            expect(user).toNot(beNil())
                            done()
                        }
                    }
                }

                it("searches contacts") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "searchContacts")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let search = "search key"

                    waitUntil { done in
                        subject.searchContacts(name: search) { users in
                            expect(users.count).to(equal(2))
                            expect(users.first!.name).to(equal("Search result 1"))
                            done()
                        }
                    }
                }

                it("gets top rated public users") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "getTopRatedPublicUsers")
                    subject = IDAPIClient(teapot: mockTeapot, cacheEnabled: false)

                    waitUntil { done in
                        subject.getTopRatedPublicUsers { users, error in
                            expect(users!.count).to(equal(2))
                            expect(users!.first!.about).to(equal("Top rated"))
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("gets latest public users") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "getLatestPublicUsers")
                    subject = IDAPIClient(teapot: mockTeapot, cacheEnabled: false)

                    waitUntil { done in
                        subject.getLatestPublicUsers { users, error in
                            DLog(String(describing: error))
                            expect(error).to(beNil())
                            expect(users!.count).to(equal(2))
                            expect(users!.first!.about).to(equal("Latest public"))
                            done()
                        }
                    }
                }

                it("reports a user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "", statusCode: .noContent)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let address = "0x6f70800cb47f7f84b6c71b3693fc02595eae7378"

                    waitUntil { done in
                        subject.reportUser(address: address, reason: "Not good") { success, error in
                            expect(success).to(beTruthy())
                            expect(error).to(beNil())
                            done()
                        }
                    }
                }

                it("logs in") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "", statusCode: .noContent)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let token = "f500a3cc32dbb78b"

                    waitUntil { done in
                        subject.adminLogin(loginToken: token) { success, _ in
                            expect(success).to(beTruthy())
                            done()
                        }
                    }
                }
                
                it("gets a list of dapps") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "dapps")
                    subject = IDAPIClient(teapot: mockTeapot)
                    
                    waitUntil { done in
                        subject.getDapps { dapps, toshiError in
                            expect(toshiError).to(beNil())
                            guard let dapps = dapps else {
                                fail("No dapps for you")
                                done()
                                return
                            }
                            
                            expect(dapps.count).to(equal(4))
                            expect(dapps.map { $0.name }).to(equal([
                                                            "Cryptokitties",
                                                            "NameBazaar",
                                                            "Cent",
                                                            "0x Portal"
                                                            ]))
                            
                            done()
                        }
                    }
                }
            }

            context("Error status") {
                var subject: IDAPIClient!

                it("fetches the timestamp") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "timestamp", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot)

                    waitUntil { done in
                        subject.fetchTimestamp { timestamp, error in
                            expect(timestamp).to(beNil())
                            expect(error).toNot(beNil())
                            done()
                        }
                    }
                }

                it("registers user if needed") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    mockTeapot.overrideEndPoint(Cereal.shared.address, withFilename: "nonExistingUser")
                    subject = IDAPIClient(teapot: mockTeapot)

                    waitUntil { done in
                        subject.registerUserIfNeeded { status in
                            expect(status.rawValue).to(equal(UserRegisterStatus.failed.rawValue))
                            done()
                        }
                    }
                }

                it("updates Avatar") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let testImage = UIImage(named: "testImage.png", in: Bundle(for: IDAPIClientTests.self), compatibleWith: nil)
                    waitUntil { done in
                        subject.updateAvatar(testImage!) { success, error in
                            expect(success).to(beFalse())
                            expect(error?.type).to(equal(.invalidResponseStatus))
                            done()
                        }
                    }
                }

                it("updates the user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let userDict: [String: Any] = [
                        "token_id": "van Diemenstraat 328",
                        "payment_address": "Longstreet 200",
                        "username": "marijn2000",
                        "about": "test user dict!",
                        "location": "Leiden",
                        "name": "Marijntje",
                        "avatar": "someURL",
                        "is_app": false,
                        "public": true,
                        "verified": false
                    ]

                    waitUntil { done in
                        subject.updateUser(userDict) { success, message in
                            expect(success).to(beFalse())
                            expect(message).toNot(beNil())
                            done()
                        }
                    }
                }

                it("retrieve user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot)

                    let username = "testUsername"

                    waitUntil { done in
                        subject.retrieveUser(username: username) { user in
                            expect(user).to(beNil())
                            done()
                        }
                    }
                }

                it("finds a contact") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "user", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot)

                    let username = "somethingCompletelyDifferent"

                    waitUntil { done in
                        subject.findContact(name: username) { user in
                            expect(user).to(beNil())
                            done()
                        }
                    }
                }

                it("searches contacts") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "searchContacts", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot)

                    let search = "search key"

                    waitUntil { done in
                        subject.searchContacts(name: search) { users in
                            expect(users.count).to(equal(0))
                            done()
                        }
                    }
                }

                it("gets top rated public users") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "getTopRatedPublicUsers", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot, cacheEnabled: false)

                    waitUntil { done in
                        subject.getTopRatedPublicUsers { users, error in
                            expect(users!.count).to(equal(0))
                            expect(error!).toNot(beNil())
                            done()
                        }
                    }
                }

                it("gets latest public users") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "getLatestPublicUsers", statusCode: .unauthorized)
                    subject = IDAPIClient(teapot: mockTeapot, cacheEnabled: false)

                    waitUntil { done in
                        subject.getLatestPublicUsers { users, error in
                            expect(users!.count).to(equal(0))
                            expect(error).toNot(beNil())
                            done()
                        }
                    }
                }

                it("reports a user") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let address = "0x6f70800cb47f7f84b6c71b3693fc02595eae7378"

                    waitUntil { done in
                        subject.reportUser(address: address, reason: "Not good") { success, error in
                            expect(success).to(beFalse())
                            expect(error?.type).to(equal(.invalidResponseStatus))
                            done()
                        }
                    }
                }

                it("logs in") {
                    let mockTeapot = MockTeapot(bundle: Bundle(for: IDAPIClientTests.self), mockFilename: "", statusCode: .unauthorized)
                    mockTeapot.overrideEndPoint("timestamp", withFilename: "timestamp")
                    subject = IDAPIClient(teapot: mockTeapot)

                    let token = "f500a3cc32dbb78b"

                    waitUntil { done in
                        subject.adminLogin(loginToken: token) { success, _ in
                            expect(success).to(beFalse())
                            done()
                        }
                    }
                }
            }
        }
    }
}
