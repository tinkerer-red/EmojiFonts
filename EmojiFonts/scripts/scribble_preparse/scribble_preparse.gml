//feel free to delete any other sizes and fonts you do not plan on using
#macro EMOJI_SIZE 16 //16, 24, 32, 48, 64 supported

///@ignore
function __scribble_preparse_buffered(_text, _font) {
    static input_buff = buffer_create(0, buffer_grow, 1);
    static output_buff = buffer_create(0, buffer_grow, 1);
    
    if (string_length(_text) == 0) return "";

    var _font_tag = $"[{font_get_name(_font)}]";
    var _font_limited = font_has_65535_limits(_font); // Check font limitation
    var _font_info = font_get_info(_font);
    var _glyphs = _font_info.glyphs;
    
    var byte_len = string_byte_length(_text);

    // Reset buffers
    buffer_seek(input_buff, buffer_seek_start, 0);
    buffer_seek(output_buff, buffer_seek_start, 0);

    // Write input buffer
    buffer_write(input_buff, buffer_text, _text);
    buffer_seek(input_buff, buffer_seek_start, 0);

    var i = 0;
    var high_surrogate = 0;

    while (i < byte_len) {
        var byte1 = buffer_read(input_buff, buffer_u8); i++;

        // **Detect 4-byte UTF-8 sequences (Emoji & Supplementary Planes)**
        if (byte1 >= 0xF0 && byte1 <= 0xF4) { 
            // Read the next three bytes of the sequence
            var byte2 = buffer_read(input_buff, buffer_u8); i++;
            var byte3 = buffer_read(input_buff, buffer_u8); i++;
            var byte4 = buffer_read(input_buff, buffer_u8); i++;

            // Decode the 4-byte UTF-8 sequence to a Unicode codepoint
            var codepoint = ((byte1 & 0x07) << 18) |
                            ((byte2 & 0x3F) << 12) |
                            ((byte3 & 0x3F) << 6) |
                            (byte4 & 0x3F);

            // **If font is limited & codepoint is above 0xFFFF, use only lower surrogate**
            if (_font_limited && codepoint > 0xFFFF) { 
                var lower_surrogate = (codepoint - 0x10000) & 0xFFFF; 

                buffer_write(output_buff, buffer_text, _font_tag);
                buffer_write_codepoint(output_buff, lower_surrogate);
                buffer_write(output_buff, buffer_text, "[/font]");
                continue;
            }

            // **If font is NOT limited, just wrap the emoji in `[font]`**
            buffer_write(output_buff, buffer_text, _font_tag);
            buffer_write_codepoint(output_buff, codepoint);
            buffer_write(output_buff, buffer_text, "[/font]");
            continue;
        }

        // **Handle UTF-16 Surrogate Pairs (if input was UTF-16)**
        if (byte1 >= 0xD800 && byte1 <= 0xDBFF) { // High Surrogate Detected
            high_surrogate = byte1;
            continue;
        }
        if (byte1 >= 0xDC00 && byte1 <= 0xDFFF && high_surrogate != 0) { 
            var codepoint = to_codepoint(high_surrogate, byte1);
            high_surrogate = 0; // Reset after use
        
            if (_font_limited && codepoint > 0xFFFF) { 
                buffer_write(output_buff, buffer_text, _font_tag);
                buffer_write_codepoint(output_buff, byte1);
                buffer_write(output_buff, buffer_text, "[/font]");
                continue;
            }

            buffer_write(output_buff, buffer_text, _font_tag);
            buffer_write_codepoint(output_buff, codepoint);
            buffer_write(output_buff, buffer_text, "[/font]");
            continue;
        }

        // **Write normally for standard characters**
        var utf8_char;
        if (byte1 < 0x80) {
            utf8_char = chr(byte1); // Single-byte ASCII
        } 
        else if ((byte1 & 0xE0) == 0xC0) {
            var byte2 = buffer_read(input_buff, buffer_u8); i++;
            utf8_char = chr(((byte1 & 0x1F) << 6) | (byte2 & 0x3F));
        } 
        else if ((byte1 & 0xF0) == 0xE0) {
            var byte2 = buffer_read(input_buff, buffer_u8); i++;
            var byte3 = buffer_read(input_buff, buffer_u8); i++;
            utf8_char = chr(((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F));
        } 
        else if ((byte1 & 0xF8) == 0xF0) {
            var byte2 = buffer_read(input_buff, buffer_u8); i++;
            var byte3 = buffer_read(input_buff, buffer_u8); i++;
            var byte4 = buffer_read(input_buff, buffer_u8); i++;
            utf8_char = chr(((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F));
        }

        // **Check if the glyph exists in the font**
        if (struct_exists(_glyphs, utf8_char)) {
            buffer_write(output_buff, buffer_text, _font_tag);
            buffer_write(output_buff, buffer_text, utf8_char);
            buffer_write(output_buff, buffer_text, "[/font]");
            continue;
        }
        
        buffer_write(output_buff, buffer_text, utf8_char);
    }

    // Convert the buffer into a proper Unicode string
    buffer_seek(output_buff, buffer_seek_start, 0);
    var parsed_str = buffer_get_size(output_buff) ? buffer_read(output_buff, buffer_text) : "";

    buffer_resize(input_buff, 0);
    buffer_resize(output_buff, 0);
    
    return parsed_str;
}

///@ignore
function font_has_65535_limits(_font) {
    var _info = font_get_info(_font);
    var _glyphs = _info.glyphs;
    var _glyph_names = struct_get_names(_glyphs);
	
    for (var i = 0; i < array_length(_glyph_names); i++) {
        var _char = _glyph_names[i];
        var _ord = ord(_char);

        // If character is above 65535, GameMaker does not support it properly
        if (_ord > 0xFFFF) {
            return false;
        }
    }

    return true;
}

///@ignore
function __scribble_noto_mono_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntFontNotoemojiMedium_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntFontNotoemojiMedium_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntFontNotoemojiMedium_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntFontNotoemojiMedium_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntFontNotoemojiMedium_Lite_64);
	}
}
function scribble_google_mono(_string) {
	return scribble(_string).preprocessor(__scribble_noto_mono_preparse);
}
function scribble_noto_mono(_string) {
	return scribble(_string).preprocessor(__scribble_noto_mono_preparse);
}

