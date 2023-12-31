extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	if $PointMesh.visible:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_POINTS)
		for i in range(11):
			for j in range(11):
				for k in range(11):
					var p = (Vector3(i,j,k)*0.1-Vector3(0.5,0.5,0.5))*0.1
					st.add_vertex(p)
		var pointmesh = st.commit()
		$PointMesh.mesh = pointmesh
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	#$PointMesh.rotation_degrees.y += delta*30
	#$PointMesh.rotation_degrees.z += delta*20
