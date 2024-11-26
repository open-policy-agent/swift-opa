struct Policy : Codable {
    var staticData : Static
    var plans : Plans = Plans()
    var funcs : Funcs = Funcs()
    
    enum CodingKeys : String, CodingKey {
        case staticData = "static"
        case plans
        case funcs
    }
}

struct Static : Codable {
    var strings : [ConstString]
    var builtinFuncs : [BuiltinFunc]?
    var files : [ConstString]
    
    enum CodingKeys : String, CodingKey {
        case strings
        case builtinFuncs = "builtin_funcs"
        case files
    }
}

struct ConstString : Codable {
    var value : String
}


struct BuiltinFunc : Codable {
    var name : String
//    var decl : FunctionDecl
}

/*
 struct FunctionDecl : Codable {
 var args [Type]
 var result Type
 var variadic Type
 }
 
 struct Type : Codable {
 
 }
 */

struct Plans : Codable {
    var plans: [Plan] = []
}

struct Plan : Codable {
    var name : String
    var blocks : [Block]
}

struct Block : Codable {
    // TODO
//    var stmts : [Statement]
}

struct Stmt : Codable {
    enum type : String, Codable {
        case CallStmt
        case AssignVarStmt
        case MakeObjectStmt
        case ObjectInsertStmt
        case ResultSetAddStmt
    }
}

protocol Statement {
    
}

struct CallStmt : Statement, Codable {
    var callFunc : String
    
    enum CodingKeys : String, CodingKey {
        case callFunc = "func"
        // TODO args
    }
    
}

struct Funcs : Codable {
    var Funcs : [Func] = []
}

struct Func : Codable {
    var name : String
    var path : [String]
    var params : [Int]
    var returnVar : Int
    var blocks : [Block]
    
    enum CodingKeys : String, CodingKey {
        case name
        case path
        case params
        case returnVar = "return"
        case blocks
    }
}

