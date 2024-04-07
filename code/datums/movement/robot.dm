/*********
* /robot *
*********/
/datum/movement_handler/robot
	expected_host_type = /mob/living/silicon/robot
	VAR_PROTECTED/mob/living/silicon/robot/robot

/datum/movement_handler/robot/New(host)
	..()
	src.robot = host

/datum/movement_handler/robot/Destroy()
	robot = null
	. = ..()

// Use power while moving.
/datum/movement_handler/robot/use_power/DoMove()
	var/datum/robot_component/actuator/A = robot.get_component("actuator")
	if(!robot.cell_use_power(A.active_usage * robot.power_efficiency))
		return GLOB.MOVEMENT_HANDLED

/datum/movement_handler/robot/use_power/MayMove()
	return robot.is_component_functioning("actuator") ? GLOB.MOVEMENT_PROCEED : GLOB.MOVEMENT_STOP
