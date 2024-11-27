const std = @import("std");

pub const NUMPRECS = 11;

pub const IDENT: u32   = 0b00;
pub const M_IDENT: u32 = 0b11;
pub const KWORD: u32   = 0b10;
pub const M_KWORD: u32 = 0b11;
pub const VALLIT: u32   = 0b01;
pub const M_VALLIT: u32 = 0b11;
pub const NUMBER: u32   = 0b0001;
pub const M_NUMBER: u32 = 0b1111;
pub const BOOL: u32   = 0b1001;
pub const M_BOOL: u32 = 0b1111;
pub const STR: u32   = 0b0101;
pub const M_STR: u32 = 0b1111;
pub const TYPE: u32   = 0b1101;
pub const M_TYPE: u32 = 0b1111;

pub const OPERAND: u32   = 0b011;
pub const M_OPERAND: u32 = 0b111;

pub const M_OPTYPE: u32   = 0b111 << 4;
pub const OT_UNARY: u32   = 0b000 << 4;
pub const OT_ARITH: u32   = 0b001 << 4;
pub const OT_ASSG: u32    = 0b010 << 4;
pub const OT_BITWISE: u32 = 0b011 << 4;
pub const OT_COMP: u32    = 0b100 << 4;
pub const OT_BOOL: u32    = 0b101 << 4;
pub const OT_FIELD: u32   = 0b110 << 4;
pub const OT_NWIDTH: u32  = 0b111 << 4;

pub const ISSIMPASSG: u32       = 1 << 0x03;
pub const ISDECL: u32           = 1 << 0x10;
pub const ISTYPEQUALF: u32      = 1 << 0x11;
pub const ISCALLMOD: u32        = 1 << 0x12;
pub const ISARGCONTFLOW: u32    = 1 << 0x13;
pub const ISSIMPLECONTFLOW: u32 = 1 << 0x14;
pub const ISDECLQUALF: u32      = 1 << 0x15;
pub const ISCOMPTYPE: u32       = 1 << 0x16;
pub const ISSUBSARG: u32        = 1 << 0x17;
pub const CANEXPRROOT: u32      = 1 << 0x18;
pub const ISAQUISTYPE: u32      = 1 << 0x19;

pub const IDOPPOS = 0x07;
pub const IDKWPOS = 0x02;
pub const OPPRECPOS = 0x0B;
pub const IDSTPOS = 0x05;

pub const IDTYPOS = 0x04;
pub const INVTYPEPOS = 0x1A;

pub const ID_IF         = 0b00000 << IDKWPOS;
pub const ID_WHILE      = 0b00001 << IDKWPOS;
pub const ID_DO         = 0b00010 << IDKWPOS;
pub const ID_VAR        = 0b00011 << IDKWPOS;
pub const ID_CONST      = 0b00100 << IDKWPOS;
pub const ID_MUT        = 0b00101 << IDKWPOS;
pub const ID_STATIC     = 0b00110 << IDKWPOS;
pub const ID_STRUCT     = 0b00111 << IDKWPOS;
pub const ID_ENUM       = 0b01000 << IDKWPOS;
pub const ID_UNION      = 0b01001 << IDKWPOS;
pub const ID_BREAK      = 0b01010 << IDKWPOS;
pub const ID_CONTINUE   = 0b01011 << IDKWPOS;
pub const ID_GOTO       = 0b01100 << IDKWPOS;
pub const ID_INLINE     = 0b01101 << IDKWPOS;
pub const ID_RETURN     = 0b01110 << IDKWPOS;
pub const ID_SWITCH     = 0b01111 << IDKWPOS;
pub const ID_ASSERT     = 0b10000 << IDKWPOS;
pub const ID_ASSUME     = 0b10001 << IDKWPOS;
pub const ID_FOR        = 0b10010 << IDKWPOS;
pub const ID_COPY       = 0b10011 << IDKWPOS;
pub const ID_FN         = 0b10100 << IDKWPOS;

