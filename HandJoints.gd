extends Node3D

var hjtips = [ OpenXRInterface.HAND_JOINT_THUMB_TIP, OpenXRInterface.HAND_JOINT_INDEX_TIP, OpenXRInterface.HAND_JOINT_MIDDLE_TIP, 
			   OpenXRInterface.HAND_JOINT_RING_TIP, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]

var hjsticks = [ [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_THUMB_METACARPAL, OpenXRInterface.HAND_JOINT_THUMB_PROXIMAL, OpenXRInterface.HAND_JOINT_THUMB_DISTAL, OpenXRInterface.HAND_JOINT_THUMB_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_INDEX_METACARPAL, OpenXRInterface.HAND_JOINT_INDEX_PROXIMAL, OpenXRInterface.HAND_JOINT_INDEX_INTERMEDIATE, OpenXRInterface.HAND_JOINT_INDEX_DISTAL, OpenXRInterface.HAND_JOINT_INDEX_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_MIDDLE_METACARPAL, OpenXRInterface.HAND_JOINT_MIDDLE_PROXIMAL, OpenXRInterface.HAND_JOINT_MIDDLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_MIDDLE_DISTAL, OpenXRInterface.HAND_JOINT_MIDDLE_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_RING_METACARPAL, OpenXRInterface.HAND_JOINT_RING_PROXIMAL, OpenXRInterface.HAND_JOINT_RING_INTERMEDIATE, OpenXRInterface.HAND_JOINT_RING_DISTAL, OpenXRInterface.HAND_JOINT_RING_TIP ],
				 [ OpenXRInterface.HAND_JOINT_WRIST, OpenXRInterface.HAND_JOINT_LITTLE_METACARPAL, OpenXRInterface.HAND_JOINT_LITTLE_PROXIMAL, OpenXRInterface.HAND_JOINT_LITTLE_INTERMEDIATE, OpenXRInterface.HAND_JOINT_LITTLE_DISTAL, OpenXRInterface.HAND_JOINT_LITTLE_TIP ]
			   ]

var xr_interface : OpenXRInterface
var xr_tracker_head : XRPositionalTracker
var xr_tracker_hands = [ ]
var xr_play_area : PackedVector3Array

@onready var FlatDisplay = $FrontOfPlayer/FlatDisplayMesh/SubViewport/FlatDisplay
@onready var joints3D = $Joints3D
@onready var joints2D = $FrontOfPlayer/Joints2D

var buttonsignalnames = [ 
	"select_button", "menu_button", 
	"trigger_touch", "trigger_click", 
	"grip_touch", "grip_click", 
	"primary_touch", "primary_click", 
	"ax_touch", "ax_button",
	"by_touch", "by_button",
]

# Set up the displayed axes for each hand and each joint of the hand 
func _ready():
	var axes3dscene = load("res://axes3d.tscn")
	var stickscene = load("res://stick.tscn")
	
	for hand in range(2):
		var LRd = "L%d" if hand == 0 else "R%d"
		for j in range(OpenXRInterface.HAND_JOINT_MAX):
			var rj = axes3dscene.instantiate()
			rj.name = LRd % j
			rj.scale = Vector3(0.01, 0.01, 0.01)
			#rj.get_node("SkinPad").visible = true
			#rj.get_node("TipPad").visible = hjtips.has(j)
			#rj.get_node("Sphere").visible = (j > 0)
			rj.get_node("ArrowX").visible = false
			rj.get_node("ArrowY").visible = false
			rj.get_node("ArrowZ").visible = false
			joints3D.add_child(rj)

			var rjf = axes3dscene.instantiate()
			rjf.name = LRd % j
			rjf.scale = Vector3(0.01, 0.01, 0.01)
			var p = flatlefthandjointsfromwrist[j]
			rjf.transform.origin = Vector3(p.x - 0.12, -p.z, p.y) if hand == 0 else Vector3(-p.x + 0.12, -p.z, p.y)
			joints2D.add_child(rjf)

		var LRstick = "L%dt%d" if hand == 0 else "R%dt%d"
		for hjstick in hjsticks:
			for i in range(0, len(hjstick)-1):
				var rstick = stickscene.instantiate()
				var j1 = hjstick[i]
				var j2 = hjstick[i+1]
				rstick.name = LRstick % [j1, j2]
				rstick.scale = Vector3(0.01, 0.01, 0.01)
				joints3D.add_child(rstick)

				var rstickf = stickscene.instantiate()
				rstickf.name = LRstick % [hjstick[i], hjstick[i+1]]
				joints2D.add_child(rstickf)
				rstickf.transform = sticktransform(joints2D.get_node(LRd % j1).transform.origin, joints2D.get_node(LRd % j2).transform.origin)
				
				joints3D.get_node(LRd % hjstick[i+1]).get_node("Sphere").visible = (i > 0)
				
		#var LRpose = "L%s" if hand == 0 else "R%s"
		#for posename in [ "grip", "aim"]:
		#	var rpose = axes3dscene.instantiate()
		#	rpose.name = LRpose % posename
		#	rpose.scale = Vector3(0.05, 0.05, 0.05)
		#	joints3D.add_child(rpose)
			
		var vboxsignals = FlatDisplay.get_node("VBoxTrackers%d" % hand)
		var buttonsig = vboxsignals.get_child(0)
		vboxsignals.remove_child(buttonsig)
		for bn in buttonsignalnames:
			var bs = buttonsig.duplicate()
			bs.text = bn
			bs.name = bn
			vboxsignals.add_child(bs)

	get_node("Joints3D/L0").transform.origin = Vector3(0,1.7,-0.2)



