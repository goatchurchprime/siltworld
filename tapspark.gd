extends Node3D


@onready var tapsparkscene = load("res://tapspark.tscn")

func finishedplaying(name):
	var tapspark = get_node_or_null(name)
	tapspark.queue_free()

var tapsparkdifferencethreshold = 0.01
func sparkcollisions(collidedhandjoints, handjointpositions, handjointfilteredpositions):
	for i in range(int(len(collidedhandjoints)/2)):
		var a = collidedhandjoints[i*2]
		var b = collidedhandjoints[i*2 + 1]
		var d = (handjointpositions[a] - handjointpositions[b]).length()
		var fd = (handjointfilteredpositions[a] - handjointfilteredpositions[b]).length()
		var name = "TapSpark%d_%d" % [a, b]
		var tapspark = get_node_or_null(name)
		if (fd - d) > tapsparkdifferencethreshold:
			if tapspark == null:
				tapspark = tapsparkscene.instantiate()
				tapspark.name = name
				add_child(tapspark)
				tapspark.get_node("AudioStreamPlayer3D").finished.connect(finishedplaying.bind(name))
			var audstream = tapspark.get_node("AudioStreamPlayer3D")
			if not audstream.playing:
				tapspark.position = (handjointpositions[a] + handjointpositions[b])*0.5
				audstream.pitch_scale = 1.0 + (fd - d - tapsparkdifferencethreshold)*140
				audstream.play()
		if tapspark != null:
			tapspark.get_node("Spark").scale = Vector3(0.2, max(0.1, 100*(fd - d)), 0.2)

