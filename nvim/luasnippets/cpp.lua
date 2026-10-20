local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

local function upper(args)
	return string.upper(args[1][1])
end

return {

	-- .hpp header with include guard and full 5-member OCF class declaration
	-- Trigger: hdr
	s(
		"hdr",
		fmta(
			[[
#ifndef <>_HPP
# define <>_HPP

class <>
{
public:
	<>(void);
	<>(<>);
	<>(const <> &other);
	<> &operator=(const <> &other);
	~<>(void);

private:
	<>
};

#endif
]],
			{
				f(upper, { 1 }), -- #ifndef CLASSNAME_HPP
				f(upper, { 1 }), -- # define CLASSNAME_HPP
				i(1, "ClassName"),
				rep(1), -- default ctor
				rep(1),
				i(2, "params"), -- parameterized ctor
				rep(1),
				rep(1), -- copy ctor
				rep(1),
				rep(1), -- assignment operator
				rep(1), -- destructor
				i(3), -- private members
			}
		)
	),

	-- Full 5-member OCF .cpp implementation
	-- Trigger: ocf
	s(
		"ocf",
		fmta(
			[[
<>::<>(void)
{
	<>
}

<>::<>(<>)
{
	<>
}

<>::<>(const <> &other)
{
	*this = other;
}

<> &<>::operator=(const <> &other)
{
	if (this != &other)
	{
		<>
	}
	return (*this);
}

<>::~<>(void)
{
	<>
}
]],
			{
				i(1, "ClassName"),
				rep(1), -- default ctor
				i(2), -- default ctor body
				rep(1),
				rep(1),
				i(3, "params"), -- parameterized ctor
				i(4), -- parameterized ctor body
				rep(1),
				rep(1),
				rep(1), -- copy ctor
				rep(1),
				rep(1),
				rep(1), -- assignment operator
				i(5), -- assignment body
				rep(1),
				rep(1), -- destructor
				i(6), -- destructor body
			}
		)
	),
}
