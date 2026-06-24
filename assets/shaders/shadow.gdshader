shader_type canvas_item;

// 阴影颜色和透明度
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
// 阴影偏移量（单位：像素）
uniform vec2 shadow_offset = vec2(4.0, 4.0);

// 【核心修改】在 Godot 4 中，必须显式声明获取屏幕纹理
// filter_nearest 确保在像素游戏中边缘保持锐利，不模糊
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    // 从屏幕纹理中读取 CanvasGroup 所有子节点合并后的本来图案
    vec4 base_color = texture(screen_texture, SCREEN_UV);

    // 计算阴影的偏移位置 (使用 SCREEN_UV 和 SCREEN_PIXEL_SIZE)
    vec2 shadow_uv = SCREEN_UV - shadow_offset * SCREEN_PIXEL_SIZE;

    // 获取偏移位置的透明度 (判断那个位置原本有没有建筑零件)
    float shadow_alpha = texture(screen_texture, shadow_uv).a;

    // 构造阴影最终的颜色
    vec4 final_shadow = shadow_color;
    final_shadow.a *= shadow_alpha; // 只有在原图案偏移位置有像素时，才显示阴影

    // 将原图与阴影混合 (原图盖在阴影上面)
    COLOR = mix(final_shadow, base_color, base_color.a);
}