pub const ID_FUNCCALL   = 0b00 << IDOPPOS; //OT_NWIDTH
pub const ID_ARRAYINDX  = 0b01 << IDOPPOS;
pub const ID_STRUCTINST = 0b10 << IDOPPOS;
pub const ID_TYPECAST   = 0b11 << IDOPPOS;
pub const ID_DOT   = 0b0 << IDOPPOS; //OT_FIELD
pub const ID_COLON = 0b1 << IDOPPOS;
pub const ID_POS   = 0b00 << IDOPPOS; //OT_UNARY
pub const ID_NEG   = 0b01 << IDOPPOS;
pub const ID_NOT   = 0b10 << IDOPPOS;
pub const ID_TILDE = 0b11 << IDOPPOS;
pub const ID_AND = 0b1100 << IDOPPOS; //OT_BITWISE xor OT_ASSG
pub const ID_XOR = 0b1101 << IDOPPOS;
pub const ID_OR  = 0b1110 << IDOPPOS;
pub const ID_MUL = 0b0000 << IDOPPOS; //OT_ARITH xor OT_ASSG
pub const ID_DIV = 0b0001 << IDOPPOS;
pub const ID_MOD = 0b0010 << IDOPPOS;
pub const ID_BSL = 0b0011 << IDOPPOS;
pub const ID_BRL = 0b0100 << IDOPPOS;
pub const ID_BSR = 0b0101 << IDOPPOS;
pub const ID_BRR = 0b0110 << IDOPPOS;
pub const ID_ADD = 0b0111 << IDOPPOS;
pub const ID_SUB = 0b1000 << IDOPPOS;
pub const ID_LT  = 0b000 << IDOPPOS; //OT_COMP
pub const ID_LE  = 0b001 << IDOPPOS;
pub const ID_EQ  = 0b010 << IDOPPOS;
pub const ID_GE  = 0b011 << IDOPPOS;
pub const ID_GT  = 0b100 << IDOPPOS;
pub const ID_NE  = 0b101 << IDOPPOS;
pub const ID_KW_AND = 0b0 << IDOPPOS; //OT_BOOL
pub const ID_KW_OR  = 0b1 << IDOPPOS;
pub const ID_VAL_ASSG = 0b0 << IDOPPOS;
pub const ID_DEF_ASSG = 0b1 << IDOPPOS;

pub const InvokeType = enum (u2) {
    binary = 0,
    unary_right = 1,
    multi_arg = 2,
};

pub const STRUCTURAL: u32   = 0b111;
pub const M_STRUCTURALS: u32 = 0b111;
pub const CAPLEFT: u32  = 1 << 0x03;
pub const CAPRIGHT: u32 = 1 << 0x04;

pub const ID_PAREN: u32     = 0b00 << IDSTPOS; //CAPLEFT xor CAPRIGHT
pub const ID_BRACKET: u32   = 0b01 << IDSTPOS; //CAPLEFT xor CAPRIGHT
pub const ID_CURLY: u32     = 0b10 << IDSTPOS; //CAPLEFT xor CAPRIGHT
pub const ID_EXPRBNDRY: u32 = 0b11 << IDSTPOS; //CAPLEFT xor CAPRIGHT
pub const ID_COMMA: u32       = 0b00 << IDSTPOS; //CAPLEFT and CAPRIGHT
pub const ID_SEMICOLON: u32   = 0b01 << IDSTPOS; //CAPLEFT and CAPRIGHT
pub const ID_QMARK: u32       = 0b10 << IDSTPOS; //CAPLEFT and CAPRIGHT

pub const ID_UINT: u32       = 0b0000 << IDTYPOS;
pub const ID_SINT: u32       = 0b0001 << IDTYPOS;
pub const ID_FPUINT: u32     = 0b0010 << IDTYPOS;
pub const ID_FPSINT: u32     = 0b0011 << IDTYPOS;
pub const ID_BINFLOAT: u32   = 0b0100 << IDTYPOS;
pub const ID_DECFLOAT: u32   = 0b0101 << IDTYPOS;
pub const ID_TYPESTRUCT: u32 = 0b0110 << IDTYPOS;
pub const ID_TYPEENUM: u32   = 0b0111 << IDTYPOS;
pub const ID_TYPEUNION: u32  = 0b1000 << IDTYPOS;
pub const ID_VOID: u32       = 0b1001 << IDTYPOS;

