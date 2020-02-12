# Expect

An experimental assertions library for Zig.

## Usage

```zig
const expect = @import("zig-expect").expect;

// ...

expect(1).toBe(1);

expect("zig").toBe("zig");
expect("zig").toNotBe("zag");
```

## Goals

  - Provide a fluent API to model testing assertions
  - Be easier to use then `std.testing`
  - Eventually be incorporated in `std.testing`.
