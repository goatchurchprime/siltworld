extends ColorRect


func _ready():
	pass # Replace with function body.



var vmax = 0.1
var n = 0
var nl = 0
@onready var line = $Line0
func addsample(v):
	line.add_point(Vector2(n, v*25))
	n += 1
	vmax = max(vmax, v)
	if n > size.x:
		line = $Line1 if line == $Line0 else $Line0
		line.clear_points()
		n = 0
		#print("vmax ", vmax)
		vmax = 0
		
#var t0 = 0
#func _process(delta):
#	t0 += delta
#	addsample(sin(t0)+1)
