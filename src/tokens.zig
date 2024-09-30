const std = @import("std");

pub const NUMPRECS = 0x11;

pub const IDENT: u64   = 0b00;
pub const M_IDENT: u64 = 0b11;
pub const KWORD: u64   = 0b10;
pub const M_KWORD: u64 = 0b11;
pub const VALLIT: u64   = 0b01;
pub const M_VALLIT: u64 = 0b11;
pub const NUMBER: u64   = 0b0001;
pub const M_NUMBER: u64 = 0b1111;
pub const BOOL: u64   = 0b1001;
pub const M_BOOL: u64 = 0b1111;
pub const STR: u64   = 0b101;
pub const M_STR: u64 = 0b111;

pub const OPERAND: u64   = 0b011;
pub const M_OPERAND: u64 = 0b111;

pub const M_OPTYPE: u64   = 0b111 << 4;
pub const OT_UNARY: u64   = 0b000 << 4;
pub const OT_ARITH: u64   = 0b001 << 4;
pub const OT_ASSG: u64    = 0b010 << 4;
pub const OT_BITWISE: u64 = 0b011 << 4;
pub const OT_COMP: u64    = 0b100 << 4;
pub const OT_BOOL: u64    = 0b101 << 4;
pub const OT_FIELD: u64   = 0b110 << 4;
pub const OT_NWIDTH: u64  = 0b111 << 4;

pub const ISSIMPASSG: u64       = 1 << 0x03;
pub const ISDECL: u64           = 1 << 0x10;
pub const ISTYPEQUALF: u64      = 1 << 0x11;
pub const ISCALLMOD: u64        = 1 << 0x12;
pub const ISARGCONTFLOW: u64    = 1 << 0x13;
pub const ISSIMPLECONTFLOW: u64 = 1 << 0x14;
pub const ISDECLQUALF: u64      = 1 << 0x15;
pub const ISCOMPTYPE: u64       = 1 << 0x16;
pub const ISSUBSARG: u64        = 1 << 0x17;
pub const CANEXPRROOT: u64      = 1 << 0x18;

pub const IDOPPOS = 0x07;
pub const IDKWPOS = 0x02;
pub const OPPRECPOS = 0x0B;

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
pub const ID_ASSUME     = 0b10011 << IDKWPOS;
pub const ID_FOR        = 0b10010 << IDKWPOS;

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

pub const STRUCTURAL: u64   = 0b111;
pub const M_STRUCTURALS: u64 = 0b111;
pub const CAPLEFT: u64  = 1 << 0x03;
pub const CAPRIGHT: u64 = 1 << 0x04;

pub const ID_PAREN: u64     = 0b00; //CAPLEFT xor CAPRIGHT
pub const ID_BRACKET: u64   = 0b01; //CAPLEFT xor CAPRIGHT
pub const ID_CURLY: u64     = 0b10; //CAPLEFT xor CAPRIGHT
pub const ID_EXPRBNDRY: u64 = 0b11; //CAPLEFT xor CAPRIGHT
pub const ID_COMMA: u64       = 0b0; //CAPLEFT and CAPRIGHT
pub const ID_SEMICOLON: u64   = 0b1; //CAPLEFT and CAPRIGHT



