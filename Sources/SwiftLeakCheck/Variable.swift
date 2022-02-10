//
//  Variable.swift
//  LeakCheck
//
//  Copyright 2020 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//
//  Created by Hoang Le Pham on 27/10/2019.
//

import SwiftSyntax

public enum RawVariable {
  case capture(capturedNode: IdentifierExprSyntax)
  case param(token: TokenSyntax)
  case binding(token: TokenSyntax, valueNode: ExprSyntax?)
  
  var token: TokenSyntax {
    switch self {
    case .capture(let capturedNode): return capturedNode.identifier
    case .binding(let token, _): return token
    case .param(let token): return token
    }
  }
}

indirect enum TypeInfo {
  case exact(TypeSyntax)
  case inferedFromExpr(ExprSyntax)
  case inferedFromSequence(ExprSyntax)
  case inferedFromTuple(tupleType: TypeInfo, index: Int)
  case inferedFromClosure(ClosureExprSyntax, paramIndex: Int, paramCount: Int)
}

// Represent a variable declaration. Eg
// var a = 1
// let b = c // b is the Variable, c is not (c is a reference)
// block { [unowned x] in // x is a Variable
// func doSmth(a: Int, b: String) // a, b are Variables
public class Variable: Hashable, CustomStringConvertible {
  public let raw: RawVariable
  public var name: String { return raw.token.text }
  let typeInfo: TypeInfo
  public let memoryAttribute: MemoryAttribute?
  public let scope: Scope
  
  var valueNode: ExprSyntax? {
    switch raw {
    case .binding(_, let valueNode): return valueNode
    case .param, .capture: return nil
    }
  }
  
  var capturedNode: IdentifierExprSyntax? {
    switch raw {
    case .capture(let capturedNode): return capturedNode
    case .binding, .param: return nil
    }
  }
  
  public var isStrong: Bool {
    return memoryAttribute?.isStrong ?? true
  }
  
  public var description: String {
    return "\(raw)"
  }
  
  private init(raw: RawVariable,
               typeInfo: TypeInfo,
               scope: Scope,
               memoryAttribute: MemoryAttribute? = nil) {
    self.raw = raw
    self.typeInfo = typeInfo
    self.scope = scope
    self.memoryAttribute = memoryAttribute
  }
  
  public static func from(_ node: ClosureCaptureItemSyntax, scope: Scope) -> Variable? {
    assert(scope.scopeNode == node.enclosingScopeNode)
    
    guard let identifierExpr: IdentifierExprSyntax = node.expression.as(IdentifierExprSyntax.self) else {
      // There're cases such as { [loggedInState.services] in ... }, which probably we don't need to care about
      return nil
    }
    
    let memoryAttribute: MemoryAttribute? = {
      guard let specifier: TokenListSyntax.Element = node.specifier?.first else {
        return nil
      }
      
      assert(node.specifier!.count <= 1, "Unhandled case")
      
      guard let memoryAttribute: MemoryAttribute = MemoryAttribute.from(specifier.text) else {
        fatalError("Unhandled specifier \(specifier.text)")
      }
      return memoryAttribute
    }()
    
    return Variable(
      raw: .capture(capturedNode: identifierExpr),
      typeInfo: .inferedFromExpr(ExprSyntax(identifierExpr)),
      scope: scope,
      memoryAttribute: memoryAttribute
    )
  }
  
  public static func from(_ node: ClosureParamSyntax, scope: Scope) -> Variable {
    guard let closure: ClosureExprSyntax = node.getEnclosingClosureNode() else {
      fatalError()
    }
    assert(scope.scopeNode == .closureNode(closure))
    
    return Variable(
      raw: .param(token: node.name),
      typeInfo: .inferedFromClosure(closure, paramIndex: node.indexInParent, paramCount: node.parent!.children.count),
      scope: scope
    )
  }
  
  public static func from(_ node: FunctionParameterSyntax, scope: Scope) -> Variable {
    assert(node.enclosingScopeNode == scope.scopeNode)
    
    guard let token: TokenSyntax = node.secondName ?? node.firstName else {
      fatalError()
    }
    
    assert(token.tokenKind != .wildcardKeyword, "Unhandled case")
    assert(node.attributes == nil, "Unhandled case")
    
    guard let type: TypeSyntax = node.type else {
      // Type is omited, must be used in closure signature
      guard case let .closureNode(closureNode) = scope.scopeNode else {
        fatalError("Only closure can omit the param type")
      }
      return Variable(
        raw: .param(token: token),
        typeInfo: .inferedFromClosure(closureNode, paramIndex: node.indexInParent, paramCount: node.parent!.children.count),
        scope: scope
      )
    }
    
    return Variable(raw: .param(token: token), typeInfo: .exact(type), scope: scope)
  }
  
