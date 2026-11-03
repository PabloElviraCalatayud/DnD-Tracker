# Relay de DnD Tracker

Servidor opcional para jugar **por internet sin estar en la misma red** cuando no queréis
usar Tailscale. Es un reenviador "tonto":

```
App del máster ──(saliente)──►  RELAY  ◄──(saliente)── Jugadores
```

- El máster abre una conexión a `/host?room=<id de la partida>&key=<clave secreta>`.
- Cada jugador abre una conexión a `/join?room=<id de la partida>`.
- El relay reenvía los mensajes entre ellos. **No guarda nada**: la partida sigue en el
  dispositivo del máster.
- Como todas las conexiones son salientes, funciona con datos móviles y CGNAT.

Sólo usa la librería estándar de Dart (`dart:io`): no tiene dependencias.

## Ejecutarlo

```bash
dart run bin/relay.dart --port 8080
```

O con Docker:

```bash
docker build -t dndt-relay .
```

```bash
docker run -d --restart unless-stopped -p 8080:8080 --name dndt-relay dndt-relay
```

Comprueba que responde abriendo `http://tu-servidor:8080/` en un navegador.

## Ponerle HTTPS (recomendado)

Sin HTTPS los mensajes viajan sin cifrar. La forma más fácil es poner
[Caddy](https://caddyserver.com) delante, que obtiene el certificado automáticamente.
`Caddyfile`:

```
relay.tudominio.com {
    reverse_proxy localhost:8080
}
```

Después, en la app del máster: **Partida → Jugar por internet → URL del relay** =
`wss://relay.tudominio.com`.

## Dónde alojarlo

Cualquier máquina con IP pública sirve: un VPS barato o de capa gratuita, un servidor
doméstico o una Raspberry Pi con el puerto redirigido en el router. Consume muy poco
(unos pocos MB de RAM).

## Límites

- 500 salas activas, 32 jugadores por sala y mensajes de hasta 4 MB.
- Si el máster se desconecta, los jugadores de su sala se desconectan y la app reintenta
  sola cuando el máster vuelve.
- Sólo puede alojar una sala quien conozca la clave del máster (la clave secreta de su
  dispositivo), así que nadie puede suplantar al anfitrión.
