extends Node3D

var xr_interface : OpenXRInterface
var xr_tracker_head : XRPositionalTracker
var xr_tracker_hands = [ ]
var xr_play_area : PackedVector3Array

# Get the trackers once the interface has been initialized
func set_xr_interface(lxr_interface : OpenXRInterface):
	xr_interface = lxr_interface
	var trackers1 = XRServer.get_trackers(1)
	xr_tracker_head = trackers1["head"]
	var trackers2 = XRServer.get_trackers(2)
	xr_tracker_hands = [ trackers2["left_hand"], trackers2["right_hand"] ]
	set_process(true)


var skelhandleft = null
var skelhandright = null

func _ready():
	set_process(false)
	skelhandleft = SkelHand.new()
	skelhandleft.extractrestfingerbones($Hand_Glove_L, 0)
	skelhandright = SkelHand.new()
	skelhandright.extractrestfingerbones($Hand_Glove_R, 1)

static func rotationtoalign(a, b):
	var axis = a.cross(b).normalized();
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads)
	return Basis()

static func rotationtoalignScaled(a, b):
	var axis = a.cross(b).normalized()
	var sca = b.length()/a.length()
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads).scaled(Vector3(sca,sca,sca))
	return Basis().scaled(Vector3(sca,sca,sca))


static func basisfrom(a, b):
	var vx = (b - a).normalized()
	var vy = vx.cross(-a.normalized())
	var vz = vx.cross(vy)
	return Basis(vx, vy, vz)

static func basisfromA(a, v):
	var vx = a.normalized()
	var vy = vx.cross(v.normalized())
	var vz = vx.cross(vy)
	return Basis(vx, vy, vz)

static func rotationtoalignB(a, b, va, vb):
	return basisfromA(b, vb)*basisfromA(a, va).inverse()

static func veclengstretchrat(vecB, vecT):
	var vecTleng = vecT.length()
	var vecBleng = vecB.length()
	var vecldiff = vecTleng - vecBleng
	return vecldiff/vecBleng

func ovrlefthandtrack(joint_transforms):
	var ovrhandrestdata = OpenXRtrackedhand_funcs.getovrhandrestdata($ovr_left_hand_model)
	var ovrhandpose = OpenXRtrackedhand_funcs.setshapetobonesOVR(joint_transforms, ovrhandrestdata)
	var skel = ovrhandrestdata["skel"]
	$ovr_left_hand_model.transform = ovrhandpose["handtransform"]
	for i in ovrhandrestdata["boneindexes"]:
		if ovrhandpose.has(i):
			skel.set_bone_pose_rotation(i, Quaternion(ovrhandpose[i].basis))
			skel.set_bone_pose_position(i, ovrhandpose[i].origin)

static func setvecstobonesG(ibR, ib0, p1, p2, p3, p4, ovrhandrestdata, ovrhandpose, tRboneposeG):
	var vec1 = p2 - p1
	var vec2 = p3 - p2
	var vec3 = p4 - p3
	var ib1 = ib0+1
	var ib2 = ib0+2
	var ib3 = ib0+3
	
	var Dskel = ovrhandrestdata["skel"]
	
	assert (Dskel.get_bone_parent(ib0) == ibR)
	assert (Dskel.get_bone_parent(ib1) == ib0)
	assert (Dskel.get_bone_parent(ib2) == ib1)
	assert (Dskel.get_bone_parent(ib3) == ib2)

	var t0bonerest = ovrhandrestdata[ib0]
	var t1bonerest = ovrhandrestdata[ib1]
	var t2bonerest = ovrhandrestdata[ib2]
	var t3bonerest = ovrhandrestdata[ib3]

	#tRboneposeG *= ovrhandrestdata[ibR]
	
	var t0bonerestG = tRboneposeG*t0bonerest
	# the rotation is to align within the coordinate frame of the bone (converted from the inverse of the basis tranform from global space vector)
	var t0boneposebasis = rotationtoalign(t1bonerest.origin, t0bonerestG.basis.inverse()*vec1)
	#var t0boneposeorigin = tRboneposeG.affine_inverse()*p1 - t0bonerest.origin
	var t0boneposeorigin = t0bonerestG.affine_inverse()*p1
	var t0bonepose = Transform3D(t0boneposebasis, t0boneposeorigin)
	var t0boneposeG = t0bonerestG*t0bonepose

	var t1bonerestG = t0boneposeG*t1bonerest
	var t1boneposebasis = rotationtoalign(t2bonerest.origin, t1bonerestG.basis.inverse()*vec2)
	var vec1rat = veclengstretchrat(t0boneposeG.basis*t1bonerest.origin, vec1)
	var t1bonepose = Transform3D(t1boneposebasis, t1bonerest.origin*vec1rat)
	var t1boneposeG = t1bonerestG*t1bonepose

	var t2bonerestG = t1boneposeG*t2bonerest
	var t2boneposebasis = rotationtoalign(t3bonerest.origin, t2bonerestG.basis.inverse()*vec3)
	var vec2rat = veclengstretchrat(t1boneposeG.basis*(t2bonerest.origin), vec2)
	var t2bonepose = Transform3D(t2boneposebasis, t2bonerest.origin*vec2rat)
	var t2boneposeG = t2bonerestG*t2bonepose

	var vec3rat = veclengstretchrat(t2boneposeG.basis*(t3bonerest.origin), vec3)
	var t3bonepose = Transform3D(Basis(), t3bonerest.origin*vec3rat)
	
	ovrhandpose[ib0] = t0bonepose
	ovrhandpose[ib1] = t1bonepose
	ovrhandpose[ib2] = t2bonepose
	ovrhandpose[ib3] = t3bonepose

	# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
	# (A.basis, A.origin) * (B.basis, B.origin) * (C.basis, C.origin)
	#  = (A.basis*B.basis*C.basis, A.origin + A.basis*B.origin + A.basis*B.basis*C.origin)

	# (A*B).origin - A.origin = A.basis*B.origin

