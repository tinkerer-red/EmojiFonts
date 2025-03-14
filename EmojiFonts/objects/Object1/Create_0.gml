/// @description Insert description here
// You can write your code in this editor
yy = 0

var _arr = string_split(get_emojis(), "\n", true)

emoji_str = get_emojis()
string_lines = string_split(emoji_str, "\n", true)

var glyph_strings = [];
var unicode_strings = [];
var name_strings = [];
for(var _i=0; _i<__SCRIBBLE_MAX_LINES; _i++) {
	var _str = string_lines[_i];
	_str = string_replace_all(_str, @'" :: "', "|");
	_str = string_replace_all(_str, @'"', "");
	var _arr = string_split(_str, "|")
	show_debug_message(_arr)
	glyph_strings[_i] = _arr[0];
	unicode_strings[_i] = " :: " + _arr[1] + " :: " + _arr[2];
	//name_strings[_i] = _arr[2];
}

//array_resize(glyph_strings, __SCRIBBLE_MAX_LINES-10)
//array_resize(unicode_strings, __SCRIBBLE_MAX_LINES)
//array_resize(name_strings, __SCRIBBLE_MAX_LINES)

glyph_string = string_join_ext("\n", glyph_strings);
unicode_string = string_join_ext("\n", unicode_strings);
//name_string = string_join_ext("\n", name_strings);



show_debug_overlay(true)