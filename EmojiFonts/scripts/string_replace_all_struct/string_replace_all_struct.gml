function string_replace_all_struct(input_string, _map, _case_sensitive=true) {
	static __convert_to_array_map = function(_map) {
	    static __buff = buffer_create(0, buffer_grow, 1);
		
	    var root = array_create(256, undefined); // Root node
		
	    var _names = struct_get_names(_map);
	    var _length = array_length(_names);
		
	    for (var _i = 0; _i < _length; _i++) {
	        var _find = _names[_i];
	        var _replace = _map[$ _find];
			
	        buffer_write(__buff, buffer_text, _find);
	        var _byte_len = buffer_tell(__buff);
	        buffer_seek(__buff, buffer_seek_start, 0);
			
	        var node = root; // Start at root
	        var _j = 0;
			
	        while (_j < _byte_len) {
	            var _byte = buffer_read(__buff, buffer_u8);
	            _j++;
				
	            if (node[_byte] == undefined) {
	                node[_byte] = array_create(256, undefined); // Create new array node
	            }
	            node = node[_byte]; // Move to next depth
	        }
			
	        node[0] = _replace; // Store replacement in index `0`, since `0` in a string is a terminator byte.
			
	        buffer_resize(__buff, 0); // Reset buffer for next word
	    }
		
	    return root; // Return just the trie
	};
	
	static temp_buff = buffer_create(0, buffer_grow, 1); // literally only used to write a string into a fast buffer with buffer_copy
	static input_buff = buffer_create(0, buffer_fast, 1);
	static output_buff = buffer_create(0, buffer_grow, 1);
	
	//micro optimization
	var _temp_buff = temp_buff;
	var _input_buff = input_buff;
	var _output_buff = output_buff;
	
	// Pre-allocate sizes
	var byte_len = string_byte_length(input_string);
	buffer_resize(_input_buff, byte_len)
	buffer_resize(_output_buff, byte_len)
	
	// Write input buffer
	buffer_write(_temp_buff, buffer_text, input_string);
	buffer_copy(_temp_buff, 0, byte_len, _input_buff, 0)
	buffer_resize(_temp_buff, 0)
	
	//probably want to cache this if possible
	var lookup = __convert_to_array_map(_map); // Precompute nested hashmap
	
	//used for keeping track of the last found replacement
	var _replacement = undefined;
	
	// Buffer Tell positions (optimization)
	var input_pos = 0;
	var output_pos = 0;
	var match_pending = false; // where we first matched
	var match_pos = undefined; // where we first matched
	var match_pos_secondary = undefined; // where another possible match could occur
	
	var node = lookup;
	var byte = undefined;
	while (byte || input_pos < byte_len) {
		if (byte == undefined){
			byte = buffer_read(_input_buff, buffer_u8); // Read UTF-16 codepoint
			input_pos += 1;
		}
		
		var _possible_match = node[byte]
		if (!_case_sensitive && _possible_match == undefined) {
			// A-Z → a-z
			if (byte >= 65 && byte <= 90) {
				var lookup_byte = byte + 32;
				_possible_match = node[lookup_byte];
			}
			// a-z → A-Z
			else if (byte >= 97 && byte <= 122) {
				var lookup_byte = byte - 32;
				_possible_match = node[lookup_byte];
			}
		}
		
		if (_possible_match != undefined) {
			node = _possible_match; // Move deeper into the nested hashmap
			
			// If there is a pending replacement, keep track of other possible matches
			if (match_pending && match_pos_secondary == undefined) {
				var _possible_match = lookup[byte];
				if (_possible_match != undefined) {
					match_pos_secondary = input_pos-1;
				}
			}
			
			// Mark that we have started a match
			if (!match_pending) {
				match_pending = true;
				match_pos = input_pos-1;
			}
			
			// Check if the static struct exists and has "value"
			var _value = node[0];
			if (_value != undefined) {
				_replacement = _value;
			}
			
			byte = undefined;
			continue;
		}
		else {
			if (match_pending) {
				if (_replacement != undefined) {
					buffer_write(_output_buff, buffer_text, _replacement);
					_replacement = undefined;
				}
				else { //if we failed to find a match
					
					//if there was a secondary match option jump back to that position
					if (match_pos_secondary) {
						buffer_seek(_input_buff, buffer_seek_start, match_pos_secondary);
						input_pos = match_pos_secondary;
						byte = undefined;
					}
					
					//copy everything form match start pos, to the current location.
					var _size = input_pos - match_pos;
					if (_size) {
						buffer_copy(_input_buff, match_pos, _size, _output_buff, buffer_tell(_output_buff));
						buffer_seek(_output_buff, buffer_seek_relative, _size);
					}
					
				}
				
				node = lookup;
				match_pending = false;
				match_pos = undefined;
				match_pos_secondary = undefined;
				continue;
			}
			
			// No match found, write the original character
			buffer_write(_output_buff, buffer_u8, byte);
			byte = undefined;
			node = lookup;
		}
	}
	
	// Final replacement in case we end on a valid match
	if (_replacement != undefined) {
		buffer_write(_output_buff, buffer_text, _replacement);
	}
	
	// Convert buffer back to string
	buffer_seek(_output_buff, buffer_seek_start, 0);
	var result = buffer_read(_output_buff, buffer_text);
	
	buffer_resize(_input_buff, 0);
	buffer_resize(_output_buff, 0);
	
	return result;
}

