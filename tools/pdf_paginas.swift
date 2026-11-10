// Herramienta para consultar los PDF de diseño (docs/pdf/, fuera de git) sin abrirlos.
// Usa PDFKit de macOS; no hace falta instalar nada.
//
//   swift tools/pdf_paginas.swift info   <pdf>
//   swift tools/pdf_paginas.swift texto  <pdf> [pag ...]            texto de cada página
//   swift tools/pdf_paginas.swift render <pdf> <carpeta> <ancho> <pag> [pag ...]
//                                                                     PNG de cada página
//   swift tools/pdf_paginas.swift hoja   <pdf> <salida.jpg> <desde> <hasta> [columnas]
//                                                                     miniaturas numeradas
//
// Las páginas se cuentan desde 1, como en el visor de PDF.
// Para ver detalle de pixel art, render a 4000 de ancho (cada píxel de la maqueta del HUD
// mide ~12,7 px a esa escala). Para leer una lámina, 1600 basta.
import AppKit
import PDFKit

let args = CommandLine.arguments
func uso() -> Never {
    print("uso: info|texto|render|hoja <pdf> ... (ver cabecera del script)")
    exit(1)
}
guard args.count >= 3, let doc = PDFDocument(url: URL(fileURLWithPath: args[2])) else { uso() }

func imagen(_ n: Int, ancho: CGFloat) -> NSImage {
    let page = doc.page(at: n - 1)!
    let caja = page.bounds(for: .mediaBox)
    let alto = ancho * caja.height / caja.width
    return page.thumbnail(of: NSSize(width: ancho, height: alto), for: .mediaBox)
}

func guardar(_ img: NSImage, _ ruta: String, jpg: Bool) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    let datos = jpg
        ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
        : rep.representation(using: .png, properties: [:])!
    try! datos.write(to: URL(fileURLWithPath: ruta))
}

switch args[1] {
case "info":
    let b = doc.page(at: 0)!.bounds(for: .mediaBox)
    print("páginas: \(doc.pageCount)  tamaño: \(Int(b.width))×\(Int(b.height)) pt")

case "texto":
    let paginas = args.count > 3 ? args[3...].map { Int($0)! } : Array(1...doc.pageCount)
    for n in paginas {
        let t = (doc.page(at: n - 1)?.string ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        print("[p. \(n)] \(t)")
    }

case "render":
    guard args.count >= 6 else { uso() }
    let ancho = CGFloat(Double(args[4])!)
    for a in args[5...] {
        let n = Int(a)!
        let ruta = "\(args[3])/pagina_\(n).png"
        guardar(imagen(n, ancho: ancho), ruta, jpg: false)
        print(ruta)
    }

case "hoja":
    guard args.count >= 6 else { uso() }
    let desde = Int(args[4])!, hasta = min(Int(args[5])!, doc.pageCount)
    let cols = args.count > 6 ? Int(args[6])! : 4
    let w: CGFloat = 420
    let b = doc.page(at: 0)!.bounds(for: .mediaBox)
    let h = w * b.height / b.width
    let n = hasta - desde + 1
    let filas = (n + cols - 1) / cols
    let hoja = NSImage(size: NSSize(width: w * CGFloat(cols), height: (h + 22) * CGFloat(filas)))
    hoja.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: hoja.size).fill()
    for (i, p) in (desde...hasta).enumerated() {
        let c = i % cols, f = filas - 1 - i / cols
        let x = CGFloat(c) * w, y = CGFloat(f) * (h + 22)
        imagen(p, ancho: w).draw(in: NSRect(x: x, y: y + 22, width: w, height: h))
        ("p. \(p)" as NSString).draw(at: NSPoint(x: x + 4, y: y + 3),
            withAttributes: [.font: NSFont.boldSystemFont(ofSize: 15), .foregroundColor: NSColor.red])
    }
    hoja.unlockFocus()
    guardar(hoja, args[3], jpg: true)
    print(args[3])

default:
    uso()
}
