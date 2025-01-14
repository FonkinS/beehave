class_name GdFunctionDescriptor
extends RefCounted

var _is_virtual :bool
var _is_static :bool
var _is_engine :bool
var _is_coroutine :bool
var _name :String
var _line_number :int
var _return_type :Variant
var _return_class :String
var _args : Array[GdFunctionArgument]
var _varargs :Array[GdFunctionArgument]


func _init(name :String,
	line_number :int,
	is_virtual :bool,
	is_static :bool,
	is_engine :bool,
	return_type :Variant,
	return_class :String,
	args : Array[GdFunctionArgument],
	varargs :Array[GdFunctionArgument] = []):
	_name = name
	_line_number = line_number
	_return_type = return_type
	_return_class = return_class
	_is_virtual = is_virtual
	_is_static = is_static
	_is_engine = is_engine
	_is_coroutine = false
	_args = args
	_varargs = varargs


func name() -> String:
	return _name


func line_number() -> int:
	return _line_number


func is_virtual() -> bool:
	return _is_virtual


func is_static() -> bool:
	return _is_static


func is_engine() -> bool:
	return _is_engine


func is_vararg() -> bool:
	return not _varargs.is_empty()


func is_coroutine() -> bool:
	return _is_coroutine


func is_parameterized() -> bool:
	for current in _args:
		var arg :GdFunctionArgument = current
		if arg.name() == GdFunctionArgument.ARG_PARAMETERIZED_TEST:
			return true
	return false


func is_private() -> bool:
	return name().begins_with("_") and not is_virtual()


func return_type() -> Variant:
	return _return_type


func return_type_as_string() -> String:
	if return_type() == TYPE_OBJECT and not _return_class.is_empty():
		return _return_class
	return GdObjects.type_as_string(return_type())


func args() -> Array[GdFunctionArgument]:
	return _args


func varargs() -> Array[GdFunctionArgument]:
	return _varargs


func typeless() -> String:
	var func_signature := ""
	if _return_type is StringName:
		func_signature = "func %s(%s) -> %s:" % [name(), typeless_args(), _return_type]
	elif _return_type == TYPE_NIL:
		func_signature = "func %s(%s) -> void:" % [name(), typeless_args()]
	elif _return_type == GdObjects.TYPE_VARIANT:
		func_signature = "func %s(%s) -> Variant:" % [name(), typeless_args()]
	else:
		func_signature = "func %s(%s) -> %s:" % [name(), typeless_args(), return_type_as_string()]
	return "static " + func_signature if is_static() else func_signature


func typeless_args() -> String:
	var collect := PackedStringArray()
	for arg in args():
		if arg.has_default():
			collect.push_back(  arg.name() + "=" + arg.value_as_string())
		else:
			collect.push_back(arg.name())
	for arg in varargs():
		collect.push_back(arg.name() + "=" + arg.value_as_string())
	return ", ".join(collect)


func typed_args() -> String:
	var collect := PackedStringArray()
	for arg in args():
		collect.push_back(arg._to_string())
	for arg in varargs():
		collect.push_back(arg._to_string())
	return ", ".join(collect)


func _to_string() -> String:
	var fsignature := "virtual " if is_virtual() else ""
	if _return_type == TYPE_NIL:
		return fsignature + "[Line:%s] func %s(%s):" % [line_number(), name(), typed_args()]
	var func_template := fsignature + "[Line:%s] func %s(%s) -> %s:"
	if is_static():
		func_template= "[Line:%s] static func %s(%s) -> %s:"
	return func_template % [line_number(), name(), typed_args(), return_type_as_string()]


# extract function description given by Object.get_method_list()
static func extract_from(method_descriptor :Dictionary) -> GdFunctionDescriptor:
	var function_flags :int = method_descriptor["flags"]
	var is_virtual :bool = function_flags & METHOD_FLAG_VIRTUAL
	var is_static :bool = function_flags & METHOD_FLAG_STATIC
	var is_vararg :bool = function_flags & METHOD_FLAG_VARARG
	var is_const :bool = function_flags & METHOD_FLAG_CONST
	var is_core :bool = function_flags & METHOD_FLAG_OBJECT_CORE
	var is_default :bool = function_flags & METHOD_FLAGS_DEFAULT
	#prints("is_virtual: ", is_virtual)
	#prints("is_static: ", is_static)
	#prints("is_const: ", is_const)
	#prints("is_core: ", is_core)
	#prints("is_default: ", is_default)
	#prints("is_vararg: ", is_vararg)
	return GdFunctionDescriptor.new(
		method_descriptor["name"],
		-1,
		is_virtual,
		is_static,
		true,
		_extract_return_type(method_descriptor["return"]),
		method_descriptor["return"]["class_name"],
		_extract_args(method_descriptor),
		_build_varargs(is_vararg)
	)