show_debug_message(
	string_replace_all_struct("happier times", {
		"happiness": "💖",
		"happily": "😃",
		"happi": "🙂"
	}, false)
);
// Expected Output: "🙂er times"
// Explanation: 
// - "happiness" and "happily" **fail** as they require extra characters.
// - "happi" is valid and should be used.

show_debug_message(
	string_replace_all_struct("abcdef-", {
		"abcdefg": "123",
		"cde": "456",
	}, false)
);
// Expected Output: "ab456f-"
// Explanation: 
// - The function starts scanning for `"abcdefg"` but **fails** since the input ends with `"-"`, not `"g"`.
// - `"cde"` was bypassed during the `"abcdefg"` scan, but it **should still be applied**.
// - `"cde"` is correctly replaced with `"456"` once `"abcdefg"` fails.

show_debug_message(
	string_replace_all_struct("abcdefg hi", {
		"abcdefghi": "999",
		"cde": "456",
	}, false)
);
// Expected Output: "ab456fg hi"
// Explanation:
// - The function starts scanning `"abcdefghi"` but **fails** at `"hi"` since `"ghi"` isn't fully present.
// - `"cde"` was skipped initially, but now that `"abcdefghi"` **fails**, `"cde"` **should be applied**.

show_debug_message(
	string_replace_all_struct("Happy!", {
		"happy": "😀",
		"happ": "😢",
		"h": "E"
	}, false)
);
//// Expected Output: "😀!"

show_debug_message(
	string_replace_all_struct("happy! HAPPY!", {
		"Happy": "😀"
	}, true)
);
// Expected Output (case-sensitive): "happy! HAPPY!"

show_debug_message(
	string_replace_all_struct("Happy! HAPPY!", {
		"Happy": "😀",
		"HAPPY": "🔥"
	}, false)
);
// Expected Output (case-insensitive): "😀! 🔥!"

show_debug_message(
	string_replace_all_struct("happier", {
		"happ": "😢",
		"happy": "😀"
	}, false)
);
// Expected Output: "😢ier"
// Explanation: It matches "happ" first, replacing it with "😢", then "ier" remains.

show_debug_message(
	string_replace_all_struct("happiest", {
		"happ": "😢",
		"happy": "😀",
		"happiest": "🥳"
	}, false)
);
// Expected Output: "🥳"
// Explanation: "happiest" fully matches first, so it replaces the whole string.

show_debug_message(
	string_replace_all_struct("happiness is key", {
		"happiness": "💖",
		"happi": "🙂"
	}, false)
);
// Expected Output: "💖 is key"
// Explanation: "happiness" is the longest match, so it takes priority.

show_debug_message(
	string_replace_all_struct("happy dog", {
		"happy": "😀",
		"h": "E"
	}, false)
);
// Expected Output: "😀 dog"
// Explanation: "happy" matches fully before "h" can be considered.

