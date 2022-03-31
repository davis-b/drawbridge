const std = @import("std");

const libc = @import("../c.zig");
const Dot = @import("../misc.zig").Dot;

pub const letterWidth: u8 = 5;
pub const letterHeight: u8 = 7; //5
pub const Letter = [letterHeight][letterWidth]bool;
const rawLetter = [letterHeight * letterWidth]bool;

pub fn intToString(int: anytype, buffer: []u8) ![]u8 {
    var fbs = std.io.fixedBufferStream(buffer);
    try std.fmt.formatIntValue(int, "", .{}, fbs.writer());
    return fbs.getWritten();
}

pub fn write(surface: *libc.SDL_Surface, string: []const u8, start: Dot, fontSize: u8, color: u32, wrapLen: u32) void {
    var pos = start;
    const sepSize = fontSize; // the pixels between each letter.
    var letter: Letter = undefined;
    for (string) |char| {
        if (char == ' ') {
            letter = alphabet.space;
        } else if (char <= '9' and char >= '0') {
            letter = numberArray[char - '0'];
        } else if (char <= 'z' and char >= 'a') {
            letter = alphabetArray[char - 'a'];
        } else if (char == 0) {
            continue;
        } else if (char == '\n') {
            pos.y += (letterHeight * fontSize) + sepSize;
            pos.x = start.x;
            continue;
        } else letter = alphabet.questionMark;
        drawLetter(surface, letter, pos.x, pos.y, fontSize, color);
        pos.x += sepSize + (fontSize * letterWidth);
        if (pos.x >= wrapLen + @intCast(u32, start.x)) {
            pos.y += (letterHeight * fontSize) + sepSize;
            pos.x = start.x;
        }
    }
}

fn drawLetter(surface: *libc.SDL_Surface, letter: Letter, x: c_int, y: c_int, fontSize: u8, color: u32) void {
    for (letter) |column, columnPos| {
        for (column) |pixel, rowPos| {
            if (pixel) {
                const drawX: c_int = x + @intCast(c_int, rowPos * fontSize);
                const drawY: c_int = y + @intCast(c_int, columnPos * fontSize);
                const rect = libc.SDL_Rect{ .x = drawX, .y = drawY, .w = fontSize, .h = fontSize };
                _ = libc.SDL_FillRect(surface, &rect, color);
            }
        }
    }
}

fn convertToLetter(letter: *const [25]u8) Letter {
    var column: usize = 0;
    var row: usize = 0;
    var result: Letter = undefined;
    for (letter) |spot, index| {
        row = index % letterWidth;
        column = index / letterWidth;
        result[column][row] = spot == '1';
    }
    return result;
}

const alphabetArray = [26]Letter{
    alphabet.a,
    alphabet.b,
    alphabet.c,
    alphabet.d,
    alphabet.e,
    alphabet.f,
    alphabet.g,
    alphabet.h,
    alphabet.i,
    alphabet.j,
    alphabet.k,
    alphabet.l,
    alphabet.m,
    alphabet.n,
    alphabet.o,
    alphabet.p,
    alphabet.q,
    alphabet.r,
    alphabet.s,
    alphabet.t,
    alphabet.u,
    alphabet.v,
    alphabet.w,
    alphabet.x,
    alphabet.y,
    alphabet.z,
};

const numberArray = [10]Letter{
    alphabet.zero,
    alphabet.one,
    alphabet.two,
    alphabet.three,
    alphabet.four,
    alphabet.five,
    alphabet.six,
    alphabet.seven,
    alphabet.eight,
    alphabet.nine,
};

const alphabet = comptime struct {
    const len: usize = 25;
    const space: Letter = convertToLetter(Space);
    const a: Letter = convertToLetter(A);
    const b: Letter = convertToLetter(B);
    const c: Letter = convertToLetter(C);
    const d: Letter = convertToLetter(D);
    const e: Letter = convertToLetter(E);
    const f: Letter = convertToLetter(F);
    const g: Letter = convertToLetter(G);
    const h: Letter = convertToLetter(H);
    const i: Letter = convertToLetter(I);
    const j: Letter = convertToLetter(J);
    const k: Letter = convertToLetter(K);
    const l: Letter = convertToLetter(L);
    const m: Letter = convertToLetter(M);
    const n: Letter = convertToLetter(N);
    const o: Letter = convertToLetter(O);
    const p: Letter = convertToLetter(P);
    const q: Letter = convertToLetter(Q);
    const r: Letter = convertToLetter(R);
    const s: Letter = convertToLetter(S);
    const t: Letter = convertToLetter(T);
    const u: Letter = convertToLetter(U);
    const v: Letter = convertToLetter(V);
    const w: Letter = convertToLetter(W);
    const x: Letter = convertToLetter(X);
    const y: Letter = convertToLetter(Y);
    const z: Letter = convertToLetter(Z);

    const one: Letter = convertToLetter(One);
    const two: Letter = convertToLetter(Two);
    const three: Letter = convertToLetter(Three);
    const four: Letter = convertToLetter(Four);
    const five: Letter = convertToLetter(Five);
    const six: Letter = convertToLetter(Six);
    const seven: Letter = convertToLetter(Seven);
    const eight: Letter = convertToLetter(Eight);
    const nine: Letter = convertToLetter(Nine);
    const zero: Letter = convertToLetter(Zero);

    const questionMark: Letter = convertToLetter(QuestionMark);
    const Colon: Letter = convertToLetter(Colon);
};