const carpallist = [ OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL ]

class SkelHand:
	var lr
	var handnode
	var skel
	var handtoskeltransform
	var wristboneindex
	var wristboneresttransform
	var hstw
	var fingerboneindexes
	var fingerboneresttransforms
	
	func extractrestfingerbones(lhandnode, hand):
		handnode = lhandnode
		print(handnode.name)
		skel = handnode.find_child("Skeleton3D")
		lr = "L" if hand == 0 else "R"
		handtoskeltransform = handnode.global_transform.inverse()*skel.global_transform
		wristboneindex = skel.find_bone("Wrist_" + lr)
		wristboneresttransform = skel.get_bone_rest(wristboneindex)
		hstw = handtoskeltransform * wristboneresttransform
		fingerboneindexes = [ ]
		fingerboneresttransforms = [ ]
		for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
			fingerboneindexes.push_back([ ])
			fingerboneresttransforms.push_back([ ])
			for b in ["Metacarpal", "Proximal", "Intermediate", "Distal", "Tip"]:
				var name = f + "_" + b + "_" + lr
				var ix = skel.find_bone(name)
				if ix != -1:
					fingerboneindexes[-1].push_back(ix)
					fingerboneresttransforms[-1].push_back(skel.get_bone_rest(ix) if ix != -1 else null)
				else:
					assert (f == "Thumb" and b == "Intermediate")

	func calchandnodetransform(oxrjps, xrorigintransform, ss):
		var xrt = handnode.get_parent().global_transform.inverse()*xrorigintransform
		
		# solve for handnodetransform where
		# avatarwristtrans = handnode.get_parent().global_transform * handnodetransform * handtoskeltransform * wristboneresttransform
		# avatarwristpos = avatarwristtrans.origin
		# avatarmiddleknucklepos = avatarwristtrans * fingerboneresttransforms[2][0] * fingerboneresttransforms[2][1]
		# handwrist = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_WRIST]
		# handmiddleknuckle = xrorigintransform * oxrjps[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL]
		#  so that avatarwristpos->avatarmiddleknucklepos is aligned along handwrist->handmiddleknuckle
		#  and rotated so that the line between index and ring knuckles are in the same plane
		
		# We want skel.global_transform*wristboneresttransform to have origin xrorigintransform*gg[OpenXRInterface.HAND_JOINT_WRIST].origin
		var wristorigin = xrt*oxrjps[OpenXRInterface.HAND_JOINT_WRIST]

		var middleknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL]
		var leftknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_RING_PROXIMAL if lr == "L" else OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL]
		var rightknuckle = xrt*oxrjps[OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL if lr == "L" else OpenXRInterface.HAND_JOINT_RING_PROXIMAL]

		var middlerestreltransform = fingerboneresttransforms[2][0] * fingerboneresttransforms[2][1]
		var leftrestreltransform = fingerboneresttransforms[3 if lr == "L" else 1][0] * fingerboneresttransforms[3 if lr == "L" else 1][1]
		var rightrestreltransform = fingerboneresttransforms[1 if lr == "L" else 3][0] * fingerboneresttransforms[1 if lr == "L" else 3][1]
		
		var m2g1 = middlerestreltransform
		var skelmiddleknuckle = handnode.transform * hstw * middlerestreltransform

		var m2g1g3 = leftrestreltransform.origin - rightrestreltransform.origin
		var hnbasis = ss.rotationtoalignB(hstw.basis*m2g1.origin, middleknuckle - wristorigin, 
								hstw.basis*m2g1g3, leftknuckle - rightknuckle)
		var hnorigin = wristorigin - hnbasis*hstw.origin

		return Transform3D(hnbasis, hnorigin)

	func calcboneposes(oxrjps, handnodetransform, xrorigintransform, ss):
		var xrt = handnode.get_parent().global_transform.inverse()*xrorigintransform
		var fingerbonetransformsOut = fingerboneresttransforms.duplicate(true)
		for f in range(5):
			var mfg = handnodetransform * hstw
			# (A.basis, A.origin) * (B.basis, B.origin) = (A.basis*B.basis, A.origin + A.basis*B.origin)
			for i in range(len(fingerboneresttransforms[f])-1):
				mfg = mfg*fingerboneresttransforms[f][i]
				# (tIbasis,atIorigin)*fingerboneresttransforms[f][i+1]).origin = mfg.inverse()*kpositions[f][i+1]
				# tIbasis*fingerboneresttransforms[f][i+1] = mfg.inverse()*kpositions[f][i+1] - atIorigin
				var atIorigin = Vector3(0,0,0)  
				var kpositionsfip1 = xrt*oxrjps[ss.carpallist[f] + i+1]
				var tIbasis = ss.rotationtoalignScaled(fingerboneresttransforms[f][i+1].origin, mfg.affine_inverse()*kpositionsfip1 - atIorigin)
				var tIorigin = mfg.affine_inverse()*kpositionsfip1 - tIbasis*fingerboneresttransforms[f][i+1].origin # should be 0
				var tI = Transform3D(tIbasis, tIorigin)
				fingerbonetransformsOut[f][i] = fingerboneresttransforms[f][i]*tI
				mfg = mfg*tI
		return fingerbonetransformsOut

	func copyouttransformstoskel(fingerbonetransformsOut):
		for f in range(len(fingerboneindexes)):
			for i in range(len(fingerboneindexes[f])):
				var ix = fingerboneindexes[f][i]
				var t = fingerbonetransformsOut[f][i]
				skel.set_bone_pose_position(ix, t.origin)
				skel.set_bone_pose_rotation(ix, t.basis.get_rotation_quaternion())
				skel.set_bone_pose_scale(ix, t.basis.get_scale())