show_debug_message(
	string_replace_all_struct("coding is fun", {
		"fun": "🔥",
		"is fun": "💡"
	}, false)
);
// Expected Output: "coding 💡"
// Explanation: "is fun" matches first, replacing the longer string before "fun" can be considered.

show_debug_message(
	string_replace_all_struct("I am happy", {
		"I am happy": "😎",
		"happy": "😀"
	}, false)
);
// Expected Output: "😎"
// Explanation: The full sentence "I am happy" matches first.

show_debug_message(
	string_replace_all_struct("abcde", {
		"a": "1",
		"ab": "2",
		"abc": "3",
		"abcd": "4"
	}, false)
);
// Expected Output: "4e"
// Explanation: "abcd" is the longest match, so it replaces first.

show_debug_message(
	string_replace_all_struct("transformers", {
		"trans": "🚀",
		"formers": "🤖",
		"transformers": "🦸‍♂️"
	}, false)
);
// Expected Output: "🦸‍♂️"
// Explanation: "transformers" fully matches, overriding the smaller replacements.

// Build replacement maps dynamically using struct_set
var map1 = {};
struct_set(map1, "abc", "123");
struct_set(map1, "123", "456");
show_debug_message(string_replace_all_struct("abcabc", map1, false));
// Expected Output: "123123"
// Expected Output: "123123"
// Explanation: No recursive evaluation, only the first replacement is applied.

var map2 = {};
var _red_apple = "🍎"
var _green_apple = "🍏"
var _banana = "🍌"
struct_set(map2, _red_apple, _green_apple);
struct_set(map2, _green_apple, _red_apple);
show_debug_message(string_replace_all_struct("🍎🍏🍌🍎", map2, false));
// Expected Output: "🍏🍎🍌🍏"
// Explanation: Each emoji is replaced independently.

var map3 = {};
struct_set(map3, "911", "🚨");
show_debug_message(string_replace_all_struct("Call 911!", map3, false));
// Expected Output: "Call 🚨!"

var map4 = {};
struct_set(map4, "#12345", "✅ Order Complete");
show_debug_message(string_replace_all_struct("Order #12345", map4, false));
// Expected Output: "✅ Order Complete"

var map5 = {};
struct_set(map5, ", world!", " 🌍");
show_debug_message(string_replace_all_struct("Hello, world!", map5, false));
// Expected Output: "Hello 🌍"

var map6 = {};
struct_set(map6, "<3", "❤️");
show_debug_message(string_replace_all_struct("I <3 coding!", map6, false));
// Expected Output: "I ❤️ coding!"

var map7 = {};
struct_set(map7, "Hello", "Hi");
struct_set(map7, "world", "Earth");
struct_set(map7, "happy", "joyful");
show_debug_message(string_replace_all_struct("Hello world, happy coding!", map7, false));
// Expected Output: "Hi Earth, joyful coding!"

var map8 = {};
struct_set(map8, "bug", "🐛");
struct_set(map8, "code", "💻");
show_debug_message(string_replace_all_struct("Fix the bug in the code!", map8, false));
// Expected Output: "Fix the 🐛 in the 💻!"

var map9 = {};
struct_set(map9, "a", "1");
struct_set(map9, "ab", "2");
struct_set(map9, "aba", "3");
struct_set(map9, "acad", "4");
struct_set(map9, "adabra", "5");
struct_set(map9, "!", "🎉");
show_debug_message(string_replace_all_struct("abacadabra!", map9, false));
// Expected Output: "3c5🎉"
// Explanation: "aba" → "3", "cadabra" → "5", and "!" → "🎉".

var map10 = {};
struct_set(map10, "happiness", "😀");
struct_set(map10, "is", "🔥");
struct_set(map10, "happi", "💖");
struct_set(map10, "happy", "🎉");
show_debug_message(string_replace_all_struct("happiness is happiness", map10, false));
// Expected Output: "😀 🔥 😀"
// Explanation: "happiness" is the longest match, so it gets replaced first.
