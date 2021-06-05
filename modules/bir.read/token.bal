import wso2/nballerina.err;
import ballerina/io;

type Token Delim|Keyword|VariableLengthToken;

type Delim ";" | "(" | ")" | "{" | "}" | "." | "," | "=" | ":";
type Keyword "boolean"
           | "function"
           | "int"
           | "module"
           | "regs"
           | "returns";

const IDENTIFIER = 0;
const DECIMAL_NUMBER = 1;
const STRING_LITERAL = 2;
type TokenTag IDENTIFIER | DECIMAL_NUMBER | STRING_LITERAL;
type VariableLengthToken [TokenTag, string];

const WS = "\n\r\t ";
const LOWER = "abcdefghijklmnopqrstuvwxyz";
const UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const DIGIT = "0123456789";
const string ALPHA = LOWER + UPPER;
const string IDENT = ALPHA + DIGIT + "_";

type Char string;

type StringIterator object {
    public isolated function next() returns record {|
        Char value;
    |}?;
};

final readonly & map<Char> ESCAPES = {
    "\\": "\\",
    "\"": "\"",
    "n": "\n",
    "r": "\r",
    "t": "\t"
};


final readonly & table< record {|
   TokenTag tag;  
   string name;  
|}> key(tag) TOKEN_TAG_NAMES = table [
    // JBUG? should be able to use IDENTIFIER instead 0
    {tag: 0, name:"identifier"},
    {tag: 1, name:"decimal number"},
    {tag: 2, name:"string literal"}
];

function tokenTagToString(TokenTag tag) returns string {
        var tagInfo = TOKEN_TAG_NAMES[tag];
        // JBUG? we do know at compile time that tagInfo won't be nil
        if(tagInfo is ()) {
            panic error("unknown token tag: " + tag.toString());
        }
        else {
            return tagInfo.name;
        }
}

function tokenToString(Token t) returns string {
    if t is string {
        return t;
    }
    else {
        // JBUG cast
        VariableLengthToken tVar = <VariableLengthToken>t;
        return "[" + tokenTagToString(tVar[0]) + ", " + tVar[1] + "]";
    }
}


class Tokenizer {
    Token? cur = ();
    // The index in `str` of the first character of `cur`
    private int startIndex = 0;
    // Index of character starting line on which startPos occurs
    private int lineStartIndex = 0;
    // Line number of line starting at lineStartIndex
    private int lineNumber = 1;
    private final string str;

    private final StringIterator iter;
    private Char? ungot = ();
    // Number of characters returned by `iter`
    private int nextCount = 0;
   

    function init(string str) {
        self.iter = str.iterator();
        self.str = str;
    }
   
    // Moves to next token.record
    // Current token is () if there is no next token
    function advance() returns err:Syntax? {
        self.cur = check self.next();
    }

    function current() returns Token? {
        return self.cur;
    }

    function currentPos() returns err:Position {
        return {
            lineNumber: self.lineNumber,
            indexInLine: self.startIndex - self.lineStartIndex
        };
    }

    private function next() returns Token?|err:Syntax {
        // This loops in order to skip over comments
        while true {
            Char? ch = self.startToken();
            if ch is () {
                return ();
            }
            else if ch == "/" {
                ch = self.getc();
                if ch == "/" {
                    // Skip the comment and loop
                    while true {
                        ch = self.getc();
                        if ch is () {
                            break;
                        }
                        else if self.isLineTerminator(ch) {
                            // handle line counting in startToken
                            self.ungetc(ch);
                            break;
                        }
                    }
                    continue;
                }
                else if !(ch is ()) {
                    return err:syntax("expected '//'; got '/'", self.currentPos());
                }
            }
            // Need to do mult-char delims before single-char delims.        
            else if ch == "{" {
                return "{";
            }
            else if ch == "." {
                return ".";
            }
            else if ch is Delim {
                return ch;
            }
            else if ALPHA.includes(ch) {
                string ident = ch;
                while true {
                    ch = self.getc();
                    if ch is () {
                        break;
                    }
                    else if !IDENT.includes(ch) {
                        self.ungetc(ch);
                        break;
                    }
                    else {
                        ident += ch;
                    }
                }
                if ident is Keyword {
                    return ident;
                }
                return [IDENTIFIER, ident];
            }
            else if DIGIT.includes(ch) {
                string digits = ch;
                while true {
                    ch = self.getc();
                    if ch is () {
                        break;
                    }
                    else if !DIGIT.includes(ch) {
                        self.ungetc(ch);
                        break;
                    }
                    else {
                        digits += ch;
                    }
                }
                return [DECIMAL_NUMBER, digits];
            }
            else if ch == "\"" {
                string content = "";
                while true {
                    ch = self.getc();
                    if ch == "\"" {
                        break;
                    }
                    if ch is () || self.isLineTerminator(ch) {
                        return self.err("missing close quote");
                    }
                    else if ch == "\\" {
                        ch = self.getc();
                        if ch is () {
                            return self.err("missing close quote");
                        }
                        else {
                            ch = ESCAPES[ch];
                            if ch is () {
                                return self.err("bad character after backslash");
                            }
                            else {
                                content += ch;
                            }
                        }
                    }
                    else {
                        content += ch;
                    }
                }
                return [STRING_LITERAL, content];
            }
            else {
               io:println(ch);
               break;
            }
        }
        return self.err("invalid token");
    }
    