///@ignore
function __scribble_noto_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntGoogleNoto_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntGoogleNoto_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntGoogleNoto_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntGoogleNoto_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntGoogleNoto_Lite_64);
	}
}
function scribble_google(_string) {
	return scribble(_string).preprocessor(__scribble_noto_preparse);
}
function scribble_noto(_string) {
	return scribble(_string).preprocessor(__scribble_noto_preparse);
}

///@ignore
function __scribble_segoe_ui_mono_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntFontSeguiemj_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntFontSeguiemj_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntFontSeguiemj_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntFontSeguiemj_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntFontSeguiemj_Lite_64);
	}
}
function scribble_microsoft_mono(_string) {
	return scribble(_string).preprocessor(__scribble_segoe_ui_mono_preparse);
}
function scribble_segoe_ui_mono(_string) {
	return scribble(_string).preprocessor(__scribble_segoe_ui_mono_preparse);
}

///@ignore
function __scribble_segoe_ui_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntMicrosoftSegoeUiEmoji_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntMicrosoftSegoeUiEmoji_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntMicrosoftSegoeUiEmoji_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntMicrosoftSegoeUiEmoji_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntMicrosoftSegoeUiEmoji_Lite_64);
	}
}
function scribble_microsoft(_string) {
	return scribble(_string).preprocessor(__scribble_segoe_ui_preparse);
}
function scribble_segoe_ui(_string) {
	return scribble(_string).preprocessor(__scribble_segoe_ui_preparse);
}

///@ignore
function __scribble_openmoji_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntOpenmoji_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntOpenmoji_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntOpenmoji_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntOpenmoji_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntOpenmoji_Lite_64);
	}
}
function scribble_openmoji(_string) {
	return scribble(_string).preprocessor(__scribble_openmoji_preparse);
}

///@ignore
function __scribble_twemoji_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntTwitterTwemoji_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntTwitterTwemoji_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntTwitterTwemoji_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntTwitterTwemoji_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntTwitterTwemoji_Lite_64);
	}
}
function scribble_twemoji(_string) {
	return scribble(_string).preprocessor(__scribble_twemoji_preparse);
}
function scribble_twitter(_string) {
	return scribble(_string).preprocessor(__scribble_twemoji_preparse);
}
function scribble_discord(_string) {
	return scribble(_string).preprocessor(__scribble_twemoji_preparse);
}

///@ignore
function __scribble_whatsapp_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return __scribble_preparse_buffered(_str, fntWhatsapp_Lite_16);
		case 24: return __scribble_preparse_buffered(_str, fntWhatsapp_Lite_24);
		case 32: return __scribble_preparse_buffered(_str, fntWhatsapp_Lite_32);
		case 48: return __scribble_preparse_buffered(_str, fntWhatsapp_Lite_48);
		case 64: return __scribble_preparse_buffered(_str, fntWhatsapp_Lite_64);
	}
}
function scribble_whatsapp(_string) {
	return scribble(_string).preprocessor(__scribble_whatsapp_preparse);
}
