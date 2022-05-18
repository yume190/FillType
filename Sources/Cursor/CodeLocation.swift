//
//  CodeLocation.swift
//  TypeFillTests
//
//  Created by Yume on 2021/10/21.
//

import Foundation
import SwiftSyntax
import Rainbow

public struct CodeLocation: CustomStringConvertible, Equatable {
    public let path: String
    public let location: SwiftSyntax.SourceLocation
    public let syntax: SyntaxProtocol?
    
    public init(path: String, location: SwiftSyntax.SourceLocation, syntax: SyntaxProtocol? = nil) {
        self.path = path
        self.location = location
        self.syntax = syntax
    }
    
    public var description: String {
        return "\(path):\(location) \(syntax?.withoutTrivia().description ?? "")"
    }
    
    public static func == (lhs: CodeLocation, rhs: CodeLocation) -> Bool {
        return
            lhs.path == rhs.path &&
            lhs.location.offset == rhs.location.offset
    }
}

extension CodeLocation: Reportable {
    public var reportXCode: String {
        if let column = location.column {
            return "col: \(column)"
        }
        return ""
    }
    
    public var reportXCodeLocation: SourceLocation? {
        return location
    }
    
    public var reportVSCode: String {
        return self.description.red
    }
}
