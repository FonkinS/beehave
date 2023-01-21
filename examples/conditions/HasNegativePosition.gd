extends ConditionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	if actor.position.x < 0.0 and actor.position.y < 0.0:
		return SUCCESS
	else:
		return FAILURE
