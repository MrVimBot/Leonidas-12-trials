class_name Dialogo
extends Resource
## Un diálogo (conversación, cartel, misión...). Se crea en resources/dialogues/ como
## recurso "Dialogo" y se escribe en el campo `texto` del Inspector:
##
##   Kathita: ¡Leonidas, despierta! Los sabios quieren verte.
##   Leonidas: Cinco minutos más...
##   Kathita: ¡Ahora!
##   # esto es un comentario: no se muestra
##
## - Cada línea es un cuadro. Si no cabe, se parte sola en varios cuadros.
## - "Nombre: texto" indica quién habla (aparece en la pestaña). Una línea sin nombre
##   la sigue diciendo el último que habló. Para un texto sin nadie (un cartel),
##   escribe la línea sin "Nombre:" al principio del diálogo.
## - El nombre debe ser corto (máx. 16 letras) para que "Dijo: algo" no se confunda.

const MAX_NOMBRE := 16

@export_multiline var texto := ""


## Lista de {nombre, texto} lista para mostrar.
func lineas() -> Array[Dictionary]:
	return parsear(texto)


static func parsear(t: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var quien := ""
	for linea in t.split("\n"):
		linea = linea.strip_edges()
		if linea.is_empty() or linea.begins_with("#"):
			continue
		var p := linea.find(": ")
		if p > 0 and p <= MAX_NOMBRE:
			quien = linea.substr(0, p).strip_edges()
			linea = linea.substr(p + 2).strip_edges()
		res.append({ "nombre": quien, "texto": linea })
	return res
