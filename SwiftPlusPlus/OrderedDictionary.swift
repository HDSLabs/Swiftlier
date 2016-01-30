//
//  OrderedDictionary.swift
//  SwiftPlusPlus
//
//  Created by Andrew J Wagner on 11/20/15.
//  Copyright © 2015 Drewag LLC. All rights reserved.
//

import Foundation

public struct OrderedDictionary<Key: Hashable, Value> {
    private var valueStore = [Value?]()
    private var lookup = [Key:Int]()

    var count: Int = 0

    public subscript(key: Key) -> Value? {
        get {
            if let index = lookup[key] {
                return self.valueStore[index]
            }
            return nil
        }
        set {
            if let existingIndex = lookup[key] {
                valueStore[existingIndex] = nil
                count--
            }
            if let index = newValue {
                valueStore.append(index)
                lookup[key] = valueStore.count - 1
                count++
            }
        }
    }

    public var values: [Value] {
        return self.valueStore.flatMap({$0})
    }

    public mutating func removeAll() {
        self.valueStore.removeAll()
        self.lookup.removeAll()
    }
}

extension OrderedDictionary where Value: Equatable {
    public func indexOfValueWithKey(key: Key) -> Int? {
        let object = self[key]
        return self.values.indexOfObjectPassingTest {$0 == object}
    }
}