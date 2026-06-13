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

    // MARK: - Boolean flags do not consume the next token (regression for #5)

    func testBooleanFlagBeforePositional() {
        // --json must NOT swallow "issues" as a value
        let p = ParsedArgs.parse(["--json", "issues", "list", "p"])
        XCTAssertTrue(p.flag("json"))
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
        XCTAssertNil(p.option("json"))
    }

    func testBooleanFlagBetweenPositionals() {
        let p = ParsedArgs.parse(["issues", "list", "--json", "p"])
        XCTAssertTrue(p.flag("json"))
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
    }

    func testBooleanFlagAndValueOptionMixed() {
        let p = ParsedArgs.parse(["--json", "issues", "list", "p", "--state", "open"])
        XCTAssertTrue(p.flag("json"))
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
        XCTAssertEqual(p.option("state"), "open")
    }

    func testKnownBooleanFlagsNeverTakeValues() {
        let p = ParsedArgs.parse(["mr", "merge", "p", "1", "--squash", "--remove-source-branch", "--message", "done"])
        XCTAssertEqual(p.positionals, ["mr", "merge", "p", "1"])
        XCTAssertTrue(p.flag("squash"))
        XCTAssertTrue(p.flag("remove-source-branch"))
        XCTAssertEqual(p.option("message"), "done")
    }

    // MARK: - --key=value form

    func testKeyEqualsValue() {
        let p = ParsedArgs.parse(["issues", "list", "p", "--state=open", "--labels=bug,high"])
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
        XCTAssertEqual(p.option("state"), "open")
        XCTAssertEqual(p.option("labels"), "bug,high")
    }

    func testKeyEqualsValueWithEqualsInValue() {
        let p = ParsedArgs.parse(["--description=a=b"])
        XCTAssertEqual(p.option("description"), "a=b")
    }

    // MARK: - Dangling value option

    func testDanglingOptionAtEndBecomesFlag() {
        // --state with no following value should not crash or consume a sibling
        let p = ParsedArgs.parse(["issues", "list", "p", "--state"])
        XCTAssertEqual(p.positionals, ["issues", "list", "p"])
        XCTAssertNil(p.option("state"))
    }

    // MARK: - Boolean flag written as --flag=value (regression for #5 review)

    func testBooleanFlagEqualsTrue() {
        // --json=true must set the json flag, not store it as an option
        let p = ParsedArgs.parse(["--json=true", "whoami"])
        XCTAssertTrue(p.flag("json"))
        XCTAssertNil(p.option("json"))
        XCTAssertEqual(p.positionals, ["whoami"])
    }

    func testBooleanFlagEqualsOneAndYes() {
        XCTAssertTrue(ParsedArgs.parse(["--json=1"]).flag("json"))
        XCTAssertTrue(ParsedArgs.parse(["--json=yes"]).flag("json"))
        XCTAssertTrue(ParsedArgs.parse(["--json="]).flag("json"))
    }

    func testBooleanFlagEqualsFalseLeavesUnset() {
        let p = ParsedArgs.parse(["--json=false", "whoami"])
        XCTAssertFalse(p.flag("json"))
        XCTAssertNil(p.option("json"))
        XCTAssertEqual(p.positionals, ["whoami"])
    }
}
