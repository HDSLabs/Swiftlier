//
//  CoderKey.swift
//  AtomicObjectFiles
//
//  Created by Andrew J Wagner on 10/9/15.
//  Copyright © 2015 Drewag, LLC. All rights reserved.
//

import Foundation

public protocol RawEncodableType: CodableType {
    init()
    var asObject: Any { get }
}

extension RawEncodableType {
    public func encode(_ encoder: EncoderType) {
        encoder.encodeAsEntireValue(self)
    }
}

extension RawEncodableType {
    public init(decoder: DecoderType) throws {
        self = try decoder.decodeAsEntireValue()
    }
}

extension String: RawEncodableType { public var asObject: Any { return self as Any } }
extension Bool: RawEncodableType { public var asObject: Any { return self as Any } }
extension Int: RawEncodableType { public var asObject: Any { return self as Any } }
extension Double: RawEncodableType { public var asObject: Any { return self as Any } }
extension Float: RawEncodableType { public var asObject: Any { return self as Any } }
extension Data: RawEncodableType { public var asObject: Any { return self as Any } }
extension Date: RawEncodableType { public var asObject: Any { return self as Any } }

open class CoderKey<Value: EncodableType> {
    open class var customKey: String? { return nil }
}

open class OptionalCoderKey<Value: EncodableType> {
    open class var customKey: String? { return nil }
}

extension CoderKey {
    static var path: [String] {
        return self.customKey?.components(separatedBy: ".")
            ?? [String(describing: Mirror(reflecting: self).subjectType).components(separatedBy: ".").first!]
    }
}

extension OptionalCoderKey {
    static var path: [String] {
        return self.customKey?.components(separatedBy: ".")
            ?? [String(describing: Mirror(reflecting: self).subjectType).components(separatedBy: ".").first!]
    }
}
