# -*- coding: utf-8 -*-
import socket, threading, select, time, argparse

parser = argparse.ArgumentParser()
parser.add_argument("-l", "--local", help="Puerto local destino (ej: 22)")
parser.add_argument("-p", "--port", help="Puerto escucha (ej: 80)")
parser.add_argument("-c", "--contr", help="Clave X-Pass (opcional)")
parser.add_argument("-r", "--response", help="Respuesta HTTP (101/200)")
parser.add_argument("-t", "--texto", help="Texto del status line")
parser.add_argument("--server", help="Server header")
args = parser.parse_args()

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(args.port) if args.port else 0
if LISTENING_PORT <= 0:
    print("Debes ingresar el puerto escucha (-p).")
    raise SystemExit(1)

TARGET_PORT = int(args.local) if args.local else 0
if TARGET_PORT <= 0:
    print("Debes ingresar el puerto destino (-l).")
    raise SystemExit(1)

PASS = str(args.contr) if args.contr else ""
STATUS_RESP = args.response if args.response else '200'

SERVER_NAME = args.server if args.server else "SinNombre"

if args.texto:
    STATUS_TXT = args.texto
elif STATUS_RESP == '101':
    STATUS_TXT = 'SN Switching Protocols'
else:
    STATUS_TXT = 'SN Connection Established'

BUFLEN = 4096 * 4
TIMEOUT = 60

RESPONSE = ('HTTP/1.1 ' + STATUS_RESP + ' ' + STATUS_TXT + '\r\n'
            'Server: ' + SERVER_NAME + '\r\n'
            'Connection: keep-alive\r\n'
            'Content-Length: 0\r\n\r\n')

def find_header(head, header):
    try:
        key = (header + ': ').encode()
        aux = head.find(key)
        if aux == -1:
            return ''
        aux = head.find(b':', aux)
        head = head[aux+2:]
        aux = head.find(b'\r\n')
        if aux == -1:
            return ''
        return head[:aux].decode(errors='ignore')
    except:
        return ''

def pick_host(head):
    # compatible con HTTP Custom
    for h in ('X-Real-Host', 'X-Forward-Host', 'X-Online-Host', 'Host'):
        v = find_header(head, h)
        if v:
            return v
    return ''

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.lock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(200)
        self.running = True
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
            try: self.soc.close()
            except: pass

class ConnectionHandler(threading.Thread):
    def __init__(self, client, addr):
        threading.Thread.__init__(self)
        self.client = client
        self.addr = addr
        self.target = None

    def close(self):
        try:
            self.client.close()
        except:
            pass
        try:
            if self.target:
                self.target.close()
        except:
            pass

    def connect_target(self):
        self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.target.connect(("127.0.0.1", TARGET_PORT))

    def run(self):
        try:
            data = self.client.recv(BUFLEN)

            # Validación opcional X-Pass
            if PASS:
                xpass = find_header(data, 'X-Pass')
                if xpass != PASS:
                    self.client.sendall(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                    self.close()
                    return

            # Leer host solo para compatibilidad (no se usa para conectar)
            _host = pick_host(data)

            # Responder header (101/200) para payload
            self.client.sendall(RESPONSE.encode())

            # Conectar SIEMPRE al destino local
            self.connect_target()

            # Si existe X-Split, consume paquete extra (compat)
            split = find_header(data, 'X-Split')
            if split:
                try: self.client.recv(BUFLEN)
                except: pass

            # tunnel
            self.do_tunnel()
        except:
            pass
        finally:
            self.close()

    def do_tunnel(self):
        socs = [self.client, self.target]
        count = 0
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                break
            if recv:
                for s in recv:
                    try:
                        buf = s.recv(BUFLEN)
                        if not buf:
                            return
                        if s is self.target:
                            self.client.sendall(buf)
                        else:
                            self.target.sendall(buf)
                        count = 0
                    except:
                        return
            if count >= TIMEOUT:
                return

def main():
    print(":-- PythonProxy Direct --:")
    print("Listen:", LISTENING_ADDR, LISTENING_PORT)
    print("Target:", "127.0.0.1", TARGET_PORT)
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    while True:
        time.sleep(2)

if __name__ == '__main__':
    main()
