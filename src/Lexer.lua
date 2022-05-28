-- OptimisticSide
-- 5/2/2022
-- Lexical scanner

-- luacheck: push globals script
local Token = require(_VERSION == "Luau" and script.Parent.Token or "./Token.lua")
-- luacheck: pop

local Lexer = {}
Lexer.__index = Lexer

Lexer.Alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
Lexer.BaseDigits = "0123456789ABCDEF"
Lexer.Whitespace = " \t\n\r\f"
Lexer.Digits = "0123456789"
Lexer.EscapeSequences = {
	["a"] = "\a",
	["b"] = "\b",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
	["v"] = "\v",
	["\\"] = "\\",
	['"'] = '"',
	["'"] = "'",
}

Lexer.NameChars = Lexer.Alphabet .. Lexer.Digits .. "-"
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
	[">="] = Token.Kind.GreaterEqual,

	["("] = Token.Kind.LeftParen,
	[")"] = Token.Kind.RightParen,
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
	Throws an error generated by the lexer.

	Note that this can be overriden by the user (since it's retrieved
	through the __index metamethod).
]]
-- luacheck: ignore self
function Lexer:_error(formatString, ...)
	error(formatString:format(...))
end

--[[
	Returns the next n-characters (defaults to 1) from the string without
	consuming them.
]]
function Lexer:_peek(count)
	local endPosition = count + self._position
	return self._source:sub(self._position, endPosition)
end

--[[
	Matches a string to what is in the source at the position that we are at.
	Returns `true` if the string was matched (does not consume anything).
]]
function Lexer:_match(toMatch)
	return self:_peek(#toMatch) == toMatch
end

--[[
	Returns the currnet character and advances to the next one.
]]
function Lexer:_advance()
	local character = self._peek()
	self._position = self._position + 1
	return character
end

--[[
	Accepts a string if valid, and returns `nil` otherwise.
]]
function Lexer:_accept(toMatch)
	if self:_match(toMatch) then
		self._position = self._position + #toMatch
		return toMatch
	end
end

function Lexer:readQuotedString()
	local start = self._position
	local quote = self:_accept("'") or self:_accept('"')
	local content = {}

	while not self:_accept(quote) do
		local character = self:_advance()

		if character == "\\" then
			local escapeChar = self:_advance()
			local escapeSequence = Lexer.EscapeSequences[escapeChar]
			if not escapeSequence then
				self:_error("%s is not a valid escape sequence", escapeChar)
				break
			end

			character = escapeChar
		end

		table.insert(content, character)
	end

	content = table.concat(content)
	return Token.new(Token.Kind.QuotedString, start, self._position, content)
end

function Lexer:readLongString(isComment, start)
	start = start or self._position
	self:_expect("[")

	local startCount = 0
	while self:_accept("=") do
		startCount = startCount + 1
	end

	self:_expect("]")
	local content = {}
	local suffix = "]" .. ("="):rep(startCount) .. "]"

	while not self:_accept(suffix) do
		table.insert(content, self:_advance())
	end

	content = table.concat(content)
	local tokenKind = isComment and Token.Kind.Comment or Token.Kind.LongString
	return Token.new(tokenKind, start, self._position, content)
end

function Lexer:readComment()
	local start = self._position
	if self:_peek("[") then
		return self:readLongString(true, start)
	end

	local content = {}
	while not self:_accept("\n") do
		table.insert(content, self:_advance())
	end

	content = table.concat(content)
	return Token.new(Token.Kind.Comment, start, self._position, content)
end

function Lexer:readName()
	local start = self._position
	local content = {}

	while Lexer.NameChars:find(self._peek()) do
		table.insert(content, self._advance())
	end

	content = table.concat(content)
	return Token.new(Token.Kind.Name, start, self._position, content)
end

function Lexer:readNumber()
	-- TODO: Do this...
end

--[[
	Main lexical-analysis function that reads something from the source.
]]
function Lexer:read()
	local start = self._position

	if self:_accept("--") then
		return self:readComment()
	end

	if self:_accept("[[") then
		return self:readLongString()
	end
	if self:_match("'") or self:_match('"') then
		return self:readQuotedString()
	end

	-- Reserved is just another word for keywords in Lua(u).
	for reserved, tokenType in pairs(Lexer.Reserved) do
		if self:_accept(reserved) then
			return Token.new(tokenType, start, self._position)
		end
	end

	-- Operators are split into groups based on their size.
	for _, operatorGroup in ipairs(Lexer.Operators) do
		for operator, tokenType in pairs(operatorGroup) do
			if self:_accept(operator) then
				return Token.new(tokenType, start, self._position)
			end
		end
	end

	local character = self:_peek()
	if Lexer.Whitespace:find(character) then
		return
	end
	if Lexer.Digits:find(character) then
		return self:readNumber()
	end
	if Lexer.Alphabet:find(character) then
		return self:readName()
	end
end

Lexer.Operators = Lexer.sortOperators(Lexer.UnsortedOperators)

return Lexer
