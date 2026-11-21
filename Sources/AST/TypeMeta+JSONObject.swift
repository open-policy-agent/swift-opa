import Foundation

// Custom decoding from Darwin JSONSerialization output (see JSONObject). Must match the Decodable conformances.

#if canImport(Darwin)

    extension RegoTypeDecl {
        package init(json: JSONValue) throws {
            let o = try JSONObject(json)
            let name = try o.stringIfPresent("name")
            let description = try o.stringIfPresent("description")
            switch try o.rawValue("type") as RegoTypeLabels {
            case .any:
                self = .any(
                    AnyTypeDecl(
                        name: name, description: description, of: try o.arrayIfPresent("of", RegoTypeDecl.init(json:))))
            case .array:
                self = .array(
                    ArrayTypeDecl(
                        name: name, description: description,
                        staticItems: try o.arrayIfPresent("static", RegoTypeDecl.init(json:)),
                        dynamicItems: try o.decodeIfPresent("dynamic", RegoTypeDecl.init(json:))))
            case .boolean:
                self = .boolean(BooleanTypeDecl(name: name, description: description))
            case .function:
                self = .function(try FunctionTypeDecl(o))
            case .null:
                self = .null(NullTypeDecl(name: name, description: description))
            case .number:
                self = .number(NumberTypeDecl(name: name, description: description))
            case .object:
                self = .object(
                    ObjectTypeDecl(
                        name: name, description: description,
                        staticProps: try o.arrayIfPresent("static") { p in
                            let p = try JSONObject(p)
                            return StaticPropertyDecl(
                                key: try p.string("key"), value: try p.decode("value", RegoTypeDecl.init(json:)))
                        },
                        dynamicProps: try o.decodeIfPresent("dynamic") { p in
                            let p = try JSONObject(p)
                            return DynamicPropertyDecl(
                                key: try p.decode("key", RegoTypeDecl.init(json:)),
                                value: try p.decode("value", RegoTypeDecl.init(json:)))
                        }))
            case .set:
                self = .set(
                    SetTypeDecl(
                        name: name, description: description, of: try o.decodeIfPresent("of", RegoTypeDecl.init(json:)))
                )
            case .string:
                self = .string(StringTypeDecl(name: name, description: description))
            }
        }
    }

    extension FunctionTypeDecl {
        /// Like the Decodable conformance, this doesn't check the `type` member.
        package init(json: JSONValue) throws {
            try self.init(JSONObject(json))
        }

        init(_ o: JSONObject) throws {
            self.init(
                name: try o.stringIfPresent("name"),
                description: try o.stringIfPresent("description"),
                args: try o.arrayIfPresent("args", RegoTypeDecl.init(json:)),
                result: try o.decodeIfPresent("result", RegoTypeDecl.init(json:)),
                variadic: try o.decodeIfPresent("variadic", RegoTypeDecl.init(json:)))
        }
    }

#endif
