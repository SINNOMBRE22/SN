# -*- coding: utf-8 -*-
"""
SinNombre - Python HTTP Proxy
Corregido: manejo de excepciones, logging, validaciones
"""
import socket
import threading
import select
import time
import argparse
import logging
import sys

# ============================
# LOGGING
# ============================
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("SN-Proxy")

# ============================
# ARGUMENTOS
# ============================
parser = argparse.ArgumentParser(description="SinNombre HTTP Proxy")
parser.add_argument("-l", "--local", type=int, required=True, help="Puerto local destino (ej: 22)")
parser.add_argument("-p", "--port", type=int, required=True, help="Puerto escucha (ej: 80)")
parser.add_argument("-c", "--contr", default="", help="Clave X-Pass (opcional)")
parser.add_argument("-r", "--response", default="200", choices=["101", "200"], help="Respuesta HTTP (101/200)")
parser.add_argument("-t", "--texto", default="", help="Texto del status line")
parser.add_argument("--server", default="SinNombre", help="Server header")
args = parser.parse_args()

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = args.port
TARGET_PORT = args.local
PASS = args.contr
STATUS_RESP = args.response
SERVER_NAME = args.server

if args.texto:
    STATUS_TXT = args.texto
elif STATUS_RESP == '101':
    STATUS_TXT = 'SN Switching Protocols'
else:
    STATUS_TXT = 'SN Connection Established'

BUFLEN = 4096 * 4
TIMEOUT = 60

RESPONSE = (
    f'HTTP/1.1 {STATUS_RESP} {STATUS_TXT}\r\n'
    f'Server: {SERVER_NAME}\r\n'
    'Connection: keep-alive\r\n'
    'Content-Length: 0\r\n\r\n'
)


def find_header(head, header):
    """Extrae el valor de un header HTTP de los bytes recibidos."""
    try:
        key = (header + ': ').encode()
        aux = head.find(key)
        if aux == -1:
            return ''
        aux = head.find(b':', aux)
        head = head[aux + 2:]
        aux = head.find(b'\r\n')
        if aux == -1:
            return ''
        return head[:aux].decode(errors='ignore')
    except (ValueError, UnicodeDecodeError):
        return ''


def pick_host(head):
    """Busca el host en varios headers comunes."""
    for h in ('X-Real-Host', 'X-Forward-Host', 'X-Online-Host', 'Host'):
        v = find_header(head, h)
        if v:
            return v
    return ''


class Server(threading.Thread):
    def __init__(self, host, port):
        super().__init__(daemon=True)
        self.running = False
        self.host = host
        self.port = port

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        try:
            self.soc.bind((self.host, self.port))
        except OSError as e:
            logger.error(f"No se pudo escuchar en {self.host}:{self.port} - {e}")
            return
        self.soc.listen(200)
        self.running = True
        logger.info(f"Proxy escuchando en {self.host}:{self.port} -> localhost:{TARGET_PORT}")
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                ConnectionHandler(c, addr).start()
        finally:
            self.running = False
            try:
                self.soc.close()
            except OSError:
                pass


class ConnectionHandler(threading.Thread):
    def __init__(self, client, addr):
        super().__init__(daemon=True)
        self.client = client
        self.addr = addr
        self.client.settimeout(TIMEOUT)

    def run(self):
        try:
            self._handle()
        except Exception as e:
            logger.debug(f"Conexión cerrada ({self.addr}): {e}")
        finally:
            try:
                self.client.close()
            except OSError:
                pass

    def _handle(self):
        data = self.client.recv(BUFLEN)
        if not data:
            return

        # Verificar password si se configuró
        if PASS:
            xpass = find_header(data, 'X-Pass')
            if xpass != PASS:
                self.client.send(b'HTTP/1.1 403 Forbidden\r\n\r\n')
                return

        self.client.send(RESPONSE.encode())

        # Conectar al destino local
        target = socket.socket(socket.AF_INET)
        target.settimeout(TIMEOUT)
        try:
            target.connect(('127.0.0.1', TARGET_PORT))
        except (ConnectionRefusedError, OSError) as e:
            logger.warning(f"No se pudo conectar a localhost:{TARGET_PORT} - {e}")
            target.close()
            return

        self._relay(self.client, target)
        target.close()

    def _relay(self, client, target):
        """Reenvía datos entre cliente y destino."""
        sockets = [client, target]
        timeout_count = 0
        while True:
            try:
                readable, _, errored = select.select(sockets, [], sockets, TIMEOUT)
            except (ValueError, OSError):
                break

            if errored:
                break

            if not readable:
                timeout_count += 1
                if timeout_count >= 3:
                    break
                continue

            timeout_count = 0
            for s in readable:
                try:
                    data = s.recv(BUFLEN)
                except (ConnectionResetError, OSError):
                    return
                if not data:
                    return
                try:
                    out = target if s is client else client
                    out.send(data)
                except (BrokenPipeError, OSError):
                    return


def main():
    logger.info(f"SinNombre Proxy v2.0")
    logger.info(f"Puerto: {LISTENING_PORT} -> {TARGET_PORT}")
    if PASS:
        logger.info(f"Password: habilitado")

    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()

    try:
        while server.running:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Detenido por el usuario")
        server.running = False
        sys.exit(0)


if __name__ == '__main__':
    main()
