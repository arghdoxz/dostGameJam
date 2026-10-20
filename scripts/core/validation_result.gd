class_name ValidationResult
extends RefCounted
## Outcome of RulesEngine.validate: an ok flag and, when rejected, a reason.

var ok: bool = true
var reason: String = ""


static func accept() -> ValidationResult:
	return ValidationResult.new()


static func reject(p_reason: String) -> ValidationResult:
	var r: ValidationResult = ValidationResult.new()
	r.ok = false
	r.reason = p_reason
	return r
