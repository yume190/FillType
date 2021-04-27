//
//  ArrayBuilder.swift
//  TypeFillKit
//
//  Created by Yume on 2021/2/19.
//

import Foundation

@frozen
public indirect enum ArrayBox<T> {
    case single(T)
    case multi([T])
    case nothing
    case nest([ArrayBox<T>])
    
    var flat: [T] {
        switch self {
        case .nothing:
            return []
        case .single(let t):
            return [t]
        case .multi(let ts):
            return ts
        case .nest(let ns):
            return ns.flatMap {
                $0.flat
            }
        }
    }
}

#if swift(>=5.4)
@resultBuilder
public enum ArrayBuilder<T> {}
#else
@_functionBuilder
public enum ArrayBuilder<T> {}
#endif

extension ArrayBuilder {
    public static func buildExpression(_ item: T) -> ArrayBox<T> {
        return .single(item)
    }
    
    public static func buildExpression(_ item: T?) -> ArrayBox<T> {
        guard let item: T = item else { return .nothing }
        return .single(item)
    }
    
    public static func buildExpression(_ item: [T]) -> ArrayBox<T> {
        return .multi(item)
    }
    
    public static func buildFinalResult(_ box: ArrayBox<T>) -> [T] {
        return box.flat
    }
    
    public static func buildBlock() -> ArrayBox<T> {
        return .nothing
    }
    
    public static func buildBlock(_ items: ArrayBox<T>...) -> ArrayBox<T> {
        return .nest(items)
    }
    
    public static func buildIf(_ value: ArrayBox<T>?) -> ArrayBox<T> {
        guard let v: ArrayBox<T> = value else { return .nothing }
        return v
    }
    
    public static func buildEither(first value: ArrayBox<T>) -> ArrayBox<T> {
        return value
    }

    public static func buildEither(second value: ArrayBox<T>) -> ArrayBox<T> {
        return value
    }
}

