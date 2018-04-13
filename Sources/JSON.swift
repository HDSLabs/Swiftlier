//
//  JSON.swift
//  Swiftlier
//
//  Created by Andrew J Wagner on 3/23/16.
//  Copyright © 2016 Drewag LLC. All rights reserved.
//

import Foundation

public struct JSON: NativeTypesStructured {
    public let object: Any

    public init(data: Data) throws {
        self.object = try JSONSerialization.jsonObject(
            with: data,
            options: JSONSerialization.ReadingOptions()
        )
    }

    public init(object: Any) {
        self.object = object
    }

    public init<E: Encodable>(encodable: E, purpose: EncodingPurpose = .saveLocally, userInfo: [CodingUserInfoKey:Any] = [:]) throws {
        let encoder = JSONWithCancelableNodesEncoder()
        var userInfo = userInfo
        userInfo[CodingOptions.encodingPurpose] = purpose
        encoder.userInfo = userInfo
        let data = try encoder.encode(encodable)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        self.init(object: object)
    }

    public func data() throws -> Data {
        return try JSONSerialization.data(withJSONObject: self.object, options: [])
    }

    public func decode<D: Decodable>(source: DecodingSource = .local, userInfo: [CodingUserInfoKey:Any] = [:]) throws -> D {
        let decoder = JSONDecoder()
        var userInfo = userInfo
        userInfo[CodingOptions.decodingSource] = source
        decoder.userInfo = userInfo
        return try decoder.decode(D.self, from: self.data())
    }
}


class JSONWithCancelableNodesEncoder: Encoder, ErrorGenerating {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    fileprivate let boxedValue: BoxedValue

    init() {
        self.boxedValue = BoxedValue(.none)
    }

    func encode<E: Encodable>(_ encodable: E) throws -> Data {
        try encodable.encode(to: self)
        guard let string = self.boxedValue.jsonString else {
            return Data()
        }
        return string.data(using: .utf8) ?? Data()
    }

    fileprivate init(boxedValue: BoxedValue) {
        self.boxedValue = boxedValue
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(JSONWithCancelableNodesKeyedEncodingContainer<Key>(boxedValue: self.boxedValue, userInfo: self.userInfo))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return JSONWithCancelableNodesUnkeyedEncodingContainer(boxedValue: self.boxedValue, userInfo: self.userInfo)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return JSONWithCancelableNodesSingleValueEncodingContainer(boxedValue: self.boxedValue, userInfo: self.userInfo)
    }
}

private enum JSONValue {
    case none
    case null
    case array([BoxedValue])
    case dictionary([String:BoxedValue])
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case double(Double)
    case float(Float)
    case bool(Bool)
}

private class BoxedValue: ErrorGenerating {
    var value: JSONValue

    static func build<E: Encodable>(from encodable: E, userInfo: [CodingUserInfoKey : Any]) throws -> BoxedValue? {
        if let date = encodable as? Date {
            return BoxedValue(.string(date.iso8601DateTime))
        }
        else if let data = encodable as? Data {
            return BoxedValue(.string(data.base64))
        }
        else {
            let encoder = JSONWithCancelableNodesEncoder()
            encoder.userInfo = userInfo
            try encodable.encode(to: encoder)

            switch encoder.boxedValue.value {
            case .none:
                return nil
            default:
                return encoder.boxedValue
            }
        }
    }

    init(_ value: JSONValue) {
        self.value = value
    }

    var jsonString: String? {
        switch self.value {
        case .none:
            return nil
        case .bool(let bool):
            return bool ? "true" : "false"
        case .double(let double):
            return "\(double)"
        case .float(let float):
            return "\(float)"
        case .integer(let integer):
            return "\(integer)"
        case .unsignedInteger(let integer):
            return "\(integer)"
        case .string(let string):
            return "\"\(self.escape(string))\""
        case .null:
            return "null"
        case .array(let array):
            let strings = array.compactMap({$0.jsonString})
            return "[" + strings.joined(separator: ",") + "]"
        case .dictionary(let dictionary):
            let strings: [String] = dictionary.compactMap({ (arg: (key: String, value: BoxedValue)) in
                let (key, value) = arg
                guard let string = value.jsonString else {
                    return nil
                }
                return "\"\(self.escape(key ))\":\(string)"
            })
            return "{" + strings.joined(separator: ",") + "}"
        }
    }

