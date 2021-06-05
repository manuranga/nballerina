import ballerina/io;

import wso2/nballerina.err;
import wso2/nballerina.bir;
import wso2/nballerina.nback.bll;
import wso2/nballerina.nback.llvm;

# The preferred output extension for the output filename.
const OUTPUT_EXTENSION = ".ll";

public function compileModule(bir:Module mod, string basename) returns err:Any|io:Error? {
    string path = basename + OUTPUT_EXTENSION;
    io:println(path);
    llvm:Output out = check new(path);
    foreach bir:ModuleDefn def in mod.defns {
        if def is bir:FunctionDefn {
            check compileFunction(mod, def, out);          
        }
    }
    check out.finish();
}

function compileFunction(bir:Module mod, bir:FunctionDefn def, llvm:Output out) returns err:Any? {
    bir:FunctionCode code = check def.generateCode(mod);
    bll:FunctionDefn ldef = check lower(mod, def, code);
    return emit(ldef, out);
}