func getoxrjointpositions(xr_interface, hand):
	var oxrjps = [ ]
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		oxrjps.push_back(xr_interface.get_hand_joint_position(hand, j))
	return oxrjps


func tracklefthand(gg, xrorigintransform):
	ovrlefthandtrack(gg)
	var oxrjps = [ ]
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		oxrjps.push_back(gg[j].origin)
	var skelhand = skelhandleft
	computeapplyskelhand(skelhand, oxrjps, xrorigintransform)
	
func computeapplyskelhand(skelhand, oxrjps, xrorigintransform):
	var xrt = skelhand.handnode.get_parent().global_transform.inverse()*xrorigintransform
	var handnodetransform = skelhand.calchandnodetransform(oxrjps, xrorigintransform, self)
	var fingerbonetransformsOut = skelhand.calcboneposes(oxrjps, handnodetransform, xrorigintransform, self)
	skelhand.handnode.transform = handnodetransform
	skelhand.copyouttransformstoskel(fingerbonetransformsOut)


func _process(delta):
	var gg = [ ]
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		gg.append(Transform3D(Basis(xr_interface.get_hand_joint_rotation(0, j)), xr_interface.get_hand_joint_position(0, j)))
	tracklefthand(gg, get_parent().global_transform)

	for hand in range(2):
		var oxrjps = getoxrjointpositions(xr_interface, hand)
		var skelhand = (skelhandleft if hand == 0 else skelhandright)
		var xrorigintransform = get_parent().global_transform
		var xrt = skelhand.handnode.get_parent().global_transform.inverse()*xrorigintransform
		var handnodetransform = skelhand.calchandnodetransform(oxrjps, xrorigintransform, self)
		var fingerbonetransformsOut = skelhand.calcboneposes(oxrjps, handnodetransform, xrorigintransform, self)
		skelhand.handnode.transform = handnodetransform
		skelhand.copyouttransformstoskel(fingerbonetransformsOut)


func _on_xr_controller_3d_right_button_pressed(name):
	print("Name right button pressed ", name)
	var gg = [ ]
	var hand = 0
	for j in range(OpenXRInterface.HAND_JOINT_MAX):
		var jointradius = xr_interface.get_hand_joint_radius(hand, j)
		var handjointflags = xr_interface.get_hand_joint_flags(hand, j);
		# (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_VALID)
		# (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_TRACKED)
		gg.append(Transform3D(Basis(xr_interface.get_hand_joint_rotation(hand, j)), xr_interface.get_hand_joint_position(hand, j)))

	if get_node("../../MQTT").socket != null:
		get_node("../../MQTT").publish("hand/2", "small")
		get_node("../../MQTT").publish("hand", var_to_str(gg))


func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_Y:
				get_node("../../MQTT").publish("hand", "hi there")
				get_node("../../MQTT").publish("hand/1", "lo there")

			if event.keycode == KEY_U:
				var fname = "lefthandcurl.txt"
				#fname = "leftthumbup.txt"
				var gg = str_to_var(FileAccess.open("res://addons/xr-autohandtracker/openxrhanddata/"+fname, FileAccess.READ).get_as_text())
				for i in range(len(gg)):
					gg[i].origin += Vector3(-0.3,0.7,0)
					get_node("../HandJoints/Joints3D/L%d" % i).transform.origin = gg[i].origin 
				tracklefthand(gg, get_parent().global_transform)
