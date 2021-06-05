import wso2/nballerina.bir;
import wso2/nballerina.front;
import nballerina.bir.read;
import wso2/nballerina.nback;

public type Options record {|
    boolean testJsonTypes = false;
    boolean showTypes = false;
    # skip frontend, instead read bir the given file
    boolean fromBir = false;
|};

const SOURCE_EXTENSION = ".bal";
public function main(string filename, *Options opts) returns error? {
    if opts.testJsonTypes {
        return testJsonTypes(filename);
    }
    if opts.showTypes {
        return showTypes(filename);
    }
    bir:Module module;
    if opts.fromBir {
        module = check read:loadModule(filename);
    } else {
        bir:ModuleId id = {
        versionString: "0.1.0",
        names: [filename],
        organization: "dummy"
        };
        module = check front:loadModule(filename, id);
    }
    check nback:compileModule(module, check stripExtension(module.id.names[0], SOURCE_EXTENSION));
}

function stripExtension(string filename, string extension) returns string|error {
    int? extIndex = filename.lastIndexOf(".");
    if extIndex is int {
        string ext = filename.substring(extIndex).toLowerAscii();
        if ext == extension {
            return filename.substring(0, extIndex);
        }
    }
    return error("filename must end with " + extension);
}