    fileprivate func escape(_ string: String) -> String {
        var output = ""
        for character in string {
            switch character {
            case "\u{8}":
                output += "\\b"
            case "\u{12}":
                output += "\\f"
            case "\n":
                output += "\\n"
            case "\r":
                output += "\\r"
            case "\r\n":
                output += "\\r\\n"
            case "\t":
                output += "\\t"
            case "\"":
                output += "\\\""
            case "\\":
                output += "\\\\"
            default:
                output.append(character)
            }
        }
        return output
    }

    fileprivate func set(_ value: JSONValue, forKey key: String) throws {
        try self.set(BoxedValue(value), forKey: key)
    }

    fileprivate func set(_ value: BoxedValue, forKey key: String) throws {
        switch self.value {
        case .none:
            self.value = .dictionary([key: value])
        case .dictionary(var existing):
            existing[key] = value
            self.value = .dictionary(existing)
        default:
            throw self.error("encoding", because: "a mixture of key/value pairs and just values is not supported")
        }
    }

    fileprivate func append(_ value: JSONValue) throws {
        try self.append(BoxedValue(value))
    }

    fileprivate func append(_ value: BoxedValue) throws {
        switch self.value {
        case .none:
            self.value = .array([value])
        case .array(var existing):
            existing.append(value)
            self.value = .array(existing)
        default:
            throw self.error("encoding", because: "a mixture of a value array and just values is not supported")
        }
    }

    fileprivate func set(singleValue: JSONValue) throws {
        switch self.value {
        case .none:
            self.value = singleValue
        default:
            throw self.error("encoding", because: "multiple single values is not supported")
        }
    }
}

private class JSONWithCancelableNodesKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey : Any]
    let boxedValue: BoxedValue

    init(boxedValue: BoxedValue, userInfo: [CodingUserInfoKey : Any]) {
        self.boxedValue = boxedValue
        self.userInfo = userInfo
    }

    func encodeNil(forKey key: Key)                 throws { try self.boxedValue.set(.null, forKey: key.stringValue) }
    func encode(_ value: Int, forKey key: Key)      throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: Bool, forKey key: Key)     throws { try self.boxedValue.set(.bool(value), forKey: key.stringValue) }
    func encode(_ value: Float, forKey key: Key)    throws { try self.boxedValue.set(.float(value), forKey: key.stringValue) }
    func encode(_ value: Double, forKey key: Key)   throws { try self.boxedValue.set(.double(value), forKey: key.stringValue) }
    func encode(_ value: String, forKey key: Key)   throws { try self.boxedValue.set(.string(value), forKey: key.stringValue) }
    func encode(_ value: Int8, forKey key: Key)     throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: Int16, forKey key: Key)    throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: Int32, forKey key: Key)    throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: Int64, forKey key: Key)    throws { try self.boxedValue.set(.integer(value), forKey: key.stringValue) }
    func encode(_ value: UInt, forKey key: Key)     throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: UInt8, forKey key: Key)    throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: UInt16, forKey key: Key)   throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: UInt32, forKey key: Key)   throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }
    func encode(_ value: UInt64, forKey key: Key)   throws { try self.boxedValue.set(.integer(Int64(value)), forKey: key.stringValue) }

    func encode<T>(_ value: T, forKey key: Key)     throws where T : Swift.Encodable {
        guard let boxed = try BoxedValue.build(from: value, userInfo: self.userInfo) else {
            return
        }
        try self.boxedValue.set(boxed, forKey: key.stringValue)
    }

    func superEncoder() -> Swift.Encoder {
        fatalError("JSONWithCancelableNodesEncoding does not support super encoders")
    }

    func superEncoder(forKey key: Key) -> Swift.Encoder {
        fatalError("JSONWithCancelableNodesEncoding does not support super encoders")
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        do {
            let boxed = BoxedValue(.none)
            try self.boxedValue.set(boxed, forKey: key.stringValue)
            return KeyedEncodingContainer(JSONWithCancelableNodesKeyedEncodingContainer<NestedKey>(boxedValue: boxed, userInfo: self.userInfo))
        }
        catch {
            fatalError("\(error)")
        }
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        do {
            let boxed = BoxedValue(.none)
            try self.boxedValue.set(boxed, forKey: key.stringValue)
            return JSONWithCancelableNodesUnkeyedEncodingContainer(boxedValue: boxed, userInfo: self.userInfo)
        }
        catch {
            fatalError("\(error)")
        }
    }
}

private class JSONWithCancelableNodesUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey : Any]
    let boxedValue: BoxedValue

    var count: Int {
        switch self.boxedValue.value {
        case .array(let array):
            return array.count
        default:
            return 0
        }
    }

    init(boxedValue: BoxedValue, userInfo: [CodingUserInfoKey : Any]) {
        self.boxedValue = boxedValue
        self.userInfo = userInfo
    }

    func encodeNil()             throws { try self.boxedValue.append(.null) }
    func encode(_ value: Bool)   throws { try self.boxedValue.append(.bool(value)) }
    func encode(_ value: Int)    throws { try self.boxedValue.append(.integer(Int64(value))) }
    func encode(_ value: Int8)   throws { try self.boxedValue.append(.integer(Int64(value))) }
    func encode(_ value: Int16)  throws { try self.boxedValue.append(.integer(Int64(value))) }
    func encode(_ value: Int32)  throws { try self.boxedValue.append(.integer(Int64(value))) }
    func encode(_ value: Int64)  throws { try self.boxedValue.append(.integer(Int64(value))) }
    func encode(_ value: UInt)   throws { try self.boxedValue.append(.unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt8)  throws { try self.boxedValue.append(.unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt16) throws { try self.boxedValue.append(.unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt32) throws { try self.boxedValue.append(.unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt64) throws { try self.boxedValue.append(.unsignedInteger(UInt64(value))) }
    func encode(_ value: String) throws { try self.boxedValue.append(.string(value)) }
    func encode(_ value: Float)  throws { try self.boxedValue.append(.float(value)) }
    func encode(_ value: Double) throws { try self.boxedValue.append(.double(value)) }

    func encode<T : Encodable>(_ value: T) throws {
        guard let boxed = try BoxedValue.build(from: value, userInfo: self.userInfo) else {
            return
        }
        try self.boxedValue.append(boxed)
    }

    func superEncoder() -> Encoder {
        fatalError("JSONWithCancelableNodesEncoding does not support super encoders")
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("encoding a nested container is not supported")
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("encoding a nested unkeyed container is not supported")
    }
}

private class JSONWithCancelableNodesSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey : Any]
    let boxedValue: BoxedValue

    var count: Int {
        switch self.boxedValue.value {
        case .array(let array):
            return array.count
        default:
            return 0
        }
    }

    init(boxedValue: BoxedValue, userInfo: [CodingUserInfoKey : Any]) {
        self.boxedValue = boxedValue
        self.userInfo = userInfo
    }

    func encodeNil()             throws { try self.boxedValue.set(singleValue: .null) }
    func encode(_ value: Bool)   throws { try self.boxedValue.set(singleValue: .bool(value)) }
    func encode(_ value: Int)    throws { try self.boxedValue.set(singleValue: .integer(Int64(value))) }
    func encode(_ value: Int8)   throws { try self.boxedValue.set(singleValue: .integer(Int64(value))) }
    func encode(_ value: Int16)  throws { try self.boxedValue.set(singleValue: .integer(Int64(value))) }
    func encode(_ value: Int32)  throws { try self.boxedValue.set(singleValue: .integer(Int64(value))) }
    func encode(_ value: Int64)  throws { try self.boxedValue.set(singleValue: .integer(Int64(value))) }
    func encode(_ value: UInt)   throws { try self.boxedValue.set(singleValue: .unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt8)  throws { try self.boxedValue.set(singleValue: .unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt16) throws { try self.boxedValue.set(singleValue: .unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt32) throws { try self.boxedValue.set(singleValue: .unsignedInteger(UInt64(value))) }
    func encode(_ value: UInt64) throws { try self.boxedValue.set(singleValue: .unsignedInteger(UInt64(value))) }
    func encode(_ value: String) throws { try self.boxedValue.set(singleValue: .string(value)) }
    func encode(_ value: Float)  throws { try self.boxedValue.set(singleValue: .float(value)) }
    func encode(_ value: Double) throws { try self.boxedValue.set(singleValue: .double(value)) }

    func encode<T : Encodable>(_ value: T) throws {
        guard let boxed = try BoxedValue.build(from: value, userInfo: self.userInfo) else {
            return
        }
        try self.boxedValue.set(singleValue: boxed.value)
    }

    func superEncoder() -> Encoder {
        fatalError("JSONWithCancelableNodesEncoding does not support super encoders")
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("encoding a nested container is not supported")
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("encoding a nested unkeyed container is not supported")
    }
}

