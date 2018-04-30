//
//  RowSortedMatrix.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/10/16.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

internal typealias ComputationSpecializedRing = 𝐙

internal final class MatrixImpl<R: Ring>: Hashable, CustomStringConvertible {
    typealias Component = MatrixComponent<R>
    typealias Table =  [Int : [(Int, R)]]
    
    enum Alignment: String, Codable {
        case Rows, Cols
    }
    
    var rows: Int
    var cols: Int
    
    var align: Alignment
    var table: Table
    
    private init(_ rows: Int, _ cols: Int, _ align: Alignment, _ table: Table) {
        if _isDebugAssertConfiguration() {
            switch align {
            case .Rows:
                assert(table.keys.forAll{ (0 ..< rows).contains($0) })
                assert(table.values.forAll{ $0.forAll{ (0 ..< cols).contains($0.0) } })
                assert(table.values.forAll{ $0.map{ $0.0 } == $0.map{ $0.0 }.unique().sorted() })
            case .Cols:
                assert(table.keys.forAll{ (0 ..< cols).contains($0) })
                assert(table.values.forAll{ $0.forAll{ (0 ..< rows).contains($0.0) } })
                assert(table.values.forAll{ $0.map{ $0.0 } == $0.map{ $0.0 }.unique().sorted() })
            }
        }
        
        self.rows = rows
        self.cols = cols
        self.align = align
        self.table = table
    }
    
    convenience init(rows: Int, cols: Int, align: Alignment = .Rows, grid: [R]) {
        let components = grid.enumerated().compactMap{ (k, a) -> Component? in
            (a != .zero) ? MatrixComponent(k / cols, k % cols, a) : nil
        }
        self.init(rows: rows, cols: cols, align: align, components: components)
    }
    
    convenience init(rows: Int, cols: Int, align: Alignment = .Rows, generator g: (Int, Int) -> R) {
        let components = (0 ..< rows).flatMap { i -> [Component] in
            (0 ..< cols).compactMap { j -> Component? in
                let a = g(i, j)
                return (a != .zero) ? Component(i, j, a) : nil
            }
        }
        self.init(rows: rows, cols: cols, align: align, components: components)
    }
    
    convenience init<S: Sequence>(rows: Int, cols: Int, align: Alignment = .Rows, components: S) where S.Element == Component {
        self.init(rows, cols, align, MatrixImpl.generateTable(align, components))
    }
    
    static func generateTable<S: Sequence>(_ align: Alignment, _ components: S) -> Table where S.Element == Component {
        switch align {
        case .Rows:
            return components.group{ c in c.row }.mapValues{ l in l.sorted{ c in c.col }.map{ c in (c.col, c.value) } }
        case .Cols:
            return components.group{ c in c.col }.mapValues{ l in l.sorted{ c in c.row }.map{ c in (c.row, c.value) } }
        }
    }
    
    subscript(i: Int, j: Int) -> R {
        get {
            switch align {
            case .Rows: return table[i]?.binarySearch(j, { $0.0 } )?.element.1 ?? .zero
            case .Cols: return table[j]?.binarySearch(i, { $0.0 } )?.element.1 ?? .zero
            }
        } set {
            switch align {
            case .Rows:
                let row = MatrixImpl.addRows(table[i] ?? [], [(j, newValue - self[i, j])])
                table[i] = row
            case .Cols:
                let col = MatrixImpl.addRows(table[j] ?? [], [(i, newValue - self[i, j])])
                table[j] = col
            }
        }
    }
    
    func copy() -> MatrixImpl<R> {
        return MatrixImpl(rows, cols, align, table)
    }
    
    func switchAlignment(_ align: Alignment) {
        if self.align == align {
            return
        }
        
        let comps = components
        
        self.align = align
        self.table = MatrixImpl.generateTable(align, comps)
    }
    
    var density: Double {
        let c = table.sum{ (_, list) in list.count }
        return Double(c) / Double(rows * cols)
    }
    
    var sparsity: Double {
        return 1.0 - density
    }
    
    var isZero: Bool {
        return table.isEmpty
    }
    
    var isDiagonal: Bool {
        return table.forAll { (i, list) in (list.count == 1) && list.first!.0 == i }
    }
    
    static func identity(size n: Int, align: Alignment) -> MatrixImpl<R> {
        let components = (0 ..< n).map{ i in MatrixComponent(i, i, R.identity)}
        return MatrixImpl(rows: n, cols: n, align: align, components: components)
    }
    
    var components: [Component] {
        switch align {
        case .Rows:
            return table.flatMap{ (i, list) in list.map{(j, a) in MatrixComponent(i, j, a)} }
        case .Cols:
            return table.flatMap{ (j, list) in list.map{(i, a) in MatrixComponent(i, j, a)} }
        }
    }
    
    func components(ofRow i: Int) -> [Component] {
        switch align {
        case .Rows:
            return table[i].map { list in list.map{ (j, r) in MatrixComponent(i, j, r) } } ?? []
        case .Cols:
            return table.compactMap{ (j, list) in list.binarySearch(i, { $0.0 } ).map{ MatrixComponent(i, j, $0.1.1) } }
        }
    }
    
