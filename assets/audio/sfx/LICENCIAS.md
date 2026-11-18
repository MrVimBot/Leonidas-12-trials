# Procedencia de los efectos de sonido

Los 19 archivos WAV de esta carpeta son originales, **sintetizados por código,
sin samples externos**, mediante `tools/audio/generar_sfx.py` para este proyecto.
No se han descargado grabaciones, usado bancos de sonidos ni incorporado voces,
música o material de terceros. No requieren atribución a bancos de samples.
Esta nota documenta la procedencia; no modifica la licencia general del proyecto.

Formato: WAV PCM de 16 bits, mono, 44100 Hz; sin bucles. Picos de −3 dBFS
para impactos y volteretas, −6 dBFS para espadas y −9 dBFS para pasos.

Archivos: `paso_1.wav` a `paso_4.wav`, `espada_1.wav`, `espada_2.wav`,
`vasija_romper_1.wav`, `vasija_romper_2.wav`, `piedra_caer_1.wav`,
`piedra_caer_2.wav`, `golpe_enemigo_1.wav`, `golpe_enemigo_2.wav`,
`leonidas_caer.wav`, `barco_golpe_1.wav`, `barco_golpe_2.wav`,
`leonidas_danio_1.wav`, `leonidas_danio_2.wav`, `voltereta_1.wav`,
`voltereta_2.wav`.

Regenerar todos: `python3 tools/audio/generar_sfx.py`.
Regenerar seleccionados: `python3 tools/audio/generar_sfx.py paso_1 voltereta`.
También se acepta una familia completa, por ejemplo `espada` o `vasija_romper`.

En el diccionario `SONIDOS` del generador, bajar `pitch` hace el sonido más
grave; subir `duration` lo alarga (respetar `limits`); bajar `peak_db` lo hace
más suave; bajar `brightness` reduce los agudos; cambiar `seed` varía la textura.
Cada entrada tiene su propia semilla y sus parámetros independientes.

La cerámica y el chapoteo son aproximaciones estilizadas por síntesis. Conviene
escuchar todos los efectos, especialmente pasos y espadas en repetición, antes
de integrarlos. La verificación automática de formato y niveles no sustituye
una revisión auditiva en el reproductor del Mac.
