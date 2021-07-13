import ballerina/test;
import ballerina/io;
import ballerina/file;

type SubtypeTestCase [string, string];
@test:Config {
    dataProvider: subtypeCaseProvider
}
function testSubtype(string balString, string expected) returns error? {
    string[] lines = check subtypeRels(balString);
    string result = "\n".'join(...lines);
    test:assertEquals(result, expected);
}

function subtypeCaseProvider() returns map<SubtypeTestCase>|error {
    map<SubtypeTestCase> tests = {};
    var testList =
        from var entry in check file:readDir("tests/data")
        let string path = entry.absPath
        let string base = check file:basename(path)
        where path.endsWith(".bal")
        let SubtypeTestCase|error res = readTestCase(path)
        // skip files with no subtype lines on them
        where res is SubtypeTestCase && res[1].length() > 0
        select [base, res];
        // JBUG #31679 should use do
        //  do {
        //   tests[base] = res;
        //  };

    foreach var t in testList {
        tests[t[0]] = t[1];
    }
    return tests;
}

function readTestCase(string filename) returns SubtypeTestCase|error {
    string str = check io:fileReadString(filename);
    string[] lines = check io:fileReadLines(filename);
    string[] results =
        from var line in lines
        where line.startsWith("// ") && line.includes("<:")
        let string result = line.substring(3).trim()
        order by result
        select result;
    string expected = "\n".'join(...results);
    return [str, expected];
}

// @test:Config{}
// function test1() returns error? {
//     var args = check readTestCase("tests/data/function.bal");
//     return testModule(...args);
// }