  public static func from(_ node: PatternBindingSyntax, scope: Scope) -> [Variable] {
    guard let parent: PatternBindingListSyntax = node.parent?.as(PatternBindingListSyntax.self) else {
      fatalError()
    }
    
    assert(parent.parent?.is(VariableDeclSyntax.self) == true, "Unhandled case")
    
    func _typeFromNode(_ node: PatternBindingSyntax) -> TypeInfo {
      // var a: Int
      if let typeAnnotation: TypeAnnotationSyntax = node.typeAnnotation {
        return .exact(typeAnnotation.type)
      }
      // var a = value
      if let value: ExprSyntax = node.initializer?.value {
        return .inferedFromExpr(value)
      }
      // var a, b, .... = value
      let indexOfNextNode: Int = node.indexInParent + 1
      return _typeFromNode(parent[indexOfNextNode])
    }
    
    let type: TypeInfo = _typeFromNode(node)
    
    if let identifier: IdentifierPatternSyntax = node.pattern.as(IdentifierPatternSyntax.self) {
      let memoryAttribute: MemoryAttribute? = {
        if let modifier: ModifierListSyntax.Element = node.parent?.parent?.as(VariableDeclSyntax.self)!.modifiers?.first {
          return MemoryAttribute.from(modifier.name.text)
        }
        return nil
      }()
      
      return [
        Variable(
          raw: .binding(token: identifier.identifier, valueNode: node.initializer?.value),
          typeInfo: type,
          scope: scope,
          memoryAttribute: memoryAttribute
        )
      ]
    }
    
    if let tuple: TuplePatternSyntax = node.pattern.as(TuplePatternSyntax.self) {
      return extractVariablesFromTuple(tuple, tupleType: type, tupleValue: node.initializer?.value, scope: scope)
    }
    
    return []
  }
  
  public static func from(_ node: OptionalBindingConditionSyntax, scope: Scope) -> Variable? {
    if let left: IdentifierPatternSyntax = node.pattern.as(IdentifierPatternSyntax.self) {
      let right: ExprSyntax = node.initializer.value
      let type: TypeInfo
      if let typeAnnotation: TypeAnnotationSyntax = node.typeAnnotation {
        type = .exact(typeAnnotation.type)
      } else {
        type = .inferedFromExpr(right)
      }
      
      return Variable(
        raw: .binding(token: left.identifier, valueNode: right),
        typeInfo: type,
        scope: scope,
        memoryAttribute: .strong
      )
    }
    
    return nil
  }
  
  public static func from(_ node: ForInStmtSyntax, scope: Scope) -> [Variable] {
    func _variablesFromPattern(_ pattern: PatternSyntax) -> [Variable] {
      if let identifierPattern: IdentifierPatternSyntax = pattern.as(IdentifierPatternSyntax.self) {
        return [
          Variable(
            raw: .binding(token: identifierPattern.identifier, valueNode: nil),
            typeInfo: .inferedFromSequence(node.sequenceExpr),
            scope: scope
          )
        ]
      }
      
      if let tuplePattern: TuplePatternSyntax = pattern.as(TuplePatternSyntax.self) {
        return extractVariablesFromTuple(
          tuplePattern,
          tupleType: .inferedFromSequence(node.sequenceExpr),
          tupleValue: nil,
          scope: scope
        )
      }
      
      if pattern.is(WildcardPatternSyntax.self) {
        return []
      }
      
      if let valueBindingPattern: ValueBindingPatternSyntax = pattern.as(ValueBindingPatternSyntax.self) {
        return _variablesFromPattern(valueBindingPattern.valuePattern)
      }
      
//      assert(false, "Unhandled pattern in for statement: \(pattern)")
      return []
    }
    
    return _variablesFromPattern(node.pattern)
  }
  
  private static func extractVariablesFromTuple(_ tuplePattern: TuplePatternSyntax,
                                                tupleType: TypeInfo,
                                                tupleValue: ExprSyntax?,
                                                scope: Scope) -> [Variable] {
    return tuplePattern.elements.enumerated().flatMap { (index: Int, element: TuplePatternElementListSyntax.Element) -> [Variable] in
      
      let elementType: TypeInfo = .inferedFromTuple(tupleType: tupleType, index: index)
      let elementValue: ExprSyntax? = {
        if let tupleValue: TupleExprSyntax = tupleValue?.as(TupleExprSyntax.self) {
          return tupleValue.elementList[index].expression
        }
        return nil
      }()
      
      if let identifierPattern: IdentifierPatternSyntax = element.pattern.as(IdentifierPatternSyntax.self) {
        return [
          Variable(
            raw: .binding(token: identifierPattern.identifier, valueNode: elementValue),
            typeInfo: elementType,
            scope: scope
          )
        ]
      }
      
      if let childTuplePattern: TuplePatternSyntax = element.pattern.as(TuplePatternSyntax.self) {
        return extractVariablesFromTuple(
          childTuplePattern,
          tupleType: elementType,
          tupleValue: elementValue,
          scope: scope
        )
      }
      
      if element.pattern.is(WildcardPatternSyntax.self) {
        return []
      }
      
      assertionFailure("I don't think there's any other kind")
      return []
    }
  }
}

// MARK: - Hashable
public extension Variable {
  static func == (_ lhs: Variable, _ rhs: Variable) -> Bool {
    return lhs.raw.token == rhs.raw.token
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(raw.token)
  }
}

public enum MemoryAttribute: Hashable {
  case weak
  case unowned
  case strong
  
  public var isStrong: Bool {
    switch self {
    case .weak,
         .unowned:
      return false
    case .strong:
      return true
    }
  }
  
  public static func from(_ text: String) -> MemoryAttribute? {
    switch text {
    case "weak":
      return .weak
    case "unowned":
      return .unowned
    default:
      return nil
    }
  }
}
