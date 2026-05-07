import XCTest
@testable import GitLabCore

final class ArgumentParserTests: XCTestCase {

    func testEmptyArgs() {
        let p = ParsedArgs.parse([])
        XCTAssertTrue(p.positionals.isEmpty)
        XCTAssertTrue(p.options.isEmpty)
        XCTAssertTrue(p.flags.isEmpty)
    }

    func testPositionals() {
        let p = ParsedArgs.parse(["issues", "list", "group/project"])
        XCTAssertEqual(p.positionals, ["issues", "list", "group/project"])
        XCTAssertNil(p.option("state"))
    }

    func testOptionKeyValue() {
        let p = ParsedArgs.parse(["issues", "list", "p", "--state", "open"])
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
        XCTAssertEqual(p.option("state"), "open")
    }

    func testBoolFlag() {
        let p = ParsedArgs.parse(["projects", "list", "--membership", "--owned"])
        XCTAssertTrue(p.flag("membership"))
        XCTAssertTrue(p.flag("owned"))
        XCTAssertFalse(p.flag("private"))
    }

    func testMixedArguments() {
        let p = ParsedArgs.parse(["issues", "create", "mygroup/proj", "--title", "Bug", "--labels", "bug,high", "--json"])
        XCTAssertEqual(p.positionals, ["issues", "create", "mygroup/proj"])
        XCTAssertEqual(p.option("title"), "Bug")
        XCTAssertEqual(p.option("labels"), "bug,high")
        XCTAssertTrue(p.flag("json"))
    }

    func testPositionalIndex() {
        let p = ParsedArgs.parse(["issues", "get", "proj", "42"])
        XCTAssertEqual(p.positional(0), "issues")
        XCTAssertEqual(p.positional(1), "get")
        XCTAssertEqual(p.positional(2), "proj")
        XCTAssertEqual(p.positional(3), "42")
        XCTAssertNil(p.positional(4))
    }

    func testOptionFollowedByFlag() {
        // "--title" "My Title" "--json"  should parse correctly
        let p = ParsedArgs.parse(["create", "--title", "My Title", "--json"])
        XCTAssertEqual(p.option("title"), "My Title")
        XCTAssertTrue(p.flag("json"))
    }

    func testTwoConsecutiveFlags() {
        let p = ParsedArgs.parse(["--membership", "--owned"])
        XCTAssertTrue(p.flag("membership"))
        XCTAssertTrue(p.flag("owned"))
        XCTAssertTrue(p.positionals.isEmpty)
    }

    func testValueWithSpaces() {
        // values with spaces arrive as a single token from the shell
        let p = ParsedArgs.parse(["--description", "Hello World"])
        XCTAssertEqual(p.option("description"), "Hello World")
    }
}