pub const TokenType = enum (u32) {
    _ident = IDENT,
    _number = NUMBER,
    _bool = BOOL,
    _string = STR,

    _if        = KWORD + ID_IF       + ISARGCONTFLOW,   
    _while     = KWORD + ID_WHILE    + ISARGCONTFLOW,   
    _do        = KWORD + ID_DO       + ISARGCONTFLOW,   
    _var       = KWORD + ID_VAR      + ISDECL,          
    _const     = KWORD + ID_CONST    + ISDECL            + ISTYPEQUALF + ISAQUISTYPE, 
    _mut       = KWORD + ID_MUT      + ISTYPEQUALF       + ISAQUISTYPE, 
    _static    = KWORD + ID_STATIC   + ISDECLQUALF,     
    _struct    = KWORD + ID_STRUCT   + ISCOMPTYPE,      
    _enum      = KWORD + ID_ENUM     + ISCOMPTYPE,      
    _union     = KWORD + ID_UNION    + ISCOMPTYPE,      
    _break     = KWORD + ID_BREAK    + ISSIMPLECONTFLOW,
    _continue  = KWORD + ID_CONTINUE + ISSIMPLECONTFLOW,
    _goto      = KWORD + ID_GOTO     + ISSIMPLECONTFLOW,
    _inline    = KWORD + ID_INLINE   + ISDECLQUALF       + ISCALLMOD,  
    _return    = KWORD + ID_RETURN   + ISSUBSARG,       
    _switch    = KWORD + ID_SWITCH   + ISARGCONTFLOW,   
    _assert    = KWORD + ID_ASSERT   + ISSUBSARG,       
    _assume    = KWORD + ID_ASSUME   + ISSUBSARG,       
    _for       = KWORD + ID_FOR      + ISARGCONTFLOW,  
    _copy      = KWORD + ID_COPY     + ISAQUISTYPE, 
    _fn        = KWORD + ID_FN,

    _funccall  = OPERAND + OT_NWIDTH  + ID_FUNCCALL   + Precidence(0) + InvType(.multi_arg)       + CANEXPRROOT,      
    _structinst= OPERAND + OT_NWIDTH  + ID_STRUCTINST + Precidence(0) + InvType(.multi_arg),
    _arrayindx = OPERAND + OT_NWIDTH  + ID_ARRAYINDX  + Precidence(0) + InvType(.binary),       
    _dot       = OPERAND + OT_FIELD   + ID_DOT        + Precidence(0) + InvType(.binary),       
    _colon     = OPERAND + OT_FIELD   + ID_COLON      + Precidence(0) + InvType(.binary), //      
    _pos       = OPERAND + OT_UNARY   + ID_POS        + Precidence(1) + InvType(.unary_right),       
    _neg       = OPERAND + OT_UNARY   + ID_NEG        + Precidence(1) + InvType(.unary_right),       
    _not       = OPERAND + OT_UNARY   + ID_NOT        + Precidence(1) + InvType(.unary_right),       
    _tilde     = OPERAND + OT_UNARY   + ID_TILDE      + Precidence(1) + InvType(.unary_right),       
    _typecast  = OPERAND + OT_NWIDTH  + ID_TYPECAST   + Precidence(1) + InvType(.binary), //    
    _mul       = OPERAND + OT_ARITH   + ID_MUL        + Precidence(2) + InvType(.binary),       
    _div       = OPERAND + OT_ARITH   + ID_DIV        + Precidence(2) + InvType(.binary),       
    _mod       = OPERAND + OT_ARITH   + ID_MOD        + Precidence(2) + InvType(.binary),       
    _bsl       = OPERAND + OT_ARITH   + ID_BSL        + Precidence(2) + InvType(.binary),       
    _brl       = OPERAND + OT_ARITH   + ID_BRL        + Precidence(2) + InvType(.binary),       
    _bsr       = OPERAND + OT_ARITH   + ID_BSR        + Precidence(2) + InvType(.binary),       
    _brr       = OPERAND + OT_ARITH   + ID_BRR        + Precidence(2) + InvType(.multi_arg), //      
    _add       = OPERAND + OT_ARITH   + ID_ADD        + Precidence(3) + InvType(.binary),       
    _sub       = OPERAND + OT_ARITH   + ID_SUB        + Precidence(3) + InvType(.binary), //    
    _and       = OPERAND + OT_BITWISE + ID_AND        + Precidence(4) + InvType(.binary), //  
    _xor       = OPERAND + OT_BITWISE + ID_XOR        + Precidence(5) + InvType(.binary), //      
    _or        = OPERAND + OT_BITWISE + ID_OR         + Precidence(6) + InvType(.binary), //      
    _lt        = OPERAND + OT_COMP    + ID_LT         + Precidence(7) + InvType(.binary),       
    _le        = OPERAND + OT_COMP    + ID_LE         + Precidence(7) + InvType(.binary),       
    _eq        = OPERAND + OT_COMP    + ID_EQ         + Precidence(7) + InvType(.binary),       
    _ge        = OPERAND + OT_COMP    + ID_GE         + Precidence(7) + InvType(.binary),       
    _gt        = OPERAND + OT_COMP    + ID_GT         + Precidence(7) + InvType(.binary),       
    _ne        = OPERAND + OT_COMP    + ID_NE         + Precidence(7) + InvType(.binary), //      
    _kw_and    = OPERAND + OT_BOOL    + ID_KW_AND     + Precidence(8) + InvType(.binary), //      
    _kw_or     = OPERAND + OT_BOOL    + ID_KW_AND     + Precidence(9) + InvType(.binary), //      
    _assg      = OPERAND + ISSIMPASSG + ID_VAL_ASSG   + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _def_assg  = OPERAND + ISSIMPASSG + ID_DEF_ASSG   + Precidence(10) + InvType(.binary),     
    _add_assg  = OPERAND + OT_ASSG    + ID_ADD        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _sub_assg  = OPERAND + OT_ASSG    + ID_SUB        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _mul_assg  = OPERAND + OT_ASSG    + ID_MUL        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _div_assg  = OPERAND + OT_ASSG    + ID_DIV        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _mod_assg  = OPERAND + OT_ASSG    + ID_MOD        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _bsl_assg  = OPERAND + OT_ASSG    + ID_BSL        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _brl_assg  = OPERAND + OT_ASSG    + ID_BRL        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _bsr_assg  = OPERAND + OT_ASSG    + ID_BSR        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _brr_assg  = OPERAND + OT_ASSG    + ID_BRR        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _and_assg  = OPERAND + OT_ASSG    + ID_AND        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _xor_assg  = OPERAND + OT_ASSG    + ID_XOR        + Precidence(10) + InvType(.binary)        + CANEXPRROOT,      
    _or_assg   = OPERAND + OT_ASSG    + ID_OR         + Precidence(10) + InvType(.binary)        + CANEXPRROOT,       

    _left_paren     = STRUCTURAL + CAPRIGHT + ID_PAREN,    
    _right_paren    = STRUCTURAL + CAPLEFT  + ID_PAREN,    
    _left_bracket   = STRUCTURAL + CAPRIGHT + ID_BRACKET,  
    _right_bracket  = STRUCTURAL + CAPLEFT  + ID_BRACKET,  
    _left_curly     = STRUCTURAL + CAPRIGHT + ID_CURLY,    
    _right_curly    = STRUCTURAL + CAPLEFT  + ID_CURLY,    
    _start_expr     = STRUCTURAL + CAPRIGHT + ID_EXPRBNDRY,
    _end_expr       = STRUCTURAL + CAPLEFT  + ID_EXPRBNDRY,
    _comma          = STRUCTURAL + CAPLEFT  + CAPRIGHT      + ID_COMMA,    
    _semicolon      = STRUCTURAL + CAPLEFT  + CAPRIGHT      + ID_SEMICOLON,
    _q_mark         = STRUCTURAL + CAPLEFT  + CAPRIGHT      + ID_QMARK,

    _uint        = TYPE + ID_UINT,      
    _sint        = TYPE + ID_SINT,      
    _fpuint      = TYPE + ID_FPUINT,    
    _fpsint      = TYPE + ID_FPSINT,    
    _binfloat    = TYPE + ID_BINFLOAT,  
    _decfloat    = TYPE + ID_DECFLOAT,  
    _type_struct = TYPE + ID_TYPESTRUCT,
    _type_enum   = TYPE + ID_TYPEENUM,  
    _type_union  = TYPE + ID_TYPEUNION, 
    _void        = TYPE + ID_VOID,  
    
    pub inline fn Int(self: @This()) u32 {
        return @intFromEnum(self);
    }

    pub inline fn IsOperand(self: @This()) bool {
        return self.Int() & M_OPERAND == OPERAND;
    }
    pub inline fn IsIdent(self: @This()) bool {
        return self.Int() & M_IDENT == IDENT;
    }
    pub inline fn IsStructural(self: @This()) bool {
        return self.Int() & M_STRUCTURALS == STRUCTURAL;
    }
    pub inline fn IsKWord(self: @This()) bool {
        return self.Int() & M_KWORD == KWORD;
    }
    pub inline fn IsType(self: @This()) bool {
        return self.Int() & M_TYPE == TYPE;
    }
    pub inline fn CanCapRight(self: @This()) bool {
        return self.Int() & CAPRIGHT != 0;
    }
    pub inline fn CanCapLeft(self: @This()) bool {
        return self.Int() & CAPLEFT != 0;
    }
    pub inline fn GetOpType(self: @This()) u32 {
        return self.Int() & M_OPTYPE;
    }
    pub inline fn IsSubsArg(self: @This()) bool {
        return self.Int() & ISSUBSARG != 0;
    }
    pub inline fn GetPrec(self: @This()) u32 {
        const bits: u32 = @intCast(32 - @clz(@as(u32, NUMPRECS)));
        return (self.Int() >> OPPRECPOS) & ((1 << bits) - 1);
    }

    pub inline fn Converse(self: @This()) u32 {
        return self.Int() ^ CAPRIGHT ^ CAPLEFT;
    }

    pub inline fn GetInvokeType(self: @This()) InvokeType {
        const val: u32 = self.Int() >> INVTYPEPOS;
        const mask = ~@intFromEnum(InvokeType.binary);
        return @enumFromInt(val & mask);
    }
};