func buttonsignal(name, hand, pressed):
	var buttonsig = FlatDisplay.get_node_or_null("VBoxTrackers%d/%s" % [ hand, name ])
	if buttonsig:
		buttonsig.button_pressed = pressed
	else:
		print("buttonsignal ", hand, " ", name, " ", pressed)
		
func inputfloatchanged(name, value, hand):
	var ifsig = FlatDisplay.get_node_or_null("VSlider%d%s" % [ hand, name ])
	if ifsig:
		ifsig.value = value*100
	else:
		print("inputfloatchanged ", hand, " ", name, " ", value)

func inputvector2changed(name, vector, hand):
	var ifstick = FlatDisplay.get_node_or_null("Thumbstick%d" % hand)
	if ifstick:
		ifstick.get_node("Pos").position = (vector + Vector2(1,1))*(70/2)
	else:
		print("inputvector2changed ", hand, " ", name, " ", vector)
	#print("inputvector2changed ", name)  # it's always primary

# Get the trackers once the interface has been initialized
func set_xr_interface(lxr_interface : OpenXRInterface):
	xr_interface = lxr_interface
	var trackers1 = XRServer.get_trackers(1)
	xr_tracker_head = trackers1["head"]
	var trackers2 = XRServer.get_trackers(2)
	xr_tracker_hands = [ trackers2["left_hand"], trackers2["right_hand"] ]
	xr_play_area = xr_interface.get_play_area()
	print("PlayAreaMode: ", xr_interface.xr_play_area_mode)
	#XR_PLAY_AREA_UNKNOWN = 0
	#XR_PLAY_AREA_3DOF = 1
	#XR_PLAY_AREA_SITTING = 2
	#XR_PLAY_AREA_ROOMSCALE = 3
	#XR_PLAY_AREA_STAGE = 4
	if xr_play_area:
		print("Play area feature supported (NOT YET DRAWN)", xr_play_area)
	else:
		print("xr_interface.get_play_area() returns [ ]")
	

	print("action_sets: ", xr_interface.get_action_sets())

	# wire up the signals from the hand trackers
	for hand in range(2):
		xr_tracker_hands[hand].button_pressed.connect(buttonsignal.bind(hand, true))
		xr_tracker_hands[hand].button_released.connect(buttonsignal.bind(hand, false))
		xr_tracker_hands[hand].input_float_changed.connect(inputfloatchanged.bind(hand))
		xr_tracker_hands[hand].input_vector2_changed.connect(inputvector2changed.bind(hand))
		


# input_float_changed(name: String, value: float)Emitted when a trigger or similar input on this tracker changes value.
# input_vector2_changed(name: String, vector: Vector2)Emitted when a thumbstick or thumbpad on this tracker moves.
# pose_changed(pose: XRPose)Emitted when the state of a pose tracked by this tracker changes.
# pose_lost_tracking(pose: XRPose)Emitted when a pose tracked by this tracker stops getting updated tracking data.
# profile_changed(role: String)Emitted when the profile of our tracker changes.

func fingertiptouchbutton():
	print("PlayArea ", xr_interface.get_play_area())
	print("PlayAreaMode: ", xr_interface.xr_play_area_mode)

func rotationtoalign(a, b):
	var axis = a.cross(b).normalized();
	if (axis.length_squared() != 0):
		var dot = a.dot(b)/(a.length()*b.length())
		dot = clamp(dot, -1.0, 1.0)
		var angle_rads = acos(dot)
		return Basis(axis, angle_rads)
	return Basis()

func sticktransform(j1, j2):
	var b = rotationtoalign(Vector3(0,1,0), j2 - j1)
	var d = (j2 - j1).length()
	return Transform3D(b, (j1 + j2)*0.5).scaled_local(Vector3(0.01, d, 0.01))

func basisfrom(a, b):
	var vx = (b - a).normalized()
	var vy = vx.cross(-a.normalized())
	var vz = vx.cross(vy)
	return Basis(vx, vy, vz)

func arrowYbasis(v):
	var axisy = v
	var axisxL = Vector3(v.y, -v.x, 0.0) if abs(v.x) < abs(v.z) else Vector3(0.0, -v.x, v.z)
	var vlen = v.length()
	var axisx = axisxL * (vlen/axisxL.length())
	var axisz = axisx.cross(axisy)/(vlen if vlen != 0 else vlen)
	return Basis(axisx, axisy, axisz)
	

