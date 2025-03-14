//feel free to delete any other sizes and fonts you do not plan on using
#macro EMOJI_SIZE 16 //16, 24, 32, 48, 64 supported

///@ignore
function scribble_preparse_buffered(_text, _font) {
    static input_buff = buffer_create(0, buffer_grow, 1);
    static output_buff = buffer_create(0, buffer_grow, 1);
    
	if (string_length(_text) == 0) return "";
	
	var _font_tag = $"[{font_get_name(_font)}]";
	
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
	            buffer_write(output_buff, buffer_text, "[{_font_arg}]");
	            buffer_write_codepoint(output_buff, byte1); // Write lower surrogate only
	            buffer_write(output_buff, buffer_text, "[/font]");
	            continue;
	        }
	    }

	    // **Write normally for standard characters**
	    if (high_surrogate == 0) {
	        buffer_write(output_buff, buffer_u8, byte1);
	    }
	}


    // Convert the buffer into a proper Unicode string
    buffer_seek(output_buff, buffer_seek_start, 0);
    var parsed_str = buffer_get_size(output_buff) ? buffer_read(output_buff, buffer_text) : "";

    buffer_resize(input_buff, 0);
    buffer_resize(output_buff, 0);

    return parsed_str;
}
function __scribble_whatsapp_preparse(_str) {
	switch (EMOJI_SIZE) {
		case 16: return scribble_preparse_buffered(_str, fntWhatsapp_Lite_16);
		case 24: return scribble_preparse_buffered(_str, fntWhatsapp_Lite_24);
		case 32: return scribble_preparse_buffered(_str, fntWhatsapp_Lite_32);
		case 48: return scribble_preparse_buffered(_str, fntWhatsapp_Lite_48);
		case 64: return scribble_preparse_buffered(_str, fntWhatsapp_Lite_64);
	}
}
function scribble_whatsapp(_string) {
	return scribble(_string).preprocessor(__scribble_whatsapp_preparse);
}