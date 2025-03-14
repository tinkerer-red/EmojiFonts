/// @description Insert description here
// You can write your code in this editor

if (mouse_wheel_down()) {
	yy -= 30
}
if (mouse_wheel_up()) {
	yy += 30
}
//draw_set_color(c_white)
//draw_set_font(fntWhatsapp_Lite_16)
//draw_text(130, yy, get_emojis())
//
//draw_set_font(Font1)
//draw_text(130, yy, get_emojis())
//

var _lines = string_count("\n", get_emojis());
var _height = font_get_info(fntWhatsapp_Lite_16).size;

draw_set_alpha(0.1)
for(var _i=0; _i<_lines; _i++){
	draw_line(0, yy+(_i*_height), 1280, yy+(_i*_height))
}
draw_set_alpha(1)

for(var _i=0; _i<_lines; _i++){
	var _unicode = glyph_names[_i]
	var _str = _unicode +" :: "+ UnicodeTool(_unicode).utf32()
	
	draw_set_font(Font1)
	draw_text(0, yy+(_i*_height), _str)
	draw_set_font(fntWhatsapp_Lite_16)
	draw_text(0, yy+(_i*_height), _str)
	
	draw_set_font(Font1)
	draw_text(130, yy+(_i*_height), string_lines[_i])
	draw_set_font(fntWhatsapp_Lite_16)
	draw_text(130, yy+(_i*_height), string_lines[_i])
	
}

scribble_whatsapp(get_emojis()).draw(0,0)



