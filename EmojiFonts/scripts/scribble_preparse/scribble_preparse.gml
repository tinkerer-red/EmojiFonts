//feel free to delete any other sizes and fonts you do not plan on using
#macro EMOJI_SIZE 16 //16, 24, 32, 48, 64 supported

///@ignore
function __scribble_preparse_buffered(_text, _font) {
    static input_buff = buffer_create(0, buffer_grow, 1);
    static output_buff = buffer_create(0, buffer_grow, 1);
    
	if (string_length(_text) == 0) return "";
	
	var _font_tag = $"[{font_get_name(_font)}]";
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

	        // **If it's an emoji (outside BMP), insert Scribble font tags**
	        if (codepoint > 0xFFFF) { 
	            var lower_surrogate = (codepoint - 0x10000) & 0xFFFF; // Extract only the last 16 bits

	            // Insert the formatted emoji with the correct font tag
	            buffer_write(output_buff, buffer_text, _font_tag);
				show_debug_message($"lower_surrogate :: {chr(lower_surrogate)} :: {lower_surrogate}")
	            buffer_write_codepoint(output_buff, lower_surrogate);
	            buffer_write(output_buff, buffer_text, "[/font]");
	            continue;
	        }
	    }

	    // **Handle UTF-16 Surrogate Pairs (if input was UTF-16)**
	    if (byte1 >= 0xD800 && byte1 <= 0xDBFF) { // High Surrogate Detected
	        high_surrogate = byte1;
	        continue;
	    }

	    if (byte1 >= 0xDC00 && byte1 <= 0xDFFF && high_surrogate != 0) { 
	        // **We have a valid surrogate pair**
	        var codepoint = to_codepoint(high_surrogate, byte1);
	        high_surrogate = 0; // Reset after use
        
	        if (codepoint > 0xFFFF) { 
	            // **Insert Scribble Font Tags for Emojis**
	            buffer_write(output_buff, buffer_text, _font_tag);
				show_debug_message($"byte1 :: {chr(byte1)} :: {byte1}")
	            buffer_write_codepoint(output_buff, byte1); // Write lower surrogate only
	            buffer_write(output_buff, buffer_text, "[/font]");
	            continue;
	        }
	    }

	    // **Write normally for standard characters**
	    if (high_surrogate == 0) {
			if (byte1 < 0x80) {
			    var utf8_char = chr(byte1); // Single-byte ASCII
			} 
			else if ((byte1 & 0xE0) == 0xC0) {
			    var byte2 = buffer_read(input_buff, buffer_u8); i++;
			    var utf8_char = chr(((byte1 & 0x1F) << 6) | (byte2 & 0x3F));
			} 
			else if ((byte1 & 0xF0) == 0xE0) {
			    var byte2 = buffer_read(input_buff, buffer_u8); i++;
			    var byte3 = buffer_read(input_buff, buffer_u8); i++;
			    var utf8_char = chr(((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F));
			} 
			else if ((byte1 & 0xF8) == 0xF0) {
			    var byte2 = buffer_read(input_buff, buffer_u8); i++;
			    var byte3 = buffer_read(input_buff, buffer_u8); i++;
			    var byte4 = buffer_read(input_buff, buffer_u8); i++;
			    var utf8_char = chr(((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F));
			}

			if (byte1 != ord(" "))
			&& (struct_exists(_glyphs, utf8_char)) {
				//show_debug_message($"Glyph found: {utf8_char}");
				buffer_write(output_buff, buffer_text, _font_tag);
				buffer_write(output_buff, buffer_text, utf8_char);
	            buffer_write(output_buff, buffer_text, "[/font]");
				
				continue;
			}
			
			
	        buffer_write(output_buff, buffer_text, utf8_char);
	    }
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
    var _font_info = font_get_info(_font);
    var _glyphs = _font_info.glyphs;
    var _glyph_keys = struct_get_names(_glyphs);
    static _mismatches = [];
    
    for (var _i = 0; _i < array_length(_glyph_keys); _i++) {
        var _key = _glyph_keys[_i];
        var _char = _glyphs[$ _key].char;

        // Convert the key to a character using ord()
        var _ord_value = ord(_key);
        
        // Check if glyph character matches the ord() value
        if (_ord_value != _char) {
            array_push(_mismatches, _key);
        }
    }

    if (array_length(_mismatches) > 0) {
		array_resize(_mismatches, 0);
        show_debug_message("Mismatched glyphs found: " + string_join(_mismatches, ", "));
		return true;
    } else {
		array_resize(_mismatches, 0);
        show_debug_message("All glyphs match their expected ord() values.");
		return false;
    }
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
