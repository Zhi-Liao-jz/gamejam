shader_type canvas_item;

// --- 面板参数 ---
group_uniforms Effect_Settings;
uniform float noise_scale : hint_range(0.001, 1) = 0.02; // 噪点缩放，决定色块斑驳的大小
uniform float intensity : hint_range(0.0, 1.0) = 0.3;      // 颜色不均匀的强度
uniform vec4 dirt_color : source_color = vec4(0.3, 0.25, 0.2, 1.0); // 污渍颜色（默认带点轻微的机油泥土色）
uniform sampler2D noise_texture;

group_uniforms Pixel_Art_Settings;
uniform float pixel_size = 1.0; // 像素化大小，如果是放大绘制的像素画，可以调大这个值（比如2、4）

// 传递给片段着色器的世界坐标
varying vec2 world_pos;

void vertex() {
    // 获取顶点的世界坐标。
    // 这样无论你怎么拼接地砖（TileMap），噪点都是连续的，不会产生接缝！
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 1. 读取地砖本来的颜色
    vec4 base_color = texture(TEXTURE, UV);

    // 如果是完全透明的像素，直接丢弃，节省性能
    if (base_color.a == 0.0) {
        discard;
    }

    // 2. 将世界坐标“像素化”
    // 这是像素风的关键！确保噪点不是平滑的高清渐变，而是方方正正的像素块
    vec2 snapped_pos = floor(world_pos / pixel_size) * pixel_size;

    // 3. 生成噪点值 (范围 0.0 到 1.0)
    //float n = noise(snapped_pos * noise_scale);
	float n = texture(noise_texture,snapped_pos * noise_scale).r;
	if (n<0.1) n=0.0;
    // 4. 将基础色和污渍/不均匀色进行混合
    // 这里使用正片叠底(Multiply)的思路，让颜色变暗变脏
    vec3 blended_color = base_color.rgb * mix(vec3(1.0), dirt_color.rgb, n * intensity);
	//vec3 blended_color = texture(noise_texture,UV).rgb;
    // 5. 输出最终颜色
    COLOR = vec4(blended_color, base_color.a);
}
