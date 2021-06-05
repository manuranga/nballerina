import wso2/nballerina.bir;
import wso2/nballerina.err;
import wso2/nballerina.types as t;
import ballerina/io;

public function loadModule(string filename) returns bir:Module|error {
    string contents = check io:fileReadString(filename);
    Tokenizer tok = new(contents);
    check tok.advance();
    return check parseTopLevel(tok);
}

function parseTopLevel(Tokenizer tok) returns bir:Module|err:Syntax {
    check tok.expect("module");

    t:Env env = new;
    t:TypeCheckContext tc = t:typeCheckContext(env);
    bir:ModuleId id = check parseModuleId(tok);
    bir:Module mod = { id, tc };

    check tok.expect("{");

    Token? token = tok.current();
    while token == "function" {
        var func = check parseFunction(tok);
        mod.defns[func.name] = func;
        token = tok.current();
    }

    io:println(mod);
    // check tok.expect("}");
    return mod;
}

function parseModuleId(Tokenizer tok) returns bir:ModuleId|err:Syntax {
    string? organization = check parseNilableString(tok);
    check tok.expect(",");
    string versionString = check tok.expectOfKind(STRING_LITERAL);
    check tok.expect(",");

    string name = check tok.expectOfKind(STRING_LITERAL);
    [string, string...] & readonly names = [name];

    return { versionString, names, organization};
}


function parseFunction(Tokenizer tok) returns bir:FunctionDefn|err:Syntax {
    // function keywrod is alrady checked
    check tok.advance();

    string name = check tok.expectOfKind(IDENTIFIER);
    var sig = check parseFunctionSig(tok);

    check tok.expect("{");
    check tok.expect("regs");
    check tok.expect(":");

    var ty = check parseType(tok);

    io:println("*******", tok.current());
    bir:Register input = { number:0, semType: t:INT };
    bir:RetInsn ret = { operand: input };
    bir:BasicBlock bb = { label: 0, insns:[ret] };
    bir:FunctionCode code = {};

    return new WrappedFunctionDefn(name, sig, code);

}
function parseType(Tokenizer tok) returns t:SemType|err:Syntax {
    if tok.current() == "(" {
        check tok.advance();
        check tok.expect(")");
        return t:NIL;
    }
    else if tok.current() == "int" {
        check tok.advance();
        return t:INT;
    }
    return parseError(tok);
}

function parseFunctionSig(Tokenizer tok) returns bir:FunctionSignature|err:Syntax {
    check tok.expect("(");
    t:SemType returnType = t:NIL;
    // TODO: params
    check tok.expect(")");

    check tok.expect("returns");

    check tok.expect("(");
    readonly & t:SemType[] paramTypes = [t:NIL];
    // TODO: return
    check tok.expect(")");

    return { returnType, paramTypes };
}

function parseNilableString(Tokenizer tok) returns string?|err:Syntax {
    Token? t = tok.current();
    if t is "(" {
        check tok.advance();
        check tok.expect(")");
        return ();
    } else {
        return check tok.expectOfKind(STRING_LITERAL);
    }
}

function parseError(Tokenizer tok) returns err:Syntax {
    string message = "parse error";
    Token? t = tok.current();
    if t is string {
        // JBUG cast needed #30734
        message += " at '" + <string>t + "'";
    }
    return tok.err(message);
}   

class WrappedFunctionDefn {
    *bir:FunctionDefn;
    public final string name;
    public final bir:FunctionSignature signature;
    public final bir:FunctionCode code;
   
    function init(string name, bir:FunctionSignature signature, bir:FunctionCode code) {
        self.name = name;
        self.signature = signature;
        self.code = code;
    }

    public function generateCode(bir:Module mod) returns bir:FunctionCode|err:Semantic|err:Unimplemented {
        return self.code;
    }
}