/// @description Insert description here
// You can write your code in this editor
yy = 32
draw_set_color(c_gray)
draw_rectangle(32,yy,32+16,32+16, false)
draw_set_color(c_white)
draw_set_font(fntTwitterTwemoji_Lite_16)
draw_text(32, yy, glyphs[floor(index)])
yy += 32
draw_set_font(fntTwitterTwemoji_Lite_24)
draw_text(32, yy, glyphs[floor(index)])
yy += 32
draw_set_font(fntTwitterTwemoji_Lite_32)
draw_text(32, yy, glyphs[floor(index)])
//yy += 32


index += 1/10