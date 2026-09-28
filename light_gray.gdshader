shader_type canvas_item;

// Redraws the wood of a sprite (its reddish-brown parts, like a tree's trunk and branches) in
// light greys, keeping its shading; everything else, like the leaves, keeps its colour.
// Used for things only blue fire burns (burnable.gd with needs_blue).
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (color.r > color.g) {
		float brightness = dot(color.rgb, vec3(0.3, 0.59, 0.11));
		color.rgb = vec3(0.6 + brightness * 0.4);
	}
	COLOR = color;
}