    private function isLineTerminator(Char ch) returns boolean {
        return ch == "\n" || ch == "\r";
    }

    // Returns first non white-space character, if any
    // Updates startIndex, lineStartIndex and lineNumber
    private function startToken() returns Char? {
        // the previous character if it ended a line, otherwise ()
        Char? prevCharLineEnd = ();
        while true {
            Char? ch = self.getc();
            if ch is () {
                break;
            }
            else {
                if prevCharLineEnd !== () {
                    // Line terminators are part of the line they terminate
                    // Line numbers increase on the first character of a line
                    self.lineStartIndex = self.getCount() - 1;
                    // For \r\n, the line number will be bumped on the
                    // character after the \n
                    if prevCharLineEnd != "\r" || ch != "\n" {
                        self.lineNumber += 1;
                    }
                }
                if ch == "\n" || ch == "\r" {
                    prevCharLineEnd = ch;
                }
                else if ch == " " || ch == "\t" {
                    prevCharLineEnd = ();
                }
                else {
                    self.startIndex = self.getCount() - 1;
                    return ch;
                }
            }
        }
        self.startIndex = self.getCount();
        return ();
    }


    // number of characters returned by getc and not ungot
    private function getCount() returns int {
        return self.ungot is Char ? self.nextCount - 1 : self.nextCount;
    }

    private function getc() returns Char? {
        Char? ch = self.ungot;
        if ch is () {
            return self.nextc();
        }
        else {
            self.ungot = ();
            return ch;
        }
    }

    private function ungetc(Char ch) {
        // we could support arbitrary numbers of unget, by allowing
        // the ungot string to be longer than 1
        // but we don't need it (yet)
        if self.ungot != () {
            panic error("double ungetc");
        }
        self.ungot = ch;
    }

    private function nextc() returns string? {
        var ret = self.iter.next();
        if ret is () {
            return ();
        }
        else {
            self.nextCount += 1;
            return ret.value;
        }
    }

    function expect(Delim|Keyword tok) returns err:Syntax? {
        if self.cur != tok {
            err:Template msg;
            Token? t = self.cur;
            if t is Token {
                // JBUG cast #30734
                msg = `expected ${<string>tok}; got ${tokenToString(t)}`;
            }
            else {
                msg = `expected ${<string>tok}`;
            }
            return self.err(msg);
        }
        check self.advance();
    }


    function expectOfKind(TokenTag tag) returns string|err:Syntax {
        // JBUG cast
        // It would have been nice to wirte this as `self.cur is [typeof tag, string]`
        // Is there a better way to express this ?
        if self.cur is VariableLengthToken && (<VariableLengthToken>self.cur)[0] == tag {
            // JBUG cast
            string tokenData = (<VariableLengthToken>self.cur)[1];
            check self.advance();
            return tokenData;
        }
        else {
            err:Template msg;
            Token? t = self.cur;
            // JBUG cast
            if t is Token {
                msg = `expected ${tokenTagToString(tag)}; got ${tokenToString(t)}`;
            }
            else {
                msg = `expected ${tokenTagToString(tag)}`;
            }
            return self.err(msg);
        }
    }

    function err(err:Message msg) returns err:Syntax {
        return err:syntax(msg, self.currentPos());
    }
}