# temporary exclude GlobalScope enums
const enum_fix := [
	"Side",
	"Corner",
	"Orientation",
	"ClockDirection",
	"HorizontalAlignment",
	"VerticalAlignment",
	"InlineAlignment",
	"EulerOrder",
	"Error",
	"Key",
	"MIDIMessage",
	"MouseButton",
	"MouseButtonMask",
	"JoyButton",
	"JoyAxis",
	"PropertyHint",
	"PropertyUsageFlags",
	"MethodFlags",
	"Variant.Type",
	"Control.LayoutMode"]

static func _extract_return_type(return_info :Dictionary) -> Variant:
	var type :int = return_info["type"]
	var usage :int = return_info["usage"]
	if type == TYPE_INT and usage & PROPERTY_USAGE_CLASS_IS_ENUM:
		var enum_value :Variant = return_info["class_name"]
		# GD-110: bug Error is not work as enum, convert it to int
		if enum_fix.has(enum_value):
			return TYPE_INT
		return enum_value
	if type == TYPE_NIL and usage & PROPERTY_USAGE_NIL_IS_VARIANT:
		return GdObjects.TYPE_VARIANT
	return type


static func _extract_args(method_descriptor :Dictionary) -> Array[GdFunctionArgument]:
	var args :Array[GdFunctionArgument] = []
	var arguments :Array = method_descriptor["args"]
	var defaults :Array = method_descriptor["default_args"]
	# iterate backwards because the default values are stored from right to left
	while not arguments.is_empty():
		var arg :Dictionary = arguments.pop_back()
		var arg_name := _argument_name(arg)
		var arg_type := _argument_type(arg)
		var arg_default := GdFunctionArgument.UNDEFINED
		if not defaults.is_empty():
			arg_default = _argument_default_value(arg, defaults.pop_back())
		args.push_front(GdFunctionArgument.new(arg_name, arg_type, arg_default))
	return args


static func _build_varargs(is_vararg :bool) -> Array[GdFunctionArgument]:
	var varargs :Array[GdFunctionArgument] = []
	if not is_vararg:
		return varargs
	# if function has vararg we need to handle this manually by adding 10 default arguments
	var type := GdObjects.TYPE_VARARG
	for index in 10:
		varargs.push_back(GdFunctionArgument.new("vararg%d_" % index, type, "\"%s\"" % GdObjects.TYPE_VARARG_PLACEHOLDER_VALUE))
	return varargs


static func _argument_name(arg :Dictionary) -> String:
	# add suffix to the name to prevent clash with reserved names
	return (arg["name"] + "_") as String


static func _argument_type(arg :Dictionary) -> int:
	var type :int = arg["type"]
	if type == TYPE_OBJECT:
		if arg["class_name"] == "Node":
			return GdObjects.TYPE_NODE
	return type


static func _argument_type_as_string(arg :Dictionary) -> String:
	var type := _argument_type(arg)
	match type:
		TYPE_NIL:
			return ""
		TYPE_OBJECT:
			var clazz_name :String = arg["class_name"]
			if not clazz_name.is_empty():
				return clazz_name
			return ""
		_:
			return GdObjects.type_as_string(type)


static func _argument_default_value(arg :Dictionary, default_value) -> String:
	if default_value == null:
		return "null"
	var type := _argument_type(arg)
	match type:
		TYPE_NIL, TYPE_RID:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_STRING:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_STRING_NAME:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_BOOL:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_RECT2, TYPE_RECT2I:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_TRANSFORM2D, TYPE_TRANSFORM3D:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_PACKED_COLOR_ARRAY:
			return GdDefaultValueDecoder.decode(type, default_value)
		TYPE_OBJECT:
			var clazz_name := arg["class_name"] as String
			if default_value == null:
				return "null"
	if GdObjects.is_primitive_type(default_value):
		return str(default_value)
	if GdObjects.is_type_array(type):
		if default_value == null:
			return "[]"
		return str(default_value)
	return "%s(%s)" % [GdObjects.type_as_string(type), str(default_value).trim_prefix("(").trim_suffix(")")]
