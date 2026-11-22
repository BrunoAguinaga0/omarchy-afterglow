# omarchy-config

Mis personalizaciones de Omarchy (tema Ristretto).

## Qué hay

- `plugins/bibek.lock`: pantalla de bloqueo con tarjeta de música, aura de colores que reacciona a la música (cava), clima, protector de pantalla con la portada y aviso "ahora suena". Basado en [omarchy-better-lock](https://github.com/BibekBhusal0/omarchy-better-lock) (MIT).
- `plugins/skyhonnor.performance`: [omarchy-performance](https://github.com/SkyHonnor/omarchy-performance) (MIT) con la opción `compact` (un solo ícono).
- `plugins/bruno.bar`: barra en islas flotantes (clon de `omarchy.bar`).
- `plugins/bruno.workspaces`: escritorios con pastilla animada e íconos de apps.
- `plugins/bruno.clock`: reloj que se corre a la derecha cuando suena música (opción `music`: `hide` / `only`).
- `plugins/bruno.music`: mini reproductor en la barra.
- `plugins/bruno.control`: centro de control (red, sonido, luz nocturna, no molestar).
- `plugins/bruno.osd`: avisos de volumen y brillo rediseñados.
- `config/omarchy/shell.json`: orden de la barra, idle y plugins activos.
- `config/omarchy/lock.json`: opciones del bloqueo (formato de hora, estilo del aura, protector, aviso).
- `config/hypr/hyprland.lua`: esquinas redondeadas (al final del archivo).
- `state/`: interruptores de Omarchy, tema y fondo elegidos.

## Guardar cambios

```bash
./sync.sh
git status
git commit -am "..." && git push
```

## Restaurar en otra compu

```bash
gh repo clone BrunoAguinaga0/omarchy-config
cd omarchy-config
omarchy pkg add cava      # para que el aura reaccione a la música
./restore.sh
```

`restore.sh` copia los plugins y la config, los interruptores de Omarchy (`state/toggles`: ventanas de vidrio, sin espacios, esquinas redondeadas, protector de terminal apagado), aplica el tema y el fondo (`state/theme`, `state/background`), enlaza el plugin de Superwhisper si la app está instalada y reinicia el shell. Todo lo que reemplaza queda antes en `*.bak.<fecha>`; no borra nada.

La ciudad del clima solo se guarda si se eligió a mano; si no, Omarchy la detecta por IP.

Los clones (`bruno.bar`, `bruno.clock`, `bruno.osd`, `bruno.workspaces`) salen de la versión de Omarchy de noviembre 2026; con una versión mucho más nueva puede hacer falta volver a clonar el original y reaplicar los cambios.