fn Precidence(val: comptime_int) u32 {
    if (val < 0) @compileError("Cannot have a negative precidence");
    if (val >= NUMPRECS) @compileError( std.fmt.comptimePrint("Precidence greater than maximum declared precidence ({})", .{NUMPRECS}));
    return val << OPPRECPOS;
}

fn InvType(val: InvokeType) u32 {
    return @as(u32, @intFromEnum(val)) << INVTYPEPOS;
}

test "Precidence" {
    try std.testing.expectEqual(3, TokenType._add.GetPrec());
}

test "Invoke Type" {
    try std.testing.expectEqual(InvokeType.multi_arg, TokenType._funccall.GetInvokeType());
}

test "Subs Arg" {
    try std.testing.expectEqual(true, TokenType._return.IsSubsArg());
}

const OpSymPair = struct {
    sym: [] const u8,
    tkn: TokenType,
};

pub const OpSyms = [_] OpSymPair {
    OpSymPair{.sym = ":", .tkn = ._colon},
    OpSymPair{.sym = ".", .tkn = ._dot},
    OpSymPair{.sym = "+", .tkn = ._pos},
    OpSymPair{.sym = "-", .tkn = ._neg},
    OpSymPair{.sym = "!", .tkn = ._not},
    OpSymPair{.sym = "~", .tkn = ._tilde},
    OpSymPair{.sym = "*", .tkn = ._mul},
    OpSymPair{.sym = "/", .tkn = ._div},
    OpSymPair{.sym = "%", .tkn = ._mod},
    OpSymPair{.sym = "<<", .tkn = ._bsl},
    OpSymPair{.sym = ">>", .tkn = ._bsr},
    OpSymPair{.sym = "<<<", .tkn = ._brl},
    OpSymPair{.sym = ">>>", .tkn = ._brr},
    OpSymPair{.sym = "+", .tkn = ._add},
    OpSymPair{.sym = "-", .tkn = ._sub},
    OpSymPair{.sym = "&", .tkn = ._and},
    OpSymPair{.sym = "^", .tkn = ._xor},
    OpSymPair{.sym = "|", .tkn = ._or},
    OpSymPair{.sym = "<", .tkn = ._lt},
    OpSymPair{.sym = "<=", .tkn = ._le},
    OpSymPair{.sym = ">", .tkn = ._gt},
    OpSymPair{.sym = ">=", .tkn = ._ge},
    OpSymPair{.sym = "==", .tkn = ._eq},
    OpSymPair{.sym = "!=", .tkn = ._ne},
    OpSymPair{.sym = "and", .tkn = ._kw_and},
    OpSymPair{.sym = "or", .tkn = ._kw_or},
    OpSymPair{.sym = "=", .tkn = ._assg},
    OpSymPair{.sym = ":=", .tkn = ._def_assg},
    OpSymPair{.sym = "+=", .tkn = ._add_assg},
    OpSymPair{.sym = "-=", .tkn = ._sub_assg},
    OpSymPair{.sym = "*=", .tkn = ._mul_assg},
    OpSymPair{.sym = "/=", .tkn = ._div_assg},
    OpSymPair{.sym = "%=", .tkn = ._mod_assg},
    OpSymPair{.sym = "<<=", .tkn = ._bsl_assg},
    OpSymPair{.sym = ">>=", .tkn = ._bsr_assg},
    OpSymPair{.sym = "<<<=", .tkn = ._brl_assg},
    OpSymPair{.sym = ">>>=", .tkn = ._brr_assg},
    OpSymPair{.sym = "&=", .tkn = ._and_assg},
    OpSymPair{.sym = "^=", .tkn = ._xor_assg},
    OpSymPair{.sym = "|=", .tkn = ._or_assg},
};

pub const StructSyms = [_] OpSymPair {
    OpSymPair{.sym = "(", .tkn = ._left_paren},
    OpSymPair{.sym = ")", .tkn = ._right_paren},
    OpSymPair{.sym = "[", .tkn = ._left_bracket},
    OpSymPair{.sym = "]", .tkn = ._right_bracket},
    OpSymPair{.sym = "{", .tkn = ._left_curly},
    OpSymPair{.sym = "}", .tkn = ._right_curly},
    OpSymPair{.sym = ",", .tkn = ._comma},
    OpSymPair{.sym = ";", .tkn = ._semicolon},
    OpSymPair{.sym = "?", .tkn = ._q_mark},
};