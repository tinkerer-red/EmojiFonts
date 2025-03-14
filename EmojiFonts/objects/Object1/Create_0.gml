/// @description Insert description here
// You can write your code in this editor

struct = font_get_info(fntWhatsapp_Lite_32).glyphs
glyphs = struct_get_names(struct);
temp = {};

for (var i=0; i<array_length(glyphs); i++){
	temp[$ glyphs[i]] = struct[$ glyphs[i]]
}

//show_debug_message(json_stringify(temp, true))

index = 0;
yy = 0

var _arr = string_split(get_emojis(), "\n", true)

emoji_str = get_emojis()
string_lines = string_split(emoji_str, "\n")

glyphs = font_get_info(fntWhatsapp_Lite_16).glyphs
glyph_names = struct_get_names(glyphs)
array_sort(glyph_names, true)
array_delete(glyph_names, 0, 1)


for(var _i=60; _i<65; _i++) {
	var _str = string_lines[_i];
	var _new_str = __scribble_whatsapp_preparse(_str);
//	show_debug_message(_new_str)
}

show_debug_message(__scribble_whatsapp_preparse(get_emojis()))