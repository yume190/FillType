//
//  CodeLocation.swift
//  TypeFillTests
//
//  Created by Yume on 2021/10/21.
//

import Foundation
import SwiftSyntax

public struct CodeLocation: CustomStringConvertible, Equatable {
    public let path: String
    public let location: SwiftSyntax.SourceLocation
    public var description: String {
        return "\(path):\(location)"
    }
}
