-- OptimisticSide
-- 5/2/2022
-- Lexical scanner

-- luacheck: push globals script
local Token = require(_VERSION == "Luau" and script.Parent.Token or "./Token.lua")
-- luacheck: pop


local Lexer = {}
Lexer.__index = Lexer

Lexer.Reserved = {
	["and"] = Token.Kind.ReservedAnd,
	["break"] = Token.Kind.ReservedBreak,
	["do"] = Token.Kind.ReservedDo,
	["else"] = Token.Kind.ReservedElse,
	["elseif"] = Token.Kind.ReservedElseIf,
	["end"] = Token.Kind.ReservedEnd,
	["false"] = Token.Kind.ReservedFalse,
	["for"] = Token.Kind.ReservedFor,
	["function"] = Token.Kind.ReservedFunction,
	["if"] = Token.Kind.ReservedIf,
	["in"] = Token.Kind.ReservedIn,
	["local"] = Token.Kind.ReservedLocal,
	["nil"] = Token.Kind.ReservedNil,
	["not"] = Token.Kind.ReservedNot,
	["or"] = Token.Kind.ReservedOr,
	["repeat"] = Token.Kind.ReservedRepeat,
	["return"] = Token.Kind.ReservedReturn,
	["then"] = Token.Kind.ReservedThen,
	["true"] = Token.Kind.ReservedTrue,
	["until"] = Token.Kind.ReservedUntil,
	["while"] = Token.Kind.ReservedWhile,
}

Lexer.UnsortedOperators = {
	["+"] = Token.Kind.Plus,
	["-"] = Token.Kind.Minus,
	["*"] = Token.Kind.Star,
	["/"] = Token.Kind.Slash,
	["%"] = Token.Kind.Modulo,
	["#"] = Token.Kind.Hashtag,
	["?"] = Token.Kind.QuestionMark,

	["^"] = Token.Kind.Caret,
	[";"] = Token.Kind.SemiColon,
	[":"] = Token.Kind.Colon,
	["."] = Token.Kind.Dot,
	[".."] = Token.Kind.Dot2,
	["..."] = Token.Kind.Dot3,
	["->"] = Token.Kind.SkinnyArrow,

	["~="] = Token.Kind.NotEqual,
	["="] = Token.Kind.Equal,
	["<"] = Token.Kind.LessThan,
	["<="] = Token.Kind.LessEqual,
	[">"] = Token.Kind.GreaterThan,
	[">="] =Token.Kind.GreaterEqual,

	["("] = Token.Kind.LeftParen,
	[")"] = Token.Kind.RightBracket,
	["["] = Token.Kind.LeftBracket,
	["]"] = Token.Kind.RightBracket,
	["{"] = Token.Kind.LeftBrace,
	["}"] = Token.Kind.RightBrace,
}

function Lexer.new(source)
	local self = {}
	setmetatable(self, Lexer)

	self._source = source
	self._position = 1
	self._tokens = {}

	return self
end

function Lexer.is(object)
	return type(object) == "table" and getmetatable(object) == Lexer
end

--[[
	Parses the operator table and creates an array of subtables,
	ordered by the length of the operator.
]]
function Lexer.sortOperators(operatorTable)
	local tables = {}

	for operator, token in pairs(operatorTable) do
		local length = operator:len()

		-- Create tables before if they do not exist.
		-- TODO: We can greatly improve this system.
		if not tables[length] then
			for i = 1, length do
				if not tables[i] then
					tables[i] = {}
				end
			end
		end

		tables[length][operator] = token
	end

	return tables
end

--[[
	Peeks at the next character without actually consuming it.
]]
function Lexer:_peek(lookAhead)
	local position = self._position + (lookAhead or 0)
	return self._source:sub(position, position)
end

--[[
	Consumes a character and returns what it was.
]]
function Lexer:_consume(count)
	self._position = self._position + (count == nil and 1 or count)
end

Lexer.Operators = Lexer.sortOperators(Lexer.UnsortedOperators)

return Lexer