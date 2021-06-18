# TypeFill

[![Quality gate](https://sonarcloud.io/api/project_badges/quality_gate?project=yume190_TypeFill)](https://sonarcloud.io/dashboard?id=yume190_TypeFill)
![Swift](https://github.com/yume190/TypeFill/workflows/Swift/badge.svg)

----

A little cli tool to help you fill your `variables type`.

~~And add `private final` attribute to `@IBAction`, `@IBOutlet`, and `@objc`.(Rewriting ...)~~

## Installation

---

### make

``` sh
brew install make
make install
```

### Swift Package Manager

``` sh
swift build -c release
cp .build/release/typefill /usr/local/bin
```

### mint

``` sh
brew install mint
mint install yume190/TypeFill
```

### Usage

``` sh
typefill single --filePath /ABSOLUTE/PATH/sample.swift --sdk macosx

typefill spm --moduleName TypeFillKit

typefill project --project PATH/TO/YOUR.xcodeproj --scheme YOUR_SCHEME

typefill workspace --workspace PATH/TO/YOUR.xcworkspace --scheme YOUR_SCHEME
```

## The Support Part & Todolist

- [x] typefill variables like `let a = 1` or `var a = "1"`.
- [x] typefill keyword like `let ``default`` = 1`.
- [x] typefill `guard let` and `if let`.
- [x] typefill some closure input.
    - `{ a, b in }`
    - `{ (a, b) in }`
- [x] typefill binding tuple `let (aa, bb) = (1, 2)`
- [ ] typefill `inout` 
- [ ] typefill closure output.
- [ ] ~~add `private final` attribute to `@IBAction/@IBOutlet/@objc` by using `--ibaction/--iboutlet/--objc`.(Rewriting)~~

``` swift
private lazy var chartHeight: [CGFloat] = {
    return self.status.sensorData?.compactMap { sensor -> CGFloat in
        guard let _chartType = sensor.chart?.type else { return 0 }
    }
}()
```

## Support

### let/var

``` swift
let a = 1
var b = a
let (c, d) = (1, 2)
struct Test {
    let a, b: Int
    let c = 1, d = 2
}
```

``` swift
let a: Int = 1
var b: Int = a
let (c, d): (Int, Int) = (1, 2)
struct Test {
    let a: Int, b: Int
    let c: Int = 1, d: Int = 2
}
```

### Option bind(`if let`/`guard let`)

``` swift
let a: Int? = nil
if let aa = a {}
guard let aa = a else {return}
```

``` swift
let a: Int? = nil
if let aa: Int = a {}
guard let aa: Int = a else {return}
```

### Closure

``` swift
let a: (Int, Int) -> String = { a, b -> String in
    return ""
}
let b: (Int, Int) -> String = { (a, b) -> String in
    return ""
}
```

``` swift
let a: (Int, Int) -> String = { (a: Int, b: Int) -> String in
    return ""
}
let b: (Int, Int) -> String = { (a: Int, b: Int) -> String in
    return ""
}
```


## Not Support

### Closure(`inout`)

``` swift
let a: (inout Int) -> Int = { i in
    return i
}
```

## Ref

 * [AST Explorer](https://swift-ast-explorer.com/)
 * [SourceKitten](https://github.com/jpsim/SourceKitten/tree/swift-5.1)
 * [SwiftSupport](https://github.com/apple/swift/blob/master/tools/SourceKit/docs/SwiftSupport.txt)
 * [Protocol](https://github.com/apple/swift/blob/master/tools/SourceKit/docs/Protocol.md)
 * [Accessors](https://github.com/apple/swift/blob/2c9def8e74ede41f09c431dab5422bb0f8cc6adb/tools/SourceKit/lib/SwiftLang/SwiftEditor.cpp#L1101-L1105)
 * [Attributes](https://github.com/apple/swift/blob/0a92b1cda36706b5e0bd30c172a24391aa524309/tools/SourceKit/lib/SwiftLang/SwiftLangSupport.cpp#L65-L81)

## License

MIT licensed.
