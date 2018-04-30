//
//  combinations.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/05/18.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

public extension 𝐙 {
    // TODO use IntList
    public func choose(_ k: Int) -> [[Int]] {
        let n = self
        switch (n, k) {
        case _ where n < k:
            return []
        case (_, 0):
            return [[]]
        default:
            return (n - 1).choose(k) + (n - 1).choose(k - 1).map{ $0 + [n - 1] }
        }
    }
    
    // TODO use IntList
    public func multichoose(_ k: Int) -> [[Int]] {
        let n = self
        switch (n, k) {
        case _ where n < 0:
            return []
        case (_, 0):
            return [[]]
        default:
            return (0 ... k).flatMap { (i: Int) -> [[Int]] in
                (n - 1).multichoose(k - i).map{ (c: [Int]) -> [Int] in c + Array(repeating: n - 1, count: i) }
            }
        }
    }
    
    public var partitions: [IntList] {
        assert(self >= 0)
        if self == 0 {
            return [IntList.empty]
        } else {
            return self.partitions(lowerBound: 1)
        }
    }
    
    internal func partitions(lowerBound: Int) -> [IntList] {
        let n = self
        if lowerBound > n {
            return []
        } else {
            return (lowerBound ... n).flatMap { i -> [IntList] in
                let ps = (n - i).partitions(lowerBound: Swift.max(i, lowerBound))
                return ps.map { I in IntList([i] + I.elements) }
            } + [IntList(n)]
        }
    }
}

