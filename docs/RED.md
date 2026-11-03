# Cómo se conectan el máster y los jugadores

## Resumen

**No hace falta ningún servidor central.** La partida vive en el dispositivo del máster,
que hace de anfitrión: la app del máster abre un pequeño servidor WebSocket (puerto
`4040` por defecto) y los jugadores se conectan a él.

```
   Jugador (Android)  ─┐
   Jugador (Windows)  ─┼──►  App del máster  (servidor + partida guardada)
   Jugador (Linux)    ─┘
```

- El máster es la **única fuente de verdad**: valida cada cambio, lo guarda en disco y
  envía a cada jugador **sólo lo que puede ver** (los datos ocultos — peso/valor de
  objetos, notas secretas, monstruos — nunca salen de su dispositivo).
- Los jugadores guardan una copia de la última vista recibida, así pueden **consultar su
  ficha sin conexión** (para editar hace falta que el máster tenga la partida abierta).
- Si se cae la conexión, la app del jugador **reconecta sola**.

## ¿Funciona con datos móviles? ¿Hace falta estar en la misma red?

Depende de dónde esté cada uno. Hay cuatro escenarios:

### 1. Misma wifi (en casa de alguien) — funciona tal cual

Los jugadores ven la partida automáticamente en **Unirse → Partidas en tu red** (la app
del máster la anuncia por la red local) o pegan la invitación.

### 2. Misma mesa pero sin wifi — zona wifi del móvil del máster

El máster activa **compartir datos / zona wifi** en su móvil y los jugadores se conectan a
esa wifi. Para la app es una red local normal: funciona igual que el caso 1 y **no gasta
datos**, porque el tráfico no sale a internet.

> Si el máster juega desde el PC, otro móvil puede compartir la zona wifi y que se
> conecten a ella tanto el PC como los demás.

### 3. Cada uno en su casa o con datos móviles — Tailscale (recomendado)

Aquí está el problema: las operadoras móviles (y muchas fibras) usan **CGNAT**, así que el
dispositivo del máster no puede recibir conexiones desde internet aunque abráis puertos.

La solución más sencilla y gratuita es **[Tailscale](https://tailscale.com)**:

1. Todos (máster y jugadores) instaláis Tailscale (Windows, Linux, Android e iOS).
2. El máster crea su red e invita a los jugadores, o comparte con ellos su dispositivo
   (función *Share* de Tailscale), para no tener que usar todos la misma cuenta.
3. Con Tailscale activado, el dispositivo del máster recibe una IP del tipo `100.x.y.z`.
   La app la detecta y **la incluye en la invitación automáticamente**.
4. Los jugadores pegan la invitación como siempre. Funciona con datos móviles.

Ventajas: no hay que montar nada, el tráfico va **cifrado** (WireGuard) y casi siempre va
directo entre dispositivos. [ZeroTier](https://www.zerotier.com) es una alternativa
equivalente.

### 4. Sin instalar nada más — relay propio

El proyecto incluye un **relay** (carpeta [`relay/`](../relay/README.md)): un servidor
diminuto que sólo reenvía mensajes. El máster y los jugadores abren conexiones *salientes*
hacia él, por eso funciona con CGNAT y datos móviles. La partida sigue guardada en el
dispositivo del máster; el relay no almacena nada.

1. Despliega el relay en cualquier máquina accesible desde internet (un VPS barato o
   gratuito, una Raspberry Pi en casa con el puerto abierto…). Con Docker es un comando.
2. En la app del máster: **Partida → Jugar por internet → URL del relay**
   (`wss://tu-relay.ejemplo.com`).
3. Vuelve a copiar la invitación: ahora incluye el relay. Los jugadores la pegan y listo.

La app prueba **todas** las rutas de la invitación a la vez (IP local, IP de Tailscale,
relay) y usa la primera que responde, así la misma invitación vale para todos los casos.

### Alternativa: abrir un puerto en el router

Si el máster juega desde un PC en casa con IP pública (sin CGNAT), puede redirigir el
puerto TCP `4040` del router a su PC y dar su IP pública en la conexión manual. Es la
opción menos recomendable: expone el puerto a internet y no funciona con CGNAT.

## Consumo de datos

Los mensajes son JSON comprimido. El máster sólo envía la vista de un jugador cuando
cambia algo que ese jugador puede ver. Una sesión de varias horas suele quedarse en
**pocos megas por jugador**.

## Seguridad y privacidad

- Para unirse por primera vez hace falta el **código de 6 letras** de la partida. Después,
  cada dispositivo se identifica con una clave secreta propia, así nadie puede hacerse
  pasar por otro jugador. El máster puede expulsar jugadores y cerrar la partida a nuevos.
- En la red local las conexiones van sin cifrar (`ws://`). Con Tailscale van cifradas. Con
  un relay, usad `wss://` (HTTPS) — ver la guía del relay.
- El **cuaderno de notas del jugador** se guarda sólo en su dispositivo: ni el máster lo ve.
- El **chat** pasa por el dispositivo del máster, que lo reenvía sólo a los miembros de cada
  conversación y no muestra en su app las conversaciones en las que no participa. Aun así,
  técnicamente los mensajes pasan por su dispositivo (en el futuro se puede añadir cifrado
  de extremo a extremo).

## Problemas habituales

| Síntoma | Solución |
|---|---|
| Windows pregunta por el cortafuegos al abrir la partida | Permite el acceso en **redes privadas**. |
| En Linux nadie puede conectar | Abre el puerto: `sudo ufw allow 4040/tcp` (y `40404/udp` para que se anuncie en la red local). |
| La partida no aparece en «Partidas en tu red» | Algunas redes (de empresa, hoteles, algunas zonas wifi) bloquean los anuncios. Usa la invitación. |
| El máster usa Android y los jugadores se desconectan | Android puede pausar las apps en segundo plano. Mantén la app abierta (o usa el PC como anfitrión en sesiones largas). |
| «Este anfitrión está alojando otra partida» | El máster tiene abierta otra partida. Debe abrir la correcta. |
| «Tu identidad no coincide» | Has cambiado de dispositivo o reinstalado. El máster puede asignarte tu personaje desde **Personajes → Asignar a un jugador**. |
