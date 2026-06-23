extends Node
## 加热台激光调参（autoload 名: HeaterTuning）。LaserGap 决定发射器间距与反射镜覆盖范围，
## 由 F4 调试面板实时改。仅影响手感，不进存档；正式版保留默认值即可。

## 激光发射器之间的垂直距离（面板像素）。反射镜高度 = LaserGap * mirror_factor。
var laser_gap: float = 26.0
## 反射镜高度相对 LaserGap 的倍数（需求固定 1.5：使覆盖 1 道 / 2 道激光概率相同）。
var mirror_factor: float = 1.5
