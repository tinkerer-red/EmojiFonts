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


