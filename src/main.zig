const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const mem = std.mem;

test "identity assertions" {
    expect(@intCast(i32, 42)).toBe(42);
    expect(@floatCast(f32, 123.45)).toBe(123.45);

    expect(true).toBe(true);
    expect(false).toBe(false);
}

test "comparison assertions" {
    expect(@intCast(i32, -1)).toBeLessOrEqualThen(0);
    expect(@intCast(i32, -24)).toBeLessThen(0);

    expect(@floatCast(f32, 123.45)).toBeGreaterOrEqualThen(0);
    expect(@floatCast(f32, 666.666)).toBeGreaterThen(600);

    expect(@intCast(i32, -1)).toBeAround(0, 2);
    expect(@floatCast(f32, 3.33)).toNotBeAround(3, 0.1);
}

test "slice assertions" {
    expect("zig").toBe("zig");
    expect("zag").toNotBe("zig");

    expect(&[_]i32{-1, 0, 1, 4}).toBe(&[_]i32{-1, 0, 1, 4});

    expect("foobar").toHaveLength(6);
}

test "comptime identity assertions" {
    expect(u8).toBe(u8);
    expect(comptime_int).toNotBe(comptime_float);
}

test "comptime comparison assertions" {
    expect(1).toBe(1);
    expect(2).toNotBe(1);

    expect(3).toBeGreaterThen(0);
    expect(42).toBeGreaterOrEqualThen(40);

    expect(-3.33).toBeLessThen(0);
    expect(600.0).toBeLessOrEqualThen(666.6);
}

fn AssertionsForType(comptime T: type) type {
    comptime const info = @typeInfo(T);

    return switch (info) {
        .Undefined,
        .Null,
        .Void
            => void,

        .Bool,
        .EnumLiteral,
        .Enum,
        .ErrorSet,
        .Vector
            => IdentityAssertions(T),

        .Int,
        .Float,
            => ComparisonAssertions(T),

        .Type
            => ComptimeIdentityAssertions(T),

        .ComptimeInt,
        .ComptimeFloat,
            => ComptimeComparisonAssertions(T),

        .Pointer
            => if (info.Pointer.size == .Slice) SliceAssertions(info.Pointer.child) else AssertionsForType(info.Pointer.child),

        .Array
            => SliceAssertions(info.Array.child),

        else
            => @compileError("value of type " ++ @typeName(T) ++ " encountered"),
    };
}

/// Given an actual value, returns an assertion object that can handle
/// assertions for the provided type.
pub fn expect(actual: var) AssertionsForType(@TypeOf(actual)) {
    comptime const T = @TypeOf(actual);
    comptime const info = @typeInfo(T);

    switch (info) {
        .Undefined,
        .Null,
        .Void,
            => return,

        .Bool,
        .EnumLiteral,
        .Enum,
        .ErrorSet,
        .Vector
            => return IdentityAssertions(T).init(actual),

        .Int,
        .Float
            => return ComparisonAssertions(T).init(actual),

        .Type
            => return ComptimeIdentityAssertions(T).init(actual),

        .ComptimeInt,
        .ComptimeFloat,
            => return ComptimeComparisonAssertions(T).init(actual),

        .Array
            => return SliceAssertions(info.Array.child).init(actual[0..]),

        .Pointer
            => if (info.Pointer.size == .Slice) {
                return SliceAssertions(info.Pointer.child).init(actual);
            } else {
                return expect(actual.*);
            },

        else
            => @compileError("value of type " ++ @typeName(T) ++ " encountered"),
    }
}

/// An assertion object to handle identity assertions.
pub fn IdentityAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,

        pub fn init(actual: T) Self {
            return .{
                .actual = actual,
            };
        }

        pub fn toBe(self: Self, expected: T) void {
            if (expected != self.actual) {
                std.debug.panic("expected {} to equal {}", .{ self.actual, expected });
            }
        }

        pub fn toNotBe(self: Self, not_expected: T) void {
            if (not_expected == self.actual) {
                std.debug.panic("expected {} to not equal {}", .{ self.actual, not_expected });
            }
        }

        inline fn getActual(self: Self) T {
            return self.actual;
        }
    };
}