func _process(delta):
	if xr_interface != null:
		for hand in range(2):
			var wristtransform = Transform3D(Basis(xr_interface.get_hand_joint_rotation(hand, OpenXRInterface.HAND_JOINT_WRIST)), 
												   xr_interface.get_hand_joint_position(hand, OpenXRInterface.HAND_JOINT_WRIST))
			var LRd = "L%d" if hand == 0 else "R%d"
			for j in range(OpenXRInterface.HAND_JOINT_MAX):
				var jointradius = xr_interface.get_hand_joint_radius(hand, j)
				var handjointflags = xr_interface.get_hand_joint_flags(hand, j);

				var joint3d = $Joints3D.get_node(LRd % j)
				joint3d.get_node("InvalidMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_VALID)
				joint3d.get_node("UntrackedMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_TRACKED)
				var handjointtransform = Transform3D(Basis(xr_interface.get_hand_joint_rotation(hand, j)), xr_interface.get_hand_joint_position(hand, j))
				joint3d.transform = handjointtransform.scaled_local(Vector3(jointradius, jointradius, jointradius))

				var joint2d = joints2D.get_node(LRd % j)
				joint2d.get_node("InvalidMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_VALID)
				joint2d.get_node("UntrackedMesh").visible = not (handjointflags & OpenXRInterface.HAND_JOINT_POSITION_TRACKED)
				joint2d.transform.basis = Basis(xr_interface.get_hand_joint_rotation(hand, j))*0.013

			var LRstick = "L%dt%d" if hand == 0 else "R%dt%d"
			for hjstick in hjsticks:
				for i in range(0, len(hjstick)-1):
					var j1 = hjstick[i]
					var j2 = hjstick[i+1]
					var rstick = $Joints3D.get_node(LRstick % [j1, j2])
					rstick.transform = sticktransform($Joints3D.get_node(LRd % j1).transform.origin, $Joints3D.get_node(LRd % j2).transform.origin)

			#var LRpose = "L%s" if hand == 0 else "R%s"
			#for posename in [ "grip", "aim"]:
			#	var rpose = $Joints3D.get_node(LRpose % posename)
			#	var xrpose = xr_tracker_hands[hand].get_pose(posename)
			#	if xrpose != null:
			#		rpose.get_node("InvalidMesh").visible = not xrpose.has_tracking_data
			#		rpose.get_node("UntrackedMesh").visible = (xrpose.tracking_confidence == 0)
			#		rpose.transform = xrpose.transform.scaled_local(Vector3(0.05, 0.05, 0.05))

	var fingertipnode = $Joints3D.get_node("R%d" % OpenXRInterface.HAND_JOINT_INDEX_TIP)
	var fingerbuttonnode = $FrontOfPlayer/FingerButton
	var d = (fingertipnode.global_transform.origin - fingerbuttonnode.global_transform.origin).length()
	var touching = (d < 0.03)
	if !($FrontOfPlayer/FingerButton/Touched.visible) and touching:
		fingertiptouchbutton()
	$FrontOfPlayer/FingerButton/Touched.visible = touching

var flatlefthandjointsfromwrist = [
	Vector3(0.000861533, -0.0012695, -0.0477441), Vector3(0, 0, 0), Vector3(0.0315846, -0.0131271, -0.0329833), Vector3(0.0545926, -0.0174885, -0.0554602), 
	Vector3(0.0757424, -0.0190563, -0.0816979), Vector3(0.0965827, -0.0188126, -0.0947297), Vector3(0.0204946, -0.00802441, -0.0356591), 
	Vector3(0.0235117, -0.00730439, -0.0958373), Vector3(0.0364556, -0.00840877, -0.131404), Vector3(0.0444214, -0.00928009, -0.154306), 
	Vector3(0.0501041, -0.00590578, -0.175658), Vector3(0.00431204, -0.00690232, -0.0335003), Vector3(0.00172306, -0.00253896, -0.0954883), 
	Vector3(0.00447122, 0.00162174, -0.138053), Vector3(0.00599042, 0.00439228, -0.165375), Vector3(0.00627589, 0.0124663, -0.188982), 
	Vector3(-0.0149675, -0.00600582, -0.034718), Vector3(-0.0174363, -0.00651854, -0.0885469), Vector3(-0.0249593, 0.000487596, -0.126097), 
	Vector3(-0.0302005, 0.00494818, -0.151718), Vector3(-0.0342363, 0.0119404, -0.17468), Vector3(-0.0229605, -0.00940424, -0.0340171), 
	Vector3(-0.034996, -0.0136686, -0.0777668), Vector3(-0.0520341, -0.00539365, -0.101889), Vector3(-0.0647082, 0.000211, -0.116692), 
	Vector3(-0.0764616, 0.00869788, -0.133135)
]