    func components(ofCol j: Int) -> [Component] {
        switch align {
        case .Cols:
            return table[j].map { list in list.map{ (i, r) in MatrixComponent(i, j, r) } } ?? []
        case .Rows:
            return table.compactMap{ (i, list) in list.binarySearch(j, { $0.0 } ).map{ MatrixComponent(i, j, $0.1.1) } }
        }
    }
    
    var grid: [R] {
        var grid = Array(repeating: R.zero, count: rows * cols)
        for c in components {
            grid[c.row * cols + c.col] = c.value
        }
        return grid
    }
    
    @discardableResult
    func transpose() -> MatrixImpl<R> {
        (rows, cols) = (cols, rows)
        align = (align == .Rows) ? .Cols : .Rows
        return self
    }
    
    var transposed: MatrixImpl<R> {
        return self.copy().transpose()
    }
    
    func submatrix(rowRange: CountableRange<Int>) -> MatrixImpl<R> {
        return submatrix(rowRange, 0 ..< cols)
    }
    
    func submatrix(colRange: CountableRange<Int>) -> MatrixImpl<R> {
        return submatrix(0 ..< rows, colRange)
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func submatrix(_ rowRange: CountableRange<Int>, _ colRange: CountableRange<Int>) -> MatrixImpl<R> {
        assert(0 <= rowRange.lowerBound && rowRange.upperBound <= rows)
        assert(0 <= colRange.lowerBound && colRange.upperBound <= cols)

        return submatrix({i in rowRange.contains(i)}, {j in colRange.contains(j)})
    }
    
    func submatrix(_ rowCond: (Int) -> Bool, _ colCond: (Int) -> Bool) -> MatrixImpl<R> {
        let (sRows, sCols, iList, jList): (Int, Int, [Int], [Int])
        
        switch align {
        case .Rows:
            (iList, jList) = ((0 ..< rows).filter(rowCond), (0 ..< cols).filter(colCond))
            (sRows, sCols) = (iList.count, jList.count)
        case .Cols:
            (iList, jList) = ((0 ..< cols).filter(colCond), (0 ..< rows).filter(rowCond))
            (sRows, sCols) = (jList.count, iList.count)
        }
        
        let subTable = table.compactMap{ (i, list) -> (Int, [(Int, R)])? in
            guard let i1 = iList.binarySearch(i) else {
                return nil
            }
            let subList = list.compactMap{ (j, a) -> (Int, R)? in
                guard let j1 = jList.binarySearch(j) else {
                    return nil
                }
                return (j1, a)
            }
            return !subList.isEmpty ? (i1, subList) : nil
        }
        
        return MatrixImpl(sRows, sCols, align, Dictionary(pairs: subTable))
    }
    
    func mapValues<R2>(_ f: (R) -> R2) -> MatrixImpl<R2> {
        typealias M = MatrixImpl<R2>
        let mapped = table.mapValues { $0.map{ ($0, f($1)) } }
        let a = (align == .Rows) ? M.Alignment.Rows : M.Alignment.Cols
        return M(rows, cols, a, mapped)
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func ==(a: MatrixImpl, b: MatrixImpl) -> Bool {
        if (a.rows, a.cols) != (b.rows, b.cols) {
            return false
        }
        return Set(a.components) == Set(b.components)
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func +(a: MatrixImpl, b: MatrixImpl) -> MatrixImpl<R> {
        assert( (a.rows, a.cols) == (b.rows, b.cols) )
        
        b.switchAlignment(a.align)
        
        let iList = Set(a.table.keys).union(b.table.keys)
        let table = iList.compactMap { i in
            MatrixImpl.addRows(a.table[i] ?? [], b.table[i] ?? []).map{ (i, $0) }
        }
        
        return MatrixImpl(a.rows, a.cols, a.align, Dictionary(pairs: table))
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static prefix func -(a: MatrixImpl) -> MatrixImpl<R> {
        return a.mapValues{ -$0 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(r: R, a: MatrixImpl) -> MatrixImpl<R> {
        return a.mapValues{ r * $0 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(a: MatrixImpl, r: R) -> MatrixImpl<R> {
        return a.mapValues{ $0 * r }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(a: MatrixImpl, b: MatrixImpl) -> MatrixImpl<R> {
        assert(a.cols == b.rows)
        
        // TODO support .Cols
        
        a.switchAlignment(.Rows)
        b.switchAlignment(.Rows)
        
        let table = a.table.compactMap { (i, list1) -> (Int, [(Int, R)])? in
            
            //       k              j
            //       v            | v        |
            //  i>|  x    *  |  k>| y   *    |
            //                    |          |
            //                    | * *    * |
            //                    |          |
            //
            //                         ↓
            //
            //                  i>| * * *  * |
            
            var tmp: [Int: R] = [:]
            
            for (k, x) in list1 where b.table[k] != nil {
                let list2 = b.table[k]!
                for (j, y) in list2 {
                    tmp[j] = (tmp[j] ?? .zero) + x * y
                }
            }
            
            let row = tmp.filter{ $0.value != .zero }.map{ ($0.key, $0.value ) }.sorted{ $0.0 }
            return !row.isEmpty ? (i, row) : nil
        }
        
        return MatrixImpl(a.rows, b.cols, a.align, Dictionary(pairs: table))
    }

    @_specialize(where R == ComputationSpecializedRing)
    func multiplyRow(at i0: Int, by r: R) {
        switchAlignment(.Rows)
        
        guard var row = table[i0] else {
            return
        }
        
        let n = row.count
        var p = UnsafeMutablePointer(&row)
        
        for _ in 0 ..< n {
            let (j, a) = p.pointee
            p.pointee = (j, r * a)
            p += 1
        }
        
        row = row.filter{ $0.1 != .zero }
        table[i0] = !row.isEmpty ? row : nil
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func addRow(at i0: Int, to i1: Int, multipliedBy r: R = .identity) {
        switchAlignment(.Rows)
        
        let row0 = table[i0]?.map{ (j, a) in (j, r * a) } ?? []
        let row1 = table[i1] ?? []
        
        table[i1] = MatrixImpl.addRows(row0, row1)
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func addRows(_ row0: [(Int, R)], _ row1: [(Int, R)]) -> [(Int, R)]? {
        switch (row0.isEmpty, row1.isEmpty) {
        case (true,  true): return nil
        case (false, true): return row0
        case (true, false): return row1
        default: ()
        }
        
        var result: [(Int, R)] = []
        
        let (n0, n1) = (row0.count, row1.count)
        var (p0, p1) = (UnsafePointer(row0), UnsafePointer(row1))
        var (k0, k1) = (0, 0) // counters

        while k0 < n0 && k1 < n1 {
            let (j0, a0) = p0.pointee
            let (j1, a1) = p1.pointee
            
            if j0 == j1 {
                result.append((j0, a0 + a1))
                
                p0 += 1
                p1 += 1
                k0 += 1
                k1 += 1
                
            } else if j0 < j1 {
                result.append((j0, a0))
                
                p0 += 1
                k0 += 1
                
            } else if j0 > j1 {
                result.append( (j1, a1) )
                
                p1 += 1
                k1 += 1
            }
        }
        
        for _ in k0 ..< n0 {
            let (j0, a0) = p0.pointee
            result.append((j0, a0))
            
            p0 += 1
            k0 += 1
        }
        
        for _ in k1 ..< n1 {
            let (j1, a1) = p1.pointee
            result.append((j1, a1))
            
            p1 += 1
            k1 += 1
        }
        
        result = result.filter{ $0.1 != .zero }
        return !result.isEmpty ? result : nil
    }
    
    func swapRows(_ i0: Int, _ i1: Int) {
        switchAlignment(.Rows)
        
        let r0 = table[i0]
        table[i0] = table[i1]
        table[i1] = r0
    }
    
    func multiplyCol(at j0: Int, by r: R) {
        transpose()
        multiplyRow(at: j0, by: r)
        transpose()
    }
    
    func addCol(at j0: Int, to j1: Int, multipliedBy r: R = .identity) {
        transpose()
        addRow(at: j0, to: j1, multipliedBy: r)
        transpose()
    }
    
    func swapCols(_ j0: Int, _ j1: Int) {
        transpose()
        swapRows(j0, j1)
        transpose()
    }
    
    var hashValue: Int {
        return isZero ? 0 : 1 // TODO
    }
    
    var description: String {
        return "CMatrix<\(rows), \(cols)> [ " + table.flatMap { (i, list) in
            list.map{ (j, a) in "\(a)" + Format.sub("\(align == .Rows ? (i, j) : (j, i) )") }
        }.joined(separator: ", ") + " ]"
    }
}

extension MatrixImpl where R: EuclideanRing{
    func eliminate(form: MatrixForm = .Diagonal) -> MatrixEliminationResultImpl<R> {
        let eliminator = { () -> MatrixEliminator<R> in
            switch form {
            case .RowEchelon: return RowEchelonEliminator(self)
            case .ColEchelon: return ColEchelonEliminator(self)
            case .RowHermite: return RowHermiteEliminator(self)
            case .ColHermite: return ColHermiteEliminator(self)
            case .Diagonal:   return DiagonalEliminator  (self)
            case .Smith:      return SmithEliminator     (self)
            default: fatalError()
            }
        }()
        
        return eliminator.run()
    }
}

extension MatrixImpl: Codable where R: Codable {
    enum CodingKeys: String, CodingKey {
        case rows, cols, grid, components
    }
    
    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decode(Int.self, forKey: .rows)
        let cols = try c.decode(Int.self, forKey: .cols)
        
        if c.contains(.grid) {
            let grid = try c.decode([R].self, forKey: .grid)
            self.init(rows: rows, cols: cols, align: .Rows, grid: grid)
        } else {
            let comps = try c.decode([Component].self, forKey: .components)
            self.init(rows: rows, cols: cols, align: .Rows, components: comps)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rows, forKey: .rows)
        try c.encode(cols, forKey: .cols)
        if density > 0.5 {
            try c.encode(grid, forKey: .grid)
        } else {
            try c.encode(components, forKey: .components)
        }
    }
}