pub const TokenType = enum (u64) {
    _ident = IDENT,
    _number = NUMBER,
    _bool = BOOL,
    _string = STR,

    _if        = KWORD + ID_IF       + ISARGCONTFLOW,   
    _while     = KWORD + ID_WHILE    + ISARGCONTFLOW,   
    _do        = KWORD + ID_DO       + ISARGCONTFLOW,   
    _var       = KWORD + ID_VAR      + ISDECL,          
    _const     = KWORD + ID_CONST    + ISDECL            + ISTYPEQUALF,
    _mut       = KWORD + ID_MUT      + ISTYPEQUALF,     
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

    _funccall  = OPERAND + OT_NWIDTH  + ID_FUNCCALL   + Precidence(0)         + CANEXPRROOT,      
    _arrayindx = OPERAND + OT_NWIDTH  + ID_ARRAYINDX  + Precidence(0),       
    _dot       = OPERAND + OT_FIELD   + ID_DOT        + Precidence(0),       
    _colon     = OPERAND + OT_FIELD   + ID_COLON      + Precidence(0),       
    _pos       = OPERAND + OT_UNARY   + ID_POS        + Precidence(1),       
    _neg       = OPERAND + OT_UNARY   + ID_NEG        + Precidence(1),       
    _not       = OPERAND + OT_UNARY   + ID_NOT        + Precidence(1),       
    _tilde     = OPERAND + OT_UNARY   + ID_TILDE      + Precidence(1),       
    _typecast  = OPERAND + OT_NWIDTH  + ID_TYPECAST   + Precidence(1),       
    _mul       = OPERAND + OT_ARITH   + ID_MUL        + Precidence(2),       
    _div       = OPERAND + OT_ARITH   + ID_DIV        + Precidence(2),       
    _mod       = OPERAND + OT_ARITH   + ID_MOD        + Precidence(2),       
    _bsl       = OPERAND + OT_ARITH   + ID_BSL        + Precidence(2),       
    _brl       = OPERAND + OT_ARITH   + ID_BRL        + Precidence(2),       
    _bsr       = OPERAND + OT_ARITH   + ID_BSR        + Precidence(2),       
    _brr       = OPERAND + OT_ARITH   + ID_BRR        + Precidence(2),       
    _add       = OPERAND + OT_ARITH   + ID_ADD        + Precidence(3),       
    _sub       = OPERAND + OT_ARITH   + ID_SUB        + Precidence(3),       
    _and       = OPERAND + OT_BITWISE + ID_AND        + Precidence(4),       
    _xor       = OPERAND + OT_BITWISE + ID_XOR        + Precidence(5),       
    _or        = OPERAND + OT_BITWISE + ID_OR         + Precidence(6),       
    _lt        = OPERAND + OT_COMP    + ID_LT         + Precidence(7),       
    _le        = OPERAND + OT_COMP    + ID_LE         + Precidence(7),       
    _eq        = OPERAND + OT_COMP    + ID_EQ         + Precidence(7),       
    _ge        = OPERAND + OT_COMP    + ID_GE         + Precidence(7),       
    _gt        = OPERAND + OT_COMP    + ID_GT         + Precidence(7),       
    _ne        = OPERAND + OT_COMP    + ID_NE         + Precidence(7),       
    _kw_and    = OPERAND + OT_BOOL    + ID_KW_AND     + Precidence(8),       
    _kw_or     = OPERAND + OT_BOOL    + ID_KW_AND     + Precidence(9),       
    _assg      = OPERAND + ISSIMPASSG + ID_VAL_ASSG   + Precidence(10)        + CANEXPRROOT,      
    _def_assg  = OPERAND + ISSIMPASSG + ID_DEF_ASSG   + Precidence(10),     
    _add_assg  = OPERAND + OT_ASSG    + ID_ADD        + Precidence(10)        + CANEXPRROOT,      
    _sub_assg  = OPERAND + OT_ASSG    + ID_SUB        + Precidence(10)        + CANEXPRROOT,      
    _mul_assg  = OPERAND + OT_ASSG    + ID_MUL        + Precidence(10)        + CANEXPRROOT,      
    _div_assg  = OPERAND + OT_ASSG    + ID_DIV        + Precidence(10)        + CANEXPRROOT,      
    _mod_assg  = OPERAND + OT_ASSG    + ID_MOD        + Precidence(10)        + CANEXPRROOT,      
    _bsl_assg  = OPERAND + OT_ASSG    + ID_BSL        + Precidence(10)        + CANEXPRROOT,      
    _brl_assg  = OPERAND + OT_ASSG    + ID_BRL        + Precidence(10)        + CANEXPRROOT,      
    _bsr_assg  = OPERAND + OT_ASSG    + ID_BSR        + Precidence(10)        + CANEXPRROOT,      
    _brr_assg  = OPERAND + OT_ASSG    + ID_BRR        + Precidence(10)        + CANEXPRROOT,      
    _and_assg  = OPERAND + OT_ASSG    + ID_AND        + Precidence(10)        + CANEXPRROOT,      
    _xor_assg  = OPERAND + OT_ASSG    + ID_XOR        + Precidence(10)        + CANEXPRROOT,      
    _or_assg   = OPERAND + OT_ASSG    + ID_OR         + Precidence(10)        + CANEXPRROOT,       

    _left_paren     = STRUCTURAL + CAPRIGHT + ID_PAREN,    
    _right_paren    = STRUCTURAL + CAPLEFT  + ID_PAREN,    
    _left_bracket   = STRUCTURAL + CAPRIGHT + ID_BRACKET,  
    _right_bracket  = STRUCTURAL + CAPLEFT  + ID_BRACKET,  
    _left_curly     = STRUCTURAL + CAPRIGHT + ID_CURLY,    
    _right_curly    = STRUCTURAL + CAPLEFT  + ID_CURLY,    
    _start_expr     = STRUCTURAL + CAPRIGHT + ID_EXPRBNDRY,
    _end_expr       = STRUCTURAL + CAPLEFT  + ID_EXPRBNDRY,
    _comma          = STRUCTURAL + CAPLEFT  + CAPRIGHT  + ID_COMMA,    
    _semicolon      = STRUCTURAL + CAPLEFT  + CAPRIGHT  + ID_SEMICOLON,
    
};

fn Precidence(val: comptime_int) u64 {
    if (val < 0) @compileError("Cannot have a negative precidence");
    if (val >= NUMPRECS) @compileError( std.fmt.comptimePrint("Precidence greater than maximum declared precidence ({})", .{NUMPRECS}));
    return val << OPPRECPOS;
}