/// An assertion object to handle comparisons.
pub fn ComparisonAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        identity: IdentityAssertions(T),

        pub fn init(actual: T) Self {
            return .{
                .identity = IdentityAssertions(T).init(actual),
            };
        }

        pub inline fn toBe(self: Self, expected: T) void {
            self.identity.toBe(expected);
        }

        pub inline fn toNotBe(self: Self, not_expected: T) void {
            self.identity.toNotBe(not_expected);
        }

        pub fn toBeGreaterOrEqualThen(self: Self, expected: T) void {
            if (!(self.getActual() >= expected)) {
                std.debug.panic("expected {} to be greater or equal then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeGreaterThen(self: Self, expected: T) void {
            if (!(self.getActual() > expected)) {
                std.debug.panic("expected {} to be greater then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeLessOrEqualThen(self: Self, expected: T) void {
            if (!(self.getActual() <= expected)) {
                std.debug.panic("expected {} to be less or equal then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeLessThen(self: Self, expected: T) void {
            if (!(self.getActual() < expected)) {
                std.debug.panic("expected {} to be less then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeAround(self: Self, expected: T, delta: T) void {
            if (self.getActual() < expected - delta or self.getActual() > expected + delta) {
                std.debug.panic("expected {} to be between {} and {}", .{ self.getActual(), expected - delta, expected + delta });
            }
        }

        pub fn toNotBeAround(self: Self, not_expected: T, delta: T) void {
            if (self.getActual() >= not_expected - delta and self.getActual() <= not_expected + delta) {
                std.debug.panic("expected {} to not be between {} and {}", .{ self.getActual(), not_expected - delta, not_expected + delta });
            }
        }

        inline fn getActual(self: Self) T {
            return self.identity.getActual();
        }
    };
}

/// An assertion object to handle slices.
pub fn SliceAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: []const T,

        pub fn init(actual: []const T) Self {
            return .{
                .actual = actual,
            };
        }

        pub fn toBe(self: Self, expected: []const T) void {
            if (!mem.eql(T, expected, self.actual)) {
                std.debug.panic("expected {} to be {}", .{ self.getActual(), expected });
            }
        }

        pub fn toNotBe(self: Self, not_expected: []const T) void {
            if (mem.eql(T, not_expected, self.actual)) {
                std.debug.panic("expected {} to not be {}", .{ self.getActual(), not_expected });
            }
        }

        pub fn toHaveLength(self: Self, length: usize) void {
            if (self.getActual().len != length) {
                std.debug.panic("expected \"{}\" to have length {}", .{ self.getActual(), length });
            }
        }

        inline fn getActual(self: Self) []const T {
            return self.actual;
        }
    };
}

/// A comptime assertion object to handle identity assertions.
pub fn ComptimeIdentityAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,

        pub fn init(comptime actual: T) Self {
            return .{
                .actual = actual,
            };
        }

        pub fn toBe(comptime self: Self, comptime expected: T) void {
            if (expected != self.actual) {
                std.debug.panic("expected {} to equal {}", .{ self.actual, expected });
            }
        }

        pub fn toNotBe(comptime self: Self, comptime not_expected: T) void {
            if (not_expected == self.actual) {
                std.debug.panic("expected {} to not equal {}", .{ self.actual, not_expected });
            }
        }

        inline fn getActual(comptime self: Self) T {
            return self.actual;
        }
    };
}

/// A comptime assertion object to handle comparison assertions.
pub fn ComptimeComparisonAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        identity: ComptimeIdentityAssertions(T),

        pub fn init(comptime actual: T) Self {
            return .{
                .identity = ComptimeIdentityAssertions(T).init(actual),
            };
        }

        pub inline fn toBe(comptime self: Self, comptime expected: T) void {
            self.identity.toBe(expected);
        }

        pub inline fn toNotBe(comptime self: Self, comptime not_expected: T) void {
            self.identity.toNotBe(not_expected);
        }

        pub fn toBeGreaterOrEqualThen(comptime self: Self, comptime expected: T) void {
            if (!(self.getActual() >= expected)) {
                std.debug.panic("expected {} to be greater or equal then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeGreaterThen(comptime self: Self, comptime expected: T) void {
            if (!(self.getActual() > expected)) {
                std.debug.panic("expected {} to be greater then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeLessOrEqualThen(comptime self: Self, comptime expected: T) void {
            if (!(self.getActual() <= expected)) {
                std.debug.panic("expected {} to be less or equal then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeLessThen(comptime self: Self, comptime expected: T) void {
            if (!(self.getActual() < expected)) {
                std.debug.panic("expected {} to be less then {}", .{ self.getActual(), expected });
            }
        }

        pub fn toBeAround(comptime self: Self, comptime expected: T, delta: T) void {
            if (self.getActual() < expected - delta or self.getActual() > expected + delta) {
                std.debug.panic("expected {} to be between {} and {}", .{ self.getActual(), expected - delta, expected + delta });
            }
        }

        pub fn toNotBeAround(comptime self: Self, comptime not_expected: T, comptime delta: T) void {
            if (self.getActual() >= expected - delta and self.getActual() <= expected + delta) {
                std.debug.panic("expected {} to not be between {} and {}", .{ self.getActual(), expected - delta, expected + delta });
            }
        }

        inline fn getActual(comptime self: Self) T {
            return self.identity.getActual();
        }
    };
}