const Space = "" ++
    "_____" ++
    "_____" ++
    "_____" ++
    "_____" ++
    "_____";

const A = "" ++
    "__1__" ++
    "_1_1_" ++
    "1___1" ++
    "11111" ++
    "1___1";

const B = "" ++
    "1111_" ++
    "1___1" ++
    "11111" ++
    "1___1" ++
    "1111_";

const C = "" ++
    "_1111" ++
    "_1___" ++
    "11___" ++
    "_1___" ++
    "_1111";

const D = "" ++
    "111__" ++
    "1__1_" ++
    "1___1" ++
    "1__1_" ++
    "111__";

const E = "" ++
    "11111" ++
    "1____" ++
    "111__" ++
    "1____" ++
    "11111";

const F = "" ++
    "11111" ++
    "1____" ++
    "111__" ++
    "1____" ++
    "1____";

const G = "" ++
    "_11__" ++
    "1____" ++
    "1_111" ++
    "1___1" ++
    "1111_";

const H = "" ++
    "1___1" ++
    "1___1" ++
    "11111" ++
    "1___1" ++
    "1___1";

const I = "" ++
    "11111" ++
    "__1__" ++
    "__1__" ++
    "__1__" ++
    "11111";

const J = "" ++
    "11111" ++
    "____1" ++
    "111_1" ++
    "_1__1" ++
    "_1111";

const K = "" ++
    "1__11" ++
    "1_1__" ++
    "11___" ++
    "1_1__" ++
    "1__11";

const L = "" ++
    "1____" ++
    "1____" ++
    "1____" ++
    "1____" ++
    "11111";

const M = "" ++
    "_1_1_" ++
    "1_1_1" ++
    "1_1_1" ++
    "1___1" ++
    "1___1";

const N = "" ++
    "1___1" ++
    "11__1" ++
    "1_1_1" ++
    "1__11" ++
    "1___1";

const O = "" ++
    "_111_" ++
    "1___1" ++
    "1___1" ++
    "1___1" ++
    "_111_";

const P = "" ++
    "1111_" ++
    "1___1" ++
    "1111_" ++
    "1____" ++
    "1____";

const Q = "" ++
    "_111_" ++
    "1___1" ++
    "_1_1_" ++
    "__1__" ++
    "__1__";

const R = "" ++
    "1111_" ++
    "1___1" ++
    "111__" ++
    "1__1_" ++
    "1___1";

const S = "" ++
    "_1111" ++
    "11___" ++
    "_11__" ++
    "__11_" ++
    "1111_";

const T = "" ++
    "11111" ++
    "__1__" ++
    "__1__" ++
    "__1__" ++
    "__1__";

const U = "" ++
    "1___1" ++
    "1___1" ++
    "1___1" ++
    "1___1" ++
    "_111_";

const V = "" ++
    "11_11" ++
    "1___1" ++
    "_1_1_" ++
    "_1_1_" ++
    "__1__";

const W = "" ++
    "1___1" ++
    "1___1" ++
    "1_1_1" ++
    "11_11" ++
    "1___1";

const X = "" ++
    "1___1" ++
    "_1_1_" ++
    "__1__" ++
    "_1_1_" ++
    "1___1";

const Y = "" ++
    "1___1" ++
    "_1_1_" ++
    "__1__" ++
    "__1__" ++
    "__1__";

const Z = "" ++
    "11111" ++
    "__11_" ++
    "_11__" ++
    "11___" ++
    "11111";

const One = "" ++
    "_11__" ++
    "1_1__" ++
    "__1__" ++
    "__1__" ++
    "11111";

const Two = "" ++
    "_111_" ++
    "1__11" ++
    "__11_" ++
    "_11__" ++
    "11111";

const Three = "" ++
    "11111" ++
    "...1." ++
    ".1111" ++
    "...1." ++
    "11111";

const Four = "" ++
    "1..1." ++
    "1..1." ++
    "11111" ++
    "...1." ++
    "...1.";

const Five = "" ++
    "11111" ++
    "1...." ++
    "1111." ++
    "....1" ++
    "1111.";

const Six = "" ++
    "..111" ++
    ".1..." ++
    "1111." ++
    "1...1" ++
    "1111.";

const Seven = "" ++
    "11111" ++
    "...1." ++
    "..1.." ++
    ".1..." ++
    "1....";

const Eight = "" ++
    ".111." ++
    "1...1" ++
    ".111." ++
    "1...1" ++
    ".111.";

const Nine = "" ++
    ".111." ++
    "1...1" ++
    ".111." ++
    "...1." ++
    "111..";

const Zero = "" ++
    ".111." ++
    "1...1" ++
    "1...1" ++
    "1...1" ++
    ".111.";

const QuestionMark = "" ++
    ".111." ++
    "1..1." ++
    "..1.." ++
    "....." ++
    "..1..";

const Colon = "" ++
    "..1.." ++
    "..1.." ++
    "..1.." ++
    "..1.." ++
    "..1..";
