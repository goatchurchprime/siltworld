extends Node3D

var xr_interface : OpenXRInterface
@onready var Graph = $XROrigin3D/HandJoints/FrontOfPlayer/FlatDisplayMesh/SubViewport/FlatDisplay/Graph

var handjointpositions = [ ]
var handjointfilteredpositions = [ ]
var handjointradii = [ ]
var handjointsorted = [ ]


# Called when the node enters the scene tree for the first time.
func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		var vp = get_viewport()

		# Enable XR on the main viewport
		vp.use_xr = true

		# Make sure v-sync is disabled, we're using the headsets v-sync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		$XROrigin3D/HandJoints.set_xr_interface(xr_interface)

	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		handjointpositions.append(null)
		handjointpositions.append(null)
		handjointfilteredpositions.append(null)
		handjointfilteredpositions.append(null)
		handjointradii.append(0.0)
		handjointradii.append(0.0)
		handjointsorted.append(j*2)
		handjointsorted.append(j*2 + 1)
		
		
	# reset the position of the 2D information panel 3 times in the first 15 seconds
	for t in range(2):
		await get_tree().create_timer(3).timeout
		var headtransform = $XROrigin3D/XRCamera3D.transform	
		$XROrigin3D/HandJoints/FrontOfPlayer.transform = Transform3D(headtransform.basis, headtransform.origin - headtransform.basis.z*0.5 + Vector3(0,-0.3,0))
		$PointShader.position = $XROrigin3D/HandJoints/FrontOfPlayer/FingerButton.global_position + Vector3(0,0.2,0)
		
func _on_xr_controller_3d_left_button_pressed(name):
	print("_on_xr_controller_3d_left_button_pressed ", name)


const filtervalue = 0.1
func readprocesshandjoints():
	for hand in range(2):
		for j in range(OpenXRInterface.HAND_JOINT_WRIST+1, OpenXRInterface.HAND_JOINT_MAX):
			var i = j*2 + hand
			var pos = $XROrigin3D.transform * xr_interface.get_hand_joint_position(hand, j)
			handjointradii[i] = xr_interface.get_hand_joint_radius(hand, j)
			var handjointflags = xr_interface.get_hand_joint_flags(hand, j);
			if (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_VALID) and (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_TRACKED):
				handjointpositions[i] = pos
				if handjointfilteredpositions[i] != null:
					handjointfilteredpositions[i] = handjointfilteredpositions[i]*(1.0 - filtervalue) + pos*filtervalue
				else:
					handjointfilteredpositions[i] = pos
			else:
				handjointpositions[i] = null
				handjointfilteredpositions[i] = null

var handjointsortvec = Vector3(1,0,0)
func sort_handjoints(a, b):
	if handjointpositions[a] == null:
		return false
	elif handjointpositions[b] == null:
		return true
	var v = handjointpositions[b] - handjointpositions[a]
	return (handjointsortvec.dot(v) > 0.0)

var hjuncontactable = [ OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, 
			   			OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL,
						OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL, OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL, OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL, 
			   			OpenXRInterface.HAND_JOINT_RING_PROXIMAL, OpenXRInterface.HAND_JOINT_LITTLE_PROXIMAL ]

func detectcollidedhandjoints():
	handjointsorted.sort_custom(sort_handjoints)
	var maxrad = handjointradii[OpenXRInterface.HAND_JOINT_THUMB_METACARPAL] + handjointradii[OpenXRInterface.HAND_JOINT_THUMB_DISTAL]
	var collidedjoints = [ ]
	for ia in range(OpenXRInterface.HAND_JOINT_MAX*2):
		var a = handjointsorted[ia]
		var pa = handjointpositions[a]
		if pa == null:
			break
		for ib in range(ia+1, OpenXRInterface.HAND_JOINT_MAX*2):
			var b = handjointsorted[ib]
			var pb = handjointpositions[b]
			if pb == null:
				break
			var v = pb - pa
			if handjointsortvec.dot(v) > maxrad:
				break
			if (a%2) == (b%2):
				if hjuncontactable.has(int(a/2)) and hjuncontactable.has(int(b/2)):
					continue
			var vlen = v.length()
			var jointcontactdist = handjointradii[a] + handjointradii[b]
			if vlen < jointcontactdist:
				collidedjoints.append(a)
				collidedjoints.append(b)
	return collidedjoints

func filterposvelocity(i0, i1):
	if handjointfilteredpositions[i0] != null and handjointfilteredpositions[i1] != null:
		var df = (handjointfilteredpositions[i0] - handjointfilteredpositions[i1]).length()
		var d = (handjointpositions[i0] - handjointpositions[i1]).length()
		if d < handjointradii[i0] + handjointradii[i1]:
			if not $AudioStreamPlayer3D.playing:
				$AudioStreamPlayer3D.position = handjointpositions[i1]
				$AudioStreamPlayer3D.play()
		return df - d
	else:
		return 0.0

var t0 = 0.0
func _process(delta):
	t0 += delta
	if xr_interface:
		$GPUParticles3D.global_position = $XROrigin3D.transform * xr_interface.get_hand_joint_position(0, OpenXRInterface.HAND_JOINT_LITTLE_TIP)
		readprocesshandjoints()
		var collidedhandjoints = detectcollidedhandjoints()
		var tinselvec = $CollisionSpots.sparkcollisions(collidedhandjoints, handjointpositions, handjointfilteredpositions)
		var gtinsel = $TinselBody/GPUParticles3Dtinsel
		if tinselvec != null and not gtinsel.emitting:
			$TinselBody.position = handjointpositions[OpenXRInterface.HAND_JOINT_MIDDLE_TIP*2 + 0]
			$TinselBody.linear_velocity = tinselvec
			gtinsel.emitting = true
			
		
		#for i in range($CollisionSpots.get_child_count()):
		#	var spot = get_node("CollisionSpots/Spot%d"%i)
		#	spot.visible = (i*2 < len(collidedhandjoints))
		#	if spot.visible:
		#		var a = collidedhandjoints[i*2]
		#		var b = collidedhandjoints[i*2 + 1]
		#		var d = (handjointpositions[a] - handjointpositions[b]).length()
		#		var fd = (handjointfilteredpositions[a] - handjointfilteredpositions[b]).length()
		#		spot.position = (handjointpositions[a] + handjointpositions[b])*0.5
		#		spot.scale = Vector3(0.2, max(0.1, 100*(fd - d)), 0.2)
		#if t0 > 1.0:
		#	print(detectcollidedhandjoints())
		#	t0 = 0.0
			
		var t = filterposvelocity(OpenXRInterface.HAND_JOINT_MIDDLE_TIP*2 + 1, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL*2 + 1)
		#var middletip = xr_interface.get_hand_joint_position(1, OpenXRInterface.HAND_JOINT_MIDDLE_TIP)
		#var thumbprox = xr_interface.get_hand_joint_position(1, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL)
		#var d = (middletip - thumbprox).length()
		if t != null:
			Graph.addsample(t*20)

